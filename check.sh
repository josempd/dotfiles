#!/usr/bin/env bash
# MVI checks (rules in agents/skills/arch-desktop/SKILL.md): prints each violation, exits 1 if any
set -uo pipefail
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" || exit 1

fail=0
bad() { printf '\033[1;31mFAIL\033[0m %s\n' "$*"; fail=1; }
# Every line a command prints is one violation
report() { local msg=$1 l; shift; while IFS= read -r l; do bad "$msg: $l"; done < <("$@"); }

eval "$(sed -n '/^FILES=(/,/^)/p' jmpd.sh)"
srcs=() dests=()
for e in "${FILES[@]}"; do srcs+=("${e%% *}"); dests+=("${e#* }"); done
mapfile -t tracked < <(git ls-files)
# Text files of our own: no vendored code, binaries, generated p10k or licenses
mapfile -t own < <(printf '%s\n' "${tracked[@]}" | grep -vE '^vendor/|\.(png|bin)$|^p10k\.zsh$|LICENSE')
mapfile -t shells < <(grep -lE '^#!/(usr/)?bin/(env )?(ba)?sh' "${own[@]}")
mapfile -t pythons < <(grep -lE '^#!.*python3' "${own[@]}")

# 1. Every tracked file is installed by jmpd.sh, and every manifest source exists
for f in "${tracked[@]}"; do
    [[ $f =~ ^(README\.md|\.gitignore|jmpd\.sh|check\.sh|agents/) ]] && continue
    grep -qF "$f" jmpd.sh && continue
    covered=0
    for s in "${srcs[@]}"; do [[ $f == "$s" || $f == "$s"/* ]] && covered=1 && break; done
    ((covered)) || bad "not installed by jmpd.sh: $f"
done
for s in "${srcs[@]}"; do [[ -n $(git ls-files "$s") ]] || bad "manifest source not tracked: $s"; done

# 2. Every script and unit is used: its name appears in another tracked file
for f in $(git ls-files bin systemd); do
    name=$(basename "$f")
    git grep -qwF "$name" -- ":!$f" ':!README.md' || bad "unreferenced: $f"
done

# 3. No guards for what jmpd.sh installs (the curl installers are the exception)
guards() { git grep -nE '\bhave |command -v' -- "${own[@]}" ':!*.md' ':!check.sh' | grep -vE 'curl -fsSL|^[^:]+:[0-9]+: *(#|--)'; }
report guard guards

# 4. One place per concern
report "PATH set outside uwsm-env/zshrc" git grep -nE '(^|[^_])PATH=' -- "${own[@]}" ':!uwsm-env' ':!zshrc' ':!check.sh'
report ".local/bin/ literal" git grep -nF '.local/bin/' -- "${own[@]}" ':!systemd/' ':!*.md' ':!jmpd.sh' ':!check.sh'
report "color outside themes/templates" git grep -nE '#[0-9a-fA-F]{6}\b' -- "${own[@]}" \
    ':!themes/templates/' ':!tmux.conf' ':!sddm/' ':!nvim/' ':!*.md' ':!check.sh' 

# 5. No unit shadowing a packaged one
for f in $(git ls-files systemd); do
    [[ -e /usr/lib/systemd/user/$(basename "$f") ]] && bad "shadows a packaged unit: $f"
done

# 6. Comments: one line at most, no commented-out code
for f in "${own[@]}"; do
    [[ $f == *.md || $f == *.json || $f == *.css || $f == *-flags.conf ]] && continue
    mark='#'; [[ $f == *.lua ]] && mark='--'
    report "multi-line comment" awk -v f="$f" -v m="$mark" '{ c = index($0, m) && $0 ~ "^[[:space:]]*" m && $0 !~ /^#!/ }
        c && prev { print f ":" NR }
        { prev = c }' "$f"
done
report "commented-out code" git grep -nE '^[[:space:]]*(#|--) ?(hl\.|require |map |bind |export |local |exec )' -- "${own[@]}" ':!*-flags.conf'

# 7. Static checks
for f in "${shells[@]}"; do bash -n "$f" || bad "syntax: $f"; done
shellcheck -S warning "${shells[@]}" || bad "shellcheck"
for f in "${pythons[@]}"; do /usr/bin/python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$f" || bad "syntax: $f"; done
for f in hypr/hyprland.lua sddm/hyprland.lua; do
    Hyprland --verify-config -c "$f" 2>&1 | grep -q '^config ok' || bad "Hyprland --verify-config: $f"
done
/usr/bin/python3 -c 'import json, re, sys; json.loads(re.sub(r"^\s*//.*$", "", open(sys.argv[1]).read(), flags=re.M))' \
    waybar/config.jsonc || bad "waybar/config.jsonc is not valid JSONC"
# shellcheck disable=SC2046
verify_units() { systemd-analyze --user verify $(git ls-files 'systemd/*.service') 2>&1; }
report "systemd-analyze verify" verify_units

# 8. Drift: live copies match the repo, and no jmpd-owned leftovers live without a repo file
for i in "${!srcs[@]}"; do
    for f in $(git ls-files "${srcs[$i]}"); do
        to="${dests[$i]}${f#"${srcs[$i]}"}"
        cmp -s "$f" "$to" 2>/dev/null || bad "drift: $to"
    done
done
for f in "$HOME"/.local/bin/jmpd-* "$HOME"/.config/systemd/user/*.service "$HOME"/.config/systemd/user/*.timer; do
    [[ -e $f && ! -e bin/$(basename "$f") && ! -e systemd/$(basename "$f") ]] || continue
    # llama-server.service is Claudia's brain, deliberately machine-local
    [[ $(basename "$f") == llama-server.service ]] || bad "live file without a repo source: $f"
done

# 9. vendor/ stays as imported: its checksum matches the one recorded in UPSTREAM
sum=$(git ls-files -s vendor | grep -v UPSTREAM | sha256sum | cut -c1-16)
grep -q "$sum" vendor/omarchy-agents/UPSTREAM || bad "vendor/ changed: update it only by copying upstream, then record $sum in UPSTREAM"

((fail)) || printf '\033[1;32mok\033[0m\n'
exit "$fail"
