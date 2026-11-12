package com.example.message_bottle_backend.letter.dto;

import java.time.LocalDateTime;

public record SentLetterResponse(Long id, String receiverUsername, boolean anonymous, LocalDateTime sentAt) {
}
