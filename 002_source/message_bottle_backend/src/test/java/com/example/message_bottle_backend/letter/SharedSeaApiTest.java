package com.example.message_bottle_backend.letter;

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

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

/** 공유 바다: 익명으로 띄우기, 무작위로 낚기, 낚은 편지에 답장하기. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SharedSeaApiTest {

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired UserRepository userRepository;
    @Autowired LetterRepository letterRepository;
    @Autowired SharedLetterRepository sharedRepository;
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

    /* ---------- helpers ---------- */

    MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder b, User u) {
        return b.header("Authorization", "Bearer " + jwt.createAccessToken(u.getId())).characterEncoding("UTF-8");
    }

    MvcResult postAs(User as, String url, String json) throws Exception {
        return mvc.perform(auth(post(url), as).contentType(MediaType.APPLICATION_JSON).content(json)).andReturn();
    }

    MvcResult getAs(User as, String url) throws Exception {
        return mvc.perform(auth(get(url), as)).andReturn();
    }

    String body(MvcResult r) throws Exception {
        return r.getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    long idOf(MvcResult r) throws Exception {
        Matcher m = Pattern.compile("\"id\":(\\d+)").matcher(body(r));
        assertTrue(m.find(), body(r));
        return Long.parseLong(m.group(1));
    }

    long write(User as, String content) throws Exception {
        MvcResult r = postAs(as, "/api/shared-sea/letters", "{\"content\":\"" + content + "\"}");
        assertEquals(201, r.getResponse().getStatus(), body(r));
        return idOf(r);
    }

    MvcResult fish(User as) throws Exception {
        return postAs(as, "/api/shared-sea/fish", "");
    }

    MvcResult reply(User as, long sharedId, String content) throws Exception {
        return postAs(as, "/api/shared-sea/letters/" + sharedId + "/replies", "{\"content\":\"" + content + "\"}");
    }

    int seaCount(User u) throws Exception {
        Matcher m = Pattern.compile("\"floatingCount\":(\\d+)").matcher(body(getAs(u, "/api/sea/me")));
        assertTrue(m.find());
        return Integer.parseInt(m.group(1));
    }

    /* ---------- 띄우기와 낚기 ---------- */

    @Test
    void emptySharedSeaTellsTheFisherThereIsNothingLeft() throws Exception {
        MvcResult r = fish(bob);
        assertEquals(404, r.getResponse().getStatus());
        assertTrue(body(r).contains("남아있는 편지가 없어요!"), body(r));
    }

    @Test
    void writingNeedsContentAndLogin() throws Exception {
        assertEquals(400, postAs(alice, "/api/shared-sea/letters", "{\"content\":\"  \"}").getResponse().getStatus());
        assertEquals(400, postAs(alice, "/api/shared-sea/letters", "{}").getResponse().getStatus());
        int noToken = mvc.perform(post("/api/shared-sea/letters").contentType(MediaType.APPLICATION_JSON)
                .content("{\"content\":\"x\"}")).andReturn().getResponse().getStatus();
        assertTrue(noToken == 401 || noToken == 403, "status " + noToken);
        int noTokenFish = mvc.perform(post("/api/shared-sea/fish")).andReturn().getResponse().getStatus();
        assertTrue(noTokenFish == 401 || noTokenFish == 403, "status " + noTokenFish);
    }

    @Test
    void fishingReturnsSomeoneElsesLetterWithoutAnyAuthorInformation() throws Exception {
        long id = write(alice, "병 속의 편지");
        MvcResult r = fish(bob);
        assertEquals(200, r.getResponse().getStatus(), body(r));
        String json = body(r);
        assertTrue(json.contains("\"id\":" + id) && json.contains("병 속의 편지"), json);
        assertFalse(json.contains("Alice1") || json.contains("author") || json.contains("sender")
                || json.contains("\"" + alice.getId() + "\""), "작성자 정보가 없어야 한다: " + json);
    }

    @Test
    void youNeverFishYourOwnLetter() throws Exception {
        write(alice, "내 편지");
        MvcResult r = fish(alice);
        assertEquals(404, r.getResponse().getStatus());
        assertTrue(body(r).contains("남아있는 편지가 없어요!"));
    }

    @Test
    void fishingAloneDoesNotRemoveTheLetterSoItStaysForOthers() throws Exception {
        long id = write(alice, "남아 있는 편지");
        for (int i = 0; i < 3; i++) {
            assertTrue(body(fish(bob)).contains("\"id\":" + id));
        }
        assertTrue(body(fish(carol)).contains("\"id\":" + id), "닫고 간 편지는 계속 바다에 남는다");
        assertEquals(SharedLetterStatus.OPEN, sharedRepository.findById(id).orElseThrow().getStatus());
    }

    @Test
    void fishingPicksRandomlyAmongTheRemainingLetters() throws Exception {
        for (int i = 0; i < 5; i++) {
            write(alice, "편지" + i);
        }
        java.util.Set<String> seen = new java.util.HashSet<>();
        for (int i = 0; i < 80 && seen.size() < 5; i++) {
            Matcher m = Pattern.compile("\"id\":(\\d+)").matcher(body(fish(bob)));
            assertTrue(m.find());
            seen.add(m.group(1));
        }
        assertEquals(5, seen.size(), "무작위로 골라 여러 편지가 나온다");
    }

    /* ---------- 답장 ---------- */

    @Test
    void replyGoesToTheAnonymousAuthorsSeaAndRemovesTheLetterFromTheSharedSea() throws Exception {
        long shared = write(alice, "누구든 읽어 주세요");
        assertEquals(200, fish(bob).getResponse().getStatus());

        MvcResult r = reply(bob, shared, "읽었어요");
        assertEquals(201, r.getResponse().getStatus(), body(r));
        assertFalse(body(r).contains("Alice1"), "답장한 사람에게 익명 작성자의 아이디를 알려주지 않는다: " + body(r));
        long replyId = idOf(r);

        // 작성자의 바다에 새 편지가 생기고, 답장한 사람은 일반 답장처럼 보인다
        assertEquals(1, seaCount(alice));
        Letter letter = letterRepository.findWithUsersById(replyId).orElseThrow();
        assertEquals(alice.getId(), letter.getReceiver().getId());
        assertEquals(bob.getId(), letter.getSender().getId());
        assertFalse(letter.isAnonymous());
        String seen = body(getAs(alice, "/api/letters/" + replyId));
        assertTrue(seen.contains("Bob123") && seen.contains("읽었어요") && seen.contains("\"canReply\":true"), seen);

        // 공유 바다에서는 사라진다
        assertEquals(SharedLetterStatus.REPLIED, sharedRepository.findById(shared).orElseThrow().getStatus());
        MvcResult again = fish(carol);
        assertEquals(404, again.getResponse().getStatus());
        assertTrue(body(again).contains("남아있는 편지가 없어요!"));

        // 이미 답장이 된 편지에는 다시 답장할 수 없다
        assertEquals(404, reply(carol, shared, "저도요").getResponse().getStatus());
    }

    @Test
    void theRepliersSentBoxNeverRevealsTheAnonymousAuthor() throws Exception {
        long shared = write(alice, "비밀 편지");
        long replyId = idOf(reply(bob, shared, "답장"));

        String list = body(getAs(bob, "/api/sent"));
        assertTrue(list.contains("답장") && list.contains("\"receiverUsername\":null"), list);
        assertFalse(list.contains("Alice1"), list);
        String detail = body(getAs(bob, "/api/sent/" + replyId));
        assertFalse(detail.contains("Alice1"), detail);
        String asSender = body(getAs(bob, "/api/letters/" + replyId));
        assertFalse(asSender.contains("Alice1"), asSender);
        assertTrue(asSender.contains("\"parentLetterId\":null"), "답장한 사람은 낚은 편지의 작성자 쪽으로 올라갈 수 없다");
        assertEquals(404, getAs(bob, "/api/letters/" + replyId + "/parent").getResponse().getStatus());
        assertEquals(404, getAs(carol, "/api/letters/" + replyId + "/parent").getResponse().getStatus());
    }

    @Test
    void theAuthorCanFollowTheReplyBackToTheirSharedLetter() throws Exception {
        long shared = write(alice, "바다에 띄운 내 편지");
        long replyId = idOf(reply(bob, shared, "답장"));

        assertTrue(body(getAs(alice, "/api/letters/" + replyId)).contains("\"parentLetterId\":" + shared));
        String parent = body(getAs(alice, "/api/letters/" + replyId + "/parent"));
        assertTrue(parent.contains("바다에 띄운 내 편지") && parent.contains("\"role\":\"SENDER\"")
                && parent.contains("\"counterpartUsername\":null") && parent.contains("\"anonymous\":true"), parent);
        assertTrue(parent.contains("\"parentLetterId\":null"), parent);
    }

    @Test
    void youCannotReplyToYourOwnSharedLetterOrWithEmptyContent() throws Exception {
        long shared = write(alice, "내 편지");
        assertEquals(400, reply(alice, shared, "내가 답장").getResponse().getStatus());
        assertEquals(400, postAs(bob, "/api/shared-sea/letters/" + shared + "/replies", "{\"content\":\" \"}")
                .getResponse().getStatus());
        assertEquals(404, reply(bob, 99999, "없는 편지").getResponse().getStatus());
        assertEquals(SharedLetterStatus.OPEN, sharedRepository.findById(shared).orElseThrow().getStatus(),
                "실패한 답장은 편지를 사라지게 하지 않는다");
    }

    @Test
    void replyFollowsTheAuthorsSeaCapacityAndQueue() throws Exception {
        long shared = write(alice, "가득 찬 바다");
        for (int i = 0; i < 10; i++) {
            MvcResult r = postAs(carol, "/api/letters",
                    "{\"receiverUsername\":\"Alice1\",\"content\":\"c" + i + "\",\"anonymous\":false}");
            assertEquals(201, r.getResponse().getStatus());
        }
        assertEquals(10, seaCount(alice));

        long replyId = idOf(reply(bob, shared, "대기열 답장"));
        assertEquals(LetterStatus.WAITING, letterRepository.findById(replyId).orElseThrow().getStatus());
        assertEquals(10, seaCount(alice), "떠 있는 편지는 10개를 넘지 않는다");
    }

    @Test
    void concurrentRepliesToTheSameLetterSucceedExactlyOnce() throws Exception {
        long shared = write(alice, "동시에 답장");
        List<User> repliers = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            repliers.add(userRepository.save(new User("Rep" + i + "Tt", "x")));
        }
        ExecutorService pool = Executors.newFixedThreadPool(6);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<Integer>> results = new ArrayList<>();
        for (User u : repliers) {
            results.add(pool.submit(() -> {
                go.await();
                return reply(u, shared, "답장 " + u.getUsername()).getResponse().getStatus();
            }));
        }
        go.countDown();
        int created = 0, gone = 0;
        for (Future<Integer> f : results) {
            int status = f.get(30, TimeUnit.SECONDS);
            if (status == 201) created++;
            else if (status == 404) gone++;
            else fail("unexpected status " + status);
        }
        pool.shutdown();
        assertEquals(1, created);
        assertEquals(5, gone);
        assertEquals(1, seaCount(alice));
    }
}
