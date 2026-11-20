#!/usr/bin/env bash
# Render the dotfiles into a throwaway home and validate what lands there.
# Runs the same way locally and in CI (.github/workflows/check.yml).
#
#   scripts/check.sh            run every check whose tool is installed
#   STRICT=1 scripts/check.sh   a missing tool is a failure (CI)
set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo" || exit 1  # so mise resolves the repo tools (shellcheck)
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
dest="$work/home"
mkdir -p "$dest"
failed=0

ok() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
ko() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; failed=1; }
skip() {
    if [ "${STRICT:-0}" = 1 ]; then ko "$1 (missing tool: $2)"; else printf '  skip %s (no %s)\n' "$1" "$2"; fi
}
have() { command -v "$1" >/dev/null; }

echo "== render"
# No user config, a private state file, no scripts (they install things) and
# no externals (network): only the files themselves.
if chezmoi apply --source "$repo" --destination "$dest" \
    --config "$work/chezmoi.toml" --persistent-state "$work/state.boltdb" \
    --exclude scripts,externals --no-tty --force >"$work/render.log" 2>&1; then
    ok "chezmoi renders every file"
else
    ko "chezmoi render"; cat "$work/render.log"
    exit 1
fi

echo "== niri"
if have niri; then
    if niri validate -c "$dest/.config/niri/config.kdl" >"$work/niri.log" 2>&1; then
        ok "config.kdl (with batlehub.kdl and the dms/ fragments)"
    else
        ko "niri validate"; cat "$work/niri.log"
    fi
else
    skip "niri validate" niri
fi

echo "== shell scripts"
if have shellcheck; then
    scripts=("$dest/.local/bin/monitor-ddc" "$repo"/default/*.sh)
    # run_ scripts are templates: render them to check the real script.
    while IFS= read -r t; do
        out="$work/$(basename "$t" .tmpl)"
        chezmoi execute-template --source "$repo" --config "$work/chezmoi.toml" <"$t" >"$out" && scripts+=("$out")
    done < <(find "$repo/home" -name 'run_*.sh.tmpl')
    for s in "${scripts[@]}"; do
        # SC1091: system files sourced by the snippets do not exist in CI.
        if shellcheck -e SC1091 "$s"; then ok "$(basename "$s")"; else ko "shellcheck $(basename "$s")"; fi
    done
else
    skip "shellcheck" shellcheck
fi

echo "== bashrc"
# Every file the rendered .bashrc sources by absolute path must exist: it once
# pointed at an old clone, and a new shell silently lost aliases, mise, starship.
# A ~/ path is looked up in the rendered home, where only managed files exist.
while IFS= read -r f; do
    path="${f/#\~/$dest}"
    if [ -f "$path" ]; then ok "sources $f"; else ko ".bashrc sources a missing file: $f"; fi
done < <(sed -nE 's/^\s*(source|\.) "?(~?\/[^" ]+)"?.*/\2/p' "$dest/.bashrc")

echo "== secrets"
if have gitleaks; then
    # Whole history: a token removed in a later commit is still published.
    if gitleaks git "$repo" --no-banner --redact -l warn >"$work/gitleaks.log" 2>&1; then
        ok "gitleaks: no secret in the history"
    else
        ko "gitleaks found something"; cat "$work/gitleaks.log"
    fi
else
    skip "gitleaks" gitleaks
fi

echo "== json"
# VS Code reads JSONC (comments, trailing commas) everywhere under its config
# dirs; every other JSON file must be strict.
jsonc_ok() {
    python3 - "$1" <<'EOF'
import json, re, sys
t = open(sys.argv[1], encoding="utf-8").read()
out, i, n = [], 0, len(t)
while i < n:
    if t[i] == '"':
        j = i + 1
        while j < n and t[j] != '"':
            j += 2 if t[j] == "\\" else 1
        out.append(t[i:j + 1]); i = j + 1
    elif t.startswith("//", i):
        i = t.find("\n", i); i = n if i == -1 else i
    elif t.startswith("/*", i):
        i = t.find("*/", i + 2); i = n if i == -1 else i + 2
    else:
        out.append(t[i]); i += 1
json.loads(re.sub(r",(\s*[}\]])", r"\1", "".join(out)))
EOF
}
if have jq; then
    while IFS= read -r f; do
        case "$f" in
        */.config/Code/* | */.vscode/*) jsonc_ok "$f" 2>/dev/null && r=0 || r=1 ;;
        *) jq empty "$f" 2>/dev/null && r=0 || r=1 ;;
        esac
        if [ "$r" = 0 ]; then ok "${f#"$dest"/}"; else ko "invalid JSON: ${f#"$dest"/}"; fi
    done < <(find "$dest" -name '*.json')
else
    skip "json" jq
fi

echo "== fontconfig"
if have xmllint; then
    while IFS= read -r f; do
        if xmllint --noout "$f"; then ok "${f#"$dest"/}"; else ko "invalid XML: ${f#"$dest"/}"; fi
    done < <(find "$dest/.config/fontconfig" -name '*.conf')
else
    skip "fontconfig" xmllint
fi

echo "== modify_ scripts keep what they do not own"
# Feed each one a file holding a foreign key; it must survive the merge.
for spec in "dms/modify_settings.json" "dms/modify_plugin_settings.json" "Code/User/modify_settings.json.tmpl"; do
    src="$repo/home/dot_config/$spec"
    script="$work/$(echo "$spec" | tr / _).py"
    chezmoi execute-template --source "$repo" --config "$work/chezmoi.toml" <"$src" >"$script"
    if echo '{"keep.me": 42}' | python3 "$script" | jq -e '."keep.me" == 42' >/dev/null; then
        ok "$spec"
    else
        ko "$spec drops keys it does not pin"
    fi
done

echo "== ghostty"
if have ghostty; then
    if XDG_CONFIG_HOME="$dest/.config" ghostty +validate-config >"$work/ghostty.log" 2>&1; then
        ok "ghostty config and theme"
    else
        ko "ghostty"; cat "$work/ghostty.log"
    fi
else
    # Not in the Fedora repos and needs a display: never required, even in CI.
    printf '  skip ghostty (not installed)\n'
fi

echo
if [ "$failed" = 0 ]; then echo "all checks passed"; else echo "some checks FAILED"; fi
exit "$failed"
