package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.letter.dto.PublicSeaResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/sea/users")
@RequiredArgsConstructor
public class PublicSeaController {

    private final SeaVisitService seaVisitService;

    @GetMapping("/{username}")
    public PublicSeaResponse visit(@AuthenticationPrincipal Long viewerId, @PathVariable String username) {
        return seaVisitService.visit(viewerId, username);
    }
}
