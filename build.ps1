[CmdletBinding()]
param(
    [string]$CompilerRoot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sourceModVersion = "1.12.0-git7041"
$sourceModUrl = "https://sm.alliedmods.net/smdrop/1.12/sourcemod-$sourceModVersion-windows.zip"
$steamWorksIncludeUrl = "https://raw.githubusercontent.com/KyleSanderson/SteamWorks/f0c1b62dff615511b27824aaa2815c7dc58d2716/Pawn/includes/SteamWorks.inc"

$projectRoot = $PSScriptRoot
$buildRoot = Join-Path $projectRoot ".build"
$dependencyInclude = Join-Path $buildRoot "include"
$sourceFile = Join-Path $projectRoot "addons\sourcemod\scripting\AdvancedReports.sp"
$projectInclude = Join-Path $projectRoot "addons\sourcemod\scripting\include"
$outputFile = Join-Path $projectRoot "addons\sourcemod\plugins\AdvancedReports.smx"

New-Item -ItemType Directory -Force -Path $buildRoot, $dependencyInclude | Out-Null

if ([string]::IsNullOrWhiteSpace($CompilerRoot)) {
    $sourceModArchive = Join-Path $buildRoot "sourcemod-$sourceModVersion-windows.zip"
    $CompilerRoot = Join-Path $buildRoot $sourceModVersion

    if (-not (Test-Path -LiteralPath $sourceModArchive)) {
        Write-Host "Downloading SourceMod $sourceModVersion..."
        Invoke-WebRequest -Uri $sourceModUrl -OutFile $sourceModArchive
    }

    if (-not (Test-Path -LiteralPath (Join-Path $CompilerRoot "addons\sourcemod\scripting\spcomp64.exe"))) {
        New-Item -ItemType Directory -Force -Path $CompilerRoot | Out-Null
        Expand-Archive -LiteralPath $sourceModArchive -DestinationPath $CompilerRoot -Force
    }
}

$compiler = Join-Path $CompilerRoot "addons\sourcemod\scripting\spcomp64.exe"
$sourceModInclude = Join-Path $CompilerRoot "addons\sourcemod\scripting\include"
$steamWorksInclude = Join-Path $dependencyInclude "SteamWorks.inc"

if (-not (Test-Path -LiteralPath $compiler)) {
    throw "SourcePawn compiler not found at '$compiler'."
}

if (-not (Test-Path -LiteralPath $steamWorksInclude)) {
    Write-Host "Downloading the pinned SteamWorks include..."
    Invoke-WebRequest -Uri $steamWorksIncludeUrl -OutFile $steamWorksInclude
}

$compilerArguments = @(
    $sourceFile,
    "-i", $projectInclude,
    "-i", $dependencyInclude,
    "-i", $sourceModInclude,
    "-o", $outputFile
)

Write-Host "Compiling AdvancedReports.sp with SourceMod $sourceModVersion..."
$compilerOutput = & $compiler @compilerArguments 2>&1
$compilerExitCode = $LASTEXITCODE
$compilerOutput | ForEach-Object { Write-Host $_ }

if ($compilerExitCode -ne 0) {
    throw "SourcePawn compilation failed with exit code $compilerExitCode."
}

if (($compilerOutput | Out-String) -match "(?im)\bwarning\s+\d+:") {
    throw "SourcePawn compilation produced one or more warnings."
}

if (-not (Test-Path -LiteralPath $outputFile)) {
    throw "The compiler completed without creating '$outputFile'."
}

Write-Host "Build succeeded with 0 errors and 0 warnings: $outputFile"
