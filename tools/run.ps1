param(
    [ValidateSet('Editor', 'Play', 'Check')]
    [string]$Mode = 'Editor',
    [string]$GodotDirectory = 'D:\Godot_v4.7.2'
)

$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$engineExecutable = Join-Path $GodotDirectory 'Godot_v4.7.2-stable_win64.exe'
$consoleExecutable = Join-Path $GodotDirectory 'Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $engineExecutable)) {
    throw "Godot was not found at $engineExecutable. Pass -GodotDirectory with the engine directory."
}

if ($Mode -eq 'Editor') {
    & $engineExecutable --editor --path $projectDirectory
} elseif ($Mode -eq 'Play') {
    & $engineExecutable --path $projectDirectory
} else {
    if (-not (Test-Path -LiteralPath $consoleExecutable)) {
        throw "Godot console executable was not found at $consoleExecutable."
    }
    $logDirectory = Join-Path $projectDirectory 'logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $importLog = Join-Path $logDirectory 'import.log'
    & $consoleExecutable --headless --path $projectDirectory --editor --import --log-file $importLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {
        throw "Godot import failed. See $importLog."
    }
    foreach ($testName in @('smoke_test', 'save_test', 'migration_test')) {
        $testLog = Join-Path $logDirectory ($testName + '.log')
        & $consoleExecutable --headless --path $projectDirectory --script ('res://tests/' + $testName + '.gd') --log-file $testLog
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $testLog -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet)) {
            throw "Godot check failed. See $testLog."
        }
    }
}
