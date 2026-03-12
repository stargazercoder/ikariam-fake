# Unified test automation: reset DB, seed data, run all Flutter tests.
# Usage: .\scripts\test_all.ps1
# Exit codes: 0 = all passed, non-zero = failure in any step.
$ErrorActionPreference = 'Stop'

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Ikariam Test Suite" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/2] Resetting database (migrations + seed)..." -ForegroundColor Yellow
npx supabase db reset --local
if ($LASTEXITCODE -ne 0) {
    Write-Host "  DATABASE RESET FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "  Database reset complete." -ForegroundColor Green
Write-Host ""

Write-Host "[2/2] Running Flutter tests..." -ForegroundColor Yellow
flutter test --reporter expanded
$FlutterExit = $LASTEXITCODE

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
if ($FlutterExit -eq 0) {
    Write-Host "  ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "  TESTS FAILED (exit code: $FlutterExit)" -ForegroundColor Red
}
Write-Host "=========================================" -ForegroundColor Cyan

exit $FlutterExit
