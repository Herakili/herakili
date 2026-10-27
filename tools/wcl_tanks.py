#!/usr/bin/env python3
"""Check the warrior tank priority against the fastest Classic Era kills on Warcraft Logs.

    python3 tools/wcl_tanks.py [--per-boss N] [--site vanilla] [encounterID ...]  > report.md

For each of the fastest kills (speed rankings) of each boss, every warrior Warcraft Logs lists as a tank is downloaded
(casts, damage done, damage taken, gear/talents; cached in ~/.cache/wcl/) and measured: spec and weapon setup, ability
use per minute, estimated threat by ability (Era values measured on the Classic server, see ERA.md), Bloodthirst
cooldown and Revenge window use, what they press when Bloodthirst and Revenge are both ready, and the opener.
Logs don't record rage, so rage is never assumed.  Needs tools/wcl.py credentials.
"""
import argparse, collections, csv, json, os, statistics, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wcl import WCL  # noqa: E402

CACHE = os.path.expanduser("~/.cache/wcl/fights")
DB2 = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".era-api", "db2")

# Single-target bosses where one warrior holds the boss for most of the fight (Classic Era zone IDs on "vanilla").
DEFAULT_BOSSES = {51118: "Patchwerk", 51115: "Loatheb", 50714: "Princess Huhuran", 50612: "Broodlord Lashlayer",
                  50616: "Chromaggus", 50672: "Ragnaros", 51084: "Onyxia", 50670: "Golemagg the Incinerator"}

# Threat by ability name: (damage multiplier, bonus threat per hit).  Defensive Stance x Defiance is applied on top.
THREAT = {"Heroic Strike": (1.0, 173), "Cleave": (1.0, 100), "Revenge": (2.25, 270), "Shield Slam": (1.0, 254),
          "Shield Bash": (1.5, 156), "Execute": (1.25, 0), "Whirlwind": (1.25, 0), "Hamstring": (1.25, 135),
          "Thunder Clap": (2.5, 0)}
CAST_THREAT = {"Sunder Armor": 261, "Demoralizing Shout": 43, "Battle Shout": 60 * 5, "Bloodrage": 5 * 20}
GCD = {"Bloodthirst", "Mortal Strike", "Revenge", "Shield Slam", "Sunder Armor", "Demoralizing Shout", "Battle Shout",
       "Thunder Clap", "Whirlwind", "Execute", "Hamstring", "Shield Bash", "Concussion Blow", "Mocking Blow", "Taunt",
       "Disarm", "Rend", "Overpower", "Intercept", "Charge", "Pummel", "Challenging Shout", "Intimidating Shout"}
REVENGE_TRIGGER = {4, 5, 7, 8}       # hitType: block, crit block, dodge, parry
BT_CD, REV_CD, REV_WINDOW = 6.0, 5.0, 5.0

# Rage (1.12 rules, as in Era/Warrior.lua): dealing white damage gives 7.5 * damage / c, taking damage 2.5 * damage / c.
RAGE_C = 0.0091107836 * 60 ** 2 + 3.225598133 * 60 + 4.2652911          # 230.6 at level 60
COST = {"Bloodthirst": 30, "Revenge": 5, "Sunder Armor": 15, "Demoralizing Shout": 10, "Battle Shout": 10,
        "Shield Block": 10, "Cleave": 20, "Whirlwind": 25, "Execute": 15, "Hamstring": 10, "Shield Bash": 10,
        "Sweeping Strikes": 30, "Shield Slam": 20, "Mocking Blow": 10, "Thunder Clap": 20, "Pummel": 10,
        "Intercept": 10, "Disarm": 20, "Rend": 10, "Overpower": 5, "Death Wish": 10, "Concussion Blow": 15,
        "Mortal Strike": 30, "Challenging Shout": 5, "Intimidating Shout": 25}
GAIN = {"Bloodrage": 20, "Mighty Rage": 60, "Great Rage": 45, "Rage": 30}       # instant + over-time, potions: average


def item_types():
    inv = {}
    path = os.path.join(DB2, "Item.csv")
    if os.path.exists(path):
        with open(path, newline="") as f:
            for r in csv.DictReader(f):
                inv[int(r["ID"])] = (int(r["InventoryType"] or 0), int(r["ClassID"] or 0))
    return inv


