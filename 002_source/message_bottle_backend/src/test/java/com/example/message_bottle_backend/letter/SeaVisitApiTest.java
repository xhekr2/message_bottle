package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.letter.dto.SendLetterRequest;
import com.example.message_bottle_backend.security.JwtProvider;
import com.example.message_bottle_backend.user.SeaVisibility;
import com.example.message_bottle_backend.user.User;
import com.example.message_bottle_backend.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;

/** 바다 공개 설정과 공개 바다 방문(GET /api/sea/users/{username}). */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SeaVisitApiTest {

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired UserRepository userRepository;
    @Autowired LetterRepository letterRepository;
    @Autowired LetterService letterService;
    @Autowired JwtProvider jwt;

    User alice, bob, carol;

    @BeforeEach
    void setUp() {
        jdbc.update("delete from letter_archives");
        jdbc.update("update letters set parent_letter_id = null");
        jdbc.update("delete from letters");
        jdbc.update("delete from shared_letters");
        jdbc.update("delete from users");
        alice = userRepository.save(new User("Alice1", "x"));
        bob = userRepository.save(new User("Bob123", "x"));
        carol = userRepository.save(new User("Carol1", "x"));
    }

    MockHttpServletRequestBuilder as(MockHttpServletRequestBuilder b, User u) {
        return b.header("Authorization", "Bearer " + jwt.createAccessToken(u.getId())).characterEncoding("UTF-8");
    }

    MvcResult getAs(User as, String url) throws Exception {
        return mvc.perform(as(get(url), as)).andReturn();
    }

    MvcResult patchVisibility(User as, String json) throws Exception {
        return mvc.perform(as(patch("/api/users/me/sea-visibility"), as).contentType(MediaType.APPLICATION_JSON).content(json)).andReturn();
    }

    String body(MvcResult r) throws Exception {
        return r.getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    void makePublic(User u) throws Exception {
        assertEquals(200, patchVisibility(u, "{\"visibility\":\"PUBLIC\"}").getResponse().getStatus());
    }

    long send(User from, User to, String content, boolean anonymous) {
        return letterService.send(from.getId(), new SendLetterRequest(to.getUsername(), content, anonymous)).id();
    }

    /* ---------- 공개 설정 ---------- */

    @Test
    void seaIsPrivateByDefaultAndTheOwnerCanSeeTheSetting() throws Exception {
        assertEquals(SeaVisibility.PRIVATE, userRepository.findById(bob.getId()).orElseThrow().getSeaVisibility());
        assertTrue(body(getAs(bob, "/api/sea/me")).contains("\"visibility\":\"PRIVATE\""));
    }

    @Test
    void ownerCanSwitchBetweenPublicAndPrivate() throws Exception {
        MvcResult toPublic = patchVisibility(bob, "{\"visibility\":\"PUBLIC\"}");
        assertEquals(200, toPublic.getResponse().getStatus());
        assertEquals("{\"visibility\":\"PUBLIC\"}", body(toPublic));
        assertTrue(body(getAs(bob, "/api/sea/me")).contains("\"visibility\":\"PUBLIC\""));

        assertEquals("{\"visibility\":\"PRIVATE\"}", body(patchVisibility(bob, "{\"visibility\":\"PRIVATE\"}")));
        assertEquals(SeaVisibility.PRIVATE, userRepository.findById(bob.getId()).orElseThrow().getSeaVisibility());
    }

    @Test
    void settingOnlyAffectsTheCallerAndRejectsBadInput() throws Exception {
        makePublic(bob);
        assertEquals(SeaVisibility.PRIVATE, userRepository.findById(alice.getId()).orElseThrow().getSeaVisibility(), "다른 사람의 설정은 바뀌지 않는다");

        assertEquals(400, patchVisibility(bob, "{\"visibility\":\"EVERYONE\"}").getResponse().getStatus());
        assertEquals(400, patchVisibility(bob, "{}").getResponse().getStatus());
        assertEquals(400, patchVisibility(bob, "not json").getResponse().getStatus());
        assertEquals(SeaVisibility.PUBLIC, userRepository.findById(bob.getId()).orElseThrow().getSeaVisibility(), "잘못된 요청은 설정을 바꾸지 않는다");
        assertEquals(401, mvc.perform(patch("/api/users/me/sea-visibility").contentType(MediaType.APPLICATION_JSON)
                .content("{\"visibility\":\"PUBLIC\"}")).andReturn().getResponse().getStatus());
    }

    /* ---------- 공개 바다 방문 ---------- */

    @Test
    void publicSeaShowsOnlyTheUsernameAndTheBottleCount() throws Exception {
        makePublic(bob);
        for (int i = 0; i < 3; i++) {
            send(alice, bob, "비밀 내용 " + i, i == 0);
        }

        MvcResult r = getAs(carol, "/api/sea/users/Bob123");

        assertEquals(200, r.getResponse().getStatus());
        assertEquals("{\"username\":\"Bob123\",\"floatingCount\":3}", body(r), "아이디와 개수 외에는 아무것도 없다");
        String b = body(r);
        assertFalse(b.contains("content") || b.contains("비밀") || b.contains("Alice1") || b.contains("sentAt") || b.contains("\"id\""));
    }

    @Test
    void countIsFloatingOnlyAndNeverExceedsTheSeaCapacity() throws Exception {
        makePublic(bob);
        for (int i = 0; i < 12; i++) {
            send(alice, bob, "편지" + i, false); // 10개는 떠 있고 2개는 대기
        }
        assertEquals("{\"username\":\"Bob123\",\"floatingCount\":10}", body(getAs(carol, "/api/sea/users/Bob123")), "대기 편지는 세지 않는다");

        // 보관·버리기·만료된 편지도 세지 않는다
        long a = send(alice, carol, "x", false);
        letterService.archive(carol.getId(), a);
        var floating = letterRepository.findByReceiverIdAndStatusOrderBySentAtAscIdAsc(bob.getId(), LetterStatus.FLOATING);
        letterService.discard(bob.getId(), floating.get(0).getId());
        letterService.archive(bob.getId(), floating.get(1).getId());
        jdbc.update("update letters set expires_at = ? where id = ?", LocalDateTime.now().minusMinutes(1), floating.get(2).getId());

        // 10 - 버림 1 - 보관 1 - 만료 1 + 대기 중이던 2통 중 빈자리로 올라간 것(버림·보관 때 2통 승격) = 9
        assertEquals("{\"username\":\"Bob123\",\"floatingCount\":9}", body(getAs(carol, "/api/sea/users/Bob123")));
    }

    @Test
    void privateSeaIsBlockedOnTheServerForEveryoneButTheOwner() throws Exception {
        send(alice, bob, "비공개 바다의 편지", false);

        MvcResult asCarol = getAs(carol, "/api/sea/users/Bob123");
        assertEquals(403, asCarol.getResponse().getStatus());
        assertFalse(body(asCarol).contains("floatingCount"), "차단되면 개수도 알려주지 않는다");
        assertEquals(403, getAs(alice, "/api/sea/users/Bob123").getResponse().getStatus(), "편지를 보낸 사람도 비공개 바다는 볼 수 없다");

        MvcResult asOwner = getAs(bob, "/api/sea/users/Bob123");
        assertEquals(200, asOwner.getResponse().getStatus(), "자기 바다는 비공개여도 볼 수 있다");
        assertEquals("{\"username\":\"Bob123\",\"floatingCount\":1}", body(asOwner));
    }

    @Test
    void switchingBackToPrivateClosesTheSeaAgain() throws Exception {
        makePublic(bob);
        assertEquals(200, getAs(carol, "/api/sea/users/Bob123").getResponse().getStatus());
        patchVisibility(bob, "{\"visibility\":\"PRIVATE\"}");
        assertEquals(403, getAs(carol, "/api/sea/users/Bob123").getResponse().getStatus());
    }

    @Test
    void unknownUsersAndWrongCaseAreNotFound() throws Exception {
        assertEquals(404, getAs(carol, "/api/sea/users/nobody").getResponse().getStatus());
        makePublic(bob);
        assertEquals(404, getAs(carol, "/api/sea/users/bob123").getResponse().getStatus(), "아이디는 대소문자를 구분한다");
    }

    @Test
    void visitingNeverTouchesTheOwnersLetters() throws Exception {
        makePublic(bob);
        long id = send(alice, bob, "열어 둔 편지", false);
        letterService.get(bob.getId(), id); // 주인이 편지를 열어 둔 상태(아직 처리하지 않음)

        getAs(carol, "/api/sea/users/Bob123");
        getAs(carol, "/api/sea/users/Bob123");

        Letter letter = letterRepository.findById(id).orElseThrow();
        assertEquals(LetterStatus.FLOATING, letter.getStatus(), "방문이 열람 후 이탈 정리를 일으키면 안 된다");
        assertNotNull(letter.getOpenedAt());
    }

    @Test
    void visitingRequiresLogin() throws Exception {
        makePublic(bob);
        assertEquals(401, mvc.perform(get("/api/sea/users/Bob123")).andReturn().getResponse().getStatus());
    }
}
