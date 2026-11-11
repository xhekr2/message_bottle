package com.example.message_bottle_backend.letter.dto;

import java.time.LocalDateTime;

public record SentDetailResponse(Long id, String receiverUsername, boolean anonymous, String content,
                                 LocalDateTime sentAt, Long parentLetterId) {
}
