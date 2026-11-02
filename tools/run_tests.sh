#!/usr/bin/env bash
# Corre todos los tests con tests/run_all.gd (regla OK/OK*/FAIL ahí). Uso: tools/run_tests.sh [filtro]
G="${QUEST_GODOT:-E:\Descargas\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.."
# Reindexa class_name nuevos (sin esto el primer --script puede fallar con "Could not find type").
"$G" --headless --path . --editor --quit >/dev/null 2>&1
"$G" --headless --path . --script res://tests/run_all.gd -- "$1"
