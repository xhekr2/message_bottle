package com.example.message_bottle_backend.letter.dto;

import com.example.message_bottle_backend.user.SeaVisibility;

import java.util.List;

/** 내 바다. visibility는 내 바다의 공개 여부(기본 PRIVATE). */
public record SeaResponse(int floatingCount, int capacity, SeaVisibility visibility, List<BottleResponse> letters) {
}