class Fetcher:
    def __init__(self, site):
        self.api, self.site = WCL(site), site
        os.makedirs(CACHE, exist_ok=True)

    def _cached(self, key, fn):
        path = os.path.join(CACHE, f"{self.site}_{key}.json")
        if os.path.exists(path):
            with open(path) as f:
                return json.load(f)
        data = fn()
        with open(path, "w") as f:
            json.dump(data, f)
        return data

    def fastest(self, enc, n):
        def get():
            d = self.api.query("query($id:Int!){ worldData { encounter(id:$id) { name fightRankings(metric: speed) } } }",
                               {"id": enc})
            return d["worldData"]["encounter"]
        e = self._cached(f"speed_{enc}", get)
        return e["name"], e["fightRankings"]["rankings"][:n]

    def report(self, code, fid):
        def get():
            return self.api.query("""query($c:String!,$f:[Int]!){ reportData { report(code:$c) {
              fights(fightIDs:$f) { id name startTime endTime kill enemyNPCs { id gameID } }
              masterData { actors(type:"Player") { id name subType } abilities { gameID name } }
              playerDetails(fightIDs:$f) } } }""", {"c": code, "f": [fid]})["reportData"]["report"]
        return self._cached(f"rep_{code}_{fid}", get)

    def events(self, code, fight, dtype, actor):
        def get():
            out, start = [], fight["startTime"]
            while start is not None:
                q = f"""query($c:String!,$f:[Int]!,$s:Float!,$e:Float!,$a:Int!){{ reportData {{ report(code:$c) {{
                  events(fightIDs:$f, startTime:$s, endTime:$e, dataType:{dtype}, sourceID:$a, limit:10000)
                  {{ data nextPageTimestamp }} }} }} }}"""
                d = self.api.query(q, {"c": code, "f": [fight["id"]], "s": start, "e": fight["endTime"], "a": actor})
                ev = d["reportData"]["report"]["events"]
                out += ev["data"]
                start = ev["nextPageTimestamp"]
            return out
        return self._cached(f"ev_{code}_{fight['id']}_{actor}_{dtype}", get)


