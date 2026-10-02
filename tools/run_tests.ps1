# Corre todos los tests/test_*.gd en headless y resume. Exit code != 0 si alguno falla.
# Uso: powershell -File tools/run_tests.ps1 [-Filter hud] [-Godot <ruta al exe console>]
param(
	[string]$Filter = "",
	[string]$Godot = $(if ($env:QUEST_GODOT) { $env:QUEST_GODOT } else { "E:\Descargas\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" })
)
$root = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $env:TEMP "quest_tests"
New-Item -ItemType Directory -Force $logs | Out-Null

# Reindexa class_name nuevos (sin esto el primer --script puede fallar con "Could not find type").
Start-Process -FilePath $Godot -ArgumentList "--headless --path `"$root`" --editor --quit" -Wait -NoNewWindow `
	-RedirectStandardOutput "$logs\_reindex.out" -RedirectStandardError "$logs\_reindex.err" | Out-Null

$failed = @()
foreach ($t in (Get-ChildItem "$root\tests\test_*.gd" | Where-Object { $_.Name -like "*$Filter*" })) {
	$p = Start-Process -FilePath $Godot -ArgumentList "--headless --path `"$root`" --script res://tests/$($t.Name)" `
		-Wait -NoNewWindow -PassThru -RedirectStandardOutput "$logs\$($t.BaseName).out" -RedirectStandardError "$logs\$($t.BaseName).err"
	$status = if ($p.ExitCode -eq 0) { "OK  " } else { "FAIL"; $failed += $t.BaseName }
	"{0} {1}" -f $status, $t.BaseName
}
"--- {0} fallo(s). Logs en {1}" -f $failed.Count, $logs
exit $failed.Count
