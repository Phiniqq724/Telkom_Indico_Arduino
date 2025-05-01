# UART Communication PowerShell Script

# Add required .NET class
Add-Type -AssemblyName System.IO.Ports

# Function to list available COM ports
function Get-AvailableCOMPorts {
    [System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object
}

# Function to initialize the UART port
function Initialize-UART {
    param (
        [string]$portName = "COM10",
        [int]$baudRate = 9600,
        [int]$dataBits = 8,
        [System.IO.Ports.Parity]$parity = [System.IO.Ports.Parity]::None,
        [System.IO.Ports.StopBits]$stopBits = [System.IO.Ports.StopBits]::One,
        [int]$readTimeout = 1000,
        [int]$writeTimeout = 1000
    )

    try {
        # Check if the port exists
        $availablePorts = [System.IO.Ports.SerialPort]::GetPortNames()
        if ($availablePorts -notcontains $portName) {
            Write-Host "Error: Port $portName not found. Available ports:" -ForegroundColor Red
            $availablePorts | ForEach-Object { Write-Host "  - $_" }
            return $null
        }

        $serialPort = New-Object System.IO.Ports.SerialPort
        $serialPort.PortName = $portName
        $serialPort.BaudRate = $baudRate
        $serialPort.Parity = $parity
        $serialPort.DataBits = $dataBits
        $serialPort.StopBits = $stopBits
        $serialPort.ReadTimeout = $readTimeout
        $serialPort.WriteTimeout = $writeTimeout
        
        # Set to use RTS/CTS handshaking if needed
        # $serialPort.Handshake = [System.IO.Ports.Handshake]::RequestToSend

        # Try to open the port
        Write-Host "Attempting to open $portName..." -ForegroundColor Yellow
        $serialPort.Open()
        Write-Host "$portName opened successfully." -ForegroundColor Green
        return $serialPort
    }
    catch {
        Write-Host "Error initializing port $portName`: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to send data over UART
function Send-UARTData {
    param (
        [System.IO.Ports.SerialPort]$serialPort,
        [string]$data
    )

    if ($null -eq $serialPort) {
        Write-Host "Serial port object is null." -ForegroundColor Red
        return
    }

    if ($serialPort.IsOpen) {
        try {
            # Append newline if not present
            if (!$data.EndsWith("`r`n")) {
                $data = "$data`r`n"
            }
            
            # Convert to bytes and write
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($data)
            $serialPort.Write($bytes, 0, $bytes.Length)
            Write-Host "Sent: $data" -ForegroundColor Cyan
        }
        catch {
            Write-Host "Error sending data: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Serial port is not open." -ForegroundColor Red
    }
}

# Function to receive data from UART with continuous reading option
function Receive-UARTData {
    param (
        [System.IO.Ports.SerialPort]$serialPort,
        [int]$timeout = 1000,
        [switch]$continuous = $false,
        [int]$duration = 10  # Duration in seconds for continuous mode
    )

    if ($null -eq $serialPort) {
        Write-Host "Serial port object is null." -ForegroundColor Red
        return $null
    }

    if (-not $serialPort.IsOpen) {
        Write-Host "Serial port is not open." -ForegroundColor Red
        return $null
    }

    if ($continuous) {
        $endTime = (Get-Date).AddSeconds($duration)
        Write-Host "Reading continuous data for $duration seconds..." -ForegroundColor Yellow
        Write-Host "Press Ctrl+C to stop reading early." -ForegroundColor Yellow
        
        try {
            while ((Get-Date) -lt $endTime) {
                if ($serialPort.BytesToRead -gt 0) {
                    $data = $serialPort.ReadLine()
                    Write-Host "Received: $data" -ForegroundColor Green
                }
                Start-Sleep -Milliseconds 100
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] {
            Write-Host "Continuous reading stopped by user." -ForegroundColor Yellow
        }
        catch {
            Write-Host "Error in continuous reading: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $null
    }
    else {
        try {
            $originalTimeout = $serialPort.ReadTimeout
            $serialPort.ReadTimeout = $timeout
            
            # Check if there's actually data to read
            if ($serialPort.BytesToRead -gt 0) {
                $data = $serialPort.ReadLine()
                $serialPort.ReadTimeout = $originalTimeout
                return $data
            }
            else {
                Start-Sleep -Milliseconds 100
                if ($serialPort.BytesToRead -gt 0) {
                    $data = $serialPort.ReadLine()
                    $serialPort.ReadTimeout = $originalTimeout
                    return $data
                }
                Write-Host "No data available to read." -ForegroundColor Yellow
                $serialPort.ReadTimeout = $originalTimeout
                return $null
            }
        }
        catch [System.TimeoutException] {
            Write-Host "Read timeout occurred." -ForegroundColor Yellow
            return $null
        }
        catch {
            Write-Host "Error reading data: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }
}

# Function to close the UART port
function Close-UART {
    param (
        [System.IO.Ports.SerialPort]$serialPort
    )

    if ($null -eq $serialPort) {
        Write-Host "Serial port object is null." -ForegroundColor Red
        return
    }

    try {
        if ($serialPort.IsOpen) {
            $serialPort.Close()
            Write-Host "Port closed successfully." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error closing port: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to display help menu
function Show-UARTHelp {
    Write-Host "`nUART Communication Commands:" -ForegroundColor Cyan
    Write-Host "  send <data>  - Send data over UART"
    Write-Host "  read         - Read a single line from UART"
    Write-Host "  monitor      - Continuously monitor incoming data"
    Write-Host "  clear        - Clear the screen"
    Write-Host "  help         - Show this help menu"
    Write-Host "  exit         - Close the port and exit the script`n"
}

# Main execution
Write-Host "=== UART Communication Tool ===" -ForegroundColor Cyan
Write-Host "Available COM ports:" -ForegroundColor Cyan
Get-AvailableCOMPorts | ForEach-Object { Write-Host "  - $_" }

$portToUse = Read-Host "Enter COM port to use (e.g., COM3)"
$baudRate = Read-Host "Enter baud rate (default: 9600)"
if (-not $baudRate) { $baudRate = 9600 }

$uartPort = Initialize-UART -portName $portToUse -baudRate ([int]$baudRate)

if ($uartPort -ne $null) {
    try {
        Show-UARTHelp
        while ($true) {
            $input = Read-Host "`nCommand"
            if ($input -eq "exit") { 
                break 
            }
            elseif ($input -eq "help") { 
                Show-UARTHelp 
            }
            elseif ($input -eq "clear") { 
                Clear-Host
                Show-UARTHelp
            }
            elseif ($input -eq "read") {
                $response = Receive-UARTData -serialPort $uartPort
                if ($response) {
                    Write-Host "Received: $response" -ForegroundColor Green
                }
            }
            elseif ($input -eq "monitor") {
                $duration = Read-Host "Enter monitoring duration in seconds (default: 30)"
                if (-not $duration) { $duration = 30 }
                Receive-UARTData -serialPort $uartPort -continuous -duration ([int]$duration)
            }
            elseif ($input -match "^send (.+)$") {
                $dataToSend = $matches[1]
                Send-UARTData -serialPort $uartPort -data $dataToSend
                
                # Automatically try to read a response
                Start-Sleep -Milliseconds 500
                $response = Receive-UARTData -serialPort $uartPort
                if ($response) {
                    Write-Host "Received: $response" -ForegroundColor Green
                }
            }
            else {
                Write-Host "Unknown command. Type 'help' for available commands." -ForegroundColor Yellow
            }
        }
    }
    finally {
        Close-UART -serialPort $uartPort
    }
}