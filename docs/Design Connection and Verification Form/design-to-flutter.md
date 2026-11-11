# 디자인과 Flutter 연결

앱 이름: Message Bottle (유리병 편지)
확인한 설계 문서와 경로: `docs/design-system.md`(색·글자·간격·컴포넌트), `docs/ui-spec.md`(화면별 상태), `docs/ui-flow.md`, 시안 `docs/mockup/index.html`·`docs/mockup/fishing.html`
검토 일자: 2026-11-11

"실제 결과"는 코드(`message_bottle_frontend/lib`)와 에뮬레이터(Pixel 9, Android 17) 화면에서 확인한 내용이다. 화면 파일은 `evidence/` 폴더에 있다. 명암비는 색상값으로 계산했다(WCAG 식).

| 설계 항목 | 문서의 기준 | 적용할 Flutter 파일·요소 | 실제 결과 | 남은 문제 |
|---|---|---|---|---|
| 색상·글자 | 주요 #0B5FA5, 배경 #F7FBFE, 본문 #12263A, 편지지 #FFF8E7, 강조 #1E8E7E, 오류 #B3261E, 바다 #CBE9F7→#2F7FB8. 제목 22 굵게, 본문 16(편지 줄 간격 1.5), 보조 13. 색만으로 뜻을 구분하지 않는다 | `lib/theme.dart`의 `AppColors`, `buildTheme()`. 편지 본문은 `lib/screens/letter_detail_screen.dart` | 색 7가지가 문서 값 그대로 들어 있다. 명암비: 본문/배경 14.8, 본문/편지지 14.5, 흰 글자/주요 6.6, 흰 글자/오류 6.5, 보조 글자/편지지 5.2. [보관]은 책갈피 아이콘+글자, 버리기는 휴지통 아이콘+글자로 구분된다(`04-letter-open.png`, `18-discard-confirm.png`) | 2026-11-11에 고침: 강조 색을 #1B8475로 바꿔 흰 글자 명암비가 4.6이 됐고, 편지 본문을 16·줄 간격 1.5로 맞췄다(수정 후 기기 화면은 다시 찍지 않음). 바다 아래쪽(#2F7FB8) 위의 어두운 글자는 3.6이다. 문서를 고칠지 코드를 고칠지 정하지 않았다 |
| 간격·모서리 | 간격 8의 배수, 버튼·입력 칸 모서리 12, 시트·팝업 위쪽 24, 터치 영역 48×48 이상 | `theme.dart`의 `kRadius = 12`, 버튼 `minimumSize: Size(48, 48)`. 시트 `sea_screen.dart`(위쪽 24), 편지함 창 `mailbox_dialog.dart`(24), `SeaChip`(최소 높이 48) | 버튼·입력 칸 12, 편지 쓰기 시트 위쪽 24, 편지함 창 24로 문서와 같다. 바다의 버튼은 높이 48 이상이다(`09-write-sheet.png`, `08-inbox.png`) | 확인 창(`dialogTheme`)은 20이었고 2026-11-11에 24로 맞췄다. 입력 칸 안쪽 여백 14, 버튼 사이 10 등 8의 배수가 아닌 값이 있다 |
| 목록·검색 | 편지함 카드: 상대 아이디(익명이면 "익명") → 날짜 → 내용 앞부분. 답장한 편지만 오른쪽에 체크. 받는 사람은 아이디로 검색해 목록에서 고른다(입력이 1초 멈추면 검색) | `lib/screens/mailbox_dialog.dart`, `lib/screens/write_letter_sheet.dart`의 `_SearchResults` | 카드에 "ichk02 · 11월 11일 · 내용", 익명은 "익명"으로 나왔다. 검색은 `ichk01 (나)`, `ichk02`가 목록으로 나왔다(`25-inbox-two.png`, `13-search-results.png`) | 답장한 카드의 체크 아이콘과 긴 목록 스크롤은 기기에서 보지 않았다(자동 테스트만). 편지 자체의 검색·필터는 없다 |
| 등록·수정 폼 | 편지 쓰기 시트: 받는 사람·내용·익명 스위치·[취소]/[보내기]. 오류는 항목 바로 아래 오류 색. 보내는 중에는 중복 제출을 막는다. 수정 모드는 없다 | `lib/screens/write_letter_sheet.dart`, `lib/widgets/common.dart`의 `ErrorText` | 시트가 문서대로 구성돼 있다. 빈 채로 보내면 두 항목 아래에 경고 아이콘과 붉은 안내가 나왔다. [보내기]를 연달아 두 번 눌러도 한 통만 갔다(`09-write-sheet.png`, `10-write-required.png`, `16-sent-toast.png`) | 답장 쓰기와 공유 바다 "편지 띄우기" 폼은 기기에서 보지 않았다. 입력 후 [취소]의 폐기 확인도 자동 테스트만 |
| 로딩·빈 결과·실패 | 빈 바다 "아직 도착한 유리병이 없어요", 빈 편지함 안내, 로딩 스피너, 실패 "불러오지 못했습니다"와 [다시 시도], 검색 결과 없음 "일치하는 사용자가 없습니다." | `lib/screens/sea_screen.dart`의 `_content()`, `lib/widgets/common.dart`, `lib/widgets/toast.dart`, `write_letter_sheet.dart` | 빈 바다 안내가 문구대로 나왔다. 연결을 끄고 보관하니 "보관하지 못했습니다. 편지는 그대로 있어요. 다시 시도해주세요."가 나왔다. 검색 결과 없음 안내는 빠져 있어서 이번에 넣었다(`24-empty-sea.png`, `06-archive-offline.png`, `11b-search-empty-after-fix.png`) | 바다·편지함 읽기 실패 화면과 [다시 시도]는 기기에서 보지 않았다. 보관 실패 안내는 약 2초 뒤 사라지고 [다시 시도] 버튼이 따로 없다(같은 버튼을 다시 누른다) |
| 본인 글의 동작 | 받은 편지: X(영구 삭제, 확인 필요)·[답장]·[보관], 익명은 [보관]만. 받은 편지함 카드는 밀어서 삭제. 보낸 편지는 읽기만 하고 삭제가 없다. 바다에서 연 편지는 바깥 터치·뒤로 가기로 닫히지 않는다 | `lib/screens/letter_detail_screen.dart`, `lib/screens/mailbox_dialog.dart`(`Dismissible`, 오른쪽에서 왼쪽), `lib/widgets/common.dart`의 확인 창(`barrierDismissible: false`) | X를 누르면 "이 편지를 버릴까요?" 확인이 나오고 [취소]/[버리기]가 색과 아이콘으로 구분된다. 익명 편지는 [보관]만 있다. 카드를 밀면 확인 없이 지워진다. 보낸 편지함에는 "보낸 편지는 삭제할 수 없어요."가 적혀 있고 삭제 단추가 없다. 뒤로 가기를 눌러도 편지가 그대로였다(`18-discard-confirm.png`, `23-anonymous-letter.png`, `26-inbox-after-swipe.png`, `17-sent-box.png`, `05-letter-back-key.png`) | 카드를 미는 동안 뒤에 보이는 붉은 바탕·휴지통·"삭제"는 화면으로 찍지 못했다 |

