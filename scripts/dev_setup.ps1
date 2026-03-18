# One-command dev environment setup: db reset, seed, Edge Functions serve, Flutter build.
# Usage: .\scripts\dev_setup.ps1
$ErrorActionPreference = 'Stop'

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir

# --- Prerequisite checks ---
function Test-Command($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: '$Name' not found in PATH. Install it first." -ForegroundColor Red
        exit 1
    }
}
Test-Command flutter
Test-Command deno
Test-Command npx

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Ikariam Dev Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] Resetting database (migrations + seed)..." -ForegroundColor Yellow
npx supabase db reset --local
if ($LASTEXITCODE -ne 0) {
    Write-Host "  DATABASE RESET FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "  Database reset complete." -ForegroundColor Green
Write-Host ""

Write-Host "[2/3] Starting Edge Functions serve (background)..." -ForegroundColor Yellow
$ServeJob = Start-Job -ScriptBlock { Set-Location $using:ProjectDir; npx supabase functions serve }
Write-Host "  Edge Functions serve started (Job ID: $($ServeJob.Id))" -ForegroundColor Green
Write-Host "  Stop with: Stop-Job $($ServeJob.Id)" -ForegroundColor Gray
Write-Host ""

Write-Host "[3/3] Building Flutter web..." -ForegroundColor Yellow
# Load .env.local if it exists
if (Test-Path ".env.local") {
    Get-Content ".env.local" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
}
$SupabaseUrl = if ($env:SUPABASE_URL) { $env:SUPABASE_URL } else { "http://127.0.0.1:54321" }
$SupabaseAnonKey = if ($env:SUPABASE_ANON_KEY) { $env:SUPABASE_ANON_KEY } else { "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH" }
flutter build web `
    --dart-define=SUPABASE_URL="$SupabaseUrl" `
    --dart-define=SUPABASE_ANON_KEY="$SupabaseAnonKey"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  FLUTTER BUILD FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "  Flutter web build complete." -ForegroundColor Green
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  DEV SETUP COMPLETE" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Edge Functions serve Job ID: $($ServeJob.Id)" -ForegroundColor White
Write-Host "  Run: Stop-Job $($ServeJob.Id)  to stop serve" -ForegroundColor White
Write-Host "=========================================" -ForegroundColor Cyan
