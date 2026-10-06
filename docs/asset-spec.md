# Tumble Toy — 리소스 스펙

## 1. 목적과 원칙

이 문서는 게임에 생성·도입할 모든 시청각 리소스의 단일 기준이다. 각 리소스는 이 문서의 ID, 용도, 형식, 완료 조건을 충족해야 한다.

- 시각 스타일: 아기자기한 **2D 쿼터뷰 Pixel Art**, 장난감 블록방.
- 이 문서의 VIS 이미지 리소스는 **2D 쿼터뷰 버전**에 사용한다. 2D 탑뷰는 코드 도형, 최종 3D 버전은 Godot 메시·재질·조명으로 별도 표현한다.
- 쿼터뷰 스프라이트는 윗면·측면 명암으로 장난감 블록의 입체감을 표현하며, 사진 질감·강한 반사광·사실적인 그림자는 사용하지 않는다.
- 게임 플레이 정보(목표 숫자, 현재 주사위 숫자, 이동 예고)를 장식보다 우선한다.
- 스프라이트와 UI 비트맵은 투명 PNG, 정수 픽셀 배율, nearest-neighbor 필터를 사용한다. 전체 화면 배경은 불투명 PNG를 사용한다.
- 정확한 숫자와 텍스트는 이미지에 생성하지 않는다. Godot UI/코드가 표시한다.
- 서비스 API 키 및 토큰은 소스·에셋·문서·버전 관리에 저장하지 않는다. 로컬 환경 변수 또는 사용자가 관리하는 비밀 저장소에서만 제공한다.

## 2. 생산 단계

| 단계 | 리소스 | 상태 |
| --- | --- | --- |
| A | 게임 플레이 핵심 스프라이트 | PixelLab MCP 승인본 생성·연결 완료 |
| B | 장난감 블록방 배경·장식 | PixelLab MCP 승인본 생성·연결 완료 |
| C | UI 디자인 리소스 | PixelLab MCP UI 키트 생성·연결 완료 |
| D | 효과음 | Stable Audio 3 원본 및 게임용 가공본 생성·연결 |
| E | 배경음악 | MiniMax Music 3 원본 및 게임용 가공본 생성·연결 |
| F | 튜토리얼 안내 음성 | Chatterbox 지정 문장 생성·가공·연결 완료 |

기존 `tools/generate_placeholder_audio.sh` 산출물은 이벤트 연결 확인에만 사용한 과거 초안이다. 최종 연결 파일은 반드시 본 문서에 지정된 Stable Audio 3, MiniMax Music 3, Chatterbox 산출물이어야 한다.

## 3. PixelLab — 이미지 리소스

### 공통 규격

| 항목 | 규격 |
| --- | --- |
| 원본 캔버스 | 항목별 표의 크기. 확대/축소 금지 |
| 파일 형식 | 투명 PNG (배경 포함 장면은 불투명 PNG) |
| 색상 | 밝은 파스텔: 하늘색, 크림색, 민트, 살구색, 코랄 핑크 |
| 외곽선 | 1–2px 짙은 보랏빛 외곽선 |
| 금지 | 글자, 숫자, 워터마크, 사실적 질감, 과도한 안티앨리어싱 |

### A. 핵심 게임플레이 스프라이트

| ID | 리소스 | 크기 | 배경 | 수량 | 용도 | 완료 조건 |
| --- | --- | ---: | --- | ---: | --- | --- |
| VIS-001 | 주사위 기본 본체 | 36×36px | 투명 | 1 | 플레이어 주사위 | 중앙 정렬, 윗면에 숫자/점 없음, 모든 가장자리 식별 가능 |
| VIS-002 | 바닥 블록 타일 | 36×36px | 투명 | 1 | 일반 이동 타일 | 테두리가 선명하고, 인접 배치 시 이음새가 자연스러움 |
| VIS-003 | 목표 타일 바탕 | 36×36px | 투명 | 1 | 요구 숫자 표시 바탕 | 중앙에 숫자를 겹쳐도 대비가 유지됨 |
| VIS-004 | 빈 공간/낙하 표현 | 36×36px | 투명 | 1 | 타일 외부 강조 | 바닥 타일과 즉시 구분되며 시각적 혼동 없음 |
| VIS-005 | 이동 예고 배지 | 20×20px | 투명 | 1 | 방향 패드의 예상 윗면 숫자 배경 | 작은 숫자를 읽을 수 있는 밝은 배지 |
| VIS-006 | 시작 타일 마커 | 36×36px | 투명 | 1 | 시작 위치 표시 | 일반 바닥 위에 겹쳐도 식별 가능하며 목표 타일과 색·형태가 다름 |

