# 데이터 모델 — Message Bottle

## 1. 기준과 범위

입력 문서는 `CLAUDE.md`(기능 명세), `docs/requirements.md`, `docs/ui-spec.md`, `docs/ui-flow.md`이다. 핵심 자료는 유리병 편지 한 종류이며 발송·바다 표시(최대 10개)·대기열·7일 만료·열람·보관·버리기·답장·보낸 편지함·공개 바다 방문·공유 바다(띄우기·낚기·답장)를 지원한다. 사진 첨부·실시간 채팅·이메일 인증·프로필 화면·공유 바다 편지의 만료는 이번 설계에 넣지 않는다.

이 문서는 **이미 구현되어 실행 중인 구조**를 적은 것이다. 예시(찾아줘)와 달리 DB는 H2가 아니라 MySQL 8이고, 테이블은 SQL 파일로 만들지 않고 Spring Data JPA 엔티티에서 Hibernate가 생성한다(`spring.jpa.hibernate.ddl-auto=update`). 아래 자료형과 제약은 2026-11-11에 개발 DB(`message_bottle`)에서 `SHOW CREATE TABLE`로 읽은 실제 구조와 엔티티 코드를 대조해 적었다. 문서와 실제 구조가 다르면 DB 구조를 먼저 확인하고 문서와 변경 계획을 함께 검토한다.

## 2. 화면 값과 저장 범위

| 분류 | 논리 이름·값 | 저장 방식 |
|---|---|---|
| 사용자 입력(가입) | username, password | users에 저장. 비밀번호는 해시(`password_hash`)만 저장 |
| 사용자 입력(편지) | receiverUsername, content, anonymous | letters의 receiver_id·content·is_anonymous |
| 사용자 입력(답장) | content | 새 letters 행. 받는 사람·부모 편지는 서버가 정함 |
| 사용자 입력(공유 바다) | content | shared_letters.content. 받는 사람·익명 선택 없음 |
| 사용자 입력(설정) | 바다 공개 여부 | users.sea_visibility |
| 시스템 관리 | id, sender_id, status, sent_at, expires_at, opened_at, created_at, archived_at, replied, deleted_at, author_id, replied_at, 토큰 해시 | 서버가 인증 사용자·서버 시각·규칙으로 정함. 요청 본문으로 받지 않음 |
| 화면 상태 | 로딩·전송 중 표시, 답장 임시 저장, UI 숨김 대기 시간(1~10초), 파도 타입, 유리병 자리, 낚기 애니메이션 단계 | 기기에서만 관리(임시 저장·설정은 `shared_preferences`). 서버 테이블에 열을 추가하지 않음 |

편지 쓰기 화면의 익명 스위치는 기본 꺼짐이고, 요청에서 `anonymous`를 생략하면 서버는 익명이 아닌 것으로 본다. 화면의 기본 선택이 DB에 행이 저장되었다는 뜻은 아니다.

## 3. 테이블과 관계

| 테이블 | 한 행의 의미 | 역할 |
|---|---|---|
| users | 사용자 한 명(아이디·비밀번호 해시·바다 공개 여부) | 계정. 사용자 행이 곧 그 사용자의 "바다"이며 바다 테이블은 따로 없다 |
| letters | 유리병 편지 한 건(일반 편지, 답장, 공유 바다 편지에 대한 답장) | 핵심 업무 테이블. 바다 상태(status)를 가진다 |
| letter_archives | 수신자가 보관한(또는 답장해서 자동 보관된) 편지 한 건 | 받은 편지함. 삭제는 소프트 삭제 |
| shared_letters | 공유 바다에 띄운 편지 한 건 | 공유 바다. 답장을 받으면 사라짐(REPLIED) |
| refresh_tokens | 발급한 리프레시 토큰 한 개의 해시 | 로그인 유지·로그아웃·토큰 갱신 |
| user_settings | 사용자 한 명의 화면 설정(바다 색감·글자 크기·UI 숨김 대기 시간·파도 종류) | 사용자별 설정. 2026-11-11 추가. 한 사용자에 한 행, 처음 바꿀 때 만든다 |

