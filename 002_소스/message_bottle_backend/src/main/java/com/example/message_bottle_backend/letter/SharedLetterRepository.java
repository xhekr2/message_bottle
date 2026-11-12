package com.example.message_bottle_backend.letter;

import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface SharedLetterRepository extends JpaRepository<SharedLetter, Long> {

    /** 내가 쓴 것을 뺀, 공유 바다에 남아 있는 편지 수 */
    @Query("select count(s) from SharedLetter s where s.status = com.example.message_bottle_backend.letter.SharedLetterStatus.OPEN "
            + "and s.author.id <> :userId")
    long countOpenNotBy(@Param("userId") Long userId);

    @Query("select s from SharedLetter s where s.status = com.example.message_bottle_backend.letter.SharedLetterStatus.OPEN "
            + "and s.author.id <> :userId order by s.id asc")
    List<SharedLetter> findOpenNotBy(@Param("userId") Long userId, Pageable pageable);

    /** 같은 편지에 동시에 답장해도 한 번만 되도록 행을 잠그고 읽는다. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from SharedLetter s join fetch s.author where s.id = :id")
    Optional<SharedLetter> findByIdForUpdate(@Param("id") Long id);
}
