#!/usr/bin/env pwsh
# Initializes the xboxrecomp submodule and applies our pinned toolkit patches.
# Safe to re-run: patches that are already applied are skipped.

$ErrorActionPreference = "Continue"
$repoRoot = Split-Path -Parent $PSScriptRoot
$toolkitDir = Join-Path $repoRoot "xboxrecomp"
$patchesDir = Join-Path $repoRoot "patches\xboxrecomp"

Write-Host "Initializing xboxrecomp submodule..."
git -C $repoRoot submodule update --init --recursive
if ($LASTEXITCODE -ne 0) { throw "git submodule update failed" }

if (Test-Path $patchesDir) {
    Get-ChildItem -Path $patchesDir -Filter "*.patch" | Sort-Object Name | ForEach-Object {
        $patch = $_.FullName
        git -C $toolkitDir apply --reverse --check $patch *>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Already applied: $($_.Name)"
            return
        }
        Write-Host "Applying: $($_.Name)"
        git -C $toolkitDir apply $patch
        if ($LASTEXITCODE -ne 0) { throw "Failed to apply $($_.Name)" }
    }
}

Write-Host "Setup complete."
