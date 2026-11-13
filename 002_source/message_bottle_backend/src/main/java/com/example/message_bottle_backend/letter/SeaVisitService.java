package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.common.ApiException;
import com.example.message_bottle_backend.letter.dto.PublicSeaResponse;
import com.example.message_bottle_backend.user.SeaVisibility;
import com.example.message_bottle_backend.user.User;
import com.example.message_bottle_backend.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SeaVisitService {

    private final UserRepository userRepository;
    private final LetterRepository letterRepository;
    private final Clock clock;

    /**
     * 다른 사용자의 바다 방문. 본인 바다는 비공개여도 볼 수 있고, 남의 비공개 바다는 서버에서 막는다.
     * 방문은 읽기만 한다: 주인의 대기열·열람 상태를 건드리지 않는다(열었지만 처리하지 않은 편지를 버리는 일은
     * 주인이 자기 바다를 불러올 때만 일어난다).
     */
    @Transactional(readOnly = true)
    public PublicSeaResponse visit(Long viewerId, String username) {
        User owner = userRepository.findByUsername(username)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "존재하지 않는 사용자입니다."));
        boolean isOwner = owner.getId().equals(viewerId);
        if (!isOwner && owner.getSeaVisibility() != SeaVisibility.PUBLIC) {
            throw new ApiException(HttpStatus.FORBIDDEN, "비공개 바다입니다.");
        }
        // 만료 시각이 지난 편지는 아직 정리되지 않았어도 세지 않는다.
        List<Letter> floating = letterRepository.findByReceiverIdAndStatusAndExpiresAtAfterOrderBySentAtAscIdAsc(
                owner.getId(), LetterStatus.FLOATING, LocalDateTime.now(clock));
        // 주인이 보는 자리와 같은 규칙으로 정한다. 어느 편지의 자리인지 드러나지 않게 번호순으로 준다.
        List<Integer> slots = SeaSlots.resolve(floating).values().stream().sorted().toList();
        return new PublicSeaResponse(owner.getUsername(), slots.size(), slots);
    }
}
