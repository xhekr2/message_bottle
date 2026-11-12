package com.example.message_bottle_backend.user;

import com.example.message_bottle_backend.security.JwtProvider;
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
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;

/** 사용자별 화면 설정(GET/PUT /api/users/me/settings). */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class UserSettingsApiTest {

    static final String DEFAULTS = "{\"seaTone\":\"DAY\",\"textStep\":1,\"idleSeconds\":5,\"waveType\":\"BOTH\"}";
    static final String NIGHT_BIG = "{\"seaTone\":\"NIGHT\",\"textStep\":4,\"idleSeconds\":9,\"waveType\":\"ROUGH\"}";

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired UserRepository userRepository;
    @Autowired JwtProvider jwt;

    User alice, bob;

    @BeforeEach
    void setUp() {
        jdbc.update("delete from letter_archives");
        jdbc.update("update letters set parent_letter_id = null");
        jdbc.update("delete from letters");
        jdbc.update("delete from shared_letters");
        jdbc.update("delete from user_settings");
        jdbc.update("delete from users");
        alice = userRepository.save(new User("Alice1", "x"));
        bob = userRepository.save(new User("Bob123", "x"));
    }

    MockHttpServletRequestBuilder as(MockHttpServletRequestBuilder b, User u) {
        return b.header("Authorization", "Bearer " + jwt.createAccessToken(u.getId())).characterEncoding("UTF-8");
    }

    MvcResult getSettings(User u) throws Exception {
        return mvc.perform(as(get("/api/users/me/settings"), u)).andReturn();
    }

    MvcResult putSettings(User u, String json) throws Exception {
        return mvc.perform(as(put("/api/users/me/settings"), u).contentType(MediaType.APPLICATION_JSON).content(json)).andReturn();
    }

    String body(MvcResult r) throws Exception {
        return r.getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    int rows() {
        return jdbc.queryForObject("select count(*) from user_settings", Integer.class);
    }

    @Test
    void aUserWhoNeverChangedAnythingGetsTheDefaults() throws Exception {
        MvcResult r = getSettings(alice);
        assertEquals(200, r.getResponse().getStatus());
        assertEquals(DEFAULTS, body(r));
        assertEquals(0, rows(), "조회만으로는 행을 만들지 않는다");
    }

    @Test
    void changedSettingsAreStoredAndReturnedOnTheNextRead() throws Exception {
        MvcResult changed = putSettings(alice, NIGHT_BIG);
        assertEquals(200, changed.getResponse().getStatus());
        assertEquals(NIGHT_BIG, body(changed));
        assertEquals(NIGHT_BIG, body(getSettings(alice)));

        String back = "{\"seaTone\":\"SYSTEM\",\"textStep\":0,\"idleSeconds\":1,\"waveType\":\"CALM\"}";
        assertEquals(back, body(putSettings(alice, back)));
        assertEquals(back, body(getSettings(alice)));
        assertEquals(1, rows(), "한 사용자에 한 행만 둔다");
    }

    @Test
    void oneUsersSettingsDoNotAffectAnotherUser() throws Exception {
        putSettings(alice, NIGHT_BIG);
        assertEquals(DEFAULTS, body(getSettings(bob)), "다른 사용자는 기본값 그대로다");

        String bobs = "{\"seaTone\":\"DAY\",\"textStep\":2,\"idleSeconds\":3,\"waveType\":\"CALM\"}";
        putSettings(bob, bobs);
        assertEquals(NIGHT_BIG, body(getSettings(alice)), "앨리스의 설정은 그대로다");
        assertEquals(bobs, body(getSettings(bob)));
        assertEquals(2, rows());
    }

    @Test
    void responseCarriesNoUserIdentity() throws Exception {
        String json = body(putSettings(alice, NIGHT_BIG));
        assertFalse(json.contains("Alice1"));
        assertFalse(json.contains("userId"));
        assertFalse(json.contains("\"id\""));
    }

    @Test
    void outOfRangeOrIncompleteRequestsAreRejectedAndChangeNothing() throws Exception {
        putSettings(alice, NIGHT_BIG);
        String[] bad = {
                "{\"seaTone\":\"DUSK\",\"textStep\":1,\"idleSeconds\":5,\"waveType\":\"BOTH\"}",
                "{\"seaTone\":\"DAY\",\"textStep\":5,\"idleSeconds\":5,\"waveType\":\"BOTH\"}",
                "{\"seaTone\":\"DAY\",\"textStep\":-1,\"idleSeconds\":5,\"waveType\":\"BOTH\"}",
                "{\"seaTone\":\"DAY\",\"textStep\":1,\"idleSeconds\":0,\"waveType\":\"BOTH\"}",
                "{\"seaTone\":\"DAY\",\"textStep\":1,\"idleSeconds\":11,\"waveType\":\"BOTH\"}",
                "{\"seaTone\":\"DAY\",\"textStep\":1,\"idleSeconds\":5,\"waveType\":\"STORM\"}",
                "{\"seaTone\":\"DAY\",\"textStep\":1,\"idleSeconds\":5}",
                "{}",
                "not json",
        };
        for (String json : bad) {
            assertEquals(400, putSettings(alice, json).getResponse().getStatus(), json);
        }
        assertEquals(NIGHT_BIG, body(getSettings(alice)), "잘못된 요청은 설정을 바꾸지 않는다");
    }

    @Test
    void settingsNeedALogin() throws Exception {
        assertEquals(401, mvc.perform(get("/api/users/me/settings")).andReturn().getResponse().getStatus());
        assertEquals(401, mvc.perform(put("/api/users/me/settings").contentType(MediaType.APPLICATION_JSON)
                .content(NIGHT_BIG)).andReturn().getResponse().getStatus());
        assertEquals(0, rows());
    }

    @Test
    void simultaneousFirstChangesCreateOnlyOneRow() throws Exception {
        int n = 6;
        ExecutorService pool = Executors.newFixedThreadPool(n);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<Integer>> results = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            int step = i % 5;
            results.add(pool.submit(() -> {
                start.await();
                return putSettings(alice, "{\"seaTone\":\"NIGHT\",\"textStep\":" + step
                        + ",\"idleSeconds\":5,\"waveType\":\"BOTH\"}").getResponse().getStatus();
            }));
        }
        start.countDown();
        for (Future<Integer> f : results) {
            assertEquals(200, f.get());
        }
        pool.shutdown();
        assertEquals(1, rows());
    }
}
