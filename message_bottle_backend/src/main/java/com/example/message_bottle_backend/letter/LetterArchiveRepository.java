package com.example.message_bottle_backend.letter;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface LetterArchiveRepository extends JpaRepository<LetterArchive, Long> {

    @EntityGraph(attributePaths = {"letter", "letter.sender"})
    List<LetterArchive> findByOwnerIdAndDeletedAtIsNullOrderByArchivedAtDescIdDesc(Long ownerId);

    @EntityGraph(attributePaths = {"letter", "letter.sender"})
    Optional<LetterArchive> findByIdAndOwnerIdAndDeletedAtIsNull(Long id, Long ownerId);

    @EntityGraph(attributePaths = {"letter"})
    Optional<LetterArchive> findByLetterIdAndOwnerIdAndDeletedAtIsNull(Long letterId, Long ownerId);
}