### B. 배경·장식

| ID | 리소스 | 크기 | 배경 | 수량 | 용도 | 완료 조건 |
| --- | --- | ---: | --- | ---: | --- | --- |
| VIS-101 | 장난감 방 벽 배경 | 360×410px | 불투명 | 1 | 상단 배경 | 저대비, 보드와 UI를 방해하지 않음 |
| VIS-103 | 벽 장식 세트 | 각 32–64px | 투명 | 3 | 구름·별·블록 장식 | 가장자리에 배치해도 보드를 가리지 않음 |

### C. UI 디자인 리소스

| ID | 리소스 | 크기 | 배경 | 수량 | 용도 | 완료 조건 |
| --- | --- | ---: | --- | ---: | --- | --- |
| VIS-201 | 언두 아이콘 | 24×24px | 투명 | 1 | 언두 버튼 | 왼쪽 회전 화살표가 24px에서 식별 가능 |
| VIS-202 | 재시작 아이콘 | 24×24px | 투명 | 1 | 재시작 버튼 | 원형 회전 화살표가 24px에서 식별 가능 |
| VIS-203 | 완벽 클리어 별 | 24×24px | 투명 | 1 | 결과 UI | 1× 크기에서 경쾌하게 읽힘 |
| VIS-204 | 공통 패널 9-slice | 48×48px | 투명 | 1 | 상단 정보·메시지·모달·가방·규칙 패널 | 8px 모서리와 테두리를 보존해 임의 크기로 확장 가능 |
| VIS-205 | 기본 버튼 9-slice | 48×24px | 투명 | 1 | 목록·일시정지·규칙·힌트·층·가방 버튼 | 텍스트 없이 6px 테두리로 확장 가능 |
| VIS-206 | 강조 버튼 9-slice | 48×24px | 투명 | 1 | 계속·다음 스테이지·선택 상태 | 기본 버튼보다 명도와 코랄 강조가 높음 |
| VIS-207 | 눌림 버튼 9-slice | 48×24px | 투명 | 1 | 클릭·터치 눌림 상태 | VIS-205보다 안쪽으로 1px 내려간 명암 |
| VIS-208 | 보기 선택 탭 9-slice | 52×28px | 투명 | 1 | 개발 과정 보존 리소스, 실제 게임 미사용 | 선택 라벨은 코드 텍스트, 탭 윤곽만 포함 |
| VIS-209 | 방향 버튼 | 54×44px | 투명 | 1 | 상·하·좌·우 패드 공통 바탕 | 중앙이 비어 있어 코드 화살표와 예상 숫자를 겹칠 수 있음 |
| VIS-210 | 아이템 슬롯 9-slice | 40×40px | 투명 | 1 | 가방 슬롯·도감 카드 | 작은 크기에서도 모서리와 내부 여백이 선명함 |
| VIS-211 | 메인 메뉴 히어로 이미지 | 288×192px | 투명 | 1 | 메인 메뉴 로고 아래의 주사위·블록 비주얼 | 최종 3D 보드를 연상시키며 글자와 숫자 없이 주사위 퍼즐 콘셉트가 즉시 읽힘 |

공통 UI 적용 범위는 메인 메뉴, 튜토리얼, 스테이지 선택, 플레이 HUD, 일시정지, 빠른 도움, 아이템 가방, 일반/완벽 클리어 화면이다. 화면마다 별도 장식 이미지를 중복 생성하지 않고 VIS-204–210의 패널·버튼·슬롯 스킨을 9-slice로 조합한다. VIS-208 보기 탭은 개발 버전 기록으로 보존하지만 실제 MVP 화면에는 표시하지 않는다. 배경에는 VIS-101과 VIS-103 장식을 재사용하며 모든 라벨은 코드 텍스트로 표시한다.

메인 메뉴는 스테이지 선택과 분리한다. VIS-211 히어로 이미지, 로고형 코드 타이틀, 진행도, 이어하기/튜토리얼/스테이지 선택/설정 버튼을 표시한다. 이어하기는 첫 미완료 스테이지의 최종 3D 버전으로 진입하고, 플레이의 목록 버튼은 스테이지 선택으로 돌아간다. 설정 화면은 VIS-204 패널과 VIS-205~207 버튼 상태를 조합한다.

