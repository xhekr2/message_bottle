package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.letter.dto.SentDetailResponse;
import com.example.message_bottle_backend.letter.dto.SentItemResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** 보낸 편지함. 삭제 API는 제공하지 않는다(DELETE 요청은 405). */
@RestController
@RequestMapping("/api/sent")
@RequiredArgsConstructor
public class SentController {

    private final LetterService letterService;

    @GetMapping
    public List<SentItemResponse> list(@AuthenticationPrincipal Long userId) {
        return letterService.sent(userId);
    }

    @GetMapping("/{letterId}")
    public SentDetailResponse detail(@AuthenticationPrincipal Long userId, @PathVariable Long letterId) {
        return letterService.sentDetail(userId, letterId);
    }
}
