package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.common.ApiException;
import com.example.message_bottle_backend.letter.dto.BottleResponse;
import com.example.message_bottle_backend.letter.dto.SeaResponse;
import com.example.message_bottle_backend.letter.dto.SeaSlotsRequest;
import com.example.message_bottle_backend.user.User;
import com.example.message_bottle_backend.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 바다의 수용량(10개)·대기열(FIFO)·만료·열람 후 이탈 정리를 한곳에서 처리한다.
 * 사용자 행을 잠근 상태에서만 수용량을 바꾸므로 동시 요청에도 떠 있는 편지가 10개를 넘지 않는다.
 */
@Service
@RequiredArgsConstructor
public class SeaService {

    private static final EnumSet<LetterStatus> ACTIVE = EnumSet.of(LetterStatus.WAITING, LetterStatus.FLOATING);

    private final UserRepository userRepository;
    private final LetterRepository letterRepository;
    private final Clock clock;

    /** 내 바다를 불러온다. 앱이 다시 시작되어 바다를 불러올 때, 열었지만 처리되지 않은 편지는 버려진다. */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public SeaResponse load(Long userId) {
        User owner = lock(userId);
        normalizeLocked(userId, true);
        List<BottleResponse> bottles = bottlesLocked(userId);
        return new SeaResponse(bottles.size(), LetterPolicy.SEA_CAPACITY, owner.getSeaVisibility(), bottles);
    }

    /**
     * 내 바다의 유리병 자리를 저장한다(물고기가 유리병을 밀었을 때). 지금 내 바다에 떠 있는 편지의 자리만 바꾸고,
     * 그 사이 사라진 편지나 남의 편지는 무시한다. 두 유리병이 같은 자리에 놓이는 요청은 거절한다.
     * 열람 상태는 건드리지 않는다(열어 둔 편지를 버리지 않는다).
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public List<BottleResponse> saveSlots(Long userId, SeaSlotsRequest request) {
        lock(userId);
        List<Letter> floating = letterRepository.findByReceiverIdAndStatusOrderBySentAtAscIdAsc(userId, LetterStatus.FLOATING);
        Map<Long, Integer> wanted = new HashMap<>(SeaSlots.resolve(floating));
        Set<Long> seen = new HashSet<>();
        for (SeaSlotsRequest.Entry e : request.slots()) {
            if (!seen.add(e.letterId())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "같은 유리병이 두 번 들어 있습니다.");
            }
            if (wanted.containsKey(e.letterId())) {
                wanted.put(e.letterId(), e.slot());
            }
        }
        if (new HashSet<>(wanted.values()).size() != wanted.size()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "두 유리병이 같은 자리에 있을 수 없습니다.");
        }
        for (Letter l : floating) {
            l.placeAt(wanted.get(l.getId()));
        }
        return toBottles(floating, wanted);
    }

    /** 떠 있는 편지에 자리를 정해 저장하고 돌려준다. 사용자 행을 이미 잠근 트랜잭션 안에서만 호출한다. */
    private List<BottleResponse> bottlesLocked(Long userId) {
        List<Letter> floating = letterRepository.findByReceiverIdAndStatusOrderBySentAtAscIdAsc(userId, LetterStatus.FLOATING);
        Map<Long, Integer> slots = SeaSlots.resolve(floating);
        for (Letter l : floating) {
            Integer slot = slots.get(l.getId());
            if (slot != null && !slot.equals(l.getSeaSlot())) {
                l.placeAt(slot);
            }
        }
        return toBottles(floating, slots);
    }

    private static List<BottleResponse> toBottles(List<Letter> floating, Map<Long, Integer> slots) {
        return floating.stream()
                .filter(l -> slots.containsKey(l.getId()))
                .map(l -> new BottleResponse(l.getId(), l.getSentAt(), slots.get(l.getId())))
                .toList();
    }

    /** 사용자 행을 잠그고 만료·승격을 반영한다. 열람 중인 편지를 버리지 않는다. */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public void normalize(Long userId) {
        lock(userId);
        normalizeLocked(userId, false);
    }

    /** 스케줄러용: 만료된 편지가 남아 있는 수신자 목록. 각 수신자는 {@link #normalize}로 따로 정리한다. */
    @Transactional(readOnly = true)
    public List<Long> receiversWithExpired() {
        return letterRepository.findReceiverIdsWithExpired(ACTIVE, LocalDateTime.now(clock));
    }

    public User lock(Long userId) {
        return userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "존재하지 않는 사용자입니다."));
    }

    /** 사용자 행을 이미 잠근 트랜잭션 안에서만 호출한다. */
    public void normalizeLocked(Long userId, boolean discardOpened) {
        if (discardOpened) {
            letterRepository.discardOpenedFloating(userId);
        }
        letterRepository.expire(userId, ACTIVE, LocalDateTime.now(clock));
        promoteLocked(userId);
    }

    /** 빈자리만큼 대기 편지를 최초 발송 시각이 빠른 순서로 바다에 올린다. */
    public void promoteLocked(Long userId) {
        long floating = letterRepository.countByReceiverIdAndStatus(userId, LetterStatus.FLOATING);
        int free = (int) (LetterPolicy.SEA_CAPACITY - floating);
        if (free <= 0) {
            return;
        }
        for (Letter waiting : letterRepository.findWaiting(userId, PageRequest.of(0, free))) {
            waiting.changeStatus(LetterStatus.FLOATING);
        }
    }

    public int capacityLeft(Long userId) {
        return (int) (LetterPolicy.SEA_CAPACITY - letterRepository.countByReceiverIdAndStatus(userId, LetterStatus.FLOATING));
    }
}
