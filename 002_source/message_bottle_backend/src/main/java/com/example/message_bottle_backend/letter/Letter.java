package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.user.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "letters", indexes = {
        @Index(name = "idx_letter_receiver_status", columnList = "receiver_id, status, sent_at"),
        @Index(name = "idx_letter_sender", columnList = "sender_id, sent_at"),
        @Index(name = "idx_letter_expiry", columnList = "status, expires_at")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Letter {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 익명 편지여도 내부 발신자는 보관한다. 수신자 응답 DTO에는 절대 넣지 않는다. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_id", nullable = false)
    private User sender;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "receiver_id", nullable = false)
    private User receiver;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "parent_letter_id")
    private Letter parent;

    /** 공유 바다에서 낚은 편지에 대한 답장이면 그 공유 편지. 이때 parent는 null이다. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "shared_parent_id")
    private SharedLetter sharedParent;

    @Column(nullable = false, columnDefinition = "LONGTEXT")
    private String content;

    @Column(name = "is_anonymous", nullable = false)
    private boolean anonymous;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private LetterStatus status;

    @Column(name = "sent_at", nullable = false)
    private LocalDateTime sentAt;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    /** 수신자가 처음 연 시각. 열었지만 답장·보관·버리기가 없으면 다음 바다 조회 때 버려진다. */
    @Column(name = "opened_at")
    private LocalDateTime openedAt;

    /** 바다에서의 자리(0~10). 떠오르기 전에는 null이고, 내 바다를 불러올 때 정해진다. */
    @Column(name = "sea_slot")
    private Integer seaSlot;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public Letter(User sender, User receiver, Letter parent, String content, boolean anonymous,
                  LetterStatus status, LocalDateTime sentAt) {
        this.sender = sender;
        this.receiver = receiver;
        this.parent = parent;
        this.content = content;
        this.anonymous = anonymous;
        this.status = status;
        this.sentAt = sentAt;
        this.expiresAt = sentAt.plusDays(LetterPolicy.EXPIRY_DAYS);
        this.createdAt = sentAt;
    }

    /** 공유 바다에서 낚은 편지에 대한 답장. */
    public Letter(User sender, User receiver, SharedLetter sharedParent, String content,
                  LetterStatus status, LocalDateTime sentAt) {
        this(sender, receiver, (Letter) null, content, false, status, sentAt);
        this.sharedParent = sharedParent;
    }

    /** 바다에서의 자리(0~10). 떠 있는 동안에만 뜻이 있다. */
    public void placeAt(int slot) {
        this.seaSlot = slot;
    }

    public void changeStatus(LetterStatus status) {
        this.status = status;
    }

    public void markOpened(LocalDateTime now) {
        if (openedAt == null) {
            openedAt = now;
        }
    }
}
