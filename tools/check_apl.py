"""Static check that a SimC-style APL only references keys defined in a Hekili class module.

Usage: python3 tools/check_apl.py <Class.lua> <file.simc> [<file.simc> ...]

Checks actions, buff./debuff./cooldown./talent./settings./action. references and
call/run_action_list targets.  Engine-provided names are allowed via ENGINE_* below.
"""
import re
import sys

ENGINE_ACTIONS = {"call_action_list", "run_action_list", "variable", "use_items", "use_item", "potion", "wait", "pool_resource", "cancel_buff"}
ENGINE_AURAS = {"casting", "training_dummy", "stance"}  # stance is an alias defined in the module, kept for clarity


def table_keys(src, register):
    """Keys of the table passed to spec:<register>( { ... } ), at 4-space indent."""
    m = re.search(r"spec:%s\(\s*\{(.*?)\n\}\s*\)" % register, src, re.S)
    if not m:
        return set()
    return set(re.findall(r"^    ([a-z_0-9]+)\s*=", m.group(1), re.M))


def main():
    lua_path, simc_paths = sys.argv[1], sys.argv[2:]
    src = open(lua_path, encoding="utf-8").read()

    abilities = table_keys(src, "RegisterAbilities")
    auras = table_keys(src, "RegisterAuras")
    talents = table_keys(src, "RegisterTalents")
    settings = set(re.findall(r'spec:RegisterSetting\(\s*"([a-z_0-9]+)"', src))
    exprs = set(re.findall(r'spec:RegisterStateExpr\(\s*"([a-z_0-9]+)"', src))

    errors = 0
    for path in simc_paths:
        lists_defined, lists_used = set(), set()
        for n, line in enumerate(open(path, encoding="utf-8"), 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            m = re.match(r"actions\.?([a-z_0-9]*)\+?=/?(.+)$", line)
            if not m:
                print(f"{path}:{n}: unparseable line")
                errors += 1
                continue
            lists_defined.add(m.group(1) or "default")
            body = m.group(2)
            action = body.split(",")[0]
            if action not in abilities and action not in ENGINE_ACTIONS:
                print(f"{path}:{n}: unknown action '{action}'")
                errors += 1
            if action in ("call_action_list", "run_action_list"):
                lists_used.add(re.search(r"name=([a-z_0-9]+)", body).group(1))

            checks = [
                (r"\b(?:buff|debuff|dot)\.([a-z_0-9]+)", auras | ENGINE_AURAS, "aura"),
                (r"\bcooldown\.([a-z_0-9]+)", abilities, "cooldown"),
                (r"\baction\.([a-z_0-9]+)", abilities, "action"),
                (r"\btalent\.([a-z_0-9]+)", talents, "talent"),
                (r"\bsettings\.([a-z_0-9]+)", settings, "setting"),
            ]
            for pattern, known, kind in checks:
                for key in re.findall(pattern, body):
                    if key not in known:
                        print(f"{path}:{n}: unknown {kind} '{key}'")
                        errors += 1

            # Bare identifiers that look like custom state expressions.
            for key in re.findall(r"\b(stance_rage_retained)\b", body):
                if key not in exprs:
                    print(f"{path}:{n}: unknown state expression '{key}'")
                    errors += 1

        for name in lists_used - lists_defined:
            print(f"{path}: action list '{name}' is used but never defined")
            errors += 1

    print(f"{len(abilities)} abilities, {len(auras)} auras, {len(talents)} talents, {len(settings)} settings; {errors} problem(s)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
