package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.common.ApiException;
import com.example.message_bottle_backend.letter.dto.*;
import com.example.message_bottle_backend.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

/** 모두가 함께 쓰는 공유 바다: 익명으로 편지를 띄우고, 남아 있는 편지 중 하나를 무작위로 낚고, 답장한다. */
@Service
@RequiredArgsConstructor
public class SharedSeaService {

    public static final String EMPTY = "남아있는 편지가 없어요!";
    private static final String GONE = "이미 답장이 되었거나 사라진 편지입니다.";

    private final SharedLetterRepository sharedRepository;
    private final UserRepository userRepository;
    private final SeaService seaService;
    private final LetterService letterService;
    private final Clock clock;

    @Transactional
    public SharedCreatedResponse write(Long userId, SharedLetterWriteRequest request) {
        SharedLetter letter = sharedRepository.save(
                new SharedLetter(userRepository.getReferenceById(userId), request.content(), LocalDateTime.now(clock)));
        return new SharedCreatedResponse(letter.getId());
    }

    /** 내가 쓰지 않은 남은 편지 중 무작위 하나. 낚기만 해서는 편지가 사라지지 않는다. 없으면 404. */
    @Transactional(readOnly = true)
    public SharedLetterResponse fish(Long userId) {
        long count = sharedRepository.countOpenNotBy(userId);
        if (count == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, EMPTY);
        }
        int offset = (int) ThreadLocalRandom.current().nextLong(count);
        List<SharedLetter> page = sharedRepository.findOpenNotBy(userId, PageRequest.of(offset, 1));
        if (page.isEmpty()) { // 그 사이 다른 사람이 답장해서 줄어든 경우
            throw new ApiException(HttpStatus.NOT_FOUND, EMPTY);
        }
        SharedLetter s = page.get(0);
        return new SharedLetterResponse(s.getId(), s.getContent(), s.getCreatedAt());
    }

    /**
     * 낚은 편지에 답장한다. 새 편지는 작성자의 바다로 가고(10개·대기열 규칙을 따른다), 그 편지는 공유 바다에서 사라진다.
     * 같은 편지에 동시에 답장해도 한 사람만 성공한다. 응답에는 작성자를 알 수 있는 값이 없다.
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public SharedCreatedResponse reply(Long userId, Long sharedId, ReplyRequest request) {
        SharedLetter shared = sharedRepository.findByIdForUpdate(sharedId)
                .filter(s -> s.getStatus() == SharedLetterStatus.OPEN)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE));
        if (shared.getAuthor().getId().equals(userId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "내가 띄운 편지에는 답장할 수 없습니다.");
        }
        Long authorId = shared.getAuthor().getId();
        // 바다 정리(normalize)가 영속성 컨텍스트를 비우므로, 상태 변경은 그 전에 해서 함께 저장되게 한다(flush 후 비움).
        shared.markReplied(LocalDateTime.now(clock));
        seaService.lock(authorId);
        seaService.normalizeLocked(authorId, false);
        Letter reply = letterService.deliverSharedReplyLocked(userId, shared, request.content());
        return new SharedCreatedResponse(reply.getId());
    }
}
