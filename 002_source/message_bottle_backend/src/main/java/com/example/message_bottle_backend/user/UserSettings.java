package com.example.message_bottle_backend.user;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import java.time.LocalDateTime;

/**
 * 사용자별 화면 설정(바다 색감, 글자 크기, UI 숨김 대기 시간, 파도 종류).
 * 한 사용자에 한 행이며, 설정을 처음 바꿀 때 만든다. 행이 없으면 기본값으로 본다.
 */
@Entity
@Table(name = "user_settings")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserSettings {

    public static final SeaTone DEFAULT_SEA_TONE = SeaTone.DAY;
    public static final int DEFAULT_TEXT_STEP = 1;
    public static final int DEFAULT_IDLE_SECONDS = 5;
    public static final WaveType DEFAULT_WAVE_TYPE = WaveType.BOTH;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "sea_tone", nullable = false, length = 10)
    private SeaTone seaTone = DEFAULT_SEA_TONE;

    /** 글자 크기 단계(0~4). 앱이 85/100/115/130/140%로 바꿔 쓴다. */
    @Column(name = "text_step", nullable = false)
    private int textStep = DEFAULT_TEXT_STEP;

    @Column(name = "idle_seconds", nullable = false)
    private int idleSeconds = DEFAULT_IDLE_SECONDS;

    @Enumerated(EnumType.STRING)
    @Column(name = "wave_type", nullable = false, length = 10)
    private WaveType waveType = DEFAULT_WAVE_TYPE;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public UserSettings(User user) {
        this.user = user;
    }

    public void change(SeaTone seaTone, int textStep, int idleSeconds, WaveType waveType) {
        this.seaTone = seaTone;
        this.textStep = textStep;
        this.idleSeconds = idleSeconds;
        this.waveType = waveType;
    }

    @PrePersist
    @PreUpdate
    void touch() {
        updatedAt = LocalDateTime.now();
    }
}