튜토리얼 메뉴는 기존 생성 리소스를 재사용해 굴리기·숫자 맞추기·되돌리기 세 카드와 `튜토리얼 시작` 버튼만 표시한다. 모델명, 제작 방식, 특수 타일 전체 규칙처럼 플레이 시작에 필요하지 않은 장문 설명은 메뉴와 도움말에서 제거한다.

### 공통 PixelLab 프롬프트 기반

```text
2D top-down pixel art game asset for a cute toy block room puzzle game.
Pastel sky blue, cream, mint, peach, and coral-pink palette; dark plum 1–2 pixel outline;
crisp hard pixels; charming handmade toy aesthetic; centered composition; no text, no numbers,
no letters, no watermark, no photorealism, no 3D render, no anti-aliasing.
```

각 생성 요청은 이 공통 프롬프트에 표의 개별 리소스 설명과 투명/불투명 배경 조건을 추가한다.

### 개별 PixelLab 프롬프트와 저장 위치

| ID | 저장 위치 | 개별 요청 내용 |
| --- | --- | --- |
| VIS-001 | `assets/visual/gameplay/die_body.png` | 36×36px transparent sprite of a cute six-sided toy die in 3D quarter view; blank cream top face with no pips; visible pastel side faces; compact dark plum outline. |
| VIS-002 | `assets/visual/gameplay/floor_tile.png` | 36×36px seamless quarter-view toy building block floor tile; warm cream top and peach side face; clear edge separation; no symbols. |
| VIS-003 | `assets/visual/gameplay/goal_tile.png` | 36×36px transparent top-down goal tile; coral-pink outer ring with pale cream empty center reserved for a code-rendered number; strong contrast and no numeral. |
| VIS-004 | `assets/visual/gameplay/void_tile.png` | 36×36px transparent top-down empty-space indicator; dark plum soft toy-room shadow with a clean square silhouette; must be visibly distinct from the floor tile. |
| VIS-005 | `assets/visual/ui/prediction_badge.png` | 20×20px transparent round mint badge with blank cream center reserved for one code-rendered number; readable at 1× size. |
| VIS-006 | `assets/visual/gameplay/start_marker.png` | 36×36px transparent top-down mint start marker: four tiny toy arrows pointing inward to a blank center; no text or numbers; clearly distinct from coral goal tile. |
| VIS-101 | `assets/visual/backgrounds/toy_room_wall.png` | 360×410px flat pixel-art toy room wall background: pastel sky-blue wallpaper, sparse pale clouds and toy shelf silhouettes only at far edges; empty high-contrast central play area. |
| VIS-103-A | `assets/visual/decor/cloud.png` | 48×32px transparent friendly pixel-art cloud wall decoration, no face, no text. |
| VIS-103-B | `assets/visual/decor/star.png` | 32×32px transparent five-point toy star wall decoration, pastel yellow, no face, no text. |
| VIS-103-C | `assets/visual/decor/blocks.png` | 64×48px transparent stack of three colorful toy blocks, top-down compatible, no letters or numbers. |
| VIS-201 | `assets/visual/ui/icon_undo.png` | 24×24px transparent pixel-art left-curving undo arrow, mint fill and dark plum outline, no text. |
| VIS-202 | `assets/visual/ui/icon_restart.png` | 24×24px transparent pixel-art clockwise restart arrow, mint fill and dark plum outline, no text. |
| VIS-203 | `assets/visual/ui/icon_perfect_star.png` | 24×24px transparent cheerful gold pixel star badge with dark plum outline, no text. |
| VIS-204 | `assets/visual/ui/panel_9slice.png` | 48×48px transparent square UI panel skin with 8px fixed corners: cream center, pale-mint inner highlight, peach lower edge and dark-plum outline; no text or icon. |
| VIS-205 | `assets/visual/ui/button_default_9slice.png` | 48×24px transparent blank UI button skin with 6px fixed corners: cream face, mint upper highlight, peach lower edge and dark-plum outline; no text or icon. |
| VIS-206 | `assets/visual/ui/button_primary_9slice.png` | 48×24px transparent blank primary UI button skin with 6px fixed corners: coral face, pale-gold upper highlight and dark-plum outline; no text or icon. |
| VIS-207 | `assets/visual/ui/button_pressed_9slice.png` | 48×24px transparent blank pressed UI button skin with 6px fixed corners: muted mint face shifted one pixel downward, darker upper inset and dark-plum outline; no text or icon. |
| VIS-208 | `assets/visual/ui/view_tab_9slice.png` | 52×28px transparent blank view-selector tab skin with 6px fixed corners: sky-blue face, cream top highlight, coral bottom accent and dark-plum outline; no text or icon. |
| VIS-209 | `assets/visual/ui/direction_button.png` | 54×44px transparent blank direction-pad button: rounded toy-block face, cream center, mint edge and dark-plum outline, open center for a code-rendered arrow and prediction badge; no symbol. |
| VIS-210 | `assets/visual/ui/item_slot_9slice.png` | 40×40px transparent blank item-slot skin with 6px fixed corners: pale-cream center, peach inset and dark-plum outline; no text or icon. |

