# DB 검증 계획·기록 — Message Bottle

2026-11-11에 Claude Code가 개발 PC에서 실행한 결과를 적었다. 구조와 집계는 개발 DB(`message_bottle`)를 조회해 확인했고, 등록·수정·삭제와 제약 위반은 개발 DB에 연습용 행(`dbcheck…` 사용자와 그 편지)을 만들어 확인한 뒤 모두 지웠다. 기존 자료는 바꾸지 않았다. 업무 규칙은 별도 테스트 DB에서 도는 백엔드 자동 테스트로 확인했다.

## 1. 실행 환경

| 항목 | 기준 | 실제 값 |
|---|---|---|
| 실행 폴더 | 프로젝트의 백엔드 폴더 | `message_bottle_backend` |
| Java | — | OpenJDK 27.0.1 |
| 프레임워크 | Spring Boot·Spring Data JPA | Spring Boot 4.1.2 |
| DB | MySQL | MySQL 8.0.46 (localhost:3306) |
| 서버 주소 | 모든 인터페이스에서 수신 | `0.0.0.0:8080` (사용자가 띄워 둔 서버가 사용 중). 확인용 서버는 8090 포트 |
| JDBC URL(개발) | 환경변수 `DB_URL` | `jdbc:mysql://localhost:3306/message_bottle?serverTimezone=Asia/Seoul&characterEncoding=UTF-8` |
| JDBC URL(테스트) | `application-test.properties` | `jdbc:mysql://localhost:3306/message_bottle_test?serverTimezone=Asia/Seoul&characterEncoding=UTF-8` |
| DB 사용자 | 환경변수 `DB_USERNAME`·`DB_PASSWORD` | 설정되어 있음(값은 기록하지 않음) |
| DB 기본 문자셋 | — | `utf8mb4` / `utf8mb4_unicode_ci` |
| DB 기본 격리 수준 | — | `REPEATABLE-READ` (서비스 트랜잭션은 `READ_COMMITTED`를 지정) |
| 스키마 적용 | 개발 `ddl-auto=update`, 테스트 `create-drop` | 설정 파일에서 확인 |
| 문서 기준 | CLAUDE.md·docs/requirements.md·docs/ui-spec.md·data-model.md | 2026-11-11 시점의 파일. Git 저장소가 아니라 커밋 기록 없음 |

## 2. 최초 준비 확인

| 검사 | 기대 결과 | 실제 결과 | 상태 |
|---|---|---|---|
| 테이블 목록 | users·letters·letter_archives·shared_letters·refresh_tokens 다섯 개 | `SHOW TABLES` 결과가 다섯 개로 같음 | 확인 |
| 초기 샘플 | 미리 넣는 샘플 행 없음. 가입·발송 API로만 생성 | 샘플 SQL·초기화 코드 없음 | 확인 |
| 현재 행 수(개발 DB) | 개발 중 직접 만든 자료 | users 17, letters 16, letter_archives 5, shared_letters 1, refresh_tokens 41 | 확인 |
| 테스트 DB | 테스트가 끝나면 테이블이 남지 않음 | 테스트 실행 뒤 `message_bottle_test`의 `SHOW TABLES` 결과 없음 | 확인 |

## 3. 표준 SQL 연습

예시의 연습용 테이블(lab_items)은 이 프로젝트에 없어서, 개발 DB에 연습용 사용자 두 명(`dbcheck01`, `dbcheck02`)을 만들고 그 사이의 편지로 연습했다. 연습용 행은 모두 끝난 뒤 지웠다(8장).

| 단계 | 실행·확인할 내용 | 기대 결과 | 실제 결과 | 상태 |
|---|---|---|---|---|
| 조회 | 테이블별 행 수, 상태별 편지 수 | 현재 자료 확인 | users 17, letters 16(FLOATING 7, DISCARDED 4, ARCHIVED 5), letter_archives 5, shared_letters 1(OPEN), refresh_tokens 41 | 확인 |
| 연습용 사용자 등록 | users에 두 행 INSERT | 두 행·실제 발급 ID 확인 | 2행 등록. 발급 ID 18, 19 | 확인 |
| 등록 | `dbcheck01` → `dbcheck02` 편지 "연습용 편지", status FLOATING | 새 행 한 건·실제 발급 ID 확인 | 1행 등록. 발급 ID 17. opened_at NULL, is_anonymous 0 | 확인 |
| 수정 | `UPDATE letters SET opened_at=NOW(6) WHERE id=17` | 의도한 한 행만 변경 | 영향받은 행 1. id 17의 opened_at에 값이 생기고 status는 FLOATING 그대로 | 확인 |
| 수정 후 | 같은 수신자의 다른 행 조회 | 다른 행 유지 | 다른 행의 변경 0건 | 확인 |
| 삭제 | 연습 행 삭제 | 의도한 행만 제거 | 4장의 한 행 삭제(영향받은 행 1), 나머지 연습 행은 8장 정리 때 삭제 | 확인 |

