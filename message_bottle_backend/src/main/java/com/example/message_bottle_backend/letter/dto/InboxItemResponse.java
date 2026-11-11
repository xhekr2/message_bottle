package com.example.message_bottle_backend.letter.dto;

import java.time.LocalDateTime;

public record InboxItemResponse(
        Long archiveId,
        Long letterId,
        String senderUsername,
        boolean anonymous,
        String preview,
        LocalDateTime sentAt,
        LocalDateTime archivedAt,
        boolean replied
) {
}
