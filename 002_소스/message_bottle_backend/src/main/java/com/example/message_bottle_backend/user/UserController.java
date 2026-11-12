package com.example.message_bottle_backend.user;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users/me")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @PatchMapping("/sea-visibility")
    public SeaVisibilityResponse changeSeaVisibility(@AuthenticationPrincipal Long userId,
                                                     @Valid @RequestBody SeaVisibilityRequest request) {
        return userService.changeSeaVisibility(userId, request.visibility());
    }

    @GetMapping("/settings")
    public UserSettingsResponse settings(@AuthenticationPrincipal Long userId) {
        return userService.getSettings(userId);
    }

    @PutMapping("/settings")
    public UserSettingsResponse changeSettings(@AuthenticationPrincipal Long userId,
                                               @Valid @RequestBody UserSettingsRequest request) {
        return userService.changeSettings(userId, request);
    }
}
