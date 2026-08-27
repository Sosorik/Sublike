# 웬델: 마석탑의 수문장

뱀서라이크 로그라이트 + 캐릭터 수집. 1인 개발.

## 시작하기

```bash
# 1. 이 폴더를 프로젝트 루트로 열기
cd wendel
claude

# 2. Claude Code가 CLAUDE.md 를 자동으로 읽는다
# 3. 첫 지시:
#    "docs/CURRENT_PHASE.md 읽고 1주차 작업 시작해줘"
```

## 파일 지도

| 파일 | 역할 | 언제 읽나 |
|---|---|---|
| `CLAUDE.md` | 작업 규칙. Claude Code가 매번 자동 로드 | 자동 |
| `GDD.md` | 전체 기획서 | 설계 판단이 필요할 때 |
| `docs/CURRENT_PHASE.md` | **지금 만들 것** | 작업 시작 전 항상 |
| `docs/ARCHITECTURE.md` | 씬 구조, 전투 파이프라인 | 구현 시 |
| `docs/SAVE_FORMAT.md` | 세이브 스키마 | 저장 관련 작업 시 |
| `docs/PROGRESS.md` | 완료 기록 | 세션 시작/종료 시 |
| `docs/BACKLOG.md` | 범위 밖 아이디어 | 딴 생각 날 때 |
| `data/*.json` | 모든 게임 수치 | 밸런싱 |
| `PROMPTS.md` | 복붙용 작업 지시문 | 막힐 때 |

## 데이터 검증

```bash
python3 scripts/validate_data.py
```

캐릭터/무기/스킬/층 참조 무결성을 검사한다. **JSON 수정 후 항상 실행.**

## 핵심 원칙 3줄

1. `docs/CURRENT_PHASE.md`에 없으면 만들지 않는다
2. 수치는 코드가 아니라 `data/*.json`에 넣는다
3. 1막이 완성되면 게임의 90%가 완성된 것이다
