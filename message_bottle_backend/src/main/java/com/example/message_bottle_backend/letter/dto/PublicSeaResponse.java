package com.example.message_bottle_backend.letter.dto;

/**
 * 공개 바다 방문자가 보는 전용 응답. 누구의 바다인지(아이디)와 떠 있는 유리병 개수만 담는다.
 * 편지 id·내용·발신자·발송 시각·대기 편지 같은 개별 편지 정보는 절대 넣지 않는다.
 */
public record PublicSeaResponse(String username, int floatingCount) {
}