관계는 다음과 같다.

- `users 1 → N letters` (sender_id): 한 사용자는 여러 편지를 보낸다.
- `users 1 → N letters` (receiver_id): 한 사용자의 바다로 여러 편지가 온다.
- `letters 1 → N letters` (parent_letter_id, 자기 참조): 답장은 바로 이전 편지를 부모로 참조한다. 단계 제한 없음.
- `shared_letters 1 → 0..1 letters` (shared_parent_id): 공유 바다 편지에 대한 답장. 이때 parent_letter_id는 NULL이다. 한 편지에 답장은 한 번만 성공한다.
- `letters 1 → 0..1 letter_archives` (letter_id, UNIQUE): 편지 한 건은 한 번만 보관된다.
- `users 1 → N letter_archives` (owner_id): 보관함의 주인(편지의 수신자).
- `users 1 → N shared_letters` (author_id): 공유 바다 편지의 작성자. 서버만 알고 응답에는 넣지 않는다.
- `users 1 → N refresh_tokens` (user_id): 외래키 제약 없이 값만 저장한다(9장 참고).

## 4. users 구조

| 열 | 자료형 | 필수·키 | 의미 |
|---|---|---|---|
| id | BIGINT | NOT NULL·PRIMARY KEY·AUTO_INCREMENT | 사용자 식별자 |
| username | VARCHAR(20), `utf8mb4_bin` | NOT NULL·UNIQUE | 아이디. 영문 대소문자·숫자 4~20자. 대소문자를 구분하는 collation이라 `Abc`와 `abc`는 다른 사용자 |
| password_hash | VARCHAR(255) | NOT NULL | 비밀번호의 단방향 해시(BCrypt). 평문은 저장하지 않음 |
| sea_visibility | ENUM('PRIVATE','PUBLIC') | NOT NULL | 바다 공개 여부. 가입 시 PRIVATE |
| created_at | DATETIME(6) | NOT NULL | 가입 시각. 수정하지 않음 |
| updated_at | DATETIME(6) | NOT NULL | 마지막 변경 시각 |

이메일·이메일 인증은 없다. 아이디 검색(`GET /api/users/search`)의 부분 일치도 같은 collation 때문에 대소문자를 구분한다.

## 5. 업무 테이블 필드 정의

### letters

| 논리 이름 | DB 열 이름 | MySQL 자료형 | NULL | 키·기본값 | 의미·입력 조건 |
|---|---|---|---|---|---|
| id | id | BIGINT | 불가 | PRIMARY KEY·AUTO_INCREMENT | 편지 식별자. 요청으로 받지 않음 |
| sender | sender_id | BIGINT | 불가 | FOREIGN KEY → users(id) | 발신자. 인증한 사용자로 정함. 익명 편지여도 내부적으로 보관하며 수신자 응답에는 넣지 않음 |
| receiver | receiver_id | BIGINT | 불가 | FOREIGN KEY → users(id) | 수신자(편지가 도착하는 바다의 주인) |
| parent | parent_letter_id | BIGINT | 허용 | FOREIGN KEY → letters(id) | 답장이면 바로 이전 편지. 일반 편지는 NULL |
| sharedParent | shared_parent_id | BIGINT | 허용 | FOREIGN KEY → shared_letters(id) | 공유 바다 편지에 대한 답장이면 그 공유 편지 |
| content | content | LONGTEXT | 불가 | 기본값 없음 | 편지 내용. 공백만 있는 내용은 API에서 거부 |
| anonymous | is_anonymous | BIT(1) | 불가 | 기본값 없음 | 익명 여부. 답장과 공유 바다 답장은 항상 false |
| status | status | ENUM('ARCHIVED','DISCARDED','FLOATING','SUNK','WAITING') | 불가 | 기본값 없음 | 수신자 바다에서의 상태(아래 표) |
| sentAt | sent_at | DATETIME(6) | 불가 | 서버 시각 | 최초 발송 시각. 대기열 순서(FIFO)와 만료의 기준 |
| expiresAt | expires_at | DATETIME(6) | 불가 | sent_at + 7일 | 만료 시각. 대기열에 오래 있어도 늘어나지 않음 |
| openedAt | opened_at | DATETIME(6) | 허용 | 기본값 없음 | 수신자가 처음 연 시각. 열람 후 이탈 판단에 사용 |
| createdAt | created_at | DATETIME(6) | 불가 | sent_at과 같은 값 | 생성 시각. 수정하지 않음 |