새 ID는 미리 가정하지 않고 등록 후 `LAST_INSERT_ID()`로 조회한 값을 썼다.

## 4. AI 도전 — 같은 값 두 행 중 한 행 수정

| 항목 | 작성할 내용 |
|---|---|
| 현재 자료 | content가 "같은 내용의 편지"인 편지 두 행(id 18, 19). 발신자·수신자·status(FLOATING)도 같고 sent_at만 1초 차이 |
| 의도 | 나중에 보낸 한 통(id 19)만 버린 편지(DISCARDED)로 바꾼다 |
| AI 요청 | "content가 같은 편지가 두 행 있다. 그중 나중에 보낸 한 행만 DISCARDED로 바꾸려면 어떻게 대상을 좁혀야 하는가" |
| 적용 전 확인 | `WHERE content='같은 내용의 편지'`로 세면 2행이 잡힌다. 내용으로 고르면 두 행이 다 바뀌므로, 먼저 두 행을 조회해 id를 확인하고 기본 키로 지정한다 |
| 실제 실행 | `UPDATE letters SET status='DISCARDED' WHERE id=19` |
| 결과 | 영향받은 행 1. id 19만 DISCARDED, id 18은 FLOATING 그대로. 이어서 `DELETE FROM letters WHERE id=19`로 한 행만 삭제(영향받은 행 1, 같은 내용의 행 1건 남음) |
| 상태 | 확인 |

## 5. 구조 대조

개발 DB에서 `SHOW CREATE TABLE`로 읽은 구조를 `data-model.md`·엔티티와 대조했다.

| 검사 | 문서의 기대 구조 | 실제 구조 | 상태 |
|---|---|---|---|
| 논리 이름→열 이름 | anonymous→is_anonymous, parent→parent_letter_id, sharedParent→shared_parent_id, sentAt→sent_at 등 | 모두 같음 | 확인 |
| ID | 다섯 테이블 모두 BIGINT·AUTO_INCREMENT·PK | 같음 | 확인 |
| users.username | VARCHAR(20)·NOT NULL·UNIQUE·`utf8mb4_bin` | `varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL`, UNIQUE KEY 있음 | 확인 |
| users.sea_visibility | PRIVATE·PUBLIC만 | `enum('PRIVATE','PUBLIC') NOT NULL` | 확인 |
| letters 필수 열 | sender_id·receiver_id·content·is_anonymous·status·sent_at·expires_at·created_at NOT NULL | 같음 | 확인 |
| letters 선택 열 | parent_letter_id·shared_parent_id·opened_at NULL 허용 | 같음(`DEFAULT NULL`) | 확인 |
| letters.status | 다섯 값 | `enum('ARCHIVED','DISCARDED','FLOATING','SUNK','WAITING')` | 확인 |
| letters 외래키 | sender_id·receiver_id→users, parent_letter_id→letters, shared_parent_id→shared_letters | 외래키 네 개 모두 있음 | 확인 |
| letters 인덱스 | idx_letter_receiver_status, idx_letter_sender, idx_letter_expiry | 세 개 모두 있음 | 확인 |
| letter_archives | letter_id UNIQUE·FK, owner_id FK, deleted_at NULL 허용, replied NOT NULL | 같음. idx_archive_owner 있음 | 확인 |
| shared_letters | author_id FK, status `OPEN`·`REPLIED`, replied_at NULL 허용 | 같음. idx_shared_status 있음 | 확인 |
| refresh_tokens | token_hash VARCHAR(64)·UNIQUE, revoked_at NULL 허용 | 같음. user_id에는 외래키 없음(문서 9장에 기록) | 확인 |
| 시각 열 | DATETIME(6) | 모든 시각 열이 `datetime(6)` | 확인 |

## 6. 업무 데이터 확인

### 개발 DB 조회(현재 자료가 규칙을 어기지 않는지)

