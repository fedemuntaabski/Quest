# Corre todos los tests con tests/run_all.gd (en paralelo; regla OK/OK*/FAIL ahí). Exit code = cantidad de fallos.
# Uso: lightshell -File tools/run_tests.ps1 [-Filter hud] [-Jobs 6] [-Reindex] [-Godot <ruta al exe console>]
#   -Reindex: antes reindexa class_name nuevos (sin esto el primer --script puede fallar con "Could not find type").
param(
	[string]$Filter = "",
	[int]$Jobs = 6,
	[switch]$Reindex,
	[string]$Godot = $(if ($env:QUEST_GODOT) { $env:QUEST_GODOT } else { "E:\Descargas\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" })
)
$root = Split-Path -Parent $PSScriptRoot
if ($Reindex) {
	Start-Process -FilePath $Godot -ArgumentList "--headless --path `"$root`" --editor --quit" -Wait -NoNewWindow `
		-RedirectStandardOutput "$env:TEMP\quest_reindex.out" -RedirectStandardError "$env:TEMP\quest_reindex.err" | Out-Null
}
$p = Start-Process -FilePath $Godot -ArgumentList "--headless --path `"$root`" --script res://tests/run_all.gd -- `"$Filter`" -j $Jobs" -Wait -NoNewWindow -PassThru
exit $p.ExitCode
