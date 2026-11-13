package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.letter.dto.SendLetterRequest;
import com.example.message_bottle_backend.security.JwtProvider;
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
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.nio.charset.StandardCharsets;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

/** 유리병 자리 저장(PUT /api/sea/me/slots)과 내 바다·공개 바다의 자리. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SeaSlotsApiTest {

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired UserRepository userRepository;
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

    String get(User u, String url) throws Exception {
        return mvc.perform(as(MockMvcRequestBuilders.get(url), u))
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    MvcResult putSlots(User u, String json) throws Exception {
        return mvc.perform(as(put("/api/sea/me/slots"), u).contentType(MediaType.APPLICATION_JSON).content(json)).andReturn();
    }

    void makePublic(User u) throws Exception {
        mvc.perform(as(patch("/api/users/me/sea-visibility"), u).contentType(MediaType.APPLICATION_JSON)
                .content("{\"visibility\":\"PUBLIC\"}")).andReturn();
    }

    long send(User from, User to) {
        return letterService.send(from.getId(), new SendLetterRequest(to.getUsername(), "안녕", false)).id();
    }

    Integer slotOf(long letterId) {
        return jdbc.queryForObject("select sea_slot from letters where id = ?", Integer.class, letterId);
    }

    String entry(long id, int slot) {
        return "{\"letterId\":" + id + ",\"slot\":" + slot + "}";
    }

    @Test
    void newBottlesGetTheFirstFreeSlotsWhenTheOwnerLoadsTheSea() throws Exception {
        long a = send(alice, bob), b = send(alice, bob);

        String sea = get(bob, "/api/sea/me");

        assertTrue(sea.contains("\"slot\":0") && sea.contains("\"slot\":1"), sea);
        assertEquals(0, slotOf(a));
        assertEquals(1, slotOf(b));
    }

    @Test
    void savedSlotsSurviveReloadAndTheVisitorSeesTheSameSlots() throws Exception {
        long a = send(alice, bob), b = send(alice, bob);
        get(bob, "/api/sea/me");
        makePublic(bob);

        // 연쇄 이동: a가 b의 자리로, b는 열한 번째 자리(10)로.
        MvcResult r = putSlots(bob, "{\"slots\":[" + entry(a, 1) + "," + entry(b, 10) + "]}");

        assertEquals(200, r.getResponse().getStatus());
        assertEquals(1, slotOf(a));
        assertEquals(10, slotOf(b));
        String again = get(bob, "/api/sea/me");
        assertTrue(again.contains("\"slot\":1") && again.contains("\"slot\":10"), again);
        assertEquals("{\"username\":\"Bob123\",\"floatingCount\":2,\"slots\":[1,10]}", get(carol, "/api/sea/users/Bob123"));
    }

    @Test
    void visitorSeesTheSameSlotsEvenBeforeTheOwnerHasLoadedNewBottles() throws Exception {
        long a = send(alice, bob);
        get(bob, "/api/sea/me");
        putSlots(bob, "{\"slots\":[" + entry(a, 4) + "]}");
        makePublic(bob);
        long b = send(alice, bob); // 주인이 아직 보지 않은 새 유리병

        String visited = get(carol, "/api/sea/users/Bob123");
        get(bob, "/api/sea/me");

        assertEquals("{\"username\":\"Bob123\",\"floatingCount\":2,\"slots\":[0,4]}", visited);
        assertEquals(0, slotOf(b), "주인이 불러오면 방문자가 본 자리와 같은 자리로 저장된다");
    }

    @Test
    void rejectsOverlapsDuplicatesAndOutOfRangeSlots() throws Exception {
        long a = send(alice, bob), b = send(alice, bob);
        get(bob, "/api/sea/me");

        assertEquals(400, putSlots(bob, "{\"slots\":[" + entry(a, 1) + "]}").getResponse().getStatus(), "b가 있는 자리");
        assertEquals(400, putSlots(bob, "{\"slots\":[" + entry(a, 3) + "," + entry(a, 4) + "]}").getResponse().getStatus());
        assertEquals(400, putSlots(bob, "{\"slots\":[" + entry(a, 11) + "]}").getResponse().getStatus());
        assertEquals(400, putSlots(bob, "{\"slots\":[" + entry(a, -1) + "]}").getResponse().getStatus());
        assertEquals(400, putSlots(bob, "{\"slots\":[{\"letterId\":" + a + "}]}").getResponse().getStatus());
        assertEquals(400, putSlots(bob, "{}").getResponse().getStatus());
        assertEquals(401, mvc.perform(put("/api/sea/me/slots").contentType(MediaType.APPLICATION_JSON)
                .content("{\"slots\":[]}")).andReturn().getResponse().getStatus());
        assertEquals(List.of(0, 1), List.of(slotOf(a), slotOf(b)), "거절된 요청은 자리를 바꾸지 않는다");
    }

    @Test
    void cannotMoveSomeoneElsesBottleAndSavingDoesNotDiscardAnOpenedLetter() throws Exception {
        long mine = send(alice, bob);
        long others = send(alice, carol);
        get(bob, "/api/sea/me");
        get(carol, "/api/sea/me");
        get(bob, "/api/letters/" + mine); // 열어 둔 상태

        MvcResult r = putSlots(bob, "{\"slots\":[" + entry(mine, 5) + "," + entry(others, 7) + "]}");

        assertEquals(200, r.getResponse().getStatus());
        assertEquals(5, slotOf(mine));
        assertEquals(0, slotOf(others), "남의 유리병은 움직이지 않는다");
        assertEquals("FLOATING", jdbc.queryForObject("select status from letters where id = ?", String.class, mine),
                "자리 저장은 열어 둔 편지를 버리지 않는다");
    }

    @Test
    void freedSlotIsReusedByTheNextBottle() throws Exception {
        long a = send(alice, bob), b = send(alice, bob);
        get(bob, "/api/sea/me");
        jdbc.update("update letters set status = 'DISCARDED' where id = ?", a);
        long c = send(alice, bob);

        get(bob, "/api/sea/me");

        assertEquals(1, slotOf(b), "남은 유리병은 제자리");
        assertEquals(0, slotOf(c), "새 유리병이 빈 앞자리로");
    }
}
