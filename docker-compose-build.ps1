#Requires -Version 5.0

Write-Host "Building CISO Assistant from local files..." -ForegroundColor Green

# Enable BuildKit for better builds
$env:DOCKER_BUILDKIT = "1"
$env:COMPOSE_DOCKER_CLI_BUILD = "1"

# Check if database already exists
if (Test-Path "db/ciso-assistant.sqlite3") {
    Write-Host "The database seems already created." -ForegroundColor Yellow
    Write-Host "For successive runs, you can now use 'docker compose up'." -ForegroundColor Yellow
    
    $response = Read-Host "Do you want to rebuild anyway? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        exit 0
    }
}

# Build the containers
Write-Host "`nBuilding containers from local source code..." -ForegroundColor Cyan
docker compose build --pull

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nBuild failed! Check the error messages above." -ForegroundColor Red
    exit 1
}

Write-Host "`nStarting services..." -ForegroundColor Cyan
docker compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nFailed to start services!" -ForegroundColor Red
    exit 1
}

Write-Host "`nWaiting for CISO Assistant backend to be ready..." -ForegroundColor Cyan
$maxAttempts = 30
$attempt = 0
$backendReady = $false

do {
    $attempt++
    try {
        $result = docker compose exec -T backend curl -f http://localhost:8000/api/health/ 2>$null
        if ($LASTEXITCODE -eq 0) {
            $backendReady = $true
        }
    }
    catch {
        Write-Host "Backend is not ready - waiting 10s... (Attempt $attempt/$maxAttempts)" -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
    
    if (-not $backendReady -and $attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 10
    }
} while (-not $backendReady -and $attempt -lt $maxAttempts)

if (-not $backendReady) {
    Write-Host "`nBackend failed to become ready after $maxAttempts attempts!" -ForegroundColor Red
    Write-Host "Check logs with: docker compose logs backend" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nBackend is ready!" -ForegroundColor Green

# Only create superuser if database was just created
if (-not (Test-Path "db/ciso-assistant.sqlite3.bak")) {
    Write-Host "`nCreating superuser..." -ForegroundColor Cyan
    docker compose exec backend poetry run python manage.py createsuperuser
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "CISO Assistant is ready!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "You can now access CISO Assistant at https://localhost:8443" -ForegroundColor Cyan
Write-Host "`nFor successive runs, use: docker compose up -d" -ForegroundColor Yellow
Write-Host "To rebuild after changes: docker compose build && docker compose up -d" -ForegroundColor Yellow

