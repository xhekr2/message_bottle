package com.example.message_bottle_backend.letter;

/** 공유 바다의 편지 상태. 답장을 받으면 REPLIED가 되어 공유 바다에서 사라진다. 조회만 하고 닫은 편지는 OPEN으로 남는다. */
public enum SharedLetterStatus {
    OPEN, REPLIED
}
