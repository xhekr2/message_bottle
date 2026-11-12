package com.example.message_bottle_backend.letter;

/**
 * WAITING: 수신자의 바다가 가득 차서 순서를 기다리는 편지
 * FLOATING: 수신자의 바다에 떠 있는 편지
 * SUNK: 발송 7일 후 만료된 편지
 * DISCARDED: 수신자가 버린(X) 편지, 또는 열어 본 뒤 답장·보관 없이 이탈한 편지
 * ARCHIVED: 수신자가 보관한(또는 답장해서 자동 보관된) 편지. 바다 수용량·만료 대상이 아니다.
 */
public enum LetterStatus { WAITING, FLOATING, SUNK, DISCARDED, ARCHIVED }
