package com.example.message_bottle_backend.user;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

/** 설정 전체를 한 번에 보낸다(일부만 보내는 요청은 받지 않는다). */
public record UserSettingsRequest(
        @NotNull(message = "바다 색감을 선택해주세요.") SeaTone seaTone,
        @NotNull(message = "글자 크기를 선택해주세요.")
        @Min(value = 0, message = "글자 크기 단계는 0~4입니다.")
        @Max(value = 4, message = "글자 크기 단계는 0~4입니다.")
        Integer textStep,
        @NotNull(message = "UI 숨김 대기 시간을 선택해주세요.")
        @Min(value = 1, message = "UI 숨김 대기 시간은 1~10초입니다.")
        @Max(value = 10, message = "UI 숨김 대기 시간은 1~10초입니다.")
        Integer idleSeconds,
        @NotNull(message = "파도 종류를 선택해주세요.") WaveType waveType
) {
}
