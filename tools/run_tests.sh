#!/usr/bin/env bash
# Equivalente bash de run_tests.ps1. Uso: tools/run_tests.sh [filtro]
G="${QUEST_GODOT:-E:\Descargas\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."
"$G" --headless --path . --editor --quit >/dev/null 2>&1
fail=0
for t in tests/test_*${1}*.gd; do
	if "$G" --headless --path . --script "res://$t" >"/tmp/$(basename "$t").log" 2>&1; then echo "OK   $t"; else echo "FAIL $t"; fail=$((fail+1)); fi
done
echo "--- $fail fallo(s)"
exit $fail