## 적용한 범위

- 색·모서리·버튼 크기는 `lib/theme.dart` 한 곳에서 정하고 화면들이 가져다 쓴다.
- 화면: 로그인·가입, 내 바다(유리병, 편지함 버튼, 편지 쓰기), 편지 상세, 답장 쓰기, 보낸/받은 편지함 창, 다른 사람의 바다, 바다 공개 설정, 공유 바다(띄우기·낚기·낚은 편지).
- 바다 표현: 그라데이션 바탕과 빛, 파도(`lib/widgets/sea_waves.dart`), 떠 있는 유리병(`lib/widgets/bottle_field.dart`), 버릴 때 물결, 공유 바다의 낚시 움직임(`lib/widgets/fishing_rig.dart`).
- 이번 검토에서 고친 것: 받는 사람 검색 결과가 없을 때의 안내(`write_letter_sheet.dart`).

## 이번에 구현하지 않은 범위

- 문서와 달랐던 값(편지 본문 17·줄 간격, 확인 창 모서리 20, [보관] 버튼 글자 명암비)은 검토 뒤 코드를 문서에 맞춰 고쳤다. 바다 아래쪽 위의 글자 명암비와 8의 배수가 아닌 여백은 그대로다.
- 어두운 화면(다크 모드), 큰 글자 설정에서의 화면은 확인하지 않았다.
- 공개 바다 방문자의 편지 열람(`docs/requirements.md` Q17), 프로필 화면, 전체 스레드 화면은 정해지지 않았거나 다른 방식으로 바꿔서 만들지 않았다.
- 시안의 CSS 픽셀 값을 자동으로 옮긴 것은 아니다. 값은 사람이 문서를 보고 Flutter 논리 픽셀로 옮겼다.

## 실행 화면

에뮬레이터(Pixel 9, 1080×2424)에서 2026-11-11에 찍었다.

| 화면 | 파일 |
|---|---|
| 로그인 | `evidence/01-login.png` |
| 내 바다 (유리병 4개) | `evidence/03-sea-list.png` |
| 편지 상세 (답장·보관, 우상단 X) | `evidence/04-letter-open.png` |
| 익명 편지 (보관만) | `evidence/23-anonymous-letter.png` |
| 버리기 확인 | `evidence/18-discard-confirm.png` |
| 편지 쓰기 시트와 입력 오류 | `evidence/09-write-sheet.png`, `evidence/10-write-required.png` |
| 받는 사람 검색 결과 / 결과 없음 | `evidence/13-search-results.png`, `evidence/11b-search-empty-after-fix.png` |
| 받은 편지함 / 보낸 편지함 | `evidence/25-inbox-two.png`, `evidence/17-sent-box.png` |
| 빈 바다 | `evidence/24-empty-sea.png` |
| 실패 안내 | `evidence/06-archive-offline.png` |

편지 쓰기 화면 사진 왼쪽의 둥근 ☰ 단추는 에뮬레이터 키보드(Gboard)의 도구 모음이며 앱 화면이 아니다. 공유 바다, 답장 쓰기, 다른 사람의 바다, 바다 공개 설정은 이번에 찍지 않았다.
