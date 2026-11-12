package com.example.message_bottle_backend.letter.dto;

import jakarta.validation.constraints.NotBlank;

/** 공유 바다에는 받는 사람도 익명 선택도 없다. 작성자는 언제나 익명이다. */
public record SharedLetterWriteRequest(
        @NotBlank(message = "편지 내용을 입력해주세요.") String content
) {
}
