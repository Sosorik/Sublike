# 진행 기록

작업 완료 시마다 기록. Claude Code가 세션 간 컨텍스트를 이어받는 용도.

## 형식
```
## YYYY-MM-DD
- [완료] 항목 — 파일 경로
- [진행중] 항목 — 남은 것
- [막힘] 항목 — 이유
```

---

## 2026-08-28

- [완료] Godot 4.7.2 설치 확인 — `~/Downloads/Godot.app`
- [완료] 프로젝트 초기화 — `project.godot` (1280x720 / canvas_items+expand / sensor_landscape(=4) / mobile 렌더러)
- [완료] 디렉토리 구조 — `scenes/{lobby,battle,entities,ui}`, `scripts/{core,combat,ui,data}`, `assets/{sprites,audio}`
- [완료] GitHub 연결 및 최초 푸시 — https://github.com/Sosorik/Sublike
- [완료] GDD v2.0(라인 방어형) 반영 확인 — `validate_data.py` 무결성 통과 (가신 3/40, 고유스킬 3/15, 층 24/100)
- [대기] `run/main_scene` 미지정 — `Main.tscn` 제작 후 설정 필요
- [대기] 라인 배치 좌표 규약 확정 — ARCHITECTURE.md의 전/중/후열 x좌표가 "전열이 피해를 먼저 받음"과 반대. 결정 후 수정
- [대기] 적 진군 차단 규칙 확정 — 전열에 막히는지, 통과하는지

- [ ] 공식 튜토리얼 "Your first 2D game" 완주
- [ ] 1주차: 적 1마리가 오른쪽에서 왼쪽으로 걸어온다
