package com.example.message_bottle_backend.letter.dto;

import java.time.LocalDateTime;

/** 낚은 편지. 작성자를 알 수 있는 값은 어디에도 없다. */
public record SharedLetterResponse(Long id, String content, LocalDateTime sentAt) {
}
