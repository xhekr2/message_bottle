package com.example.message_bottle_backend.letter.dto;

import jakarta.validation.constraints.NotBlank;

/** anonymous를 생략하면 익명이 아닌 것으로 본다. */
public record SendLetterRequest(
        @NotBlank(message = "받는 사람을 선택해주세요.") String receiverUsername,
        @NotBlank(message = "편지 내용을 입력해주세요.") String content,
        Boolean anonymous
) {
    public boolean anonymousOrDefault() {
        return Boolean.TRUE.equals(anonymous);
    }
}
