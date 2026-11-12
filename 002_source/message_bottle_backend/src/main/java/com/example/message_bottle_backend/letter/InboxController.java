package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.letter.dto.InboxDetailResponse;
import com.example.message_bottle_backend.letter.dto.InboxItemResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/inbox")
@RequiredArgsConstructor
public class InboxController {

    private final LetterService letterService;

    @GetMapping
    public List<InboxItemResponse> list(@AuthenticationPrincipal Long userId) {
        return letterService.inbox(userId);
    }

    @GetMapping("/{archiveId}")
    public InboxDetailResponse detail(@AuthenticationPrincipal Long userId, @PathVariable Long archiveId) {
        return letterService.inboxDetail(userId, archiveId);
    }

    @DeleteMapping("/{archiveId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Long userId, @PathVariable Long archiveId) {
        letterService.deleteFromInbox(userId, archiveId);
    }
}
