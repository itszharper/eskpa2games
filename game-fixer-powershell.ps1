# ESKPA2 Games Fixer - PowerShell version
# Based on the Python original by zHarper

# Importar ensamblados necesarios para algunas funcionalidades
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Variable global para controlar la animación
$script:stopAnimation = $false

function Show-BrailleAnimation {
    param (
        [string]$message
    )
    
    $brailleChars = "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
    
    while (-not $script:stopAnimation) {
        foreach ($char in $brailleChars) {
            if ($script:stopAnimation) { break }
            
            Write-Host "`r$char $message" -ForegroundColor Cyan -NoNewline
            Start-Sleep -Milliseconds 100
        }
    }
    
    Write-Host "`r$(" " * ($message.Length + 2))" -NoNewline
}

function Start-Animation {
    param (
        [string]$message
    )
    
    $script:stopAnimation = $false
    
    $job = Start-Job -ScriptBlock {
        param($message)
        
        $brailleChars = "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
        
        while ($true) {
            foreach ($char in $brailleChars) {
                Write-Host "`r$char $message" -ForegroundColor Cyan -NoNewline
                Start-Sleep -Milliseconds 100
            }
        }
    } -ArgumentList $message
    
    return $job
}

function Stop-AnimationThread {
    param (
        [System.Management.Automation.Job]$job
    )
    
    $script:stopAnimation = $true
    Stop-Job -Job $job
    Remove-Job -Job $job
    Start-Sleep -Milliseconds 200
    Write-Host "`r$(" " * 80)" -NoNewline
}

