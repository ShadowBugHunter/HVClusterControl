# AgentService.ps1
# Configuration
$ServerAddress = "127.0.0.1" # Change to the IP address of your management server
$MonitorPort = 5001
$ControlPort = 5002
$AgentId = "agent001" # Replace with a unique identifier for this agent
$ServiceName = "ClusterControlAgent" # Имя службы
$LogFile = "AgentService.log"
$LogLevel = "Info" # Debug, Info, Warning, Error

# Function to write to log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "Info"
    )

    # Check if the log level should be written
    $LogLevelOrder = @{
        "Debug"   = 1
        "Info"    = 2
        "Warning" = 3
        "Error"   = 4
    }

    if ($LogLevelOrder[$Level] -ge $LogLevelOrder[$LogLevel]) {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "$Timestamp [$Level] - $Message"
        Out-File -FilePath $LogFile -Append -InputObject $LogEntry
        Write-Host $LogEntry # Still write to console
    }
}

# Function to Get VM Data
function Get-VMData {
  try {
    $vms = Get-VM | Select-Object Name, State, CPUUsage, MemoryAssigned
    $vmData = @()

    foreach ($vm in $vms) {
      $vmData += [PSCustomObject]@{
        name           = $vm.Name
        state          = $vm.State
        cpuUsage       = $vm.CPUUsage
        memoryAssigned = $vm.MemoryAssigned
      }
    }
    return $vmData
  }
  catch {
    Write-Log "Error getting VM data: $($_.Exception.Message)" -Level Error
    return $null
  }
}

# Function to Send Data to Server
function Send-DataToServer {
  param (
    [string]$Server,
    [int]$Port,
    [string]$Data
  )

  try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient($Server, $Port)
    $networkStream = $tcpClient.GetStream()
    $writer = New-Object System.IO.StreamWriter($networkStream)
    $writer.WriteLine($Data)
    $writer.Flush()

    # Optional: Read response from server
    # $reader = New-Object System.IO.StreamReader($networkStream)
    # $response = $reader.ReadLine()
    # Write-Host "Server response: $response"

    $writer.Close()
    $networkStream.Close()
    $tcpClient.Close()
    Write-Log "Data sent successfully to server $Server:$Port" -Level Debug

  }
  catch {
    Write-Log "Error sending data: $($_.Exception.Message)" -Level Error
  }
}

# Monitor Loop (Sends data to server)
function Start-MonitorLoop {
  while ($true) {
    try {
        $vmData = Get-VMData
        if ($vmData) {
          $data = @{
              agentId = $AgentId
              vmData  = $vmData
          } | ConvertTo-Json

          Send-DataToServer -Server $ServerAddress -Port $MonitorPort -Data $data
          Write-Log "Data sent to server"
        }
        else {
            Write-Log "No VM data to send." -Level Info
        }
        Start-Sleep -Seconds 60 # Adjust as needed
    }
    catch {
      Write-Log "Error in MonitorLoop: $($_.Exception.Message)" -Level Error
    }
  }
}

# Control Listener (Receives and executes commands)
function Start-ControlListener {
  $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $ControlPort)
  $listener.Start()
  Write-Log "Listening for commands on port $ControlPort..." -Level Info

  while ($true) {
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)

    try {
      $commandJson = $reader.ReadLine()
      $command = ConvertFrom-Json -InputObject $commandJson

      Write-Log "Received command: $($command.command)" -Level Debug
      Write-Log "Full Command Object: $($command | Out-String)" -Level Debug


      switch ($command.command) {
        "Start-VM" {
          try {
            Start-VM -Name $command.vmName
            Write-Log "Started VM $($command.vmName)" -Level Info
            $writer.WriteLine("VM started successfully")
          }
          catch {
            Write-Log "Error starting VM: $($_.Exception.Message)" -Level Error
            $writer.WriteLine("Error starting VM: $($_.Exception.Message)")
          }
        }
        "Stop-VM" {
          try {
            Stop-VM -Name $command.vmName -Force
            Write-Log "Stopped VM $($command.vmName)" -Level Info
            $writer.WriteLine("VM stopped successfully")
          }
          catch {
            Write-Log "Error stopping VM: $($_.Exception.Message)" -Level Error
            $writer.WriteLine("Error stopping VM: $($_.Exception.Message)")
          }
        }
        "Restart-VM" {
          try {
            Restart-VM -Name $command.vmName -Force
            Write-Log "Restarted VM $($command.vmName)" -Level Info
            $writer.WriteLine("VM restarted successfully")
          }
          catch {
            Write-Log "Error restarting VM: $($_.Exception.Message)" -Level Error
            $writer.WriteLine("Error restarting VM: $($_.Exception.Message)")
          }
        }
        "Suspend-VM" {
          try {
            Suspend-VM -Name $command.vmName
            Write-Log "Suspended VM $($command.vmName)" -Level Info
            $writer.WriteLine("VM suspended successfully")
          }
          catch {
            Write-Log "Error suspending VM: $($_.Exception.Message)" -Level Error
            $writer.WriteLine("Error suspending VM: $($_.Exception.Message)")
          }
        }
        default {
          Write-Log "Unknown command: $($command.command)" -Level Warning
          $writer.WriteLine("Unknown command")
        }
      }

      $writer.Flush()

    }
    catch {
      Write-Log "Error processing command: $($_.Exception.Message)" -Level Error
    }
    finally {
      $reader.Close()
      $writer.Close()
      $stream.Close()
      $client.Close()
    }
  }

  $listener.Stop()
}

# Main loop of the agent service
try {
    while ($true) {
        try {
            # Start the monitor loop and control listener in separate runspaces
            Write-Log "Starting Monitor Loop..." -Level Info
            Start-Job -ScriptBlock { Start-MonitorLoop } | Out-Null

            Write-Log "Starting Control Listener..." -Level Info
            Start-Job -ScriptBlock { Start-ControlListener } | Out-Null

            Write-Log "Agent started.  Monitoring and listening for commands..." -Level Info

            # Keep the main loop alive - check every 60 seconds if monitor and control listeners are still running
            while ($true) {
                Start-Sleep -Seconds 60

                # Check if jobs are still running
                $monitorJob = Get-Job | Where-Object {$_.ScriptBlock -like "*Start-MonitorLoop*"}
                $controlJob = Get-Job | Where-Object {$_.ScriptBlock -like "*Start-ControlListener*"}

                if ($monitorJob -eq $null -or $monitorJob.State -ne "Running") {
                    Write-Log "Monitor loop job has stopped. Restarting..." -Level Warning
                    Start-Job -ScriptBlock { Start-MonitorLoop } | Out-Null
                }

                if ($controlJob -eq $null -or $controlJob.State -ne "Running") {
                    Write-Log "Control listener job has stopped. Restarting..." -Level Warning
                    Start-Job -ScriptBlock { Start-ControlListener } | Out-Null
                }
            }
        }
        catch {
            Write-Log "Main loop error: $($_.Exception.Message)" -Level Error
        }
    }
}
finally {
    # Cleanup (optional)
    Write-Log "Agent service exiting..." -Level Info
    # Stop-Job commands would go here if you wanted a cleaner exit
}