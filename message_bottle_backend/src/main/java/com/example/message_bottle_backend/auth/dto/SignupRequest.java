package com.example.message_bottle_backend.auth.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

public record SignupRequest(
        @NotNull(message = "아이디를 입력해주세요.")
        @Pattern(regexp = "[A-Za-z0-9]{4,20}", message = "아이디는 영문, 숫자만 사용하여 4~20자로 입력해주세요.")
        String username,

        @NotNull(message = "비밀번호를 입력해주세요.")
        @Pattern(regexp = "[\\x21-\\x7E]{8,20}", message = "비밀번호는 영문, 숫자, 특수기호만 사용하여 8~20자로 입력해주세요.")
        String password
) {
}
