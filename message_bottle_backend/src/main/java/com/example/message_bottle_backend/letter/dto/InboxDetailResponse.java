package com.example.message_bottle_backend.letter.dto;

import java.time.LocalDateTime;

public record InboxDetailResponse(
        Long archiveId,
        Long letterId,
        String senderUsername,
        boolean anonymous,
        String content,
        LocalDateTime sentAt,
        LocalDateTime archivedAt,
        boolean replied,
        Long parentLetterId
) {
}