| status | 의미 | 바다 수용량(10개) | 7일 만료 대상 |
|---|---|---|---|
| WAITING | 바다가 가득 차서 순서를 기다림 | 차지하지 않음 | 대상 |
| FLOATING | 수신자의 바다에 떠 있음 | 차지함 | 대상 |
| SUNK | 발송 7일 후 만료됨 | 차지하지 않음 | — |
| DISCARDED | 수신자가 X로 버렸거나, 열어 본 뒤 답장·보관·X 없이 이탈함 | 차지하지 않음 | — |
| ARCHIVED | 수신자가 보관했거나 답장해서 자동 보관됨 | 차지하지 않음 | 대상 아님 |

`ARCHIVED`는 `CLAUDE.md` 12장의 초안(`WAITING`·`FLOATING`·`SUNK`·`DISCARDED`)에 없는 값으로, 보관된 편지를 수용량과 만료에서 빼기 위해 구현에서 추가했다.

인덱스: `idx_letter_receiver_status(receiver_id, status, sent_at)`는 바다·대기열 조회, `idx_letter_sender(sender_id, sent_at)`는 보낸 편지함, `idx_letter_expiry(status, expires_at)`는 만료 스케줄러가 쓴다.

### letter_archives

| 논리 이름 | DB 열 이름 | MySQL 자료형 | NULL | 키·기본값 | 의미 |
|---|---|---|---|---|---|
| id | id | BIGINT | 불가 | PRIMARY KEY·AUTO_INCREMENT | 보관 항목 식별자(`/api/inbox/{archiveId}`) |
| letter | letter_id | BIGINT | 불가 | FOREIGN KEY → letters(id)·UNIQUE | 보관한 편지. 한 편지는 한 번만 보관 |
| owner | owner_id | BIGINT | 불가 | FOREIGN KEY → users(id) | 보관함 주인 |
| archivedAt | archived_at | DATETIME(6) | 불가 | 서버 시각 | 보관 시각. 목록 정렬 기준 |
| replied | replied | BIT(1) | 불가 | 기본값 없음 | 답장을 보내 자동 보관되었으면 true(카드의 체크 아이콘) |
| deletedAt | deleted_at | DATETIME(6) | 허용 | 기본값 없음 | 받은 편지함에서 삭제한 시각(소프트 삭제). 값이 있으면 수신자에게 보이지 않음 |

인덱스: `idx_archive_owner(owner_id, deleted_at, archived_at)`.

### shared_letters

| 논리 이름 | DB 열 이름 | MySQL 자료형 | NULL | 키·기본값 | 의미 |
|---|---|---|---|---|---|
| id | id | BIGINT | 불가 | PRIMARY KEY·AUTO_INCREMENT | 공유 편지 식별자 |
| author | author_id | BIGINT | 불가 | FOREIGN KEY → users(id) | 작성자. 답장을 작성자의 바다로 보내기 위해 보관. 응답에는 절대 넣지 않음 |
| content | content | LONGTEXT | 불가 | 기본값 없음 | 편지 내용 |
| status | status | ENUM('OPEN','REPLIED') | 불가 | 띄울 때 OPEN | OPEN은 낚을 수 있음, REPLIED는 답장을 받아 사라짐 |
| createdAt | created_at | DATETIME(6) | 불가 | 서버 시각 | 띄운 시각(낚은 사람에게는 `sentAt`으로 전달) |
| repliedAt | replied_at | DATETIME(6) | 허용 | 기본값 없음 | 답장을 받은 시각 |