## 4. Stable Audio — 효과음 리소스

### 공통 규격

- 형식: WAV, 44.1 kHz, 16-bit, mono (BGM 제외)
- 길이: 0.15–1.2초
- 루프 없음, 음성·가사·저작권 식별 가능한 멜로디 없음
- 밝고 부드러운 장난감 소리. 과도한 저음, 큰 충격음, 공포 분위기 금지.

| ID | 이벤트 | 길이 | 사운드 방향 | 완료 조건 |
| --- | --- | ---: | --- | --- |
| SFX-001 | 주사위 굴림 시작 | 0.25–0.4초 | 나무 블록 위의 작은 딸깍임 | 단일 입력에 한 번만 재생 |
| SFX-002 | 주사위 착지 | 0.2–0.35초 | 부드러운 톡 소리 | 반복해도 피로감이 낮음 |
| SFX-003 | 낙하 시도 | 0.35–0.6초 | 짧고 귀여운 실수 효과 | 불쾌하거나 큰 소리가 아님 |
| SFX-004 | 언두 | 0.25–0.5초 | 가벼운 되감기/팝 | 되돌림 피드백이 명확함 |
| SFX-005 | 일반 클리어 | 0.7–1.2초 | 작은 장난감 종과 반짝임 | 긍정적이되 BGM을 덮지 않음 |
| SFX-006 | 완벽 클리어 | 0.9–1.2초 | SFX-005보다 한 단계 풍성한 상승음 | 일반 클리어와 확실히 구분됨 |
| SFX-007 | 사망/게임 오버 | 0.55–0.9초 | 낮게 튕기는 나무 블록과 부드러운 하강음 | 막힌 이동과 구분되며 공포스럽거나 크지 않음 |

### 개별 Stable Audio 프롬프트와 저장 위치

| ID | 저장 위치 | 생성 프롬프트 |
| --- | --- | --- |
| SFX-001 | `assets/audio/sfx/dice_roll.wav` | Short cute wooden toy block click, one gentle forward roll, dry and warm, no music, 0.35 seconds. |
| SFX-002 | `assets/audio/sfx/dice_land.wav` | Soft single toy die landing tap on wood, warm and light, no music, 0.25 seconds. |
| SFX-003 | `assets/audio/sfx/blocked.wav` | Brief adorable wrong-move toy wobble with a soft descending pop, no music, 0.45 seconds. |
| SFX-004 | `assets/audio/sfx/undo.wav` | Light magical rewind pop made from toy xylophone and soft wood click, no music, 0.4 seconds. |
| SFX-005 | `assets/audio/sfx/clear.wav` | Short cheerful toy bell and sparkle success flourish, no melody quotation, no voice, 1 second. |
| SFX-006 | `assets/audio/sfx/perfect_clear.wav` | Brighter celebratory toy bell, xylophone, and sparkle upward flourish, no voice, 1.1 seconds. |
| SFX-007 | `assets/audio/sfx/death.wav` | Cute toy block tumble and soft descending wooden marimba failure cue, gentle and brief, no music bed, no voice, no harsh impact, 0.75 seconds. |

## 5. MiniMax Music 3 — 배경음악 리소스

### 공통 규격

- 형식: OGG 또는 WAV, 44.1 kHz, stereo
- 무가사, 게임 내 루프를 고려한 자연스러운 시작/끝
- 효과음과 UI를 방해하지 않도록 중간 이하의 다이내믹 레인지

| ID | 용도 | 길이 | 음악 방향 | 완료 조건 |
| --- | --- | ---: | --- | --- |
| BGM-001 | 기본 퍼즐 화면 | 60–90초 루프 | 장난감 피아노, 실로폰, 부드러운 우드 퍼커션; 느긋하고 호기심 많은 분위기 | 루프 경계가 거슬리지 않고 긴 퍼즐 플레이에 피로감이 낮음 |
| BGM-002 | 클리어 화면 | 4–7초 | BGM-001과 같은 악기군의 짧은 축하 징글 | 일반/완벽 클리어 효과음과 충돌하지 않음 |