| 검사 | 기대 결과 | 실제 결과 | 상태 |
|---|---|---|---|
| 바다 수용량 | FLOATING이 10개를 넘는 수신자 없음 | 0명 | 확인 |
| 만료 시각 | 모든 편지가 expires_at = sent_at + 7일 | 어긋난 행 0건 | 확인 |
| 보관 일치 | status=ARCHIVED인 편지는 모두 letter_archives 행이 있음 | 빠진 행 0건 | 확인 |
| 비밀번호 | 평문이 아닌 해시로 저장 | BCrypt 형식(`$2…`)이 아닌 행 0건 | 확인 |

개발 DB의 자료는 16건뿐이라, 위 결과는 "현재 자료에 위반이 없다"는 뜻이지 규칙이 항상 지켜진다는 증명은 아니다. 규칙 자체는 아래 자동 테스트로 확인한다.

### 백엔드 자동 테스트(테스트 DB, `./gradlew test`)

2026-11-11 실행 결과: **61개 모두 통과**(실패 0, 오류 0, 건너뜀 0).

| 테스트 클래스 | 개수 | 확인하는 내용 |
|---|---|---|
| LetterApiTest | 30 | 발송, 수용량 10개와 대기열, FIFO 승격, 7일 만료, 열람·보관·버리기, 열람 후 이탈, 답장과 자동 보관, 익명 보호, 받은·보낸 편지함, 이전 편지 보기 |
| SharedSeaApiTest | 12 | 공유 바다 띄우기·낚기·답장, 작성자 비노출, 자기 편지 제외, 동시 답장 중 한 번만 성공, 수용량·대기열 적용 |
| SeaVisitApiTest | 10 | 공개·비공개 바다 접근, 개수만 반환, 개별 편지 정보 비노출 |
| AuthServiceRefreshTest | 5 | 토큰 갱신(교체), 폐기·만료·모르는 토큰 거부, 로그아웃 |
| SignupRequestValidationTest | 3 | 아이디·비밀번호 형식 검증 |
| MessageBottleBackendApplicationTests | 1 | 애플리케이션 구동 |

### 직접 SQL로 확인한 제약(개발 DB, 연습용 행)

| 검사 | 기대 결과 | 실제 결과 | 상태 |
|---|---|---|---|
| 필수값 누락 | content 열 없이 등록하면 오류 | `ERROR 1364: Field 'content' doesn't have a default value` | 확인 |
| 필수값 NULL | content에 NULL을 넣으면 오류 | `ERROR 1048: Column 'content' cannot be null` | 확인 |
| 허용 값 위반 | status에 없는 값 'LOST'를 넣으면 오류 | `ERROR 1265: Data truncated for column 'status' at row 1` | 확인 |
| 아이디 중복 | 같은 username 등록 시 UNIQUE 오류 | `ERROR 1062: Duplicate entry 'dbcheck01' for key 'users.UK…'` | 확인 |
| 아이디 대소문자 | 대소문자만 다른 `DBCHECK01`은 등록됨 | 등록 성공. `dbcheck01`과 `DBCHECK01`이 따로 조회됨 | 확인 |
| 아이디 길이 | 20자를 넘으면 오류 | `ERROR 1406: Data too long for column 'username' at row 1` | 확인 |
| 외래키(없는 발신자) | 없는 사용자 id로 편지 등록 시 오류 | `ERROR 1452: Cannot add or update a child row: a foreign key constraint fails (… FOREIGN KEY (sender_id) REFERENCES users (id))` | 확인 |
| 외래키(편지가 있는 사용자 삭제) | 편지가 남아 있는 사용자는 삭제 불가 | `ERROR 1451: Cannot delete or update a parent row: a foreign key constraint fails` | 확인 |
| 중복 보관 | 같은 letter_id로 letter_archives 두 번 등록 시 UNIQUE 오류 | 첫 번째는 성공, 두 번째는 `ERROR 1062: Duplicate entry '17' for key 'letter_archives.UK…'` | 확인 |
| 공백만 있는 내용 | DB는 막지 않음(API가 막는 항목) | content가 공백 3자인 편지가 등록됨(확인 후 삭제). `NOT NULL`만으로는 걸러지지 않는다 | 확인 |

오류가 난 등록은 행을 남기지 않았다. 다만 실패한 등록도 `AUTO_INCREMENT` 번호를 쓰므로 users의 id 20처럼 건너뛴 번호가 생겼다.

### API로 확인한 가입·로그인(개발 DB, 8090 포트의 확인용 서버)

