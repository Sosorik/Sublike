#!/usr/bin/env python3
"""데이터 무결성 검사.  python3 scripts/validate_data.py"""
import json, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
errors, warnings = [], []

def load(name):
    p = DATA / name
    if not p.exists():
        errors.append(f"파일 없음: {name}"); return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errors.append(f"JSON 파싱 실패 {name}: {e}"); return None

heroes   = load("heroes.json")
atypes   = load("attack_types.json")
hskills  = load("hero_skills.json")
askills  = load("aida_skills.json")
floors   = load("floors.json")
enemies  = load("enemies.json")
upgrades = load("run_upgrades.json")

if not errors:
    atype_ids  = {a["id"] for a in atypes["attack_types"]}
    hskill_ids = {s["id"] for s in hskills["hero_skills"]}
    askill_ids = {s["id"] for s in askills["skills"]}
    hero_list  = [h for h in heroes["heroes"] if not h["id"].startswith("_")]
    hero_ids   = {h["id"] for h in hero_list}
    valid_types = {"ground", "high"}
    valid_lanes = {"a", "b", "c"}

    for h in hero_list:
        if h["attack_type_id"] not in atype_ids:
            errors.append(f"[heroes] '{h['id']}' 없는 공격타입: {h['attack_type_id']}")
        if h["skill_id"] not in hskill_ids:
            errors.append(f"[heroes] '{h['id']}' 없는 고유스킬: {h['skill_id']}")
        gs = h.get("grants_skill")
        if gs and gs not in askill_ids:
            errors.append(f"[heroes] '{h['id']}' 없는 아이다 스킬 전수: {gs}")
        if h["deploy_type"] not in valid_types:
            errors.append(f"[heroes] '{h['id']}' 잘못된 배치 종류: {h['deploy_type']}")
        if h.get("deploy_cost", 0) <= 0:
            errors.append(f"[heroes] '{h['id']}' 배치 코스트가 0 이하")
        block = h["base_stats"].get("block_count", 0)
        if h["deploy_type"] == "high" and block != 0:
            errors.append(f"[heroes] '{h['id']}' 고지 배치인데 저지 수가 {block} (0이어야 한다)")
        if h["deploy_type"] == "ground" and block <= 0:
            errors.append(f"[heroes] '{h['id']}' 지상 배치인데 저지 수가 0")
        if not h.get("cutin_line"):
            warnings.append(f"[heroes] '{h['id']}' 컷인 대사 없음")

    seen = {}
    for h in hero_list:
        f = h.get("floor", 0)
        if f == 0: continue
        if f in seen: errors.append(f"[heroes] 층 {f} 중복: {seen[f]} / {h['id']}")
        seen[f] = h["id"]
        if not (1 <= f <= 100): errors.append(f"[heroes] '{h['id']}' 층 범위 초과: {f}")

    for seg in floors["segments"]:
        b = seg.get("boss_hero_id")
        if b:
            if b not in hero_ids:
                errors.append(f"[floors] '{seg['id']}' 없는 보스: {b}")
            else:
                bh = next(h for h in hero_list if h["id"] == b)
                if bh["floor"] not in seg["floors"]:
                    errors.append(f"[floors] '{seg['id']}' 보스 '{b}' 층({bh['floor']})이 구간 밖")

    all_floors = [f for seg in floors["segments"] for f in seg["floors"]]
    if all_floors != sorted(all_floors): errors.append("[floors] 층 순서 오름차순 아님")
    if len(set(all_floors)) != len(all_floors): errors.append("[floors] 층 중복 정의")

    for s in askills["skills"]:
        if s["slot"] not in {"buff", "element", "heal"}:
            errors.append(f"[aida_skills] '{s['id']}' 잘못된 슬롯: {s['slot']}")
        if s["cooldown"] <= 0:
            errors.append(f"[aida_skills] '{s['id']}' 쿨타임 0 이하")
    for slot in {"buff", "element", "heal"}:
        if not any(s["slot"] == slot for s in askills["skills"]):
            errors.append(f"[aida_skills] 슬롯 '{slot}' 비어 있음")

    lanes = enemies["wave_pattern"]["lanes_y"]
    for ln in valid_lanes:
        if ln not in lanes: errors.append(f"[enemies] lanes_y에 '{ln}' 없음")
    for e in enemies["enemies"]:
        lp = e.get("lane_pref", "any")
        if lp != "any" and lp not in valid_lanes:
            errors.append(f"[enemies] '{e['id']}' 잘못된 lane_pref: {lp}")

    # 배치 종류 커버리지 — 지상/고지 둘 다 있어야 9칸을 쓸 수 있다
    for dt in valid_types:
        n = sum(1 for h in hero_list if h["deploy_type"] == dt)
        if n == 0:
            errors.append(f"배치 종류 '{dt}' 가신 없음")
        else:
            warnings.append(f"{dt} 가신 {n}명")

    if len(hero_list) < 40:      warnings.append(f"가신 {len(hero_list)}/40 명")
    if len(hskills["hero_skills"]) < 15: warnings.append(f"고유스킬 {len(hskills['hero_skills'])}/15 종")
    if len(all_floors) < 100:    warnings.append(f"층 {len(all_floors)}/100 정의됨")
    low = [a["id"] for a in atypes["attack_types"] if a["impl_cost"] == "low"]
    warnings.append(f"먼저 구현할 저비용 공격타입: {', '.join(low)}")

print("=" * 52)
if errors:
    print(f"오류 {len(errors)}건")
    for e in errors: print(f"  X {e}")
else:
    print("데이터 무결성 통과")
if warnings:
    print(f"\n참고 {len(warnings)}건")
    for w in warnings: print(f"  - {w}")
print("=" * 52)
sys.exit(1 if errors else 0)