def analyse(fetch, inv, code, fid, boss):
    rep = fetch.report(code, fid)
    fight = rep["fights"][0]
    names = {a["gameID"]: a["name"] for a in rep["masterData"]["abilities"]}
    actors = {a["id"]: a for a in rep["masterData"]["actors"]}
    tanks = [p for p in rep["playerDetails"]["data"]["playerDetails"].get("tanks", []) if p["type"] == "Warrior"]
    t0, dur = fight["startTime"], (fight["endTime"] - fight["startTime"]) / 1000
    results = []
    for p in tanks:
        aid = p["id"]
        casts = [e for e in fetch.events(code, fight, "Casts", aid) if e["type"] == "cast"]
        done = [e for e in fetch.events(code, fight, "DamageDone", aid) if e["type"] == "damage" and e.get("sourceID") == aid]
        taken = [e for e in fetch.events(code, fight, "DamageTaken", aid) if e.get("targetID") == aid and e["type"] == "damage"]
        info = fetch.events(code, fight, "CombatantInfo", aid)
        info = info[0] if info else {}
        tree = [t.get("id", 0) for t in info.get("talents", [])] or [0, 0, 0]
        gear = {g.get("slot", i): g.get("id", 0) for i, g in enumerate(info.get("gear", []))}
        oh = inv.get(gear.get(16, 0), (0, 0))
        mh = inv.get(gear.get(15, 0), (0, 0))
        setup = "shield" if oh[0] == 14 else ("2H" if mh[0] == 17 else ("DW" if oh[1] == 2 else "?"))
        mult = 1.3 * (1.15 if tree[2] >= 15 else 1.0)          # Defensive Stance, Defiance 5/5 assumed with 15+ Prot
        boss_melee = sum(1 for e in taken if e.get("abilityGameID") == 1)

        def nm(e):
            return names.get(e["abilityGameID"], str(e["abilityGameID"]))

        # Threat estimate by ability (damage events, plus flat-threat casts).
        threat = collections.Counter()
        for e in done:
            m, bonus = THREAT.get(nm(e), (1.0, 0))
            hit = e.get("hitType", 1) not in (0, 7, 8)          # miss / dodge / parry: no damage, no bonus
            threat[nm(e)] += mult * (m * e.get("amount", 0) + (bonus if hit else 0))
        for e in casts:
            if nm(e) in CAST_THREAT:
                threat[nm(e)] += mult * CAST_THREAT[nm(e)] if nm(e) != "Bloodrage" else CAST_THREAT[nm(e)]
        per_min = collections.Counter(nm(e) for e in casts)

        # Bloodthirst / Revenge availability and choices.
        triggers = sorted((e["timestamp"] - t0) / 1000 for e in taken if e.get("hitType") in REVENGE_TRIGGER)
        bt_times = [(e["timestamp"] - t0) / 1000 for e in casts if nm(e) == "Bloodthirst"]
        rev_times = [(e["timestamp"] - t0) / 1000 for e in casts if nm(e) == "Revenge"]
        has_bt = bool(bt_times)
        last_bt, last_rev, choice = -99.0, -99.0, collections.Counter()
        # Most Revenges possible: each dodge/parry/block opens a 5 s window, and Revenge has a 5 s cooldown.
        rev_windows, ready_at = 0, -99.0
        for tr in triggers:
            use = max(tr, ready_at)
            if use <= tr + REV_WINDOW:
                rev_windows += 1
                ready_at = use + REV_CD
        for e in sorted(casts, key=lambda x: x["timestamp"]):
            t, a = (e["timestamp"] - t0) / 1000, nm(e)
            if a not in GCD:
                continue
            bt_ready = has_bt and t >= last_bt + BT_CD - 0.2
            rev_ready = t >= last_rev + REV_CD - 0.2 and any(t - REV_WINDOW <= tr <= t and tr > last_rev for tr in triggers)
            if bt_ready and rev_ready:
                choice["both ready: " + (a if a in ("Bloodthirst", "Revenge") else "other")] += 1
            if a == "Bloodthirst":
                last_bt = t
            elif a == "Revenge":
                last_rev = t
        # Rage timeline: income from damage taken and white swings, Bloodrage/potions; spending from casts; 0-100.
        hs_cost = 15 - min(tree[0], 3)                         # Improved Heroic Strike: assume Arms points go there first
        timeline = [((e["timestamp"] - t0) / 1000, 2.5 * e.get("amount", 0) / RAGE_C) for e in taken]
        whites = [e for e in done if nm(e) == "Melee"]
        timeline += [((e["timestamp"] - t0) / 1000, 7.5 * e.get("amount", 0) / RAGE_C) for e in whites]
        for e in casts:
            a = nm(e)
            delta = GAIN.get(a, 0) - (hs_cost if a == "Heroic Strike" else COST.get(a, 0))
            if delta:
                timeline.append(((e["timestamp"] - t0) / 1000, delta))
        rage, overflow, short, income = 0.0, 0.0, 0.0, 0.0
        rage_at = []
        for t, d in sorted(timeline):
            if d > 0:
                income += d
            rage += d
            if rage > 100:
                overflow += rage - 100
                rage = 100
            elif rage < 0:
                short += -rage                                 # spent more than the model earned (pre-pull rage, procs)
                rage = 0
            rage_at.append((t, rage))

        def rage_before(t):
            r = 0.0
            for tt, rr in rage_at:
                if tt >= t:
                    break
                r = rr
            return r

        # Re-walk the "both ready" moments with the rage at that moment.
        choice_by_rage = collections.Counter()
        last_bt, last_rev = -99.0, -99.0
        for e in sorted(casts, key=lambda x: x["timestamp"]):
            t, a = (e["timestamp"] - t0) / 1000, nm(e)
            if a not in GCD:
                continue
            bt_ready = has_bt and t >= last_bt + BT_CD - 0.2
            rev_ready = t >= last_rev + REV_CD - 0.2 and any(t - REV_WINDOW <= tr <= t and tr > last_rev for tr in triggers)
            if bt_ready and rev_ready and a in ("Bloodthirst", "Revenge"):
                r = rage_before(t)
                band = "<30" if r < 30 else ("30-59" if r < 60 else "60+")
                choice_by_rage[(band, a)] += 1
            if a == "Bloodthirst":
                last_bt = t
            elif a == "Revenge":
                last_rev = t

        # Their own threat per rage / per GCD (averages of landed hits).
        def avg(ability):
            v = [e.get("amount", 0) for e in done if nm(e) == ability and e.get("hitType", 1) not in (0, 7, 8)]
            return statistics.mean(v) if v else None
        white_avg = avg("Melee")
        eff = {}
        if avg("Bloodthirst"):
            eff["Bloodthirst"] = (mult * avg("Bloodthirst"), 30)
        if avg("Revenge"):
            eff["Revenge"] = (mult * (2.25 * avg("Revenge") + 270), 5)
        if avg("Heroic Strike") and white_avg:
            # Replaces a white swing: the gain over that swing, and its cost plus the white swing's lost rage.
            eff["Heroic Strike"] = (mult * (avg("Heroic Strike") + 173 - white_avg), hs_cost + 7.5 * white_avg / RAGE_C)
        eff["Sunder Armor"] = (mult * 261, 15)

        first = sorted(casts, key=lambda x: x["timestamp"])[:6]
        results.append({
            "boss": boss, "code": code, "fight": fid, "duration": dur, "name": actors.get(aid, {}).get("name", p["name"]),
            "tree": "/".join(map(str, tree)), "setup": setup, "boss_melee": boss_melee,
            "per_min": {k: v * 60 / dur for k, v in per_min.items()},
            "threat": dict(threat), "tps": sum(threat.values()) / dur,
            "bt_use": (len(bt_times) * BT_CD / dur) if has_bt else None,
            "rev_use": (len(rev_times) / rev_windows) if rev_windows else None,
            "choice": dict(choice),
            "choice_by_rage": {f"{b}|{a}": v for (b, a), v in choice_by_rage.items()},
            "rage_income": income / dur, "rage_overflow": overflow / dur, "rage_short": short / dur,
            "rage_taken": sum(2.5 * e.get("amount", 0) / RAGE_C for e in taken) / dur,
            "eff": {k: {"threat": v[0], "rage": v[1]} for k, v in eff.items()},
            "opener": [f"{nm(e)}@{(e['timestamp'] - t0) / 1000:.1f}" for e in first],
        })
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--per-boss", type=int, default=8)
    ap.add_argument("--site", default="vanilla")
    ap.add_argument("bosses", nargs="*", type=int)
    args = ap.parse_args()
    fetch, inv = Fetcher(args.site), item_types()
    rows = []
    for enc in args.bosses or DEFAULT_BOSSES:
        boss, fights = fetch.fastest(enc, args.per_boss)
        for r in fights:
            try:
                rows += analyse(fetch, inv, r["report"]["code"], r["report"]["fightID"], boss)
            except SystemExit as e:
                print(f"<!-- skipped {boss} {r['report']['code']}: {str(e)[:120]} -->")
        print(f"<!-- {boss}: {len(fights)} fights -->", file=sys.stderr)
    with open(os.path.join(CACHE, "..", "tank_rows.json"), "w") as f:
        json.dump(rows, f)
    report(rows)


