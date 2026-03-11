# Start Supabase local dev and run Flutter with correct dart-defines.
# Usage: .\scripts\run_local.ps1 [flutter-run-args...]
# Examples:
#   .\scripts\run_local.ps1                    # default: flutter run -d chrome
#   .\scripts\run_local.ps1 -d windows         # run on Windows desktop
#   .\scripts\run_local.ps1 -d emulator-5554   # run on Android emulator
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir

# Load .env.local if it exists
if (Test-Path ".env.local") {
    Get-Content ".env.local" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
}

# Fallback defaults (standard local Supabase values)
$SupabaseUrl = if ($env:SUPABASE_URL) { $env:SUPABASE_URL } else { "http://127.0.0.1:54321" }
$SupabaseAnonKey = if ($env:SUPABASE_ANON_KEY) { $env:SUPABASE_ANON_KEY } else { "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH" }

# Ensure Supabase is running
Write-Host "Checking Supabase status..."
$statusResult = npx supabase status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Supabase not running. Starting..."
    npx supabase start
    Write-Host "Waiting for services to be healthy..."
    Start-Sleep -Seconds 5
} else {
    Write-Host "Supabase is already running."
}

# Default device: chrome (web)
if (-not $FlutterArgs) {
    $FlutterArgs = @("-d", "chrome")
}

Write-Host ""
Write-Host "Running Flutter with local Supabase:"
Write-Host "  URL:  $SupabaseUrl"
Write-Host "  Key:  $($SupabaseAnonKey.Substring(0, 20))..."
Write-Host ""

flutter run `
    --dart-define=SUPABASE_URL="$SupabaseUrl" `
    --dart-define=SUPABASE_ANON_KEY="$SupabaseAnonKey" `
    @FlutterArgs
