package com.example.message_bottle_backend.user;

/** 내 화면 설정. 사용자 식별 정보는 담지 않는다. */
public record UserSettingsResponse(SeaTone seaTone, int textStep, int idleSeconds, WaveType waveType) {

    public static UserSettingsResponse defaults() {
        return new UserSettingsResponse(UserSettings.DEFAULT_SEA_TONE, UserSettings.DEFAULT_TEXT_STEP,
                UserSettings.DEFAULT_IDLE_SECONDS, UserSettings.DEFAULT_WAVE_TYPE);
    }

    public static UserSettingsResponse of(UserSettings s) {
        return new UserSettingsResponse(s.getSeaTone(), s.getTextStep(), s.getIdleSeconds(), s.getWaveType());
    }
}
