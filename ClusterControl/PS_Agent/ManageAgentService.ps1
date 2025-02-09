# ManageAgentService.ps1
# Этот скрипт управляет службой ClusterControlAgent

param (
    [Parameter(Mandatory=$true, HelpMessage="Specify the action: install, remove, start, stop, restart")]
    [ValidateSet("install", "remove", "start", "stop", "restart")]
    [string]$Action
)

# Configuration
$ServiceName = "ClusterControlAgent"
$ScriptPath = "C:\path\to\your\AgentService.ps1" # Замените правильным путем к AgentService.ps1

function Install-Service {
    Write-Host "Installing service '$ServiceName'..."
    # Сначала остановите службу, если она уже существует
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Warning "Service already exists. Stopping and removing..."
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5 # Дайте время службе остановиться
        Remove-Service -Name $ServiceName -ErrorAction SilentlyContinue # Удалить старую службу
    }

    # Создаем новую службу с помощью sc.exe (так как New-Service требует PS7+)
    try {
        $cmd = "sc.exe create `"$ServiceName`" binPath=`"powershell.exe -ExecutionPolicy Bypass -File `"$ScriptPath`"`" start= auto displayname= `"$($ServiceName) Display`""
        Invoke-Expression $cmd # Выполняем команду
        # Задаем описание службы (обязательно запускать после создания)
        $desc = "sc.exe description `"$ServiceName`" `"$($ServiceName) description`""
        Invoke-Expression $desc
        # Включаем восстановление после сбоев
        $restartcmd = "sc.exe failure `"$ServiceName`" reset= 86400 actions= restart/60000/restart/60000/restart/60000"
        Invoke-Expression $restartcmd
        Write-Host "Service '$ServiceName' installed successfully."
    } catch {
        Write-Error "Failed to install service: $($_.Exception.Message)"
    }
}

function Remove-Service {
    Write-Host "Removing service '$ServiceName'..."
    try {
        if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5 # Дайте время службе остановиться
            Remove-Service -Name $ServiceName -ErrorAction SilentlyContinue
        }
        Write-Host "Service '$ServiceName' removed successfully."
    } catch {
        Write-Error "Failed to remove service: $($_.Exception.Message)"
    }
}

function Start-ServiceFunction {
    Write-Host "Starting service '$ServiceName'..."
    try {
        Start-Service -Name $ServiceName
        Write-Host "Service '$ServiceName' started successfully."
    } catch {
        Write-Error "Failed to start service: $($_.Exception.Message)"
    }
}

function Stop-ServiceFunction {
    Write-Host "Stopping service '$ServiceName'..."
    try {
        Stop-Service -Name $ServiceName -Force
        Write-Host "Service '$ServiceName' stopped successfully."
    } catch {
        Write-Error "Failed to stop service: $($_.Exception.Message)"
    }
}

function Restart-ServiceFunction {
    Write-Host "Restarting service '$ServiceName'..."
    try {
        Restart-Service -Name $ServiceName -Force
        Write-Host "Service '$ServiceName' restarted successfully."
    } catch {
        Write-Error "Failed to restart service: $($_.Exception.Message)"
    }
}

# Main switch statement
switch ($Action) {
    "install" { Install-Service }
    "remove"  { Remove-Service }
    "start"   { Start-ServiceFunction }
    "stop"    { Stop-ServiceFunction }
    "restart" { Restart-ServiceFunction }
}