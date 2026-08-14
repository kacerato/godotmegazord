# Build Script for Godot Engine Android / Mobile
[CmdletBinding()]
param (
    [ValidateSet("editor", "template_release", "template_debug", "all")]
    [string]$Target = "editor",

    [ValidateSet("arm64", "arm32", "x86_64", "all")]
    [string]$Arch = "arm64",

    [int]$Jobs = [System.Environment]::ProcessorCount,

    [switch]$SkipScons,
    [switch]$SkipApk,
    [switch]$Production
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Godot Engine Mobile (Android) Build Script" -ForegroundColor Cyan
Write-Host " Target: $Target | Arch: $Arch | Jobs: $Jobs" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Environment Setup
$env:ANDROID_HOME = "C:\Users\jamaa\AppData\Local\Android\Sdk"
$env:ANDROID_NDK_ROOT = "C:\Users\jamaa\AppData\Local\Android\Sdk\ndk\27.1.12297006"
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot"

$pythonDirs = @(
    "C:\Users\jamaa\AppData\Local\Python\pythoncore-3.14-64\Scripts",
    "C:\Users\jamaa\AppData\Local\Python\pythoncore-3.14-64",
    "C:\Users\jamaa\AppData\Local\Python\bin",
    "$env:JAVA_HOME\bin"
)

foreach ($dir in $pythonDirs) {
    if ((Test-Path $dir) -and ($env:PATH -notlike "*$dir*")) {
        $env:PATH = "$dir;$env:PATH"
    }
}

$PYTHON_EXE = "C:\Users\jamaa\AppData\Local\Python\bin\python.exe"
if (-not (Test-Path $PYTHON_EXE)) {
    $PYTHON_EXE = "python.exe"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Determine Targets and Arches to build
$targetsToBuild = @()
if ($Target -eq "all") {
    $targetsToBuild = @("editor", "template_release", "template_debug")
} else {
    $targetsToBuild = @($Target)
}

$archesToBuild = @()
if ($Arch -eq "all") {
    $archesToBuild = @("arm64", "arm32")
} else {
    $archesToBuild = @($Arch)
}

# 2. SCons C++ Compilation
if (-not $SkipScons) {
    foreach ($t in $targetsToBuild) {
        foreach ($a in $archesToBuild) {
            Write-Host "`n>>> Compiling Godot C++ for Android [Target: $t, Arch: $a, Jobs: $Jobs]..." -ForegroundColor Yellow
            
            $sconsArgs = @(
                "-m", "SCons",
                "platform=android",
                "target=$t",
                "arch=$a",
                "swappy=yes",
                "-j$Jobs"
            )

            if ($Production) {
                $sconsArgs += "production=yes"
            }

            Write-Host "Running: $PYTHON_EXE $($sconsArgs -join ' ')" -ForegroundColor Gray
            & $PYTHON_EXE @sconsArgs

            if ($LASTEXITCODE -ne 0) {
                Write-Error "SCons compilation failed for target $t ($a) with exit code $LASTEXITCODE"
                exit $LASTEXITCODE
            }
        }
    }
    Write-Host "`n[✓] SCons C++ compilation completed successfully!" -ForegroundColor Green
}

# 3. Gradle APK Packaging
if (-not $SkipApk) {
    Write-Host "`n>>> Packaging Android APK with Gradle..." -ForegroundColor Yellow
    $gradleDir = Join-Path $ScriptDir "platform\android\java"
    Set-Location $gradleDir

    $gradleTasks = @()
    if ($Target -eq "editor" -or $Target -eq "all") {
        $gradleTasks += "generateGodotEditor"
    }
    if ($Target -eq "template_release" -or $Target -eq "template_debug" -or $Target -eq "all") {
        $gradleTasks += "generateGodotTemplates"
    }

    foreach ($task in $gradleTasks) {
        Write-Host "Running: .\gradlew.bat $task" -ForegroundColor Gray
        & .\gradlew.bat $task

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Gradle build failed for task $task with exit code $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }

    Set-Location $ScriptDir

    # 4. Output Summary
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host " BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green

    $outputApkDir = Join-Path $ScriptDir "platform\android\java\app\build\outputs\apk"
    $binDir = Join-Path $ScriptDir "bin"

    Write-Host "`nGenerated APKs in '$outputApkDir':" -ForegroundColor Cyan
    if (Test-Path $outputApkDir) {
        Get-ChildItem -Path $outputApkDir -Recurse -Filter "*.apk" | ForEach-Object {
            $sizeMB = [math]::Round($_.Length / 1MB, 2)
            Write-Host "  - $($_.Name) ($sizeMB MB)" -ForegroundColor Green
            Write-Host "    Path: $($_.FullName)" -ForegroundColor Gray
        }
    }

    if (Test-Path $binDir) {
        Write-Host "`nNative Libraries / Binaries in '$binDir':" -ForegroundColor Cyan
        Get-ChildItem -Path $binDir -Include "*.apk", "*.so", "*.a", "*.aar", "*.zip" -Recurse | ForEach-Object {
            $sizeMB = [math]::Round($_.Length / 1MB, 2)
            Write-Host "  - $($_.Name) ($sizeMB MB)" -ForegroundColor Green
            Write-Host "    Path: $($_.FullName)" -ForegroundColor Gray
        }
    }
}
