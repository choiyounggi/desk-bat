# DeskBat — 프로젝트 지침

## 문서 이중화 규칙 (필수)

- README는 두 버전을 항상 동기화한다: `README.md`(영어, 메인) + `README.ko.md`(한국어).
- **둘 중 하나를 수정하면 반드시 같은 커밋에서 다른 쪽도 동일 내용으로 갱신할 것.**
- 두 파일 상단의 언어 상호 링크(`English | 한국어`)를 유지할 것.
- 톤: 익살스러운 컨셉("일하는 척하며 몰래 야구") 유지. 스크린샷은 `docs/images/`.

## 빌드/검증

- `swift build && swift test` — 변경 후 항상 실행 (테스트 49개 전체 통과 상태 유지).
- `.app` 번들: `sh Scripts/make-app.sh` (산출물 `DeskBat.app`은 gitignore 대상, 커밋 금지).

## 아키텍처 경계

- `DeskBatCore`: 순수 로직(Foundation만). SpriteKit/AppKit import 금지, 랜덤은 RNG 주입 유지.
- `DeskBat`: AppKit+SpriteKit 실행 타깃. 판정/궤적 수치를 재구현하지 말고 반드시 Core API 호출.
- 판정·거리 수치 변경 시 `docs/superpowers/specs/`의 스펙과 양쪽 README 게임 규칙 섹션도 함께 갱신.
