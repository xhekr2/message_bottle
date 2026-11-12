package com.example.message_bottle_backend.auth;

import com.example.message_bottle_backend.common.ApiException;
import com.example.message_bottle_backend.security.JwtProvider;
import com.example.message_bottle_backend.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class AuthServiceRefreshTest {

    private UserRepository userRepository;
    private RefreshTokenRepository refreshTokenRepository;
    private AuthService service;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        refreshTokenRepository = mock(RefreshTokenRepository.class);
        JwtProvider jwt = new JwtProvider("test-secret-key-0123456789abcdef-test", 60);
        service = new AuthService(userRepository, refreshTokenRepository, mock(PasswordEncoder.class), jwt, 14);
        when(refreshTokenRepository.save(any(RefreshToken.class))).thenAnswer(i -> i.getArgument(0));
    }

    private RefreshToken stored(String raw, LocalDateTime expiresAt) {
        RefreshToken token = new RefreshToken(1L, AuthService.hash(raw), expiresAt);
        when(refreshTokenRepository.findByTokenHash(AuthService.hash(raw))).thenReturn(Optional.of(token));
        return token;
    }

    @Test
    void refreshRotatesToken() {
        RefreshToken old = stored("raw", LocalDateTime.now().plusDays(1));
        when(userRepository.existsById(1L)).thenReturn(true);

        var response = service.refresh("raw");

        assertNotNull(response.accessToken());
        assertNotNull(response.refreshToken());
        assertNotEquals("raw", response.refreshToken());
        assertNotNull(old.getRevokedAt());
    }

    @Test
    void revokedTokenCannotBeReused() {
        RefreshToken old = stored("raw", LocalDateTime.now().plusDays(1));
        old.revoke(LocalDateTime.now());

        assertEquals(401, assertThrows(ApiException.class, () -> service.refresh("raw")).getStatus().value());
    }

    @Test
    void expiredTokenRejected() {
        stored("raw", LocalDateTime.now().minusMinutes(1));

        assertEquals(401, assertThrows(ApiException.class, () -> service.refresh("raw")).getStatus().value());
    }

    @Test
    void unknownTokenRejected() {
        when(refreshTokenRepository.findByTokenHash(anyString())).thenReturn(Optional.empty());

        assertEquals(401, assertThrows(ApiException.class, () -> service.refresh("nope")).getStatus().value());
    }

    @Test
    void logoutRevokesAndIsIdempotent() {
        RefreshToken token = stored("raw", LocalDateTime.now().plusDays(1));

        service.logout("raw");
        LocalDateTime firstRevocation = token.getRevokedAt();
        service.logout("raw");
        service.logout("unknown");

        assertNotNull(firstRevocation);
        assertEquals(firstRevocation, token.getRevokedAt());
        assertFalse(token.isUsable(LocalDateTime.now()));
    }
}
