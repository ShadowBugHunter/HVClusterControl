# Переменные для настройки
$gitInstallerUrl = "C:\distr\Git-2.47.1.2-64-bit.exe"
$gitInstallPath = "C:\Program Files\Git"
$gitHubUserName = "ShadowBugHunter"
$gitHubEmail = "lva_vladimir@outlook.com"
$gitHubRepoUrl = "https://github.com/ShadowBugHunter/HVClusterControl.git"
$localRepoPath = "C:\MyProjects"

# Функция для загрузки и установки Git
Function Install-Git {
    $installerPath = "$env:TEMP\GitInstaller.exe"
    Invoke-WebRequest -Uri $gitInstallerUrl -OutFile $installerPath
    Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT", "/DIR=$gitInstallPath" -Wait
    Remove-Item $installerPath
}

# Установка Git
Install-Git

# Настройка Git
& "$gitInstallPath\cmd\git.exe" config --global user.name $gitHubUserName
& "$gitInstallPath\cmd\git.exe" config --global user.email $gitHubEmail

# Клонирование репозитория
& "$gitInstallPath\cmd\git.exe" clone $gitHubRepoUrl $localRepoPath

Write-Host "Git установлен и настроен. Репозиторий клонирован в $localRepoPath"
