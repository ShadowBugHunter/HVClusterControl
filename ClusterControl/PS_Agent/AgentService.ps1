# AgentService.ps1
# Замените <путь_к_скрипту> фактическим путем к вашему скрипту
# Configuration
$ServerAddress = "172.25.0.50" # Change to the IP address of your management server
$MonitorPort = 5001
$ControlPort = 5002
$AgentId = "agent001" # Replace with a unique identifier for this agent
$ServiceName = "ClusterControlAgent" # Имя службы

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
    Write-Error "Error getting VM data: $($_.Exception.Message)"
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
  }
  catch {
    Write-Error "Error sending data: $($_.Exception.Message)"
  }
}

# Monitor Loop (Sends data to server)
function Start-MonitorLoop {
  while ($true) {
    $vmData = Get-VMData
    if ($vmData) {
      $data = @{
        agentId = $AgentId
        vmData  = $vmData
      } | ConvertTo-Json

      Send-DataToServer -Server $ServerAddress -Port $MonitorPort -Data $data
      Write-Host "Data sent to server"
    }
    else {
      Write-Host "No VM data to send."
    }
    Start-Sleep -Seconds 60 # Adjust as needed
  }
}

# Control Listener (Receives and executes commands)
function Start-ControlListener {
  $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $ControlPort)
  $listener.Start()
  Write-Host "Listening for commands on port $ControlPort..."

  while ($true) {
    $client = $listener.AcceptTcpClient()
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)

    try {
      $commandJson = $reader.ReadLine()
      $command = ConvertFrom-Json -InputObject $commandJson

      Write-Host "Received command: $($command.command)"
      Write-Host "Full Command Object: $($command | Out-String)"


      switch ($command.command) {
        "Start-VM" {
          try {
            Start-VM -Name $command.vmName
            Write-Host "Started VM $($command.vmName)"
            $writer.WriteLine("VM started successfully")
          }
          catch {
            Write-Error "Error starting VM: $($_.Exception.Message)"
            $writer.WriteLine("Error starting VM: $($_.Exception.Message)")
          }
        }
        "Stop-VM" {
          try {
            Stop-VM -Name $command.vmName -Force
            Write-Host "Stopped VM $($command.vmName)"
            $writer.WriteLine("VM stopped successfully")
          }
          catch {
            Write-Error "Error stopping VM: $($_.Exception.Message)"
            $writer.WriteLine("Error stopping VM: $($_.Exception.Message)")
          }
        }
        "Restart-VM" {
          try {
            Restart-VM -Name $command.vmName -Force
            Write-Host "Restarted VM $($command.vmName)"
            $writer.WriteLine("VM restarted successfully")
          }
          catch {
            Write-Error "Error restarting VM: $($_.Exception.Message)"
            $writer.WriteLine("Error restarting VM: $($_.Exception.Message)")
          }
        }
        "Suspend-VM" {
          try {
            Suspend-VM -Name $command.vmName
            Write-Host "Suspended VM $($command.vmName)"
            $writer.WriteLine("VM suspended successfully")
          }
          catch {
            Write-Error "Error suspending VM: $($_.Exception.Message)"
            $writer.WriteLine("Error suspending VM: $($_.Exception.Message)")
          }
        }
        default {
          Write-Warning "Unknown command: $($command.command)"
          $writer.WriteLine("Unknown command")
        }
      }

      $writer.Flush()

    }
    catch {
      Write-Error "Error processing command: $($_.Exception.Message)"
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
            Write-Host "Starting Monitor Loop..."
            Start-Job -ScriptBlock { Start-MonitorLoop } | Out-Null

            Write-Host "Starting Control Listener..."
            Start-Job -ScriptBlock { Start-ControlListener } | Out-Null

            Write-Host "Agent started.  Monitoring and listening for commands..."

            # Keep the main loop alive - check every 60 seconds if monitor and control listeners are still running
            while ($true) {
                Start-Sleep -Seconds 60

                # Check if jobs are still running
                $monitorJob = Get-Job | Where-Object {$_.ScriptBlock -like "*Start-MonitorLoop*"}
                $controlJob = Get-Job | Where-Object {$_.ScriptBlock -like "*Start-ControlListener*"}

                if ($monitorJob -eq $null -or $monitorJob.State -ne "Running") {
                    Write-Warning "Monitor loop job has stopped. Restarting..."
                    Start-Job -ScriptBlock { Start-MonitorLoop } | Out-Null
                }

                if ($controlJob -eq $null -or $controlJob.State -ne "Running") {
                    Write-Warning "Control listener job has stopped. Restarting..."
                    Start-Job -ScriptBlock { Start-ControlListener } | Out-Null
                }
            }
        }
        catch {
            Write-Error "Main loop error: $($_.Exception.Message)"
        }
    }
}
finally {
    # Cleanup (optional)
    Write-Host "Agent service exiting..."
    # Stop-Job commands would go here if you wanted a cleaner exit
}