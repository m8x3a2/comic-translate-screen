# Packs the Windows release build into one zip that runs on another computer
# without installing anything: comic_translate.exe, cts.exe, their libraries,
# the Visual C++ runtime (app-local copy, allowed by its licence), the
# licences and the GPU check guide. Models are not included (copy them or
# download them in the program).
#
#   cd apps/comic_translate; flutter build windows --release
#   powershell -ExecutionPolicy Bypass -File tools/package_windows.ps1 [-Out dist]
param(
    [string]$Out = "dist"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$release = Join-Path $repo "apps\comic_translate\build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $release "comic_translate.exe"))) {
    throw "No release build in $release. Run: cd apps/comic_translate; flutter build windows --release"
}

$pubspec = Get-Content (Join-Path $repo "apps\comic_translate\pubspec.yaml")
$version = (($pubspec | Where-Object { $_ -match '^version:' }) -replace '^version:\s*', '' -replace '\+.*$', '').Trim()
$name = "ComicTranslateScreen-$version-windows-x64"

$outDir = if ([IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path $repo $Out }
$stage = Join-Path $outDir $name
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null

Copy-Item -Recurse (Join-Path $release "*") $stage

# Visual C++ runtime next to the programs, from the installed build tools.
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
$crt = $null
if (Test-Path $vswhere) {
    $vs = & $vswhere -latest -products * -property installationPath
    if ($vs) {
        $crt = Get-ChildItem -Directory (Join-Path $vs "VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT") -ErrorAction SilentlyContinue |
            Sort-Object FullName | Select-Object -Last 1
    }
}
if ($crt) {
    foreach ($dll in "msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "vcruntime140.dll", "vcruntime140_1.dll") {
        $src = Join-Path $crt.FullName $dll
        if (Test-Path $src) { Copy-Item $src $stage }
    }
} else {
    Write-Warning "Visual C++ runtime not found; the other computer needs the Visual C++ Redistributable."
}

foreach ($doc in "LICENSE", "NOTICE", "README.md", "README.ru.md", "docs\GPU_CHECK.ru.md") {
    $src = Join-Path $repo $doc
    if (Test-Path $src) { Copy-Item $src $stage }
}

# Three test pages (Pepper&Carrot, CC BY 4.0) so that timings of different
# computers can be compared.
$samples = New-Item -ItemType Directory -Force (Join-Path $stage "samples")
foreach ($page in "en_E01P01.jpg", "en_E06P05.jpg", "ja_E01P02.jpg") {
    Copy-Item (Join-Path $repo "test_data\pages\peppercarrot\$page") $samples
}
Set-Content -Encoding utf8 (Join-Path $samples "LICENSE.txt") @(
    "Pepper&Carrot by David Revoy - https://www.peppercarrot.com",
    "Creative Commons Attribution 4.0 International (CC BY 4.0) - https://creativecommons.org/licenses/by/4.0/",
    "Pages of episodes 1 and 6, not modified."
)

$zip = Join-Path $outDir "$name.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $stage -DestinationPath $zip -CompressionLevel Optimal
Remove-Item -Recurse -Force $stage
$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Output "$zip ($size MB)"