### 개별 MiniMax Music 3 프롬프트와 저장 위치

| ID | 저장 위치 | 생성 프롬프트 |
| --- | --- | --- |
| BGM-001 | `assets/audio/music/puzzle_loop.wav` | Instrumental seamless 75-second loop for a cute top-down toy block puzzle room. Gentle toy piano, xylophone, soft wooden percussion, warm major-key curiosity; relaxed mid-slow tempo; no vocals, no dramatic drops, no copyrighted melody. |
| BGM-002 | `assets/audio/music/clear_jingle.ogg` | Instrumental 5-second celebratory jingle matching a cute toy block puzzle room: toy piano, xylophone, soft bell sparkle; no vocals, clean ending. |
| BGM-003 | `assets/audio/music/menu_loop.wav` | Instrumental seamless main-menu loop for a cute pastel toy-block dice puzzle. Calm 76 BPM, music box, toy piano, celesta and airy felt pads; welcoming and distinct from the puzzle loop; no vocals or dramatic drop. |

## 6. Chatterbox — 튜토리얼 안내 음성

주사위는 플레이어가 조작하는 게임 오브젝트이므로 별도의 캐릭터 보이스를 사용하지 않는다. 음성은 게임의 규칙을 처음 알리는 짧은 한국어 안내 내레이션으로만 사용한다.

### 공통 규격

- 언어: 한국어
- 화자: 특정 캐릭터가 아닌 친절하고 차분한 장난감방 안내자
- 톤: 밝고 짧으며 설명적. 과장된 연기, 유아화된 말투, 지나치게 빠른 발화 금지.
- 형식: WAV, 44.1 kHz, 16-bit, mono
- 길이: 항목당 1.5–3.5초
- 각 대사는 해당 튜토리얼 문구가 최초로 표시될 때 한 번만 재생한다.
- 자막은 항상 음성과 동일한 문구를 화면에 표시한다.

| ID | 대사 | 재생 조건 | 완료 조건 |
| --- | --- | --- | --- |
| VO-001 | "화면의 방향 화살표를 눌러 주사위를 굴려 보세요." | 레벨 1 시작 | 차분하고 또렷하며 3.5초 이내 |
| VO-002 | "목표 숫자와 윗면 숫자가 같아야 해요." | 레벨 2 시작 | 숫자 규칙을 명확히 들을 수 있음 |
| VO-003 | "위험한 블록에서는 Undo나 재시작으로 돌아올 수 있어요." | 첫 사망 | 캠페인의 사망 복구 규칙을 부드럽게 안내, 3.5초 이내 |
| VO-004 | "Undo 버튼을 누르면 한 번의 행동을 되돌릴 수 있어요." | 레벨 4 시작 | 연쇄 이동을 포함한 Undo 기능을 또렷하게 안내 |
| VO-005 | "목표 입력 수 안에 풀면 완벽 클리어예요." | 레벨 5 시작 | 완벽 클리어 조건을 명확히 안내 |
| VO-006 | "잘했어요! 다음 퍼즐로 가 볼까요?" | 첫 레벨 클리어 | 짧고 긍정적이며 효과음과 충돌하지 않음 |

### 개별 Chatterbox 요청과 저장 위치

| ID | 저장 위치 | 생성 요청 |
| --- | --- | --- |
| VO-001 | `assets/audio/voice/tutorial_move.wav` | Speak the exact Korean line naturally in a friendly, calm game-guide voice: "화면의 방향 화살표를 눌러 주사위를 굴려 보세요." |
| VO-002 | `assets/audio/voice/tutorial_goal.wav` | Speak the exact Korean line naturally in a friendly, calm game-guide voice: "목표 숫자와 윗면 숫자가 같아야 해요." |
| VO-003 | `assets/audio/voice/tutorial_safe.wav` | Speak the exact Korean line naturally in a reassuring game-guide voice: "위험한 블록에서는 Undo나 재시작으로 돌아올 수 있어요." |
| VO-004 | `assets/audio/voice/tutorial_undo.wav` | Speak the exact Korean line naturally in a friendly, calm game-guide voice: "Undo 버튼을 누르면 한 번의 행동을 되돌릴 수 있어요." |
| VO-005 | `assets/audio/voice/tutorial_par.wav` | Speak the exact Korean line naturally in a friendly, encouraging game-guide voice: "목표 입력 수 안에 풀면 완벽 클리어예요." |
| VO-006 | `assets/audio/voice/tutorial_clear.wav` | Speak the exact Korean line naturally in a warm, concise game-guide voice: "잘했어요! 다음 퍼즐로 가 볼까요?" |

