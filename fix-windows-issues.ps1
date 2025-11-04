#Requires -Version 5.0

Write-Host "Fixing common Windows Docker build issues..." -ForegroundColor Cyan

# Fix line endings in shell scripts
Write-Host "`n1. Fixing line endings in shell scripts..." -ForegroundColor Yellow

$shellScripts = @(
    "backend/startup.sh",
    "docker-compose.sh",
    "docker-compose-build.sh",
    "update-ciso-assistant.sh"
)

foreach ($script in $shellScripts) {
    if (Test-Path $script) {
        try {
            $content = Get-Content $script -Raw
            $content = $content -replace "`r`n", "`n"
            [System.IO.File]::WriteAllText((Resolve-Path $script).Path, $content)
            Write-Host "   Fixed: $script" -ForegroundColor Green
        }
        catch {
            Write-Host "   Warning: Could not fix $script - $_" -ForegroundColor Red
        }
    }
}

# Check Docker is running
Write-Host "`n2. Checking Docker Desktop is running..." -ForegroundColor Yellow
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Docker is running" -ForegroundColor Green
    } else {
        Write-Host "   Docker is NOT running! Please start Docker Desktop." -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "   Docker is NOT running! Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Check Docker Compose version
Write-Host "`n3. Checking Docker Compose..." -ForegroundColor Yellow
try {
    $composeVersion = docker compose version
    Write-Host "   $composeVersion" -ForegroundColor Green
}
catch {
    Write-Host "   Docker Compose not found! Please update Docker Desktop." -ForegroundColor Red
    exit 1
}

# Clean up old containers and images (optional)
Write-Host "`n4. Cleaning up old containers..." -ForegroundColor Yellow
docker compose down 2>$null

# Check available disk space
Write-Host "`n5. Checking disk space..." -ForegroundColor Yellow
$drive = (Get-Location).Drive.Name
$disk = Get-PSDrive $drive
$freeGB = [math]::Round($disk.Free / 1GB, 2)
Write-Host "   Free space on ${drive}: $freeGB GB" -ForegroundColor $(if ($freeGB -gt 10) { "Green" } else { "Yellow" })

if ($freeGB -lt 5) {
    Write-Host "   Warning: Low disk space! Docker builds need at least 5GB free." -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Windows environment is ready for Docker build!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Run: .\docker-compose-build.ps1" -ForegroundColor White
Write-Host "  OR" -ForegroundColor Yellow
Write-Host "  2. Run: docker compose build && docker compose up -d" -ForegroundColor White