function Show-Banner {
    $banner = @"

[36m╔══════════════════════════════════════════════════════════╗
[36m║ [97m[1mESKPA2 Games Fixer[0m[36m
[36m║ [33mBy zHarper your daddy[0m[36m    
[36m╚══════════════════════════════════════════════════════════╝[0m
"@
    
    Write-Host $banner
}

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminPrivileges {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
}

function Get-AllDrives {
    return Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null } | ForEach-Object { "$($_.Name):\" }
}

function Find-GameFolders {
    param (
        [string[]]$folderNames
    )
    
    $foundFolders = @()
    
    # Buscar en Descargas
    $downloadsPath = [System.IO.Path]::Combine([Environment]::GetFolderPath("UserProfile"), "Downloads")
    if (Test-Path -Path $downloadsPath) {
        foreach ($folderName in $folderNames) {
            $folderPath = Join-Path -Path $downloadsPath -ChildPath $folderName
            if (Test-Path -Path $folderPath) {
                $foundFolders += $folderPath
            }
        }
    }
    
    # Buscar en todas las unidades
    foreach ($drive in (Get-AllDrives)) {
        if (Test-Path -Path $drive) {
            try {
                $searchDepth = 0
                Get-ChildItem -Path $drive -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($searchDepth -ge 3) { return }
                    
                    $dirPath = $_.FullName
                    $searchDepth++
                    
                    foreach ($folderName in $folderNames) {
                        $targetPath = Join-Path -Path $dirPath -ChildPath $folderName
                        if (Test-Path -Path $targetPath -PathType Container) {
                            $foundFolders += $targetPath
                        }
                    }
                    
                    # Buscar un nivel más abajo
                    Get-ChildItem -Path $dirPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                        $subDirPath = $_.FullName
                        
                        foreach ($folderName in $folderNames) {
                            $targetPath = Join-Path -Path $subDirPath -ChildPath $folderName
                            if (Test-Path -Path $targetPath -PathType Container) {
                                $foundFolders += $targetPath
                            }
                        }
                        
                        # Un nivel más
                        Get-ChildItem -Path $subDirPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                            $subSubDirPath = $_.FullName
                            
                            foreach ($folderName in $folderNames) {
                                $targetPath = Join-Path -Path $subSubDirPath -ChildPath $folderName
                                if (Test-Path -Path $targetPath -PathType Container) {
                                    $foundFolders += $targetPath
                                }
                            }
                        }
                    }
                }
            }
            catch {
                # Ignorar errores de acceso denegado
            }
        }
    }
    
    return $foundFolders
}

function Add-SecurityExclusion {
    param (
        [string]$folderPath
    )
    
    try {
        Add-MpPreference -ExclusionPath $folderPath -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "Error al añadir exclusión para $folderPath`: $_" -ForegroundColor Red
        return $false
    }
}

function Show-GameMenu {
    Write-Host "`n[36m╔══════════════════════════════════════════════════════════╗[0m"
    Write-Host "[36m║ [97m[1mSelecciona un juego:[0m[36m                                         [0m"
    Write-Host "[36m║                                                          [0m"
    Write-Host "[36m║ [33m1. Schedule 1[0m[36m                                          [0m"
    Write-Host "[36m║ [33m2. REPO[0m[36m                                                [0m"
    Write-Host "[36m╚══════════════════════════════════════════════════════════╝[0m"
    
    while ($true) {
        try {
            Write-Host "`n[32mIngresa tu elección: [0m" -NoNewline
            $choice = [int](Read-Host)
            
            if ($choice -ge 1 -and $choice -le 2) {
                return $choice
            }
            else {
                Write-Host "Opción inválida. Por favor ingresa un número entre 1 y 2." -ForegroundColor Red
            }
        }
        catch {
            Write-Host "Por favor ingresa un número válido." -ForegroundColor Red
        }
    }
}

function Get-FoldersForGame {
    param (
        [int]$gameChoice
    )
    
    switch ($gameChoice) {
        1 { return @("Schedule 1 ESKPA2 Uploaded", "Schedule 1", "Schedule 1") }
        2 { return @("R.E.P.O. ESKPA2 Uploaded", "R.E.P.O") }
        3 {
            Write-Host "`n[33mIngresa los nombres de carpetas separados por comas:[0m"
            Write-Host "[32m> [0m" -NoNewline
            $customFolders = Read-Host
            return $customFolders -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        }
        default { return @() }
    }
}

function Start-Main {
    if (-not (Test-Admin)) {
        Write-Host "Solicitando privilegios de administrador..." -ForegroundColor Yellow
        Request-AdminPrivileges
        exit
    }
    
    Clear-Host
    Show-Banner
    
    $gameChoice = Show-GameMenu
    $folderNames = Get-FoldersForGame -gameChoice $gameChoice
    
    if ($folderNames.Count -eq 0) {
        Write-Host "No se especificaron carpetas para buscar." -ForegroundColor Red
        return
    }
    
    Write-Host "`n[97mBuscando las siguientes carpetas:[0m"
    foreach ($folder in $folderNames) {
        Write-Host "[36m• $folder[0m"
    }
    
    Write-Host ""
    $animationJob = Start-Animation -message "Buscando carpetas en el sistema"
    
    $foundFolders = Find-GameFolders -folderNames $folderNames
    
    Stop-AnimationThread -job $animationJob
    
    if ($foundFolders.Count -eq 0) {
        Write-Host "No se encontraron las carpetas especificadas." -ForegroundColor Red
        return
    }
    
    Write-Host "`n[32mSe encontraron las siguientes carpetas:[0m"
    for ($i = 0; $i -lt $foundFolders.Count; $i++) {
        Write-Host "[36m$($i+1). [97m$($foundFolders[$i])[0m"
    }
    
    Write-Host "`n[33mAgregando carpetas a las exclusiones de Seguridad de Windows...[0m"
    $successCount = 0
    
    foreach ($folder in $foundFolders) {
        $animationJob = Start-Animation -message "Procesando $(Split-Path -Path $folder -Leaf)"
        Start-Sleep -Seconds 1
        $result = Add-SecurityExclusion -folderPath $folder
        Stop-AnimationThread -job $animationJob
        
        if ($result) {
            Write-Host "[32m✓ Exclusión agregada: $folder[0m"
            $successCount++
        }
        else {
            Write-Host "[31m✗ No se pudo agregar la exclusión: $folder[0m"
        }
    }
    
    Write-Host "`n[36m╔════════════════════════════════════════════╗[0m"
    Write-Host "[36m║ [97mProceso completado                                      [36m[0m"
    Write-Host "[36m║ [97mAgregadas [32m$successCount[97m de [33m$($foundFolders.Count)[97m carpetas a las exclusiones [36m[0m"
    Write-Host "[36m╚══════════════════════════════════════════════════════════╝[0m"
    
    Write-Host "`n[33mPresiona Enter para salir...[0m" -NoNewline
    Read-Host
}

# Iniciar el script
Start-Main