### 제외 범위

- 주사위의 대사 또는 감정 표현
- 전투·스토리·캐릭터 상호작용용 음성
- 영어 및 기타 언어 현지화

## 7. 에셋 적용 게이트

1. 이 문서의 개별 ID와 생성 순서를 확정한다.
2. 생성물은 픽셀 크기, 투명도, 가독성, 금지 요소를 검수한다.
3. 승인된 파일만 `assets/`에 저장하고 Godot 씬/코드에서 참조한다.
4. 적용 후 1× 크기·모바일·PC 화면에서 UI/보드 가독성을 확인한다.
5. 리소스 교체 후에도 `gameplay-spec.md`의 모든 검증 기준을 유지한다.

## 7A. 최종 3D용 픽셀 아트 표면 텍스처

최종 3D는 기존 Godot 메시·조명·직교 카메라를 유지하고 표면에 PixelLab Pixflux로 제작한 저해상도 텍스처를 적용한다. 2D 쿼터뷰 스프라이트를 3D 면에 그대로 투영하지 않는다.

| ID | 저장 위치 | 크기 | 용도 | 완료 조건 |
| --- | --- | ---: | --- | --- |
| TEX-301 | `assets/visual/3d/toy_block_surface.png` | 32×32px | 바닥·벽·특수 블록의 공통 표면. 코드에서 테마색으로 변조 | 이음새 없는 타일, 4색 이하의 명암, 원근·외곽선 없음 |
| TEX-302 | `assets/visual/3d/die_surface.png` | 32×32px | 주사위 본체 표면. 숫자 점은 기존 코드 텍스처로 겹침 | 크림색 무광 장난감 질감, 점·숫자 없음, 이음새 없음 |

- 모델: PixelLab `generate-image-pixflux`.
- 필터: Godot `TEXTURE_FILTER_NEAREST`, mipmap 비활성.
- 재질: 거칠기 0.9 이상, 금속성 0, 노멀·사진 질감·부드러운 그라데이션 없음.
- 조명은 면 방향을 보여주는 현재 3D 조명을 유지하되, 텍스처 자체는 1–2px 단위의 제한된 명암만 사용한다.
- 특수 타일과 10개 테마는 공통 표면을 코드에서 색상 변조해 표현한다. 숫자와 텍스트는 이미지에 생성하지 않는다.
- 실제 생성 프롬프트와 결과 해시는 `docs/3d-texture-prompts.json`에 기록한다.

## 8. 고정 생성 순서와 상태

생성은 반드시 아래 순서대로 한 항목씩 수행·검수한다. 거절된 결과물은 같은 ID의 새 버전 파일(`-v2`, `-v3`)로 저장하며 기존 승인본을 덮어쓰지 않는다.

| 순서 | ID | 선행 조건 | 상태 |
| ---: | --- | --- | --- |
| 1 | VIS-001 | 없음 | PixelLab MCP 생성·검수·연결 완료 |
| 2 | VIS-002 | VIS-001 검수 | PixelLab MCP 생성·검수·연결 완료 |
| 3 | VIS-003 | VIS-002 검수 | PixelLab MCP 생성·검수·연결 완료 |
| 4 | VIS-005, VIS-006 | VIS-003 검수 | PixelLab MCP 생성·검수·연결 완료 |
| 5 | VIS-004 | VIS-002 검수 | PixelLab MCP 생성·검수·연결 완료 |
| 6 | VIS-101, VIS-103-A/B/C | 핵심 스프라이트 검수 | PixelLab MCP 생성·검수·연결 완료 |
| 7 | VIS-201–210 | 색상·외곽선 검수 | PixelLab MCP 생성·검수·연결 완료 |
| 8 | SFX-001–007 | 게임 이벤트 연결 스펙 확정 | Stable Audio 3 생성·가공·연결 완료 |
| 9 | BGM-001–003 | UI 및 효과음 볼륨 기준 확정 | MiniMax Music 3 생성·가공·연결 완료 |
| 10 | VO-001–006 | 튜토리얼 재생 상태 스펙 확정 | Chatterbox 생성·가공·연결 완료 |

