#!/usr/bin/env python3
"""데이터 무결성 검사. 커밋 전에 실행할 것.
    python3 scripts/validate_data.py
"""
import json, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
errors, warnings = [], []

def load(name):
    p = DATA / name
    if not p.exists():
        errors.append(f"파일 없음: {name}")
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errors.append(f"JSON 파싱 실패 {name}: {e}")
        return None

heroes  = load("heroes.json")
weapons = load("weapons.json")
skills  = load("skills.json")
floors  = load("floors.json")
enemies = load("enemies.json")
upgrades= load("run_upgrades.json")

if not errors:
    weapon_ids = {w["id"] for w in weapons["weapons"]}
    skill_ids  = {s["id"] for s in skills["skills"]}
    hero_list  = [h for h in heroes["heroes"] if not h["id"].startswith("_")]
    hero_ids   = {h["id"] for h in hero_list}

    # 1. 캐릭터 -> 무기 참조
    for h in hero_list:
        if h["weapon_id"] not in weapon_ids:
            errors.append(f"[heroes] '{h['id']}' 가 존재하지 않는 무기 참조: {h['weapon_id']}")
        gs = h.get("grants_skill")
        if gs and gs not in skill_ids:
            errors.append(f"[heroes] '{h['id']}' 가 존재하지 않는 스킬 참조: {gs}")

    # 2. 층 중복 배치
    seen = {}
    for h in hero_list:
        f = h.get("floor", 0)
        if f == 0: continue
        if f in seen:
            errors.append(f"[heroes] 층 {f} 중복 배치: {seen[f]} / {h['id']}")
        seen[f] = h["id"]
        if not (1 <= f <= 100):
            errors.append(f"[heroes] '{h['id']}' 층 범위 초과: {f}")

    # 3. 구간 -> 보스 참조
    for seg in floors["segments"]:
        b = seg.get("boss_hero_id")
        if b and b not in hero_ids:
            errors.append(f"[floors] '{seg['id']}' 가 존재하지 않는 보스 참조: {b}")
        if b:
            bh = next(h for h in hero_list if h["id"] == b)
            if bh["floor"] not in seg["floors"]:
                errors.append(f"[floors] '{seg['id']}' 보스 '{b}' 의 층({bh['floor']})이 구간 범위 밖")

    # 4. 층 연속성
    all_floors = []
    for seg in floors["segments"]:
        all_floors += seg["floors"]
    if all_floors != sorted(all_floors):
        errors.append("[floors] 층 순서가 오름차순이 아님")
    if len(set(all_floors)) != len(all_floors):
        errors.append("[floors] 층 중복 정의")

    # 5. 스킬 슬롯 유효성
    valid_slots = {"buff", "element", "heal"}
    for s in skills["skills"]:
        if s["slot"] not in valid_slots:
            errors.append(f"[skills] '{s['id']}' 잘못된 슬롯: {s['slot']}")
        if s["cooldown"] <= 0:
            errors.append(f"[skills] '{s['id']}' 쿨타임이 0 이하")

    # 6. 슬롯별 최소 1개
    for slot in valid_slots:
        if not any(s["slot"] == slot for s in skills["skills"]):
            errors.append(f"[skills] 슬롯 '{slot}' 에 스킬이 하나도 없음")

    # --- 경고 (기획 목표 대비) ---
    if len(hero_list) < 40:
        warnings.append(f"가신 {len(hero_list)}/40 명 (목표 미달, 확장 필요)")
    if len(weapons["weapons"]) < 15:
        warnings.append(f"무기 {len(weapons['weapons'])}/15 종")
    total_floors = len(all_floors)
    if total_floors < 100:
        warnings.append(f"층 {total_floors}/100 정의됨")

    low = [w["id"] for w in weapons["weapons"] if w["impl_cost"] == "low"]
    warnings.append(f"먼저 구현할 저비용 무기: {', '.join(low)}")

print("=" * 50)
if errors:
    print(f"❌ 오류 {len(errors)}건")
    for e in errors: print(f"  - {e}")
else:
    print("✅ 데이터 무결성 통과")
if warnings:
    print(f"\n⚠️  참고 {len(warnings)}건")
    for w in warnings: print(f"  - {w}")
print("=" * 50)
sys.exit(1 if errors else 0)
