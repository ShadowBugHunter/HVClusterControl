$sourceFiles = @(
    ".\AgentService.ps1",
    ".\ManageAgentService.ps1",
    ".\TestAgent.ps1",
    ".\config.json"
)

$targetComputers = @("172.25.0.11", "172.25.0.12")   # "172.25.0.11", "172.25.0.12", "172.25.0.10"
$targetFolder = "C$\Script\"

foreach ($computer in $targetComputers) {
    $destination = "\\$computer\$targetFolder"
    
    if (!(Test-Path $destination)) {
        Write-Host "Создаю папку $destination на $computer"
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
    }
    
    foreach ($file in $sourceFiles) {
        $fileName = Split-Path -Path $file -Leaf
        $destFile = Join-Path -Path $destination -ChildPath $fileName
        
        Write-Host "Копирование $file -> $destFile"
        Copy-Item -Path $file -Destination $destFile -Force -ErrorAction Continue
    }
}

Write-Host "Копирование завершено."
