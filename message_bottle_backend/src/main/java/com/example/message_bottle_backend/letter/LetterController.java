package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.letter.dto.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/letters")
@RequiredArgsConstructor
public class LetterController {

    private final LetterService letterService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public SentLetterResponse send(@AuthenticationPrincipal Long userId, @Valid @RequestBody SendLetterRequest request) {
        return letterService.send(userId, request);
    }

    @GetMapping("/{letterId}")
    public LetterDetailResponse get(@AuthenticationPrincipal Long userId, @PathVariable Long letterId) {
        return letterService.get(userId, letterId);
    }

    @GetMapping("/{letterId}/parent")
    public ParentLetterResponse parent(@AuthenticationPrincipal Long userId, @PathVariable Long letterId) {
        return letterService.parent(userId, letterId);
    }

    @PostMapping("/{letterId}/archive")
    @ResponseStatus(HttpStatus.CREATED)
    public ArchiveResponse archive(@AuthenticationPrincipal Long userId, @PathVariable Long letterId) {
        return letterService.archive(userId, letterId);
    }

    @PostMapping("/{letterId}/discard")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void discard(@AuthenticationPrincipal Long userId, @PathVariable Long letterId) {
        letterService.discard(userId, letterId);
    }

    @PostMapping("/{letterId}/replies")
    @ResponseStatus(HttpStatus.CREATED)
    public SentLetterResponse reply(@AuthenticationPrincipal Long userId, @PathVariable Long letterId,
                                    @Valid @RequestBody ReplyRequest request) {
        return letterService.reply(userId, letterId, request);
    }
}
