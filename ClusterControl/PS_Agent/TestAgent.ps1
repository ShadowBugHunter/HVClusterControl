# TestAgent.ps1
# Скрипт для тестирования агента ClusterControlAgent

# Load configuration from JSON file
$ConfigFile = "config.json"
try {
    $Config = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
} catch {
    Write-Host "Error loading configuration file: $($_.Exception.Message)"
    exit
}

# Extract configurations
$ServerAddress = $Config.AgentService.ServerAddress
$ControlPort = $Config.AgentService.ControlPort
$LoggingType = $Config.TestAgent.LoggingType
$LogFile = $Config.TestAgent.LogFile

# Function to write log messages
function Write-TestLog {
    param (
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"

    switch ($LoggingType) {
        "Console" { Write-Host $LogEntry }
        "File"    { Out-File -FilePath $LogFile -Append -InputObject $LogEntry }
        "Combined"{ Write-Host $LogEntry; Out-File -FilePath $LogFile -Append -InputObject $LogEntry }
    }
}

# Function to send command to Agent
function Send-Command {
    param (
        [string]$Command
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient($ServerAddress, $ControlPort)
        $networkStream = $tcpClient.GetStream()
        $writer = New-Object System.IO.StreamWriter($networkStream)
        $reader = New-Object System.IO.StreamReader($networkStream)

        Write-TestLog "Sending command: $Command"

        $writer.WriteLine($Command)
        $writer.Flush()

        $response = $reader.ReadLine()
        Write-TestLog "Received response: $response"

        $writer.Close()
        $reader.Close()
        $networkStream.Close()
        $tcpClient.Close()

    } catch {
        Write-TestLog "Error sending command: $($_.Exception.Message)"
    }
}

# --- Test Scenarios ---
Write-TestLog "--- Starting Test Scenarios ---"

# Test 1: Start a VM
Write-TestLog "--- Test 1: Starting VM 'TestVM' ---"
$command = @{ command = "Start-VM"; vmName = "TestVM" } | ConvertTo-Json
Send-Command -Command $command

# Test 2: Stop a VM
Write-TestLog "--- Test 2: Stopping VM 'TestVM' ---"
$command = @{ command = "Stop-VM"; vmName = "TestVM" } | ConvertTo-Json
Send-Command -Command $command

# Test 3: Restart a VM
Write-TestLog "--- Test 3: Restarting VM 'TestVM' ---"
$command = @{ command = "Restart-VM"; vmName = "TestVM" } | ConvertTo-Json
Send-Command -Command $command

# Test 4: Suspend a VM
Write-TestLog "--- Test 4: Suspending VM 'TestVM' ---"
$command = @{ command = "Suspend-VM"; vmName = "TestVM" } | ConvertTo-Json
Send-Command -Command $command

# Test 5: Invalid Command
Write-TestLog "--- Test 5: Sending Invalid Command ---"
$command = @{ command = "Do-Something"; vmName = "TestVM" } | ConvertTo-Json
Send-Command -Command $command

Write-TestLog "--- End of Test Scenarios ---"