package com.example.message_bottle_backend.user;

import jakarta.validation.constraints.NotNull;

public record SeaVisibilityRequest(@NotNull(message = "공개 여부를 선택해주세요.") SeaVisibility visibility) {
}
