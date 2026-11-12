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

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class LetterApiTest {

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired UserRepository userRepository;
    @Autowired LetterRepository letterRepository;
    @Autowired LetterArchiveRepository archiveRepository;
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

    /* ---------- helpers ---------- */

    String token(User u) {
        return "Bearer " + jwt.createAccessToken(u.getId());
    }

    MockHttpServletRequestBuilder auth(MockHttpServletRequestBuilder b, User u) {
        return b.header("Authorization", token(u)).characterEncoding("UTF-8");
    }

    MvcResult postAs(User as, String url, String json) throws Exception {
        return mvc.perform(auth(post(url), as).contentType(MediaType.APPLICATION_JSON).content(json)).andReturn();
    }

    MvcResult getAs(User as, String url) throws Exception {
        return mvc.perform(auth(get(url), as)).andReturn();
    }

    long idOf(MvcResult r) throws Exception {
        Matcher m = Pattern.compile("\"(?:id|archiveId)\":(\\d+)").matcher(r.getResponse().getContentAsString());
        assertTrue(m.find(), r.getResponse().getContentAsString());
        return Long.parseLong(m.group(1));
    }

    String body(MvcResult r) throws Exception {
        return r.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
    }

    long sendLetter(User from, User to, String content, boolean anonymous) throws Exception {
        MvcResult r = postAs(from, "/api/letters",
                "{\"receiverUsername\":\"" + to.getUsername() + "\",\"content\":\"" + content + "\",\"anonymous\":" + anonymous + "}");
        assertEquals(201, r.getResponse().getStatus(), body(r));
        return idOf(r);
    }

    int seaCount(User u) throws Exception {
        MvcResult r = getAs(u, "/api/sea/me");
        assertEquals(200, r.getResponse().getStatus());
        Matcher m = Pattern.compile("\"floatingCount\":(\\d+)").matcher(body(r));
        assertTrue(m.find());
        return Integer.parseInt(m.group(1));
    }

    LetterStatus statusOf(long letterId) {
        return letterRepository.findById(letterId).orElseThrow().getStatus();
    }

    long count(User receiver, LetterStatus s) {
        return letterRepository.countByReceiverIdAndStatus(receiver.getId(), s);
    }

    /* ---------- 발송과 바다 ---------- */

    @Test
    void sentLetterAppearsInReceiversSea() throws Exception {
        sendLetter(alice, bob, "안녕", false);
        assertEquals(1, seaCount(bob));
        assertEquals(0, seaCount(alice));
    }

    @Test
    void seaHoldsAtMostTenAndExtraLettersWaitButSendStillSucceeds() throws Exception {
        for (int i = 0; i < 12; i++) {
            sendLetter(alice, bob, "편지" + i, false);   // 11번째, 12번째도 201
        }
        assertEquals(10, seaCount(bob));
        assertEquals(2, count(bob, LetterStatus.WAITING));
    }

    @Test
    void waitingLettersPromoteInFirstSentOrderWhenASlotOpens() throws Exception {
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < 12; i++) {
            ids.add(sendLetter(alice, bob, "편지" + i, false));
        }
        long w1 = ids.get(10), w2 = ids.get(11);
        assertEquals(LetterStatus.WAITING, statusOf(w1));
        assertEquals(LetterStatus.WAITING, statusOf(w2));

        assertEquals(204, postAs(bob, "/api/letters/" + ids.get(0) + "/discard", "").getResponse().getStatus());

        assertEquals(LetterStatus.FLOATING, statusOf(w1), "가장 먼저 발송된 대기 편지가 먼저 올라온다");
        assertEquals(LetterStatus.WAITING, statusOf(w2));
        assertEquals(10, seaCount(bob));

        // 보관으로 생긴 빈자리도 같은 규칙
        assertEquals(201, postAs(bob, "/api/letters/" + ids.get(1) + "/archive", "").getResponse().getStatus());
        assertEquals(LetterStatus.FLOATING, statusOf(w2));
    }

    @Test
    void concurrentSendsNeverExceedTenFloating() throws Exception {
        int n = 30;
        ExecutorService pool = Executors.newFixedThreadPool(n);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<?>> futures = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            int k = i;
            futures.add(pool.submit(() -> {
                start.await();
                return letterService.send(alice.getId(), new SendLetterRequest(bob.getUsername(), "동시 " + k, false));
            }));
        }
        start.countDown();
        for (Future<?> f : futures) {
            f.get(60, TimeUnit.SECONDS);
        }
        pool.shutdown();
        assertEquals(10, count(bob, LetterStatus.FLOATING));
        assertEquals(20, count(bob, LetterStatus.WAITING));
    }

    @Test
    void concurrentSendsAndDiscardsKeepTheQueueConsistent() throws Exception {
        List<Long> initial = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            initial.add(letterService.send(alice.getId(), new SendLetterRequest(bob.getUsername(), "처음 " + i, false)).id());
        }
        assertEquals(10, count(bob, LetterStatus.FLOATING));

        ExecutorService pool = Executors.newFixedThreadPool(20);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<?>> futures = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            Long victim = initial.get(i);
            int k = i;
            futures.add(pool.submit(() -> { start.await(); letterService.discard(bob.getId(), victim); return null; }));
            futures.add(pool.submit(() -> {
                start.await();
                return letterService.send(carol.getId(), new SendLetterRequest(bob.getUsername(), "새 편지 " + k, false));
            }));
        }
        start.countDown();
        for (Future<?> f : futures) {
            f.get(60, TimeUnit.SECONDS);
        }
        pool.shutdown();

        // 처음 10통은 모두 버려졌고 새 10통만 남는다. 보낸 순서와 상관없이 빈자리는 모두 채워져야 한다.
        assertEquals(10, count(bob, LetterStatus.FLOATING));
        assertEquals(0, count(bob, LetterStatus.WAITING));
        assertEquals(10, count(bob, LetterStatus.DISCARDED));
    }

    @Test
    void anonymousFlagIsOptionalAndDefaultsToNotAnonymous() throws Exception {
        MvcResult r = postAs(alice, "/api/letters", "{\"receiverUsername\":\"Bob123\",\"content\":\"플래그 없음\"}");
        assertEquals(201, r.getResponse().getStatus(), body(r));
        assertFalse(letterRepository.findById(idOf(r)).orElseThrow().isAnonymous());
    }

    /* ---------- 만료 ---------- */

    @Test
    void expiryAppliesToFloatingAndWaitingFromFirstSentTimeAndPromotesNext() throws Exception {
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < 12; i++) {
            ids.add(sendLetter(alice, bob, "편지" + i, false));
        }
        long oldFloating = ids.get(0), oldWaiting = ids.get(10), laterWaiting = ids.get(11);
        LocalDateTime past = LocalDateTime.now().minusMinutes(1);
        jdbc.update("update letters set expires_at = ? where id in (?, ?)", past, oldFloating, oldWaiting);

        assertEquals(10, seaCount(bob)); // 호출 시점에 만료를 검증한다(스케줄러에 의존하지 않음)

        assertEquals(LetterStatus.SUNK, statusOf(oldFloating));
        assertEquals(LetterStatus.SUNK, statusOf(oldWaiting), "대기 편지도 최초 발송 7일 후 만료");
        assertEquals(LetterStatus.FLOATING, statusOf(laterWaiting), "만료로 생긴 빈자리에 다음 대기 편지가 올라온다");
    }

    @Test
    void sevenDaysIsMeasuredFromSendTime() throws Exception {
        long id = sendLetter(alice, bob, "x", false);
        Letter l = letterRepository.findById(id).orElseThrow();
        assertEquals(l.getSentAt().plusDays(7), l.getExpiresAt());
    }

    @Test
    void archivedLettersDoNotExpireAndDoNotTakeCapacity() throws Exception {
        long id = sendLetter(alice, bob, "보관할 편지", false);
        assertEquals(201, postAs(bob, "/api/letters/" + id + "/archive", "").getResponse().getStatus());
        jdbc.update("update letters set expires_at = ? where id = ?", LocalDateTime.now().minusDays(30), id);

        assertEquals(0, seaCount(bob));
        assertEquals(LetterStatus.ARCHIVED, statusOf(id));
        assertTrue(body(getAs(bob, "/api/inbox")).contains("보관할 편지"));
    }

    /* ---------- 열람 · 보관 · 버리기 ---------- */

    @Test
    void discardIsPermanentAndSenderRecordSurvives() throws Exception {
        long id = sendLetter(alice, bob, "버릴 편지", false);
        assertEquals(204, postAs(bob, "/api/letters/" + id + "/discard", "").getResponse().getStatus());
        assertEquals(0, seaCount(bob));
        assertEquals("[]", body(getAs(bob, "/api/inbox")));
        assertEquals(404, getAs(bob, "/api/letters/" + id).getResponse().getStatus());
        assertTrue(body(getAs(alice, "/api/sent")).contains("버릴 편지"));
    }

    @Test
    void archiveMovesToInboxAndSecondArchiveConflicts() throws Exception {
        long id = sendLetter(alice, bob, "보관 편지", false);
        assertEquals(201, postAs(bob, "/api/letters/" + id + "/archive", "").getResponse().getStatus());
        assertEquals(409, postAs(bob, "/api/letters/" + id + "/archive", "").getResponse().getStatus());
        assertEquals(0, seaCount(bob));
        String inbox = body(getAs(bob, "/api/inbox"));
        assertTrue(inbox.contains("보관 편지") && inbox.contains("\"replied\":false"));
    }

    @Test
    void inboxDeleteIsSoftAndDoesNotTouchSenderRecord() throws Exception {
        long id = sendLetter(alice, bob, "보관 편지", false);
        long archiveId = idOf(postAs(bob, "/api/letters/" + id + "/archive", ""));
        assertEquals(204, mvc.perform(auth(delete("/api/inbox/" + archiveId), bob)).andReturn().getResponse().getStatus());
        assertEquals("[]", body(getAs(bob, "/api/inbox")));
        assertEquals(404, getAs(bob, "/api/inbox/" + archiveId).getResponse().getStatus());
        assertTrue(body(getAs(alice, "/api/sent")).contains("보관 편지"));
    }

    @Test
    void onlyTheReceiverCanDiscardOrArchive() throws Exception {
        long id = sendLetter(alice, bob, "남의 편지", false);
        assertEquals(404, postAs(carol, "/api/letters/" + id + "/discard", "").getResponse().getStatus());
        assertEquals(404, postAs(carol, "/api/letters/" + id + "/archive", "").getResponse().getStatus());
        assertEquals(404, postAs(alice, "/api/letters/" + id + "/archive", "").getResponse().getStatus(), "발신자도 불가");
        assertEquals(404, getAs(carol, "/api/letters/" + id).getResponse().getStatus());
        assertEquals(LetterStatus.FLOATING, statusOf(id));
    }

    @Test
    void senderCannotDeleteFromSentBox() throws Exception {
        long id = sendLetter(alice, bob, "보낸 편지", false);
        assertEquals(405, mvc.perform(auth(delete("/api/sent/" + id), alice)).andReturn().getResponse().getStatus());
        assertTrue(body(getAs(alice, "/api/sent/" + id)).contains("보낸 편지"));
        assertEquals(404, getAs(bob, "/api/sent/" + id).getResponse().getStatus(), "받는 사람은 남의 보낸 편지함을 볼 수 없다");
    }

    @Test
    void openedButUnresolvedLetterIsDiscardedWhenTheSeaIsLoadedAgain() throws Exception {
        long opened = sendLetter(alice, bob, "열어만 본 편지", false);
        long untouched = sendLetter(alice, bob, "안 연 편지", false);
        assertEquals(200, getAs(bob, "/api/letters/" + opened).getResponse().getStatus()); // 열람

        // 앱이 종료된 뒤 다시 시작해 바다를 불러온다
        assertEquals(1, seaCount(bob));

        assertEquals(LetterStatus.DISCARDED, statusOf(opened));
        assertEquals(LetterStatus.FLOATING, statusOf(untouched));
        assertEquals("[]", body(getAs(bob, "/api/inbox")), "받은 편지함에도 저장되지 않는다");
        assertTrue(body(getAs(alice, "/api/sent")).contains("열어만 본 편지"), "발신자 기록은 유지");
    }

    @Test
    void openedLetterSurvivesWhileResolvedByArchiveOrDiscard() throws Exception {
        long a = sendLetter(alice, bob, "보관할 편지", false);
        long d = sendLetter(alice, bob, "버릴 편지", false);
        getAs(bob, "/api/letters/" + a);
        getAs(bob, "/api/letters/" + d);
        postAs(bob, "/api/letters/" + a + "/archive", "");
        postAs(bob, "/api/letters/" + d + "/discard", "");
        assertEquals(0, seaCount(bob));
        assertEquals(LetterStatus.ARCHIVED, statusOf(a));
        assertEquals(1, archiveRepository.findByOwnerIdAndDeletedAtIsNullOrderByArchivedAtDescIdDesc(bob.getId()).size());
    }

    /* ---------- 답장 ---------- */

    @Test
    void replyCreatesNewLetterLinkedToParentAndAutoArchivesTheOriginal() throws Exception {
        long original = sendLetter(alice, bob, "첫 편지", false);
        getAs(bob, "/api/letters/" + original);

        MvcResult r = postAs(bob, "/api/letters/" + original + "/replies", "{\"content\":\"답장입니다\"}");
        assertEquals(201, r.getResponse().getStatus(), body(r));
        long replyId = idOf(r);

        Letter reply = letterRepository.findWithUsersById(replyId).orElseThrow();
        assertEquals(alice.getId(), reply.getReceiver().getId());
        assertEquals(bob.getId(), reply.getSender().getId());
        assertEquals(original, reply.getParent().getId(), "직전 편지를 부모로 참조");
        assertFalse(reply.isAnonymous(), "답장에는 익명이 없다");
        assertEquals(LetterStatus.FLOATING, reply.getStatus());

        assertEquals(LetterStatus.ARCHIVED, statusOf(original));
        assertEquals(0, seaCount(bob));
        assertEquals(1, seaCount(alice));
        String inbox = body(getAs(bob, "/api/inbox"));
        assertTrue(inbox.contains("첫 편지") && inbox.contains("\"replied\":true"));
    }

    @Test
    void repliesCanChainWithoutLimit() throws Exception {
        long l1 = sendLetter(alice, bob, "1", false);
        long l2 = idOf(postAs(bob, "/api/letters/" + l1 + "/replies", "{\"content\":\"2\"}"));
        long l3 = idOf(postAs(alice, "/api/letters/" + l2 + "/replies", "{\"content\":\"3\"}"));
        long l4 = idOf(postAs(bob, "/api/letters/" + l3 + "/replies", "{\"content\":\"4\"}"));
        assertEquals(l3, letterRepository.findById(l4).orElseThrow().getParent().getId());
        assertEquals(l2, letterRepository.findById(l3).orElseThrow().getParent().getId());
    }

    @Test
    void aReplyLinksBackToItsParentForBothSidesAlongTheWholeChain() throws Exception {
        long l1 = sendLetter(alice, bob, "첫째", false);
        long l2 = idOf(postAs(bob, "/api/letters/" + l1 + "/replies", "{\"content\":\"둘째\"}"));
        long l3 = idOf(postAs(alice, "/api/letters/" + l2 + "/replies", "{\"content\":\"셋째\"}"));
        long l4 = idOf(postAs(bob, "/api/letters/" + l3 + "/replies", "{\"content\":\"넷째\"}"));

        // 답장을 받은 사람은 자기가 보낸 이전 편지로 거슬러 올라간다 (alice: l4 -> l3 -> l2 -> l1)
        assertTrue(body(getAs(alice, "/api/letters/" + l4)).contains("\"parentLetterId\":" + l3));
        String p3 = body(getAs(alice, "/api/letters/" + l4 + "/parent"));
        assertTrue(p3.contains("\"id\":" + l3) && p3.contains("\"role\":\"SENDER\"")
                && p3.contains("셋째") && p3.contains("\"counterpartUsername\":\"Bob123\""), p3);
        assertTrue(p3.contains("\"parentLetterId\":" + l2), "l3의 부모 l2는 alice가 받아 보관한 편지: " + p3);
        String p2 = body(getAs(alice, "/api/letters/" + l3 + "/parent"));
        assertTrue(p2.contains("\"id\":" + l2) && p2.contains("\"role\":\"RECEIVER\"")
                && p2.contains("\"counterpartUsername\":\"Bob123\"") && p2.contains("둘째"), p2);
        assertTrue(p2.contains("\"parentLetterId\":" + l1), p2);
        String p1 = body(getAs(alice, "/api/letters/" + l2 + "/parent"));
        assertTrue(p1.contains("\"id\":" + l1) && p1.contains("\"role\":\"SENDER\"") && p1.contains("첫째"), p1);
        assertTrue(p1.contains("\"parentLetterId\":null"), "첫 편지는 부모가 없다: " + p1);

        // 보낸 편지함·받은 편지함 상세에도 부모 표시가 있다
        assertTrue(body(getAs(bob, "/api/sent/" + l4)).contains("\"parentLetterId\":" + l3));
        long archiveId = archiveRepository.findByLetterIdAndOwnerIdAndDeletedAtIsNull(l2, alice.getId()).orElseThrow().getId();
        assertTrue(body(getAs(alice, "/api/inbox/" + archiveId)).contains("\"parentLetterId\":" + l1));
    }

    @Test
    void parentLookupHidesWhatTheCallerMayNotSee() throws Exception {
        long l1 = sendLetter(alice, bob, "첫째", false);
        long l2 = idOf(postAs(bob, "/api/letters/" + l1 + "/replies", "{\"content\":\"둘째\"}"));

        assertEquals(404, getAs(alice, "/api/letters/" + l1 + "/parent").getResponse().getStatus(), "첫 편지는 부모가 없다");
        assertEquals(404, getAs(carol, "/api/letters/" + l2 + "/parent").getResponse().getStatus(), "남의 편지는 알려주지 않는다");
        assertEquals(404, getAs(alice, "/api/letters/99999/parent").getResponse().getStatus());
        assertTrue(body(getAs(alice, "/api/letters/" + l1)).contains("\"parentLetterId\":null"));

        // bob이 받은 첫 편지를 보관함에서 지우면, bob은 더 이상 그 편지를 볼 수 없다. alice의 기록은 그대로다.
        assertTrue(body(getAs(bob, "/api/letters/" + l2 + "/parent")).contains("첫째"));
        long archiveId = archiveRepository.findByLetterIdAndOwnerIdAndDeletedAtIsNull(l1, bob.getId()).orElseThrow().getId();
        assertEquals(204, mvc.perform(auth(delete("/api/inbox/" + archiveId), bob)).andReturn().getResponse().getStatus());
        assertEquals(404, getAs(bob, "/api/letters/" + l2 + "/parent").getResponse().getStatus());
        assertTrue(body(getAs(bob, "/api/sent/" + l2)).contains("\"parentLetterId\":null"));
        assertEquals(200, getAs(alice, "/api/sent/" + l1).getResponse().getStatus());
    }

    @Test
    void anonymousLettersCannotBeRepliedToEvenWithDirectRequests() throws Exception {
        long id = sendLetter(alice, bob, "익명 편지", true);
        MvcResult r = postAs(bob, "/api/letters/" + id + "/replies", "{\"content\":\"답장\"}");
        assertEquals(400, r.getResponse().getStatus());
        assertFalse(body(r).contains(alice.getUsername()), "오류 메시지로 발신자가 드러나면 안 된다");
        assertEquals(LetterStatus.FLOATING, statusOf(id));
        assertEquals(1, letterRepository.count());
    }

    @Test
    void replyIsOnlyPossibleFromTheSeaByTheReceiver() throws Exception {
        long id = sendLetter(alice, bob, "편지", false);
        assertEquals(404, postAs(carol, "/api/letters/" + id + "/replies", "{\"content\":\"x\"}").getResponse().getStatus());
        assertEquals(404, postAs(alice, "/api/letters/" + id + "/replies", "{\"content\":\"x\"}").getResponse().getStatus());

        postAs(bob, "/api/letters/" + id + "/archive", ""); // 보관함의 편지에는 답장할 수 없다
        assertEquals(404, postAs(bob, "/api/letters/" + id + "/replies", "{\"content\":\"x\"}").getResponse().getStatus());
        assertEquals(1, letterRepository.count());
    }

    @Test
    void replyValidatesContentAndKeepsTheOriginalWhenItFails() throws Exception {
        long id = sendLetter(alice, bob, "편지", false);
        assertEquals(400, postAs(bob, "/api/letters/" + id + "/replies", "{\"content\":\"  \"}").getResponse().getStatus());
        assertEquals(LetterStatus.FLOATING, statusOf(id));
        assertEquals(1, seaCount(bob));
    }

    @Test
    void replyJoinsTheTargetsQueueWhenTheirSeaIsFull() throws Exception {
        for (int i = 0; i < 10; i++) {
            sendLetter(carol, alice, "가득 " + i, false); // 앨리스의 바다를 채운다
        }
        long id = sendLetter(alice, bob, "편지", false);
        long replyId = idOf(postAs(bob, "/api/letters/" + id + "/replies", "{\"content\":\"답장\"}"));
        assertEquals(LetterStatus.WAITING, statusOf(replyId), "답장도 10개 수용량·대기열 규칙을 따른다");
    }

    /* ---------- 익명 ---------- */

    @Test
    void anonymousSenderIsNeverExposedToTheReceiver() throws Exception {
        long id = sendLetter(alice, bob, "익명 편지", true);
        String senderName = alice.getUsername();
        String senderId = String.valueOf(alice.getId());

        String sea = body(getAs(bob, "/api/sea/me"));
        MvcResult detail = getAs(bob, "/api/letters/" + id);
        String detailBody = body(detail);
        assertEquals(200, detail.getResponse().getStatus());
        assertTrue(detailBody.contains("\"anonymous\":true") && detailBody.contains("\"counterpartUsername\":null"));
        assertTrue(detailBody.contains("\"canReply\":false") && detailBody.contains("\"canArchive\":true"));
        assertFalse(sea.contains(senderName));
        assertFalse(detailBody.contains(senderName));
        assertFalse(detailBody.contains("\"senderId\"") || detailBody.contains("\"sender\""));

        postAs(bob, "/api/letters/" + id + "/archive", "");
        String inbox = body(getAs(bob, "/api/inbox"));
        assertFalse(inbox.contains(senderName));
        assertTrue(inbox.contains("\"senderUsername\":null"));
        long archiveId = idOf(getAs(bob, "/api/inbox"));
        String inboxDetail = body(getAs(bob, "/api/inbox/" + archiveId));
        assertFalse(inboxDetail.contains(senderName));
        assertFalse(inboxDetail.contains("\"senderId\""));
        assertNotEquals(senderId, "");
    }

    @Test
    void senderOfAnAnonymousLetterStillSeesItInTheSentBox() throws Exception {
        long id = sendLetter(alice, bob, "익명 편지", true);
        String sent = body(getAs(alice, "/api/sent"));
        assertTrue(sent.contains("\"receiverUsername\":\"Bob123\"") && sent.contains("\"anonymous\":true"));
        assertTrue(body(getAs(alice, "/api/sent/" + id)).contains("익명 편지"));
    }

    /* ---------- 입력 검증 · 검색 · 인증 ---------- */

    @Test
    void sendValidation() throws Exception {
        assertEquals(400, postAs(alice, "/api/letters", "{\"receiverUsername\":\"Alice1\",\"content\":\"나에게\"}").getResponse().getStatus(),
                "자기 자신에게는 보낼 수 없다");
        assertEquals(404, postAs(alice, "/api/letters", "{\"receiverUsername\":\"nobody\",\"content\":\"x\"}").getResponse().getStatus());
        assertEquals(404, postAs(alice, "/api/letters", "{\"receiverUsername\":\"bob123\",\"content\":\"x\"}").getResponse().getStatus(),
                "받는 사람 아이디는 대소문자를 구분한다");
        assertEquals(400, postAs(alice, "/api/letters", "{\"receiverUsername\":\"Bob123\",\"content\":\"   \"}").getResponse().getStatus());
        assertEquals(0, letterRepository.count());
    }

    @Test
    void contentHasNoLengthLimit() throws Exception {
        String longText = "가".repeat(50_000);
        long id = sendLetter(alice, bob, longText, false);
        assertEquals(50_000, letterRepository.findById(id).orElseThrow().getContent().length());
    }

    @Test
    void userSearchIsPartialCaseSensitiveAndReturnsUsernamesOnly() throws Exception {
        userRepository.save(new User("abc123", "x"));
        userRepository.save(new User("Abc123", "x"));
        String both = body(getAs(alice, "/api/users/search?username=bc"));
        assertTrue(both.contains("\"abc123\"") && both.contains("\"Abc123\""));
        String onlyUpper = body(getAs(alice, "/api/users/search?username=Ab"));
        assertTrue(onlyUpper.contains("\"Abc123\"") && !onlyUpper.contains("\"abc123\""), "대소문자 구분");
        assertFalse(onlyUpper.contains("password") || onlyUpper.contains("\"id\""));
        assertEquals("[]", body(getAs(alice, "/api/users/search?username=zzzz")));
        assertEquals(400, getAs(alice, "/api/users/search?username=a_b").getResponse().getStatus());
        assertEquals(400, getAs(alice, "/api/users/search?username=%25").getResponse().getStatus());
    }

    @Test
    void everythingRequiresLogin() throws Exception {
        for (String url : List.of("/api/sea/me", "/api/sea/me/letters", "/api/inbox", "/api/sent", "/api/letters/1", "/api/users/search?username=a")) {
            assertEquals(401, mvc.perform(get(url)).andReturn().getResponse().getStatus(), url);
        }
        assertEquals(401, mvc.perform(post("/api/letters").contentType(MediaType.APPLICATION_JSON)
                .content("{\"receiverUsername\":\"Bob123\",\"content\":\"x\"}")).andReturn().getResponse().getStatus());
    }
}