## 9. 적용 기록

| 일자 | 리소스 | 결과 | 검증 | 상태 |
| --- | --- | --- | --- | --- |
| 2026-10-02 | BGM-001 | 로컬 Stable Audio 3 `sm-music`으로 `assets/audio/music/puzzle_loop.wav` 생성, 75초·44.1kHz 스테레오 루프 | Godot 메인 씬 기동 시 로딩 오류 없음 | 수동 청취 검수 대기 |
| 2026-10-02 | SFX-001–006, BGM-002, VO-001–006 | 로컬 임시 생성본을 `assets/audio/`에 저장하고 게임 이벤트에 연결 | 형식 확인 및 Godot 메인 씬 기동 | 승인본 교체·수동 청취 대기 |
| 2026-10-05 | SFX-001–007 | Stable Audio 3 Small-SFX 로컬 MLX 원본 7개 생성, 명세 길이 가공, 사망 효과음 별도 연결 | 44.1kHz·16-bit·mono·길이·해시 검사 | 자동 검증 완료 · 수동 청취 대기 |
| 2026-10-05~06 | BGM-001–003 | MiniMax Music 3 BF16 로컬 MLX 원본 생성, 75초 퍼즐 루프·5초 징글·57.734초 메뉴 루프 가공 | 44.1kHz·stereo·길이·해시·순환 경계 검사 | 자동 검증 완료 · 수동 청취 대기 |
| 2026-10-05 | VO-001–006 | Chatterbox Multilingual v3 지정 한국어 대사 생성, 앞뒤 무음 제거 및 정규화 | 44.1kHz·16-bit·mono, 2.37–3.49초, 자막 문자열 일치 | 자동 검증 완료 · 수동 청취 대기 |
| 2026-10-06 | VIS-001–210, TEX-301–302 | PixelLab MCP의 `create_image_pixflux`로 22개 생성 후 `get_image`로 수신; 거절된 REST v1 시안은 감사 기록으로 분리 | MCP 작업 ID·실제 합성 프롬프트·seed·원본/최종 SHA-256 기록, 네이티브 크기·임포트·세 보기 캡처 확인 | 생성·연결·자동 검증 완료 |

## 2026-10-06 PixelLab MCP 승인본

- `mcp-remote`를 통해 `https://api.pixellab.ai/mcp`에 연결했고, MCP 초기화와 도구 목록 조회 후 `create_image_pixflux`와 `get_image`를 호출했다.
- 최종 범위는 VIS 20개와 3D 표면 TEX 2개, 합계 22개다. 공통 UI는 패널, 버튼 3상태, 보기 탭, 방향 버튼, 아이템 슬롯을 이미지 스킨으로 연결한다.
- 실제 합성 프롬프트, seed, 초기 가이드, 후처리 조건은 `docs/pixellab-generation-prompts.json`에, MCP 작업 ID와 파일 해시는 `artifacts/pixellab-mcp-final-results.json`에 기록한다.
- 최초 REST v1 결과는 `artifacts/pixellab-generation-results-rest-v1.json`에 남긴 비승인 감사 자료이며 게임에는 사용하지 않는다.
- TEX-301과 TEX-302는 최종 3D 메시의 albedo texture로 적용하고 Godot nearest 필터를 사용한다. 주사위 점과 숫자는 기존 코드가 별도로 표시한다.
- Godot 4.7.2에서 시각 리소스 20개 임포트 감사, 100개 규칙 검사, 100스테이지 1,537입력 재생 검사를 통과했다. `artifacts/views/`에 동일 스테이지의 초기 탑뷰·중기 쿼터뷰·최종 3D를 새로 캡처했다.
- 메뉴는 타이틀·월드 선택·스테이지 카드·간단한 상태 영역에 공통 스킨을 적용한다. 일시정지와 빠른 도움은 보드를 완전히 가리는 생성 배경 위에 VIS-204 패널과 VIS-206 강조 버튼을 사용한다.
- 2026-10-06 UI v2: 기존 VIS-204–210의 비대칭 모서리와 반복되는 테두리를 폐기하고 PixelLab MCP `create_ui_asset` 한 시트에서 7개 요소를 다시 제작했다. 정확한 프롬프트·shape pieces·작업 ID·후처리·해시는 `docs/pixellab-ui-v2-prompts.json`과 `artifacts/pixellab-ui-v2/final-results.json`에 기록한다. v1 감사 기록은 `artifacts/pixellab-mcp-final-results-before-ui-v2.json`에 보존한다.
- 2026-10-06 VIS-211 v2: PixelLab MCP `create_image_pixflux`로 최종 3D 보드와 같은 구도의 메인 메뉴 히어로를 다시 제작했다. 첫 결과는 구성이 성겨 제외했고, 두 번째 결과의 캔버스 가장자리와 연결된 청록 배경색만 투명 처리해 구름·보드·주사위·목표·그림자를 보존했다. 두 프롬프트, seed, 작업 ID, 채택 여부와 원본/최종 해시는 `docs/pixellab-main-menu-prompts.json`과 `artifacts/pixellab-main-menu/final-results.json`에 기록한다.

