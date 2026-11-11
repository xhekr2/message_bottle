package com.example.message_bottle_backend.auth;

import com.example.message_bottle_backend.auth.dto.LoginRequest;
import com.example.message_bottle_backend.auth.dto.SignupRequest;
import com.example.message_bottle_backend.auth.dto.TokenResponse;
import com.example.message_bottle_backend.common.ApiException;
import com.example.message_bottle_backend.security.JwtProvider;
import com.example.message_bottle_backend.user.User;
import com.example.message_bottle_backend.user.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HexFormat;

@Service
public class AuthService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtProvider jwtProvider;
    private final long refreshExpirationDays;

    public AuthService(UserRepository userRepository,
                       RefreshTokenRepository refreshTokenRepository,
                       PasswordEncoder passwordEncoder,
                       JwtProvider jwtProvider,
                       @Value("${jwt.refresh-expiration-days}") long refreshExpirationDays) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtProvider = jwtProvider;
        this.refreshExpirationDays = refreshExpirationDays;
    }

    @Transactional
    public void signup(SignupRequest request) {
        if (userRepository.existsByUsername(request.username())) {
            throw duplicate();
        }
        try {
            userRepository.saveAndFlush(new User(request.username(), passwordEncoder.encode(request.password())));
        } catch (DataIntegrityViolationException e) {
            throw duplicate(); // concurrent signup with the same username
        }
    }

    @Transactional
    public TokenResponse login(LoginRequest request) {
        User user = userRepository.findByUsername(request.username())
                .filter(u -> passwordEncoder.matches(request.password(), u.getPasswordHash()))
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "아이디 또는 비밀번호가 올바르지 않습니다."));
        return issueTokens(user.getId());
    }

    /** Rotates the refresh token: the presented one is revoked and a new pair is issued. */
    @Transactional
    public TokenResponse refresh(String rawRefreshToken) {
        LocalDateTime now = LocalDateTime.now();
        RefreshToken stored = refreshTokenRepository.findByTokenHash(hash(rawRefreshToken))
                .filter(t -> t.isUsable(now))
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "유효하지 않거나 만료된 리프레시 토큰입니다."));
        if (!userRepository.existsById(stored.getUserId())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "유효하지 않거나 만료된 리프레시 토큰입니다.");
        }
        stored.revoke(now);
        return issueTokens(stored.getUserId());
    }

    /** Idempotent: unknown or already revoked tokens are ignored. */
    @Transactional
    public void logout(String rawRefreshToken) {
        refreshTokenRepository.findByTokenHash(hash(rawRefreshToken))
                .ifPresent(t -> t.revoke(LocalDateTime.now()));
    }

    private TokenResponse issueTokens(Long userId) {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String rawRefresh = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        refreshTokenRepository.save(new RefreshToken(userId, hash(rawRefresh),
                LocalDateTime.now().plusDays(refreshExpirationDays)));
        return TokenResponse.bearer(jwtProvider.createAccessToken(userId), rawRefresh);
    }

    static String hash(String raw) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(raw.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private ApiException duplicate() {
        return new ApiException(HttpStatus.CONFLICT, "이미 사용 중인 아이디입니다.");
    }
}
