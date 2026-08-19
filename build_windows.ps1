# Build Script for Godot Engine Windows Native (.exe)
[CmdletBinding()]
param (
    [ValidateSet("editor", "template_release", "template_debug", "all")]
    [string]$Target = "editor",

    [ValidateSet("x86_64", "x86_32", "arm64", "all")]
    [string]$Arch = "x86_64",

    [int]$Jobs = [System.Environment]::ProcessorCount,

    [switch]$Production
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Godot Engine Windows Native (.exe) Build Script" -ForegroundColor Cyan
Write-Host " Target: $Target | Arch: $Arch | Jobs: $Jobs" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$pythonDirs = @(
    "C:\Users\jamaa\AppData\Local\Python\pythoncore-3.14-64\Scripts",
    "C:\Users\jamaa\AppData\Local\Python\pythoncore-3.14-64",
    "C:\Users\jamaa\AppData\Local\Python\bin"
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
    $archesToBuild = @("x86_64")
} else {
    $archesToBuild = @($Arch)
}

foreach ($t in $targetsToBuild) {
    foreach ($a in $archesToBuild) {
        Write-Host "`n>>> Compiling Godot Native Windows [Target: $t, Arch: $a, Jobs: $Jobs]..." -ForegroundColor Yellow
        
        $sconsArgs = @(
            "-m", "SCons",
            "platform=windows",
            "target=$t",
            "arch=$a",
            "-j$Jobs"
        )

        if ($Production) {
            $sconsArgs += "production=yes"
        }

        Write-Host "Running: $PYTHON_EXE $($sconsArgs -join ' ')" -ForegroundColor Gray
        & $PYTHON_EXE @sconsArgs

        if ($LASTEXITCODE -ne 0) {
            Write-Error "SCons Windows compilation failed for target $t ($a) with exit code $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " WINDOWS BUILD SUCCESSFUL!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

$binDir = Join-Path $ScriptDir "bin"
if (Test-Path $binDir) {
    Write-Host "`nGenerated Executables in '$binDir':" -ForegroundColor Cyan
    Get-ChildItem -Path $binDir -Filter "*.exe" | ForEach-Object {
        $sizeMB = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  - $($_.Name) ($sizeMB MB)" -ForegroundColor Green
        Write-Host "    Path: $($_.FullName)" -ForegroundColor Gray
    }
}