## 2026-10-05 이미지 초안 감사 기록

- 사용자 요청: 미생성 리소스 전체 생성, 게임 연결, 실제 생성 프롬프트 전부 기록.
- 범위: 저장 경로가 정의된 VIS 이미지 13개. VIS-102는 정의·경로가 없는 이전 표의 오기이므로 생성 대상에서 제외.
- 당시 생성 도구: 내장 imagegen. 사용자가 지정한 PixelLab이 아니므로 이 결과는 승인본이 아니다. 개별 요청/원본/현재 연결 경로는 `docs/asset-generation-prompts.json`에 기록되어 있다.
- 생성 원본을 보존하며 게임용 크기는 명세 크기로 정규화한다. 기존의 원본 확대/축소 금지 조항 대신 생성 도구 출력 크기에 맞춰 nearest 필터로 게임에서 축소 표시할 수 있다.
- 완료 조건: 13개 파일 존재·디코딩·투명도 확인, 실제 화면에 연결, 숫자와 글자는 코드 표시, 규칙 및 캠페인 회귀 검사, 새 시뮬레이터 기동과 캡처 확인.
- 기존 오디오는 재생성 범위가 아니며 캠페인의 미연결 착지/징글/음성 이벤트는 함께 연결한다.

당시 초안 표시 구현: 2026-10-05 초안은 생성된 2D PNG로 배경·바닥·주사위·마커·아이콘을 그리고 3D 뷰포트를 표시하지 않았다. 현재 최종 버전은 텍스처가 적용된 3D 뷰포트를 기본으로 표시하며, 2D 탑뷰와 2D 쿼터뷰는 내부 비교용 숫자 키 1·2로 보존한다. 특수 타일은 바닥 이미지의 색과 코드 라벨로 구분하고, 생성 원본 해상도와 논리 표시 크기를 프롬프트 기록에서 구분한다.

캠페인 음성 적용: 이동/숫자 목표/Undo/par/첫 클리어의 기존 음성 5개를 재생한다. VO-003의 “마지막 안전한 곳으로 돌아와요”는 캠페인 사망/Undo 규칙과 다르므로 연결하지 않는다. 해당 음원의 재작성은 별도 오디오 교체 작업으로 남긴다. 자동 테스트는 음성의 문장 품질이나 루프 청감을 승인하지 않는다.

### 2026-10-05 초안 검증 결과

- 내장 imagegen으로 만든 13개 PNG는 로딩·표시 검증만 마친 비승인 초안이다. `docs/asset-generation-prompts.json`은 당시 실제 생성 기록이며 PixelLab 생성 기록으로 해석하지 않는다.
- 생성 도구는 20–64px 원본 출력을 따르지 않아 고해상도 원본을 보존하고 nearest 필터로 표시한다. 반투명 미세 노이즈를 제외한 알파 128 이상 영역을 `assets/visual/regions.json`에 기록하고 AtlasTexture의 표시 영역에 적용한다. 이미지 파일 자체는 편집하지 않았다.
- `tools/audit_visual_assets.gd`: 13개 Godot import·빈 이미지·스프라이트 모서리 투명도 검사 통과.
- `tests/rules_test.tscn`: 100개 지형/해법/규칙 통과.
- `tests/campaign_play_test.gd`: 1,537입력, 100스테이지, 모든 층 화면 범위, Undo/사망/대기/힌트 회귀 통과. 종료 시 기존 계열 ObjectDB 잔존 경고 4개 발생.
- `tools/capture_campaign.gd`: 실제 OpenGL 화면 캡처 완료, 오류 없음. `artifacts/campaign/`의 게임 화면·가방·도감·완벽 클리어·파괴 타일 확인.
- 당시 임시 오디오 연결 기록은 2026-10-05 지정 모델 재생성 작업으로 대체한다.