인덱스: `idx_shared_status(status, id)`. 만료 열은 없다(공유 바다 편지는 만료하지 않기로 정함).

### user_settings (2026-11-11 추가)

| 논리 이름 | DB 열 이름 | MySQL 자료형 | NULL | 키·기본값 | 의미 |
|---|---|---|---|---|---|
| id | id | BIGINT | 불가 | PK, AUTO_INCREMENT | 설정 행 식별자(응답에 넣지 않음) |
| user | user_id | BIGINT | 불가 | UNIQUE, FK → users(id) ON DELETE CASCADE | 설정의 주인. 한 사용자에 한 행 |
| seaTone | sea_tone | ENUM('DAY','NIGHT','SYSTEM') | 불가 | 앱 기본 DAY | 바다 색감 |
| textStep | text_step | INT | 불가 | 앱 기본 1 | 글자 크기 단계 0~4 (85/100/115/130/140%) |
| idleSeconds | idle_seconds | INT | 불가 | 앱 기본 5 | UI 숨김 대기 시간 1~10초 |
| waveType | wave_type | ENUM('BOTH','CALM','ROUGH') | 불가 | 앱 기본 BOTH | 파도 종류 |
| updatedAt | updated_at | DATETIME(6) | 불가 | 서버 시각 | 마지막으로 바꾼 시각 |

행이 없는 사용자는 API가 기본값을 돌려준다. `text_step`·`idle_seconds`의 범위는 DB가 아니라 API(`UserSettingsRequest`)가 검사한다. 같은 사용자의 첫 저장이 동시에 와도 행이 하나만 생기도록 서비스가 users 행을 `FOR UPDATE`로 잠근다. 실제 구조는 2026-11-11 개발 DB의 `SHOW CREATE TABLE user_settings`로 확인했다.

### refresh_tokens

| 논리 이름 | DB 열 이름 | MySQL 자료형 | NULL | 키·기본값 | 의미 |
|---|---|---|---|---|---|
| id | id | BIGINT | 불가 | PRIMARY KEY·AUTO_INCREMENT | 식별자 |
| userId | user_id | BIGINT | 불가 | 외래키 제약 없음 | 토큰 주인 |
| tokenHash | token_hash | VARCHAR(64) | 불가 | UNIQUE(`idx_refresh_token_hash`) | 리프레시 토큰의 해시. 토큰 원문은 저장하지 않음 |
| expiresAt | expires_at | DATETIME(6) | 불가 | 발급 + 14일 | 만료 시각 |
| revokedAt | revoked_at | DATETIME(6) | 허용 | 기본값 없음 | 로그아웃·갱신으로 폐기한 시각 |

`AUTO_INCREMENT`는 새 ID를 발급하는 방식이다. 삭제나 실패한 요청으로 중간 번호가 비어도 정상이며 연속 번호로 다시 매기지 않는다. `DATETIME(6)`에는 시간대 정보가 없고, 서버 기본 시간대의 시각을 그대로 저장한다(JDBC URL은 `serverTimezone=Asia/Seoul`).

## 6. DB 제약과 API 검증

