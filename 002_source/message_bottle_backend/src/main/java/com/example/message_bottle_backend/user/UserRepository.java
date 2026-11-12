package com.example.message_bottle_backend.user;

import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    // Case-sensitive because the column uses a binary collation.
    Optional<User> findByUsername(String username);

    boolean existsByUsername(String username);

    /** 바다 수용량·대기열 변경을 직렬화하기 위해 사용자 행을 잠근다. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from User u where u.id = :id")
    Optional<User> findByIdForUpdate(@Param("id") Long id);

    /** 부분 일치, 대소문자 구분(컬럼이 binary collation). */
    List<User> findByUsernameContainingOrderByUsernameAsc(String part, Pageable pageable);
}
