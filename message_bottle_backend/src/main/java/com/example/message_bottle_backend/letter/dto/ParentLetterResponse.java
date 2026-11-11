package com.example.message_bottle_backend.letter.dto;

import java.time.LocalDateTime;

/**
 * 답장의 부모(이전) 편지. role=SENDER면 내가 보낸 편지, RECEIVER면 내가 받아 보관한 편지다.
 * 익명 편지를 받은 쪽(RECEIVER)에게는 counterpartUsername이 항상 null이다.
 * parentLetterId는 이 편지의 부모도 내가 볼 수 있을 때만 값이 있다.
 */
public record ParentLetterResponse(
        Long id,
        String role,
        String counterpartUsername,
        boolean anonymous,
        String content,
        LocalDateTime sentAt,
        Long parentLetterId
) {
}