| 조건 | DB에서 확인할 내용 | API·UI에서 확인할 내용 |
|---|---|---|
| 아이디 형식 | VARCHAR(20)·NOT NULL | 영문 대소문자·숫자만 4~20자(`[A-Za-z0-9]{4,20}`) |
| 아이디 중복 | UNIQUE + `utf8mb4_bin`(대소문자 구분) | 중복이면 가입 거부 안내 |
| 비밀번호 | 해시만 저장(NOT NULL) | 영문·숫자·특수기호 8~20자(`[\x21-\x7E]{8,20}`) |
| 편지 내용 | NOT NULL | 공백만 있으면 거부(`@NotBlank`). 길이 상한은 정하지 않음 |
| 받는 사람 | receiver_id가 존재하는 users.id | 아이디로 사용자를 찾고, 없으면 거부 |
| 상태 값 | ENUM 허용 값만 | 상태 전환은 서비스 계층 트랜잭션에서만 수행 |
| 바다 최대 10개 | DB 제약 없음 | 수신자 사용자 행을 잠근 뒤 FLOATING 수를 세어 10개면 WAITING으로 저장 |
| 대기열 FIFO | DB 제약 없음 | 빈자리만큼 `sent_at`, `id` 오름차순으로 승격 |
| 7일 만료 | expires_at NOT NULL | 생성 시 sent_at + 7일. 스케줄러와 조회 시점 양쪽에서 SUNK 처리 |
| 중복 보관 | letter_archives.letter_id UNIQUE | 이미 처리된 편지의 보관 요청 거부 |
| 답장 권한 | parent_letter_id가 존재하는 편지 | 원본의 수신자만, 바다에 떠 있는 편지에만, 익명 편지에는 불가 |
| 공유 편지 답장 1회 | DB 제약 없음 | 공유 편지 행을 잠그고 OPEN일 때만 성공. 자기 편지에는 불가 |
| 소유권 | 외래키로 사용자 존재만 보장 | 모든 편지 조회·변경에서 인증 사용자와 수신자·발신자·보관함 주인을 대조 |
| 익명 보호 | sender_id는 그대로 저장 | 수신자용 응답 DTO와 오류 메시지에 발신자 정보를 넣지 않음 |
| 공개 바다 | DB 제약 없음 | 비공개면 서버가 거부. 공개면 개수만 담은 전용 DTO 반환 |

`NOT NULL`은 빈 문자열이나 공백만 있는 문자열을 거부하지 않는다. 내용의 공백 검사는 API가 한다. 외래키는 참조하는 사용자·편지가 존재하는지만 보장하며, 요청자가 그 편지를 볼 권한이 있는지는 API의 인증·소유권 검사가 맡는다.

수용량 10개, FIFO 승격, 공유 편지 답장 1회는 DB 제약으로 표현하지 않았다. 대신 수신자의 users 행(또는 공유 편지 행)을 `SELECT … FOR UPDATE`로 잠그고 `READ_COMMITTED` 트랜잭션 안에서 처리해 동시 요청에도 규칙이 깨지지 않게 한다. DB 서버의 기본 격리 수준은 `REPEATABLE-READ`이고, 서비스 메서드가 트랜잭션마다 `READ_COMMITTED`를 지정한다.

시간의 "지금"은 서버 시각(`Clock`)이다. 만료와 열람 후 이탈은 앱의 시각이 아니라 서버 시각으로 판단한다.

## 7. 조회·변경 기준

| 동작 | 기준 |
|---|---|
| 내 바다 | receiver_id가 나이고 status=FLOATING인 편지를 sent_at, id 오름차순으로. 조회 전에 만료·승격을 먼저 반영 |
| 열람 후 이탈 | 앱이 다시 시작되어 바다를 불러올 때, opened_at이 있는 FLOATING 편지를 DISCARDED로 바꿈 |
| 발송 | 새 letters 행. 수신자의 FLOATING이 10개 미만이면 FLOATING, 아니면 WAITING |
| 승격 | 빈자리만큼 WAITING을 sent_at이 빠른 순서로 FLOATING으로 |
| 만료 | expires_at이 지난 WAITING·FLOATING을 SUNK로. ARCHIVED는 대상이 아님 |
| 버리기(X) | status를 DISCARDED로. 행은 지우지 않음(보낸 편지함 기록 유지) |
| 보관 | status를 ARCHIVED로 바꾸고 letter_archives 행 생성(replied=false) |
| 답장 | 새 letters 행(parent_letter_id=원본) 생성과 원본 보관(replied=true)을 한 트랜잭션으로 |
| 받은 편지함 | owner_id가 나이고 deleted_at이 NULL인 letter_archives를 archived_at 내림차순으로 |
| 받은 편지함 삭제 | deleted_at에 시각 기록(소프트 삭제). letters 행과 발신자 기록은 그대로 |
| 보낸 편지함 | sender_id가 나인 letters를 sent_at 내림차순으로. status와 무관. 삭제 API 없음 |
| 이전 편지 보기 | 부모 편지가 내가 보낸 편지이거나 내가 받아 보관함에 둔 편지일 때만 조회 가능 |
| 공개 바다 방문 | 대상이 PUBLIC일 때 FLOATING 개수만 반환. WAITING은 세지 않음 |
| 공유 바다 낚기 | status=OPEN이고 author_id가 내가 아닌 것 중 무작위 하나. 상태를 바꾸지 않음 |
| 공유 바다 답장 | 공유 편지를 REPLIED로 바꾸고, 작성자의 바다로 새 letters 행(shared_parent_id) 생성 |

