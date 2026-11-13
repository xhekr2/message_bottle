package com.example.message_bottle_backend.letter.dto;

import java.util.List;

/**
 * 공개 바다 방문자가 보는 전용 응답. 누구의 바다인지(아이디), 떠 있는 유리병 개수, 유리병이 놓인 자리 번호만 담는다.
 * 자리 번호는 주인이 보는 자리와 같다(오름차순이라 어느 편지의 자리인지는 알 수 없다).
 * 편지 id·내용·발신자·발송 시각·대기 편지 같은 개별 편지 정보는 절대 넣지 않는다.
 */
public record PublicSeaResponse(String username, int floatingCount, List<Integer> slots) {
}
