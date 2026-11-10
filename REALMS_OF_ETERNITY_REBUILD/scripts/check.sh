#!/usr/bin/env bash
# Verification gate: strict type-check against the Roblox API, lint, format, unit tests, place build.
# Usage: scripts/check.sh            full gate
#        scripts/check.sh <paths>    analyze/selene/stylua only for the given paths
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="$HOME/.local/bin:$PATH"
SM="${SOURCEMAP:-/tmp/roe-sourcemap-$$.json}"
OUT="/tmp/roe-analyze-$$.txt"
DEFS="$ROOT/.tools/globalTypes.d.luau"
[ -f "$DEFS" ] || bash scripts/setup-tools.sh >/dev/null
TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(src)
status=0

echo "── rojo sourcemap"
rojo sourcemap default.project.json -o "$SM" || status=1

echo "── luau-lsp analyze (strict)"
luau-lsp analyze --sourcemap "$SM" --definitions="$DEFS" --base-luaurc .luaurc \
	--formatter plain "${TARGETS[@]}" >"$OUT" 2>&1
grep -v '^$' "$OUT" | grep -v 'LintWarning\|Lint' | head -200
if grep -qE 'TypeError|SyntaxError' "$OUT"; then
	echo "analyze: $(grep -cE 'TypeError|SyntaxError' "$OUT") error(s)"
	status=1
fi

echo "── selene"
selene --display-style quiet "${TARGETS[@]}" || status=1

echo "── stylua --check"
if ! stylua --check "${TARGETS[@]}" >/dev/null 2>&1; then
	echo "stylua: formatting differs (run: stylua src tests)"
	status=1
fi

if [ $# -eq 0 ]; then
	echo "── lune unit tests"
	lune run tests/run.luau || status=1
	echo "── rojo build"
	rojo build default.project.json -o build/REALMS_OF_ETERNITY.rbxl || status=1
fi

rm -f "$SM" "$OUT"
if [ $status -eq 0 ]; then echo "CHECK: PASS"; else echo "CHECK: FAIL"; fi
exit $status