def report(rows):
    mts = [r for r in rows if r["boss_melee"] >= 10]           # warriors who actually held the boss
    print(f"# Warrior tanks in the fastest Classic Era kills\n\n{len(rows)} tank entries, {len(mts)} holding the boss "
          f"(10+ boss melee hits), from {len({(r['code'], r['fight']) for r in rows})} kills.\n")
    print("## Setups\n")
    for k, v in collections.Counter((r["setup"], r["tree"]) for r in mts).most_common(12):
        print(f"- {k[0]} {k[1]}: {v}")
    print("\n## Casts per minute (median over tanks holding the boss; tanks who used it at least once)\n")
    abil = collections.Counter(a for r in mts for a in r["per_min"])
    print("| Ability | Tanks using it | Median per minute |\n|---|---|---|")
    for a, n in abil.most_common(25):
        vals = [r["per_min"][a] for r in mts if a in r["per_min"]]
        print(f"| {a} | {n}/{len(mts)} | {statistics.median(vals):.1f} |")
    print("\n## Estimated threat share (median %, tanks holding the boss)\n")
    share = collections.defaultdict(list)
    for r in mts:
        tot = sum(r["threat"].values()) or 1
        for a, v in r["threat"].items():
            share[a].append(100 * v / tot)
    print("| Source | Median share | Tanks |\n|---|---|---|")
    for a, vals in sorted(share.items(), key=lambda kv: -statistics.median(kv[1]))[:15]:
        print(f"| {a} | {statistics.median(vals):.1f}% | {len(vals)} |")
    tps = [r["tps"] for r in mts]
    if tps:
        print(f"\nEstimated TPS: median {statistics.median(tps):.0f}, range {min(tps):.0f}-{max(tps):.0f}.")
    print("\n## Bloodthirst vs. Revenge\n")
    c = collections.Counter()
    for r in mts:
        c.update(r["choice"])
    tot = sum(c.values())
    for k, v in c.most_common():
        print(f"- {k}: {v} ({100 * v / tot:.0f}%)")
    bt = [r["bt_use"] for r in mts if r["bt_use"]]
    rv = [r["rev_use"] for r in mts if r["rev_use"]]
    if bt:
        print(f"\nBloodthirst cooldown use: median {100 * statistics.median(bt):.0f}% of the fight (casts x 6 s).")
    if rv:
        print(f"Revenge windows used: median {100 * statistics.median(rv):.0f}% (one window per dodge/parry/block, 5 s cooldown).")
    print("\n## Rage model (1.12 formulas; logs don't record rage, so this is rebuilt from damage events and casts)\n")
    med = lambda k: statistics.median([r[k] for r in mts])  # noqa: E731
    print(f"- Income: median {med('rage_income'):.1f} rage/s, of which {med('rage_taken'):.1f} from damage taken.")
    print(f"- Overflow (rage above 100, wasted): median {med('rage_overflow'):.2f} rage/s; "
          f"{sum(1 for r in mts if r['rage_overflow'] > 0.2)}/{len(mts)} tanks waste more than 0.2 rage/s.")
    print(f"- Spending beyond modelled income (pre-pull rage, Unbridled Wrath and other procs): median "
          f"{med('rage_short'):.2f} rage/s.")
    print("\n### Bloodthirst or Revenge, by rage at that moment\n\n| Rage | Bloodthirst | Revenge |\n|---|---|---|")
    cb = collections.Counter()
    for r in mts:
        cb.update(r["choice_by_rage"])
    for band in ("<30", "30-59", "60+"):
        print(f"| {band} | {cb.get(band + '|Bloodthirst', 0)} | {cb.get(band + '|Revenge', 0)} |")
    print("\n### Threat per rage and per use, from these tanks' own hits (median)\n")
    print("| Ability | Threat per use | Rage per use | Threat per rage |\n|---|---|---|---|")
    for a in ("Revenge", "Bloodthirst", "Heroic Strike", "Sunder Armor"):
        v = [r["eff"][a] for r in mts if a in r["eff"]]
        if v:
            th, rg = statistics.median(x["threat"] for x in v), statistics.median(x["rage"] for x in v)
            print(f"| {a} | {th:.0f} | {rg:.1f} | {th / rg:.0f} |")

    print("\n## Openers (first six casts, seconds from pull)\n")
    for k, v in collections.Counter(" > ".join(o.split("@")[0] for o in r["opener"][:4]) for r in mts).most_common(10):
        print(f"- {k}: {v}")
    print("\n## Tanks\n\n| Boss | Kill | Tank | Setup | Talents | TPS | BT use | Rev use | Both ready: BT / Rev / other |\n|---|---|---|---|---|---|---|---|---|")
    for r in sorted(mts, key=lambda r: (r["boss"], r["duration"])):
        ch = r["choice"]
        print(f"| {r['boss']} | {r['duration']:.0f}s [{r['code']}](https://vanilla.warcraftlogs.com/reports/{r['code']}#fight={r['fight']}) "
              f"| {r['name']} | {r['setup']} | {r['tree']} | {r['tps']:.0f} | "
              f"{'-' if r['bt_use'] is None else f'{100 * r['bt_use']:.0f}%'} | {'-' if r['rev_use'] is None else f'{100 * r['rev_use']:.0f}%'} | "
              f"{ch.get('both ready: Bloodthirst', 0)} / {ch.get('both ready: Revenge', 0)} / {ch.get('both ready: other', 0)} |")


if __name__ == "__main__":
    main()
