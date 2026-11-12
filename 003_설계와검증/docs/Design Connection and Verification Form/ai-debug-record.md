# AI와 조사한 문제

통합 확인(2026-11-11) 중에 나온 두 가지를 적는다. 하나는 앱의 문제였고, 하나는 앱이 아니라 조작 도구의 문제였다.

## 발생 상황
실행 명령: `flutter build apk --debug` → `adb install -r build/app/outputs/flutter-apk/app-debug.apk` → `adb shell am start -n com.example.message_bottle_frontend/.MainActivity`. 화면 조작은 `adb shell input tap/text`, 화면 확인은 `adb exec-out screencap`.
기기·주소·버전: Android 에뮬레이터 Pixel 9 (Android 17, API 37), 앱 → `http://10.0.2.2:8080`, Flutter 3.47.9, 앱 1.0.0+1, 서버 Spring Boot 4.1.2

**문제 1 (앱): 받는 사람 검색 결과가 없을 때 안내가 없다**
기대 동작: 편지 쓰기에서 없는 아이디를 검색하면 "일치하는 사용자가 없습니다."가 보인다(`docs/ui-spec.md` S02, 시안 `docs/mockup/index.html`).
실제 동작: `zzzznone`을 입력하고 기다려도 검색 칸 아래에 아무것도 나오지 않았다. 검색이 안 된 것인지 결과가 없는 것인지 알 수 없었다.
오류 메시지와 관련 파일: 오류 메시지 없음. `message_bottle_frontend/lib/screens/write_letter_sheet.dart`, 화면 `evidence/11a-search-empty-before-fix.png`

**문제 2 (도구): 내 바다의 [받은 편지함]·[보낸 편지함]·[편지 쓰기]가 눌리지 않는 것처럼 보였다**
기대 동작: 버튼을 누르면 편지함 창이 열린다.
실제 동작: `adb shell input tap`으로 눌러도 화면이 바뀌지 않았다. 같은 방법으로 유리병, [보관], 메뉴 버튼은 눌렸다.
오류 메시지와 관련 파일: 오류 메시지 없음. `adb logcat`에 Flutter 오류도 없었다. `message_bottle_frontend/lib/screens/sea_screen.dart`

## AI에게 요청한 내용

- 양식을 채우기 위해 실제 에뮬레이터·서버·DB로 통합 확인을 하도록 했다. 문제 1, 2는 그 과정에서 AI(Claude Code)가 화면을 찍어 보다가 발견했다.
- 문제 1: 문서의 기준과 화면이 다른 이유를 코드에서 찾고, 문서에 적힌 문구대로만 고치게 했다(새 기능 추가 없음).
- 문제 2: 앱의 문제인지 조작 방법의 문제인지 먼저 가리게 했다.

## 원인 후보와 확인 근거

**문제 1**
| 원인 후보 | 확인 근거 | 결론 |
|---|---|---|
| 검색 요청이 가지 않았다 | 같은 화면에서 `ichk0`은 결과 두 줄이 나왔다(`evidence/13-search-results.png`) | 아님 |
| 결과가 비었을 때 보여 줄 내용이 코드에 없다 | `_SearchResults`가 대기·검색 중·실패·결과 있음만 그리고, 결과가 빈 경우에는 빈 위젯을 돌려줬다. 문구 "일치하는"을 `lib`와 `test`에서 찾아도 없었다 | 원인 |
| 테스트가 있었는데 왜 통과했나 | `test/write_sheet_test.dart`의 "결과 없음과 검색 실패를 구분해서 안내한다"가 결과 줄이 없는지만 확인하고 안내 문구는 확인하지 않았다 | 테스트 누락 |

**문제 2**
| 원인 후보 | 확인 근거 | 결론 |
|---|---|---|
| 좌표가 틀렸다 | 화면 사진에서 버튼 위치를 다시 재도 맞았고, 좌표를 조금씩 바꿔도 같았다 | 아님 |
| 위쪽 "내 바다 / 공유 바다" 표시가 버튼을 가린다 | `sea_backdrop.dart`에서 표시는 버튼 윗줄에만 있고, `test/top_layout_test.dart`가 겹치지 않음을 확인한다 | 아님 |
| 앱이 터치를 못 받는 상태다 | 왼쪽 위 메뉴는 열렸고, 오른쪽 아래 [편지 쓰기]는 안 열렸다. 차이는 누르기 직전에 기다린 시간이었다 | 실마리 |
| 5초 동안 조작이 없으면 버튼을 숨기는 기능 | `sea_screen.dart`의 `_hideable`이 대기 상태에서 `IgnorePointer`로 터치를 막고, 화면 어디든 누르면 `_wake()`로 다시 보인다. 그래서 숨은 상태의 첫 터치는 "다시 보이기"에만 쓰이고, 그 직후 찍은 화면에는 버튼이 보여서 눌린 줄 알았다 | 원인. 앱은 설계대로 동작했고 조작 스크립트가 대기 시간을 고려하지 않았다 |

덧붙여, 편지 쓰기 화면 사진에 보이는 둥근 ☰ 단추는 앱의 것이 아니라 에뮬레이터 키보드(Gboard)의 떠 있는 도구 모음이다. "Hold and drag to move toolbar" 안내가 함께 찍혀 확인했다(`evidence/15-write-filled.png`).

## 수정한 파일과 이유

| 파일 | 바꾼 내용 | 이유 |
|---|---|---|
| `message_bottle_frontend/lib/screens/write_letter_sheet.dart` | 검색이 끝났는데 결과가 없으면 `_noMatch`를 켜고 "일치하는 사용자가 없습니다."를 보여 준다. 검색어가 바뀌면 끈다 | 문서(S02)에 적힌 안내가 빠져 있었다 |
| `message_bottle_frontend/test/write_sheet_test.dart` | 결과가 없을 때 안내 문구가 보이는지, 검색 실패 때는 보이지 않는지 확인을 추가 | 같은 누락이 다시 생기면 테스트가 잡도록 |
| (문제 2) 앱 코드는 고치지 않음 | 확인용 스크립트에서 빈 곳을 한 번 눌러 버튼을 보이게 한 뒤 1초 안에 버튼을 누르도록 바꿨다 | 앱의 문제가 아니었다 |

## 변경 후 재검사
같은 실행 조건: 같은 에뮬레이터·서버·계정. APK를 다시 빌드해 덮어 설치한 뒤 같은 순서로 실행했다.
실제 결과:
- 문제 1: `zzzznone` 검색 후 "일치하는 사용자가 없습니다."가 검색 칸 아래에 나왔다. `ichk0` 검색은 전처럼 결과 두 줄이 나왔다. `flutter test` 132개 통과, `flutter analyze` 문제 없음.
- 문제 2: 한 번 깨운 뒤 누르니 받은 편지함·보낸 편지함·편지 쓰기가 모두 열렸다.
근거 파일: `evidence/11a-search-empty-before-fix.png`(전), `evidence/11b-search-empty-after-fix.png`(후), `evidence/13-search-results.png`, `evidence/08-inbox.png`, `evidence/17-sent-box.png`, `evidence/09-write-sheet.png`
남은 문제:
- 숨은 버튼 자리를 처음 누르면 아무 일도 일어나지 않는 것은 설계된 동작이지만, 처음 쓰는 사람에게는 안 눌린 것처럼 느껴질 수 있다. 바꿀지는 정하지 않았다.
- 재검사는 에뮬레이터 한 대에서만 했다.

앱의 문제와 테스트 도구의 대기·선택 문제를 구분한다. AI가 설명한 원인은 실행 근거와 대조한다.
