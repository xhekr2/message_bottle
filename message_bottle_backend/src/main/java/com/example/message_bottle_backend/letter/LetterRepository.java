package com.example.message_bottle_backend.letter;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;

public interface LetterRepository extends JpaRepository<Letter, Long> {

    long countByReceiverIdAndStatus(Long receiverId, LetterStatus status);

    long countByReceiverIdAndStatusAndExpiresAtAfter(Long receiverId, LetterStatus status, LocalDateTime now);

    @EntityGraph(attributePaths = {"sender", "receiver"})
    List<Letter> findByReceiverIdAndStatusOrderBySentAtAscIdAsc(Long receiverId, LetterStatus status);

    /** 대기 편지를 최초 발송 시각이 빠른 순서(FIFO)로 */
    @Query("select l from Letter l where l.receiver.id = :receiverId and l.status = com.example.message_bottle_backend.letter.LetterStatus.WAITING "
            + "order by l.sentAt asc, l.id asc")
    List<Letter> findWaiting(@Param("receiverId") Long receiverId, Pageable pageable);

    @EntityGraph(attributePaths = {"receiver"})
    List<Letter> findBySenderIdOrderBySentAtDescIdDesc(Long senderId);

    @EntityGraph(attributePaths = {"sender", "receiver"})
    java.util.Optional<Letter> findWithUsersById(Long id);

    /** 열었지만 답장·보관·버리기를 하지 않은 떠 있는 편지를 버린 편지로 정리한다. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("update Letter l set l.status = com.example.message_bottle_backend.letter.LetterStatus.DISCARDED "
            + "where l.receiver.id = :receiverId and l.status = com.example.message_bottle_backend.letter.LetterStatus.FLOATING "
            + "and l.openedAt is not null")
    int discardOpenedFloating(@Param("receiverId") Long receiverId);

    /** 최초 발송 후 7일이 지난 대기·떠 있는 편지를 가라앉힌다. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("update Letter l set l.status = com.example.message_bottle_backend.letter.LetterStatus.SUNK "
            + "where l.receiver.id = :receiverId and l.status in :statuses and l.expiresAt <= :now")
    int expire(@Param("receiverId") Long receiverId, @Param("statuses") Collection<LetterStatus> statuses,
               @Param("now") LocalDateTime now);

    @Query("select distinct l.receiver.id from Letter l where l.status in :statuses and l.expiresAt <= :now")
    List<Long> findReceiverIdsWithExpired(@Param("statuses") Collection<LetterStatus> statuses,
                                          @Param("now") LocalDateTime now);
}
