#!/usr/bin/env bash
# Corre todos los tests con tests/run_all.gd (en paralelo; regla OK/OK*/FAIL ahí).
# Uso: tools/run_tests.sh [--reindex] [filtro] [-j N]
#   --reindex: antes reindexa class_name nuevos (sin esto el primer --script puede fallar con "Could not find type").
G="${QUEST_GODOT:-E:\Descargas\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."
if [ "${1:-}" = "--reindex" ]; then
	shift
	"$G" --headless --path . --editor --quit >/dev/null 2>&1
fi
"$G" --headless --path . --script res://tests/run_all.gd -- "$@"
