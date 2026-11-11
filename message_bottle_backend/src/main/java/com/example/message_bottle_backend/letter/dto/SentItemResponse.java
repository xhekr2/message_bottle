package com.example.message_bottle_backend.letter.dto;

import java.time.LocalDateTime;

public record SentItemResponse(Long id, String receiverUsername, boolean anonymous, String preview, LocalDateTime sentAt) {
}
