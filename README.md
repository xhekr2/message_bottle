# Message Bottle (유리병 편지)

## 무엇을 하는 앱인가
사용자와 주요 기능: 로그인한 사용자가 다른 사람의 "바다"로 유리병 편지를 보내고, 내 바다에 도착한 편지를 열어 답장·보관·버리기 중 하나를 고른다. 실시간 채팅이 아니라 편지 한 통 단위로 주고받는다.
실제로 구현한 범위:
- 아이디·비밀번호 가입, 로그인, 로그아웃, 토큰 자동 갱신
- 편지 쓰기(받는 사람 검색, 익명 선택), 내 바다(최대 10개, 초과분 대기, 7일 만료)
- 편지 열람 후 답장·보관·버리기, 열어 보고 처리하지 않은 채 앱을 종료하면 버려짐
- 보낸 편지함(삭제 없음), 받은 편지함(밀어서 삭제)
- 바다 공개 설정과 다른 사람의 공개 바다 방문(유리병 개수만)
- 공유 바다(편지 띄우기, 유리병 낚기, 익명 작성자에게 답장)
- 화면 설정(아침·밤바다, 글자 크기, UI 숨김 대기 시간, 파도 종류)을 사용자별로 서버에 저장
- 네트워크가 끊기면 안내 후 종료(편지를 열어 둔 동안에는 다시 시도)

## 필요한 도구
JDK 버전과 경로: 확인한 환경은 OpenJDK 27.0.1이다. 빌드 설정의 대상은 Java 17이다(`message_bottle_backend/build.gradle`). 경로는 PC마다 다르므로 `java -version`으로 확인한다.
Flutter·Dart 버전: Flutter 3.47.9 (stable). Dart SDK는 `pubspec.yaml`에서 3.13.7 이상을 요구한다.
Android 기기 또는 에뮬레이터: Android 에뮬레이터 Pixel 9 (Android 17, API 37)에서 확인했다.
다른 실행 대상: MySQL 8.0 (확인한 버전 8.0.46). 실제 휴대폰, iOS, 웹은 확인하지 않았다.

## 서버 준비와 실행
프로젝트 폴더: `message_bottle_backend`
설정 파일과 설정할 값: `src/main/resources/application.properties`. 값은 파일에 적지 않고 환경 변수로 준다.
- `DB_URL`: MySQL 접속 주소 (데이터베이스 이름은 `message_bottle`)
- `DB_USERNAME`, `DB_PASSWORD`: MySQL 계정
- `JWT_SECRET`: 토큰 서명에 쓰는 값(32바이트 이상)
스키마·샘플 데이터 준비 방법: MySQL에 빈 데이터베이스 `message_bottle`을 만들어 둔다. 테이블은 서버가 처음 실행될 때 만든다(`spring.jpa.hibernate.ddl-auto=update`). 따로 적용할 SQL 파일과 샘플 데이터는 없다.
실행 명령:
```bash
./gradlew bootRun
```
포트와 정상 응답 확인 방법: 8080 포트, 모든 네트워크에서 접속을 받는다(`server.address=0.0.0.0`). 토큰 없이 `GET http://localhost:8080/api/sea/me`를 호출해 401이 오면 서버가 떠 있는 것이다.
```bash
curl -i http://localhost:8080/api/sea/me
```
자동 테스트는 `./gradlew test`로 실행하며, 테스트용 데이터베이스 `message_bottle_test`가 필요하다(`src/test/resources/application-test.properties`).

## 앱 실행
프로젝트 폴더: `message_bottle_frontend`
기기 선택 방법: `flutter devices`로 목록을 보고 `-d <기기 id>`로 고른다.
기기에서 접근할 API 주소: 기본값은 Android에서 `http://10.0.2.2:8080`(에뮬레이터에서 본 서버 PC), iOS에서 `http://localhost:8080`(시뮬레이터에서 본 Mac)이다. 실제 휴대폰이나 다른 기기에서는 서버 PC의 LAN IP를 `API_BASE_URL`로 준다(`lib/config.dart`).
실행 명령:
```bash
flutter run --dart-define=API_BASE_URL=http://<서버 PC의 IP>:8080
```
에뮬레이터에서 기본 주소를 쓸 때는 `flutter run`만으로 된다. 설치 파일을 만들 때는 `flutter build apk --debug`를 쓴다.
iOS는 Xcode가 설치된 Mac에서만 빌드할 수 있다. 시뮬레이터는 `flutter run -d <시뮬레이터 id>`, 실제 iPhone은 Xcode에서 `ios/Runner.xcworkspace`를 열어 서명 팀(Signing & Capabilities)을 고른 뒤 실행한다. iOS 빌드와 실행은 이 프로젝트에서 실제로 해 보지 못했다(Windows에서 작업).
예제 계정 준비 방법: 미리 넣어 둔 계정은 없다. 앱의 회원가입 화면에서 아이디(영문·숫자 4~20자)와 비밀번호(8~20자)로 직접 만든다. 편지를 주고받으려면 계정이 두 개 필요하다.

실제 비밀번호·토큰·서명 키는 이 문서에 넣지 않는다. 별도로 제공해야 하는 값은 전달 방법만 적는다. DB 계정과 `JWT_SECRET`은 실행하는 사람이 자기 PC의 환경 변수로 정한다.

## 핵심 기능 확인
실행할 순서와 입력:
1. 계정 A, B를 가입한다.
2. A로 로그인해 [편지 쓰기]에서 B를 검색해 고르고 내용을 써서 [보내기]를 누른다.
3. A의 [보낸 편지함]을 연다.
4. 로그아웃하고 B로 로그인해 내 바다의 유리병을 누른다.
5. [보관]을 누르고 [받은 편지함]을 연다.
기대 결과:
- 2: "보냈습니다. 보낸 편지함에서 확인할 수 있어요." 안내가 나온다.
- 3: 방금 보낸 편지가 한 줄 보인다.
- 4: B의 바다에 유리병이 하나 떠 있고, 누르면 "A 님의 편지"가 열린다.
- 5: 유리병이 바다에서 사라지고 받은 편지함에 그 편지가 보인다.

## 검증 범위와 알려진 제한
실제로 확인한 기기·환경: Android 에뮬레이터 Pixel 9, 서버 PC의 Spring Boot와 MySQL (2026-11-11). 서버 자동 테스트 68개, 앱 자동 테스트 151개 통과.
미완료 또는 미확인 기능:
- 실제 휴대폰과 같은 LAN의 기기 2대 동시 사용은 확인하지 않았다.
- 답장, 10개 초과 대기, 공유 바다, 바다 공개·방문은 자동 테스트로만 확인했다.
- 공유 바다 편지의 만료, 내가 띄운 편지를 다시 보는 화면은 정해지지 않아 만들지 않았다.
- 앱 종료(네트워크 끊김)는 Android에서만 확인했다.
검증 문서 위치: `docs/acceptance.md`, `docs/Design Connection and Verification Form/`(통합 확인, AI와 조사한 문제, 근거 화면), `docs/Data design example/db-verification.md`, `docs/portfolio/006_내포트폴리오/004_수정과최종검증.md`
포트폴리오 위치: `docs/portfolio/006_내포트폴리오/포트폴리오_MessageBottle.pptx` (같은 이름의 PDF 포함)
