package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.letter.dto.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/shared-sea")
@RequiredArgsConstructor
public class SharedSeaController {

    private final SharedSeaService sharedSeaService;

    @PostMapping("/letters")
    @ResponseStatus(HttpStatus.CREATED)
    public SharedCreatedResponse write(@AuthenticationPrincipal Long userId, @Valid @RequestBody SharedLetterWriteRequest request) {
        return sharedSeaService.write(userId, request);
    }

    @PostMapping("/fish")
    public SharedLetterResponse fish(@AuthenticationPrincipal Long userId) {
        return sharedSeaService.fish(userId);
    }

    @PostMapping("/letters/{sharedId}/replies")
    @ResponseStatus(HttpStatus.CREATED)
    public SharedCreatedResponse reply(@AuthenticationPrincipal Long userId, @PathVariable Long sharedId,
                                       @Valid @RequestBody ReplyRequest request) {
        return sharedSeaService.reply(userId, sharedId, request);
    }
}
