package com.example.message_bottle_backend.letter.dto;

import java.time.LocalDateTime;

/** 바다에 떠 있는 유리병 하나. 발신자 정보는 담지 않는다. */
public record BottleResponse(Long id, LocalDateTime sentAt) {
}
