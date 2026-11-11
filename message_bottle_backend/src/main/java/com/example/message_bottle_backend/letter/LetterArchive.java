package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.user.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/** 수신자가 보관한(또는 답장해서 자동 보관된) 편지. 삭제는 소프트 삭제라 보낸 편지함·답장 연결에는 영향이 없다. */
@Entity
@Table(name = "letter_archives", indexes = @Index(name = "idx_archive_owner", columnList = "owner_id, deleted_at, archived_at"))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class LetterArchive {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "letter_id", nullable = false, unique = true)
    private Letter letter;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "owner_id", nullable = false)
    private User owner;

    @Column(name = "archived_at", nullable = false)
    private LocalDateTime archivedAt;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    /** 답장을 보내서 자동 보관된 경우 true (받은 편지함 카드의 체크 아이콘) */
    @Column(nullable = false)
    private boolean replied;

    public LetterArchive(Letter letter, User owner, LocalDateTime archivedAt, boolean replied) {
        this.letter = letter;
        this.owner = owner;
        this.archivedAt = archivedAt;
        this.replied = replied;
    }

    public void delete(LocalDateTime now) {
        if (deletedAt == null) {
            deletedAt = now;
        }
    }
}
