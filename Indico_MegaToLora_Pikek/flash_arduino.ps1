# Arduino Mega 2560 Flashing Script
arduino-cli config init

$boardType = "arduino:avr:mega"
$sketchPath = "c:\Users\fahre\OneDrive\Dokumen\Arduino\Indico123\Indico_MegaToLora"

# Get available ports
$ports = arduino-cli board list
Write-Host "Available ports:"
$ports | ForEach-Object { Write-Host $_ }

$portName = Read-Host "Enter COM port to use (e.g., COM3)"

# Compile and upload
Write-Host "Compiling sketch..." -ForegroundColor Yellow
arduino-cli compile --fqbn $boardType $sketchPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "Compilation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Uploading to Arduino Mega 2560 on $portName..." -ForegroundColor Yellow
arduino-cli upload -p $portName --fqbn $boardType $sketchPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "Upload failed!" -ForegroundColor Red
    exit 1
}

Write-Host "Upload successful!" -ForegroundColor Green
