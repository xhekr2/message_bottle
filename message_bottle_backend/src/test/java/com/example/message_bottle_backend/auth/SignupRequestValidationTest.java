package com.example.message_bottle_backend.auth;

import com.example.message_bottle_backend.auth.dto.SignupRequest;
import jakarta.validation.Validation;
import jakarta.validation.Validator;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class SignupRequestValidationTest {

    private final Validator validator = Validation.buildDefaultValidatorFactory().getValidator();

    private int violations(String username, String password) {
        return validator.validate(new SignupRequest(username, password)).size();
    }

    @Test
    void validRequest() {
        assertEquals(0, violations("Abc123", "Pass#word12*"));
        assertEquals(0, violations("a".repeat(20), "p".repeat(20)));
    }

    @Test
    void usernameRules() {
        assertEquals(1, violations("abc", "password1"));
        assertEquals(1, violations("a".repeat(21), "password1"));
        assertEquals(1, violations("abc_123", "password1"));
        assertEquals(1, violations("아이디테스트", "password1"));
        assertEquals(1, violations("abc 123", "password1"));
    }

    @Test
    void passwordRules() {
        assertEquals(1, violations("abcd", "short1!"));
        assertEquals(1, violations("abcd", "p".repeat(21)));
        assertEquals(1, violations("abcd", "pass word1"));
        assertEquals(1, violations("abcd", "비밀번호12345678"));
    }
}
