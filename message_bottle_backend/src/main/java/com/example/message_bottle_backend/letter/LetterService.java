package com.example.message_bottle_backend.letter;

import com.example.message_bottle_backend.common.ApiException;
import com.example.message_bottle_backend.letter.dto.*;
import com.example.message_bottle_backend.user.User;
import com.example.message_bottle_backend.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class LetterService {

    private static final String GONE = "이미 사라졌거나 존재하지 않는 편지입니다.";

    private final UserRepository userRepository;
    private final LetterRepository letterRepository;
    private final LetterArchiveRepository archiveRepository;
    private final SeaService seaService;
    private final Clock clock;

    /* ---------- 발송 ---------- */

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public SentLetterResponse send(Long senderId, SendLetterRequest request) {
        User receiver = userRepository.findByUsername(request.receiverUsername())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "존재하지 않는 사용자입니다."));
        if (receiver.getId().equals(senderId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "나 자신에게는 보낼 수 없습니다.");
        }
        seaService.lock(receiver.getId());
        seaService.normalizeLocked(receiver.getId(), false);
        Letter letter = deliverLocked(userRepository.getReferenceById(senderId), userRepository.getReferenceById(receiver.getId()),
                null, request.content(), request.anonymousOrDefault());
        return new SentLetterResponse(letter.getId(), request.receiverUsername(), letter.isAnonymous(), letter.getSentAt());
    }

    /**
     * 받는 사람의 사용자 행을 잠근 상태에서 호출한다. 바다에 빈자리가 있으면 떠 있는 편지(FLOATING),
     * 가득 찼으면 대기(WAITING)로 저장하며 발송 자체는 거부하지 않는다.
     */
    private Letter deliverLocked(User sender, User receiver, Letter parent, String content, boolean anonymous) {
        LetterStatus status = seaService.capacityLeft(receiver.getId()) > 0 ? LetterStatus.FLOATING : LetterStatus.WAITING;
        return letterRepository.save(new Letter(sender, receiver, parent, content, anonymous, status, LocalDateTime.now(clock)));
    }

    /** 공유 바다에서 낚은 편지에 대한 답장을 작성자의 바다로 전달한다. 작성자의 사용자 행을 잠근 상태에서 호출한다. */
    Letter deliverSharedReplyLocked(Long replierId, SharedLetter shared, String content) {
        User author = shared.getAuthor();
        LetterStatus status = seaService.capacityLeft(author.getId()) > 0 ? LetterStatus.FLOATING : LetterStatus.WAITING;
        return letterRepository.save(new Letter(userRepository.getReferenceById(replierId), author, shared, content,
                status, LocalDateTime.now(clock)));
    }

    /* ---------- 답장 ---------- */

    /**
     * 바다에서 받은 직후의 일반 편지에만 답장할 수 있다. 새 편지가 원 발신자에게 가고,
     * 원본은 같은 트랜잭션에서 자동으로 받은 편지함에 보관된다.
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public SentLetterResponse reply(Long userId, Long letterId, ReplyRequest request) {
        Letter first = letterRepository.findWithUsersById(letterId)
                .filter(l -> l.getReceiver().getId().equals(userId))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE));
        Long targetId = first.getSender().getId();

        // 서로에게 동시에 답장해도 교착되지 않도록 항상 id 순서로 잠근다.
        lockInOrder(userId, targetId);
        seaService.normalizeLocked(userId, false);
        seaService.normalizeLocked(targetId, false);

        Letter original = letterRepository.findWithUsersById(letterId)
                .filter(l -> l.getReceiver().getId().equals(userId) && l.getStatus() == LetterStatus.FLOATING)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE));
        if (original.isAnonymous()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "익명 편지에는 답장할 수 없습니다.");
        }
        LocalDateTime now = LocalDateTime.now(clock);
        Letter reply = deliverLocked(original.getReceiver(), original.getSender(), original, request.content(), false);
        original.changeStatus(LetterStatus.ARCHIVED);
        archiveRepository.save(new LetterArchive(original, original.getReceiver(), now, true));
        seaService.promoteLocked(userId);
        return new SentLetterResponse(reply.getId(), original.getSender().getUsername(), false, reply.getSentAt());
    }

    /* ---------- 열람 · 보관 · 버리기 ---------- */

    /** 수신자가 바다의 편지를 처음 열면 열람 시각을 기록한다. 발신자는 자기가 보낸 편지를 읽기만 한다. */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public LetterDetailResponse get(Long userId, Long letterId) {
        Letter peek = letterRepository.findWithUsersById(letterId).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE));
        if (peek.getSender().getId().equals(userId)) {
            return new LetterDetailResponse(peek.getId(), "SENDER", receiverName(peek), peek.isAnonymous(),
                    peek.getContent(), peek.getSentAt(), false, false, parentIdFor(peek, userId));
        }
        if (!peek.getReceiver().getId().equals(userId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, GONE); // 남의 편지는 존재 여부도 알려주지 않는다
        }
        seaService.normalize(userId);
        Letter letter = letterRepository.findWithUsersById(letterId).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE));
        if (letter.getStatus() == LetterStatus.FLOATING) {
            letter.markOpened(LocalDateTime.now(clock));
            return receiverView(letter, userId, !letter.isAnonymous(), true);
        }
        if (letter.getStatus() == LetterStatus.ARCHIVED
                && archiveRepository.findByLetterIdAndOwnerIdAndDeletedAtIsNull(letterId, userId).isPresent()) {
            return receiverView(letter, userId, false, false);
        }
        throw new ApiException(HttpStatus.NOT_FOUND, GONE);
    }

    private LetterDetailResponse receiverView(Letter l, Long userId, boolean canReply, boolean canArchive) {
        String counterpart = l.isAnonymous() ? null : l.getSender().getUsername();
        return new LetterDetailResponse(l.getId(), "RECEIVER", counterpart, l.isAnonymous(), l.getContent(), l.getSentAt(),
                canReply, canArchive, parentIdFor(l, userId));
    }

    /* ---------- 답장의 이전(부모) 편지 ---------- */

    /**
     * 답장에서 이전 편지로 거슬러 올라간다. 내가 보낸 편지이거나, 내가 받아 보관함에 두고 있는 편지만 볼 수 있다.
     * 그 밖에는 존재 여부도 알려주지 않는다(404). 익명 편지를 받은 쪽에는 발신자를 알려주지 않는다.
     */
    @Transactional(readOnly = true)
    public ParentLetterResponse parent(Long userId, Long letterId) {
        Letter child = letterRepository.findWithUsersById(letterId)
                .filter(l -> l.getSender().getId().equals(userId) || l.getReceiver().getId().equals(userId))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE));
        SharedLetter shared = child.getSharedParent();
        if (shared != null) {
            // 공유 바다에 띄운 내 편지에 대한 답장이면, 내가 띄운 편지로 거슬러 올라간다(받는 사람이 없다).
            if (!shared.getAuthor().getId().equals(userId)) {
                throw new ApiException(HttpStatus.NOT_FOUND, GONE);
            }
            return new ParentLetterResponse(shared.getId(), "SENDER", null, true, shared.getContent(),
                    shared.getCreatedAt(), null);
        }
        Letter p = child.getParent();
        if (p == null || !viewable(p, userId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, GONE);
        }
        boolean iAmSender = p.getSender().getId().equals(userId);
        String counterpart = iAmSender ? receiverName(p) : senderName(p);
        return new ParentLetterResponse(p.getId(), iAmSender ? "SENDER" : "RECEIVER", counterpart, p.isAnonymous(),
                p.getContent(), p.getSentAt(), parentIdFor(p, userId));
    }

    /** 내가 볼 수 있는 편지인가: 내가 보낸 편지, 또는 내가 받아 보관함에 남아 있는 편지. */
    private boolean viewable(Letter l, Long userId) {
        if (l.getSender().getId().equals(userId)) {
            return true;
        }
        return l.getReceiver().getId().equals(userId) && l.getStatus() == LetterStatus.ARCHIVED
                && archiveRepository.findByLetterIdAndOwnerIdAndDeletedAtIsNull(l.getId(), userId).isPresent();
    }

    /** 이 편지의 부모가 있고 내가 볼 수 있을 때만 그 id를 돌려준다. */
    private Long parentIdFor(Letter l, Long userId) {
        SharedLetter shared = l.getSharedParent();
        if (shared != null) { // 이 id는 공유 편지의 id다. 값이 있는지만 쓰이고, 부모 조회는 항상 자식 편지 id로 한다.
            return shared.getAuthor().getId().equals(userId) ? shared.getId() : null;
        }
        Letter p = l.getParent();
        return p != null && viewable(p, userId) ? p.getId() : null;
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public ArchiveResponse archive(Long userId, Long letterId) {
        Letter letter = ownedFloating(userId, letterId, true);
        letter.changeStatus(LetterStatus.ARCHIVED);
        LetterArchive archive = archiveRepository.save(new LetterArchive(letter, letter.getReceiver(), LocalDateTime.now(clock), false));
        seaService.promoteLocked(userId);
        return new ArchiveResponse(archive.getId());
    }

    @Transactional(isolation = Isolation.READ_COMMITTED)
    public void discard(Long userId, Long letterId) {
        Letter letter = ownedFloating(userId, letterId, false);
        letter.changeStatus(LetterStatus.DISCARDED);
        seaService.promoteLocked(userId);
    }

    /** 수신자 본인의 떠 있는 편지를 잠금·정리 후 다시 읽어 돌려준다. */
    private Letter ownedFloating(Long userId, Long letterId, boolean forArchive) {
        letterRepository.findById(letterId)
                .filter(l -> l.getReceiver().getId().equals(userId))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE));
        seaService.normalize(userId);
        Letter letter = letterRepository.findWithUsersById(letterId).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE));
        if (forArchive && letter.getStatus() == LetterStatus.ARCHIVED) {
            throw new ApiException(HttpStatus.CONFLICT, "이미 보관한 편지입니다.");
        }
        if (letter.getStatus() != LetterStatus.FLOATING) {
            throw new ApiException(HttpStatus.NOT_FOUND, GONE);
        }
        return letter;
    }

    /* ---------- 받은 편지함 ---------- */

    @Transactional(readOnly = true)
    public List<InboxItemResponse> inbox(Long userId) {
        return archiveRepository.findByOwnerIdAndDeletedAtIsNullOrderByArchivedAtDescIdDesc(userId).stream()
                .map(a -> {
                    Letter l = a.getLetter();
                    return new InboxItemResponse(a.getId(), l.getId(), senderName(l), l.isAnonymous(),
                            LetterPolicy.preview(l.getContent()), l.getSentAt(), a.getArchivedAt(), a.isReplied());
                })
                .toList();
    }

    @Transactional(readOnly = true)
    public InboxDetailResponse inboxDetail(Long userId, Long archiveId) {
        LetterArchive a = archiveRepository.findByIdAndOwnerIdAndDeletedAtIsNull(archiveId, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE));
        Letter l = a.getLetter();
        return new InboxDetailResponse(a.getId(), l.getId(), senderName(l), l.isAnonymous(), l.getContent(),
                l.getSentAt(), a.getArchivedAt(), a.isReplied(), parentIdFor(l, userId));
    }

    /** 보관함에서 삭제(소프트 삭제). 발신자의 보낸 편지함 기록에는 영향이 없다. */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public void deleteFromInbox(Long userId, Long archiveId) {
        archiveRepository.findByIdAndOwnerIdAndDeletedAtIsNull(archiveId, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE))
                .delete(LocalDateTime.now(clock));
    }

    /** 익명 편지의 발신자 아이디는 수신자 응답에 절대 넣지 않는다. */
    private String senderName(Letter l) {
        return l.isAnonymous() ? null : l.getSender().getUsername();
    }

    /* ---------- 보낸 편지함 (삭제 없음) ---------- */

    @Transactional(readOnly = true)
    public List<SentItemResponse> sent(Long userId) {
        return letterRepository.findBySenderIdOrderBySentAtDescIdDesc(userId).stream()
                .map(l -> new SentItemResponse(l.getId(), receiverName(l), l.isAnonymous(),
                        LetterPolicy.preview(l.getContent()), l.getSentAt()))
                .toList();
    }

    @Transactional(readOnly = true)
    public SentDetailResponse sentDetail(Long userId, Long letterId) {
        Letter l = letterRepository.findWithUsersById(letterId)
                .filter(x -> x.getSender().getId().equals(userId))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, GONE));
        return new SentDetailResponse(l.getId(), receiverName(l), l.isAnonymous(), l.getContent(), l.getSentAt(),
                parentIdFor(l, userId));
    }

    /** 공유 바다에서 낚은 익명 편지에 보낸 답장은 받는 사람(익명 작성자)의 아이디를 보내는 사람에게도 알려주지 않는다. */
    private String receiverName(Letter l) {
        return l.getSharedParent() != null ? null : l.getReceiver().getUsername();
    }

    private void lockInOrder(Long a, Long b) {
        seaService.lock(Math.min(a, b));
        if (!a.equals(b)) {
            seaService.lock(Math.max(a, b));
        }
    }
}
