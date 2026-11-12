package com.example.message_bottle_backend.auth;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;

import java.util.Optional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    // Row lock so two concurrent refreshes with the same token cannot both succeed.
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<RefreshToken> findByTokenHash(String tokenHash);
}
