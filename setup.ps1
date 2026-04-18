# setup.ps1
# This script initializes the environments for both frontend and backend and starts them.

$ErrorActionPreference = "Stop"
$originalPath = Get-Location

Write-Host "Starting project setup..." -ForegroundColor Green

# --- Backend Setup ---
Write-Host "Setting up Background (Python + FastAPI)..." -ForegroundColor Yellow
Set-Location -Path "backend"

if (-not (Test-Path "venv")) {
    Write-Host "Creating Python virtual environment..."
    python -m venv venv
}

# Activate virtual environment and install requirements
$venvPython = if ($IsWindows) { ".\venv\Scripts\python.exe" } else { "./venv/bin/python" }
$venvPip = if ($IsWindows) { ".\venv\Scripts\pip.exe" } else { "./venv/bin/pip" }

Write-Host "Installing backend dependencies..."
& $venvPip install -r requirements.txt

# Start backend as an independent job/process
if ($IsWindows) {
    Write-Host "Starting FastAPI Backend server in a new window..." -ForegroundColor Green
    Start-Process -FilePath ".\venv\Scripts\python.exe" -ArgumentList "main.py" -WindowStyle Normal
} else {
    Write-Host "Starting FastAPI Backend server in background..." -ForegroundColor Green
    Start-Job -ScriptBlock { & "./venv/bin/python" "main.py" }
}

Set-Location -Path $originalPath

# --- Frontend Setup ---
Write-Host "Setting up Frontend (React)..." -ForegroundColor Yellow
Set-Location -Path "frontend"

Write-Host "Installing frontend dependencies..."
# Wait for npm to finish
if ($IsWindows) {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c npm install" -Wait -NoNewWindow
} else {
    npm install
}

# Start frontend
if ($IsWindows) {
    Write-Host "Starting React Frontend server in a new window..." -ForegroundColor Green
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c npm start" -WindowStyle Normal
} else {
    Write-Host "Starting React Frontend server..." -ForegroundColor Green
    Start-Job -ScriptBlock { npm start }
}

Set-Location -Path $originalPath
Write-Host "Setup complete. Both servers are starting up!" -ForegroundColor Green