어떤 동작도 letters 행을 실제로 삭제하지 않는다. 발신자의 보낸 편지함이 수신자의 보관·삭제·만료와 무관하게 영구 보존되어야 하기 때문이다.

## 8. 초기 준비와 스키마 적용

예시와 달리 초기 자료 테이블(app_users·lab_items·COURSE_BOOTSTRAP)은 없고, 미리 넣어 두는 샘플 행도 없다. 사용자는 회원가입 API로, 편지는 발송 API로 만든다.

| 대상 | 방식 | 기준 |
|---|---|---|
| 개발 DB `message_bottle` | 서버 실행 시 Hibernate가 엔티티에 맞춰 테이블 생성·열 추가(`ddl-auto=update`) | 데이터베이스 자체는 미리 만들어 둔다. 접속 정보는 환경변수 `DB_URL`·`DB_USERNAME`·`DB_PASSWORD` |
| 테스트 DB `message_bottle_test` | 테스트 실행 때마다 생성하고 끝나면 삭제(`ddl-auto=create-drop`) | 개발 DB를 건드리지 않음. 데이터베이스 자체는 미리 만들어 둔다 |

`ddl-auto=update`는 새 테이블과 새 열은 만들지만, 기존 열의 자료형 변경이나 열 삭제는 하지 않는다. 엔티티에서 열을 지우거나 바꾸면 실제 구조가 문서와 달라질 수 있으므로 `SHOW CREATE TABLE`로 먼저 확인하고, DROP·전체 삭제를 기본 해결책으로 쓰지 않는다. ENUM 열은 값이 추가될 때 Hibernate가 열 정의를 바꾸는지 확인이 필요하다(`ARCHIVED`를 추가했을 때는 반영되어 있다).

`docs/sql/`의 생성·샘플 SQL 파일은 만들지 않았다. 필요하면 현재 구조에서 뽑아 작성할 수 있다(9장).

## 9. 다음에 확정할 항목

| 항목 | 현재 기준 | 다음 확인 |
|---|---|---|
| 스키마 관리 | Hibernate `ddl-auto=update` | 제출·배포용으로 SQL 파일(생성·샘플)을 따로 둘지 |
| refresh_tokens.user_id | 외래키 제약 없이 값만 저장 | users(id) 외래키를 추가할지 |
| 편지 내용 길이 | LONGTEXT, 상한 없음 | 화면과 서버에 최대 길이를 둘지 |
| 공유 바다 편지 만료 | 없음(결정됨) | 운영 중 편지가 쌓일 때의 정리 방법 |
| 내가 띄운 공유 편지 | 보낸 편지함에 넣지 않음. 답장에서 "이전 편지 보기"로만 볼 수 있음 | 다시 보는 화면을 만들지 |
| 시간대 | 서버 기본 시간대의 시각을 DATETIME으로 저장 | 서버 PC의 시간대가 바뀌는 환경에서의 동작 |
| 오래된 토큰·만료 편지 | 지우지 않고 쌓임 | 정리 작업을 둘지 |

## 10. 설계 검토 기준

`CLAUDE.md` 12장의 논리 필드가 모두 대응되는지(추가된 것: letters.status의 `ARCHIVED`, letters.shared_parent_id, shared_letters 테이블), 사용자 입력과 시스템 관리값이 구분되는지, 키·자료형·NULL·관계·허용 값이 실제 구조와 같은지 확인한다. 확인 결과는 `db-verification.md`에 기록한다.