| 검사 | 기대 결과 | 실제 결과 | 상태 |
|---|---|---|---|
| 가입 | 규칙에 맞는 아이디·비밀번호면 생성 | `POST /api/auth/signup` → 201 | 확인 |
| 같은 아이디로 다시 가입 | 거부 | 409, "이미 사용 중인 아이디입니다." | 확인 |
| 대소문자만 다른 아이디 가입 | 다른 사용자로 생성 | `DBCHECK03` → 201 | 확인 |
| 로그인 | 가입한 아이디로 토큰 발급 | 200, 토큰 발급 | 확인 |
| 대소문자가 다른 아이디로 로그인 | 거부 | `Dbcheck03` → 401, "아이디 또는 비밀번호가 올바르지 않습니다." | 확인 |
| 미로그인 접근 | 거부 | `GET /api/sea/me` → 401 | 확인 |

같은 아이디로 다시 가입할 때의 거부는 자동 테스트에는 없고, 이번에 API로 직접 확인했다.

외래키 확인은 API 권한 검사가 아니다. 타인의 편지 열람·보관·버리기 거부와 JWT 검증은 자동 테스트(`onlyTheReceiverCanDiscardOrArchive`, `everythingRequiresLogin` 등)에서 확인한다.

## 7. 재시작 후 확인

8080 포트에는 사용자가 띄워 둔 서버가 이미 돌고 있어서 건드리지 않았다. 같은 개발 DB를 쓰는 확인용 서버를 8090 포트에 따로 띄워(`./gradlew bootRun --args='--server.port=8090'`) 두 번 시작했다.

| 순서 | 기대·확인할 내용 | 실제 기록 | 상태 |
|---|---|---|---|
| 종료 전 | 유지할 편지의 ID·상태·발송 시각 기록 | 편지 17("연습용 편지", FLOATING, 2026-11-11 10:26:25.917692), 편지 18("같은 내용의 편지", FLOATING). `CHECKSUM TABLE` 값: users 3430162884, letters 4059273154, letter_archives 1348030242, shared_letters 3840435653 | 확인 |
| 첫 실행 | 서버 시작 | 8.9초에 시작. `GET /api/sea/me` → 401 응답 확인 | 확인 |
| 종료 | 서버 정상 종료 | 프로세스를 강제 종료(`taskkill /F`)했다. 정상 종료 절차는 아님 | 부분 확인 |
| 재실행 | 같은 폴더와 환경변수로 실행 | 같은 명령으로 다시 실행. 9.2초에 시작 | 확인 |
| 재조회 | 기록한 편지가 같은 값으로 존재 | 편지 17·18의 발신자·수신자·상태·내용·발송 시각이 종료 전과 같음 | 확인 |
| 초기 자료 | `ddl-auto=update`가 기존 행을 지우거나 중복으로 넣지 않음 | 네 테이블의 체크섬이 종료 전·종료 후·재실행 후 모두 같고 행 수도 같음(users 20, letters 18, letter_archives 6, shared_letters 1 — 연습용 행 포함) | 확인 |
| 열람 후 이탈 | 앱을 다시 시작해 바다를 불러오면, 열어 두기만 한 편지가 DISCARDED가 됨 | 자동 테스트에서 확인. 실제 기기에서는 미확인 | 부분 확인 |

refresh_tokens는 로그인할 때마다 행이 늘어나는 테이블이라 체크섬 비교에서 뺐다.

## 8. 정리와 다음 단계 전달

연습용 행은 확인이 끝난 뒤 모두 지웠다.

| 대상 | 지운 행 수 |
|---|---|
| 연습용 사용자(`dbcheck01`, `dbcheck02`, `DBCHECK01`, `dbcheck03`, `DBCHECK03`) | 5 |
| 연습용 편지(id 17, 18) | 2 |
| 연습용 보관 기록 | 1 |
| 연습용 사용자의 리프레시 토큰 | 1 |

정리 후 행 수는 users 17, letters 16, letter_archives 5, shared_letters 1, refresh_tokens 41로 시작 전과 같고, 상태별 편지 수(FLOATING 7, DISCARDED 4, ARCHIVED 5)도 같다. 다음 발급 ID만 앞으로 밀렸다.

전달 파일은 `data/data-model.md`와 이 파일이다. 생성·샘플 SQL 파일은 없다(테이블은 Hibernate가 생성). 남은 확인은 서버의 정상 종료 절차를 거친 재시작과, 실제 기기에서의 열람 후 이탈이다.
