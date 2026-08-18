# DeskBat — 졸라맨 야구 오버레이 게임 설계 (2026-08-18)

macOS 화면 좌측 하단에 항상 최상위로 떠 있는 졸라맨 야구 미니게임.
"일하는 척하면서 게임" 컨셉 — 모든 조작은 글로벌 단축키로만 한다.

## 확정 요구사항

- 네이티브 macOS 앱 (Swift, AppKit + SpriteKit). 외부 의존성 없음.
- 글로벌 단축키 조작 (다른 앱에 포커스가 있어도 동작, 접근성 권한 불필요).
- 랜덤 투구 + 구종(직구 빠름/느림, 커브, 체인지업).
- 타이밍 판정: 헛스윙 / 파울 / 안타 / 홈런.
- 1게임 = 10구 자동 연속 투구, 비거리(m) 합산이 점수.
- 최고점수 히스토리 저장·표시.
- 보스키로 창 즉시 숨김/복귀.
- 1인 플레이 우선. 2인 확장은 로직을 Core에 순수 함수로 분리하는 수준까지만 대비 (추가 추상화 금지).

## 프로젝트 구조 (Swift Package)

```
desk-bat/
├── Package.swift
├── Sources/
│   ├── DeskBatCore/        # 순수 로직 라이브러리 — UI 의존성 없음, 유닛 테스트 대상
│   │   ├── PitchEngine.swift      # 구종·구속·궤적 계산 (시간→공 위치 순수 함수)
│   │   ├── SwingJudge.swift       # 타이밍 오프셋 → 판정 + 비거리
│   │   ├── GameSession.swift      # 10구 진행 상태머신, 점수 합산
│   │   ├── ScoreStore.swift       # history.json 저장/로드
│   │   └── GameConfig.swift       # config.json (키 매핑) 로드
│   └── DeskBat/            # 실행 타깃 (AppKit + SpriteKit)
│       ├── main.swift             # NSApplication 부트스트랩
│       ├── OverlayWindow.swift    # 투명 무테두리 창
│       ├── HotkeyManager.swift    # Carbon RegisterEventHotKey
│       ├── GameScene.swift        # SpriteKit 씬 (투수·타자·공·HUD)
│       ├── StickmanNode.swift     # 졸라맨 그리기 + 투구/스윙 애니메이션
│       └── EffectsNode.swift      # 타격 이펙트, 파티클, 판정 텍스트
├── Tests/DeskBatCoreTests/
├── Scripts/make-app.sh     # swift build → DeskBat.app 번들 생성
└── docs/superpowers/specs/
```

## 컴포넌트 설계

### 앱 셸 (OverlayWindow)

- 투명 배경, 무테두리 `NSWindow`, `level = .floating` (항상 최상위),
  `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` (모든 Spaces·풀스크린 위 표시).
- 크기 약 380×260pt, 화면 좌측 하단 고정.
- Dock 아이콘 없음 (`LSUIElement = true`).
- 창에 마우스 호버 시 작은 컨트롤 표시: 기록 보기, 종료. (메뉴바 아이콘 없이 종료 경로 확보)
- 보스키: 창 `orderOut`/`orderFront` 즉시 토글. 게임 진행 중이면 일시정지.

### 글로벌 단축키 (HotkeyManager)

- Carbon `RegisterEventHotKey` — 접근성 권한 불필요.
- 기본 키: **⌃⌥S 스윙, ⌃⌥G 게임 시작, ⌃⌥H 보스키** (modifier 마스크 6144 = Control+Option).
  F키 기본값은 폐기 — 외장 키보드 다수가 Fn을 펌웨어 처리해 F6~F8이 macOS에 전달되지 않음.
- `~/Library/Application Support/DeskBat/config.json`에서 키코드·modifier 변경 가능.
  파일 없으면 기본값으로 생성. 손상되었거나 modifier 필드가 없는 구버전 파일이면 기본값으로 재작성.

### 게임 규칙 (DeskBatCore)

- **투구**: 게임 시작 후 랜덤 간격(1.5~3.5초)으로 10구. 구종 랜덤 선택:
  - 직구(빠름 ~0.45초 도달 / 느림 ~0.8초 도달)
  - 커브 (세로로 휘어지는 궤적)
  - 체인지업 (중반 이후 감속)
- **궤적**: `PitchEngine.position(pitch:, t:)` 순수 함수 — 렌더링과 판정이 같은 함수를 사용.
- **판정**: 공이 타점을 지나는 시각 대비 스윙 입력 시간차 |Δ|:
  - ≤ 40ms → 홈런 (90~120m)
  - ≤ 90ms → 안타 (30~80m)
  - ≤ 140ms → 파울 (0m, 파울 이펙트)
  - 그 외 / 스윙 안 함 → 헛스윙 (0m)
  - 비거리 = 정확도 비례 + 소폭 랜덤. 랜덤은 주입 가능한 RNG(시드 고정 테스트용).
- **점수**: 10구 비거리 합산. 종료 화면에서 총점·판정 요약 표시, 최고기록 갱신 시 축하 이펙트.

### 기록 저장 (ScoreStore)

- `~/Library/Application Support/DeskBat/history.json`
- 게임별: 날짜(ISO8601), 총점, 타석별 결과 배열.
- 손상/빈 파일 → 빈 히스토리로 폴백 (크래시 금지).
- HUD 상시 표시: 현재 구 번호(n/10), 누적 미터, 역대 최고점.

### 렌더링 (SpriteKit)

- `SKView(allowsTransparency)` + 투명 씬.
- 졸라맨 2체: 투수(와인드업→릴리즈 애니메이션), 타자(대기→스윙 애니메이션).
- 판정별 이펙트: 홈런(파티클 + "HOMERUN!" + 공이 화면 밖으로), 안타(공 날아감 + 미터 표시),
  파울(공 뒤로 튐), 헛스윙("휙" 모션).

## 테스트 (XCTest, DeskBatCore만)

- SwingJudge: 판정 경계값 (정확히 40/90/140ms, 0ms, 음수 Δ), 비거리 범위.
- PitchEngine: 각 구종 궤적의 시작/타점 통과 시각, t 경계(0, 도달시각).
- GameSession: 10구 진행, 조기 입력/중복 입력 무시, 합산.
- ScoreStore/GameConfig: 정상 저장/로드, 빈 파일, 손상 JSON, 파일 없음.
- 렌더링·핫키·창 동작은 수동 QA.

## 빌드·실행

- `swift build` / `swift test` (CLI).
- `Scripts/make-app.sh` → `DeskBat.app` 생성 (Info.plist에 LSUIElement 포함), 더블클릭 실행.

## 비범위 (이번에 안 함)

- 2인 플레이, 키 리매핑 UI(파일 편집으로 충분), 사운드, 메뉴바 아이콘,
  코드사인/공증/배포, 구종 추가 설정.
