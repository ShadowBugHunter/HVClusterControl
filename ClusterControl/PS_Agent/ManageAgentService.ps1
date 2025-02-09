# ManageAgentService.ps1
# Этот скрипт управляет службой ClusterControlAgent

param (
    [Parameter(Mandatory=$true, HelpMessage="Specify the action: install, remove, start, stop, restart")]
    [ValidateSet("install", "remove", "start", "stop", "restart", "status")]
    [string]$Action
)

# Configuration
$ServiceName = "ClusterControlAgent"
$ScriptPath = "C:\path\to\your\AgentService.ps1" # Замените правильным путем к AgentService.ps1
$LogFile = "ManageAgentService.log"
$EnableLogging = $true  # Измените на $false, чтобы отключить логирование

# Function to write to log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "Info" # Info, Warning, Error
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp [$Level] - $Message"

    if ($EnableLogging) {
        Out-File -FilePath $LogFile -Append -InputObject $LogEntry
    }

    Write-Host $LogEntry
}

function Get-ServiceStatus {
    Write-Log "Checking service status..."
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop # Используем Stop, чтобы отлавливать несуществующие службы

        if ($service) {
            Write-Log "Service '$ServiceName' status: $($service.Status)"
            return $service.Status
        } else {
            Write-Log "Service '$ServiceName' not found." -Level Warning
            return $null
        }
    } catch {
        Write-Log "Service '$ServiceName' not found." -Level Warning
        return $null
    }
}

function Install-Service {
    Write-Log "Installing service '$ServiceName'..."
    $currentStatus = Get-ServiceStatus

    if ($currentStatus -ne $null) {
        Write-Log "Service already exists. Stopping and removing..."
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
        Remove-Service -Name $ServiceName -ErrorAction SilentlyContinue
    }

    try {
        $cmd = "sc.exe create `"$ServiceName`" binPath=`"powershell.exe -ExecutionPolicy Bypass -File `"$ScriptPath`"`" start= auto displayname= `"$($ServiceName) Display`""
        Invoke-Expression $cmd
        $desc = "sc.exe description `"$ServiceName`" `"$($ServiceName) description`""
        Invoke-Expression $desc
        $restartcmd = "sc.exe failure `"$ServiceName`" reset= 86400 actions= restart/60000/restart/60000/restart/60000"
        Invoke-Expression $restartcmd
        Write-Log "Service '$ServiceName' installed successfully."
    } catch {
        Write-Log "Failed to install service: $($_.Exception.Message)" -Level Error
    }
}

function Remove-Service {
    Write-Log "Removing service '$ServiceName'..."
    $currentStatus = Get-ServiceStatus

    if ($currentStatus -ne $null) {
        try {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
            Remove-Service -Name $ServiceName -ErrorAction SilentlyContinue
            Write-Log "Service '$ServiceName' removed successfully."
        } catch {
            Write-Log "Failed to remove service: $($_.Exception.Message)" -Level Error
        }
    } else {
        Write-Log "Service '$ServiceName' does not exist." -Level Warning
    }
}

function Start-ServiceFunction {
    Write-Log "Starting service '$ServiceName'..."
    try {
        Start-Service -Name $ServiceName
        Write-Log "Service '$ServiceName' started successfully."
    } catch {
        Write-Log "Failed to start service: $($_.Exception.Message)" -Level Error
    }
}

function Stop-ServiceFunction {
    Write-Log "Stopping service '$ServiceName'..."
    try {
        Stop-Service -Name $ServiceName -Force
        Write-Log "Service '$ServiceName' stopped successfully."
    } catch {
        Write-Log "Failed to stop service: $($_.Exception.Message)" -Level Error
    }
}

function Restart-ServiceFunction {
    Write-Log "Restarting service '$ServiceName'..."
    try {
        Restart-Service -Name $ServiceName -Force
        Write-Log "Service '$ServiceName' restarted successfully."
    } catch {
        Write-Log "Failed to restart service: $($_.Exception.Message)" -Level Error
    }
}

function Status-ServiceFunction {
    $status = Get-ServiceStatus
    if ($status) {
        Write-Log "Service '$ServiceName' status is: $status"
    } else {
        Write-Log "Service '$ServiceName' not found." -Level Warning
    }
}

# Main switch statement
switch ($Action) {
    "install" { Install-Service }
    "remove"  { Remove-Service }
    "start"   { Start-ServiceFunction }
    "stop"    { Stop-ServiceFunction }
    "restart" { Restart-ServiceFunction }
    "status"  { Status-ServiceFunction }
}