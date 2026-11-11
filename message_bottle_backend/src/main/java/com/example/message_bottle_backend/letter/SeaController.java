package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.letter.dto.BottleResponse;
import com.example.message_bottle_backend.letter.dto.SeaResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/sea/me")
@RequiredArgsConstructor
public class SeaController {

    private final SeaService seaService;

    /** 내 바다 요약과 떠 있는 편지. 호출하면 열었지만 처리되지 않은 편지는 버려진다(앱 재시작 시 판단). */
    @GetMapping
    public SeaResponse me(@AuthenticationPrincipal Long userId) {
        return seaService.load(userId);
    }

    @GetMapping("/letters")
    public List<BottleResponse> letters(@AuthenticationPrincipal Long userId) {
        return seaService.load(userId).letters();
    }
}
