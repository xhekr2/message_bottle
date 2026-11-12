package com.example.message_bottle_backend.letter.dto;

import java.time.LocalDateTime;

/**
 * 편지 상세. role=RECEIVER일 때 익명 편지의 counterpartUsername은 항상 null이며
 * 발신자를 알 수 있는 값(id, 아이디 등)은 어디에도 없다.
 * parentLetterId는 이 편지가 답장이고 부모 편지를 내가 볼 수 있을 때만 값이 있다.
 */
public record LetterDetailResponse(
        Long id,
        String role,
        String counterpartUsername,
        boolean anonymous,
        String content,
        LocalDateTime sentAt,
        boolean canReply,
        boolean canArchive,
        Long parentLetterId
) {
}
