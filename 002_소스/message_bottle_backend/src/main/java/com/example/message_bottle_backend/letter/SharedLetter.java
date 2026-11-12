package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.user.User;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 모든 사용자가 함께 쓰는 공유 바다에 띄운 편지. 작성자는 항상 익명으로 보이지만 서버는 작성자를 보관한다
 * (답장을 작성자의 바다로 전달하기 위해). 작성자 정보는 낚은 사람에게 주는 응답에 절대 넣지 않는다.
 */
@Entity
@Table(name = "shared_letters", indexes = {
        @Index(name = "idx_shared_status", columnList = "status, id")
})
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SharedLetter {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "author_id", nullable = false)
    private User author;

    @Column(nullable = false, columnDefinition = "LONGTEXT")
    private String content;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private SharedLetterStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "replied_at")
    private LocalDateTime repliedAt;

    public SharedLetter(User author, String content, LocalDateTime now) {
        this.author = author;
        this.content = content;
        this.status = SharedLetterStatus.OPEN;
        this.createdAt = now;
    }

    public void markReplied(LocalDateTime now) {
        this.status = SharedLetterStatus.REPLIED;
        this.repliedAt = now;
    }
}
