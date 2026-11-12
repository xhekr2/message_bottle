package com.example.message_bottle_backend.letter.dto;

import jakarta.validation.constraints.NotBlank;

/** 답장에는 익명 선택이 없다. */
public record ReplyRequest(
        @NotBlank(message = "답장 내용을 입력해주세요.") String content
) {
}
