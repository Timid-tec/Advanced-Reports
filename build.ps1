[CmdletBinding()]
param(
    [string]$CompilerRoot = "",
    [switch]$Package
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sourceModVersion = "1.12.0-git7041"
$pluginVersion = "4.5.0"
$sourceModUrl = "https://sm.alliedmods.net/smdrop/1.12/sourcemod-$sourceModVersion-windows.zip"
$steamWorksVersion = "1.2.3c"
$steamWorksIncludeCommit = "f0c1b62dff615511b27824aaa2815c7dc58d2716"
$steamWorksIncludeUrl = "https://raw.githubusercontent.com/KyleSanderson/SteamWorks/$steamWorksIncludeCommit/Pawn/includes/SteamWorks.inc"
$steamWorksPackageUrl = "https://github.com/KyleSanderson/SteamWorks/releases/download/$steamWorksVersion/package-lin.tgz"
$steamWorksPackageSha256 = "6679E6DFD19D4C78A71D224FF3F7D72D9BECBC256082ED4BCE85CBAA1E012713"

$projectRoot = $PSScriptRoot
$buildRoot = Join-Path $projectRoot ".build"
$dependencyInclude = Join-Path $buildRoot "include\steamworks-$steamWorksIncludeCommit"
$sourceFile = Join-Path $projectRoot "addons\sourcemod\scripting\advanced_reports.sp"
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

Write-Host "Compiling advanced_reports.sp with SourceMod $sourceModVersion..."
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

if ($Package) {
    $steamWorksRoot = Join-Path $buildRoot "steamworks-$steamWorksVersion"
    $steamWorksArchive = Join-Path $steamWorksRoot "package-lin.tgz"
    $steamWorksExtracted = Join-Path $steamWorksRoot "package"
    $extensionOutput = Join-Path $projectRoot "addons\sourcemod\extensions\SteamWorks.ext.so"

    New-Item -ItemType Directory -Force -Path $steamWorksRoot | Out-Null

    if (-not (Test-Path -LiteralPath $steamWorksArchive)) {
        Write-Host "Downloading SteamWorks $steamWorksVersion for Linux..."
        Invoke-WebRequest -Uri $steamWorksPackageUrl -OutFile $steamWorksArchive
    }

    $actualPackageHash = (Get-FileHash -LiteralPath $steamWorksArchive -Algorithm SHA256).Hash
    if ($actualPackageHash -ne $steamWorksPackageSha256) {
        throw "SteamWorks package checksum mismatch. Expected $steamWorksPackageSha256, received $actualPackageHash."
    }

    if (-not (Test-Path -LiteralPath (Join-Path $steamWorksExtracted "addons\sourcemod\extensions\SteamWorks.ext.so"))) {
        tar -xzf $steamWorksArchive -C $steamWorksRoot
        if ($LASTEXITCODE -ne 0) {
            throw "Could not extract the SteamWorks Linux package."
        }
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $extensionOutput) | Out-Null
    Copy-Item -LiteralPath (Join-Path $steamWorksExtracted "addons\sourcemod\extensions\SteamWorks.ext.so") -Destination $extensionOutput -Force

    $packageName = "AdvancedReports-$pluginVersion-sm1.12-linux"
    $packageRoot = Join-Path $buildRoot "package\$packageName"
    $packageAddons = Join-Path $packageRoot "addons\sourcemod"
    $packageConfig = Join-Path $packageRoot "cfg\sourcemod"
    $distributionRoot = Join-Path $projectRoot "dist"
    $distributionArchive = Join-Path $distributionRoot "$packageName.zip"

    if (Test-Path -LiteralPath $packageRoot) {
        Remove-Item -LiteralPath $packageRoot -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path `
        (Join-Path $packageAddons "plugins"), `
        (Join-Path $packageAddons "extensions"), `
        (Join-Path $packageAddons "scripting"), `
        (Join-Path $packageAddons "configs\advreport"), `
        $packageConfig, `
        $distributionRoot | Out-Null

    Copy-Item -LiteralPath $outputFile -Destination (Join-Path $packageAddons "plugins\AdvancedReports.smx") -Force
    Copy-Item -LiteralPath $extensionOutput -Destination (Join-Path $packageAddons "extensions\SteamWorks.ext.so") -Force
    Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $packageAddons "scripting\advanced_reports.sp") -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot "addons\sourcemod\configs\advreport\advreasons.cfg") -Destination (Join-Path $packageAddons "configs\advreport\advreasons.cfg") -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot "cfg\sourcemod\AdvancedReports.cfg") -Destination (Join-Path $packageConfig "AdvancedReports.cfg") -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot "packaging\README_INSTALL.txt") -Destination (Join-Path $packageRoot "README_INSTALL.txt") -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot "CHANGELOG.md") -Destination (Join-Path $packageRoot "CHANGELOG.md") -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot "THIRD_PARTY_NOTICES.md") -Destination (Join-Path $packageRoot "THIRD_PARTY_NOTICES.md") -Force

    if (Test-Path -LiteralPath $distributionArchive) {
        Remove-Item -LiteralPath $distributionArchive -Force
    }

    Compress-Archive -Path (Join-Path $packageRoot "*") -DestinationPath $distributionArchive -CompressionLevel Optimal
    Write-Host "Drag-and-drop Linux package created: $distributionArchive"
}
