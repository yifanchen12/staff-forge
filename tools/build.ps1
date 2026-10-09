param([switch]$Verify)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location $taskRoot
$taskOriginalAppData = $env:APPDATA
try {
    New-Item -ItemType Directory -Force -Path 'artifacts/profile','build/windows','tools/godot','tools/templates' | Out-Null
    foreach ($taskIgnoredFolder in 'artifacts','build','tools') {
        Set-Content -LiteralPath (Join-Path $taskIgnoredFolder '.gdignore') -Value '' -NoNewline
    }
    $env:APPDATA = Join-Path $taskRoot 'artifacts/profile'
    $taskEngine = Join-Path $taskRoot 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
    if (-not (Test-Path -LiteralPath $taskEngine)) {
        Invoke-WebRequest -Uri 'https://downloads.godotengine.org/?flavor=stable&platform=windows.64&slug=win64.exe.zip&version=4.7.2' -OutFile 'tools/godot-win64.zip' -TimeoutSec 180
        Expand-Archive -LiteralPath 'tools/godot-win64.zip' -DestinationPath 'tools/godot' -Force
    }
    Set-Content -LiteralPath 'tools/godot/_sc_' -Value '' -NoNewline
    $taskTemplate = Join-Path $taskRoot 'tools/templates/templates/windows_release_x86_64.exe'
    if (-not (Test-Path -LiteralPath $taskTemplate)) {
        Write-Host 'Downloading the official multi-platform template archive (approximately 1.2 GB).'
        Invoke-WebRequest -Uri 'https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=4.7.2' -OutFile 'tools/export_templates.tpz' -TimeoutSec 600
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $taskArchive = [IO.Compression.ZipFile]::OpenRead((Join-Path $taskRoot 'tools/export_templates.tpz'))
        try {
            foreach ($taskEntry in $taskArchive.Entries) {
                if ($taskEntry.FullName -match '^templates/(windows_(debug|release)_x86_64(_console)?\.exe|version\.txt)$') {
                    $taskDestination = Join-Path $taskRoot ('tools/templates/' + $taskEntry.FullName)
                    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $taskDestination) | Out-Null
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($taskEntry, $taskDestination, $true)
                }
            }
        } finally { $taskArchive.Dispose() }
    }
    & $taskEngine --headless --editor --import --path . --log-file (Join-Path $taskRoot 'artifacts/import.log')
    if ($LASTEXITCODE -ne 0) { throw 'Project import failed.' }
    & $taskEngine --headless --path . --script tests/test_rules.gd --quit-after 2 --log-file (Join-Path $taskRoot 'artifacts/rules.log')
    if ($LASTEXITCODE -ne 0) { throw 'Rules checks failed.' }
    & $taskEngine --headless --path . --script tests/test_visuals.gd --quit-after 60 --log-file (Join-Path $taskRoot 'artifacts/visuals.log')
    if ($LASTEXITCODE -ne 0) { throw 'Visual evolution checks failed.' }
    & $taskEngine --headless --path . --script tests/test_chronicle.gd --quit-after 60 --log-file (Join-Path $taskRoot 'artifacts/chronicle.log')
    if ($LASTEXITCODE -ne 0) { throw 'Chronicle checks failed.' }
    & $taskEngine --headless --path . --script tests/test_balance.gd --quit-after 2
    if ($LASTEXITCODE -ne 0) { throw 'Balance check failed.' }
    & $taskEngine --headless --path . --script tests/export_licenses.gd --quit-after 2
    if ($LASTEXITCODE -ne 0) { throw 'License export failed.' }
    & $taskEngine --headless --path . --export-release 'Windows Desktop' 'build/windows/StaffForge.exe' --log-file (Join-Path $taskRoot 'artifacts/export.log')
    if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
    Copy-Item -LiteralPath 'docs/操作说明.md','docs/素材来源.md','docs/GODOT_LICENSES.txt' -Destination 'build/windows' -Force
    if (Test-Path -LiteralPath 'docs/测试记录.md') {
        Copy-Item -LiteralPath 'docs/测试记录.md' -Destination 'build/windows' -Force
    }
    Copy-Item -LiteralPath 'docs/发行说明.md' -Destination 'build/windows/README.md' -Force
    New-Item -ItemType Directory -Force -Path 'build/windows/licenses' | Out-Null
    Copy-Item -Path 'assets/licenses/*.txt' -Destination 'build/windows/licenses' -Force
    Copy-Item -LiteralPath 'assets/fonts/OFL.txt' -Destination 'build/windows/licenses/OFL.txt' -Force
    if ($Verify) {
        $taskExecutable = Join-Path $taskRoot 'build/windows/StaffForge.console.exe'
        & $taskExecutable --resolution 1920x1080 --position -2200,-1200 --audio-driver Dummy --quit-after 5000 --log-file (Join-Path $taskRoot 'artifacts/standalone.log') -- --smoke-test
        if ($LASTEXITCODE -ne 0) { throw 'Standalone verification failed.' }
        $taskReport = Get-Content -LiteralPath 'build/windows/verification/smoke-test.json' -Raw | ConvertFrom-Json
        if ($taskReport.failures.Count -ne 0) { throw 'Standalone checks reported failures.' }
        Copy-Item -LiteralPath 'artifacts/rules-test.json','artifacts/visuals-test.json','artifacts/chronicle-test.json','artifacts/balance-test.json' -Destination 'build/windows/verification' -Force
        Copy-Item -LiteralPath 'artifacts/standalone.log','artifacts/rules.log','artifacts/visuals.log','artifacts/chronicle.log','artifacts/export.log' -Destination 'build/windows/verification' -Force
    }
    Write-Host 'Built: build/windows/StaffForge.exe'
} finally {
    $env:APPDATA = $taskOriginalAppData
    Pop-Location
}
