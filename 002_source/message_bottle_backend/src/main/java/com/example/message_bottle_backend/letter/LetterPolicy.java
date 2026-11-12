package com.example.message_bottle_backend.letter;

public final class LetterPolicy {
    /** 바다에 동시에 떠 있을 수 있는 편지 수 */
    public static final int SEA_CAPACITY = 10;
    /** 최초 발송 후 만료까지의 일수 */
    public static final int EXPIRY_DAYS = 7;
    /** 목록에 보여주는 내용 미리보기 길이 */
    public static final int PREVIEW_LENGTH = 80;

    private LetterPolicy() {
    }

    public static String preview(String content) {
        String firstLine = content.strip().lines().findFirst().orElse("");
        return firstLine.length() <= PREVIEW_LENGTH ? firstLine : firstLine.substring(0, PREVIEW_LENGTH) + "…";
    }
}
