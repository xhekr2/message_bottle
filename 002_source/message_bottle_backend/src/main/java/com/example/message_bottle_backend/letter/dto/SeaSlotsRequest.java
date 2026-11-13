package com.example.message_bottle_backend.letter.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/** 내 바다의 유리병 자리 저장 요청. 물고기가 유리병을 밀어 자리가 바뀌었을 때 앱이 보낸다. */
public record SeaSlotsRequest(
        @NotNull(message = "유리병 자리를 보내주세요.")
        @Size(max = 10, message = "유리병은 최대 10개입니다.")
        List<@NotNull(message = "유리병 자리를 보내주세요.") @Valid Entry> slots
) {
    public record Entry(
            @NotNull(message = "편지를 선택해주세요.") Long letterId,
            @NotNull(message = "자리를 선택해주세요.")
            @Min(value = 0, message = "자리는 0~10입니다.")
            @Max(value = 10, message = "자리는 0~10입니다.")
            Integer slot
    ) {
    }
}
