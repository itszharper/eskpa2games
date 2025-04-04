# ESKPA2 Games Fixer - PowerShell Mejorado
# Versión 2.0

# Configuración inicial
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"

# Función para verificar privilegios de administrador
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Función para solicitar privilegios de administrador si no los tiene
function Request-AdminPrivileges {
    if (-not (Test-Administrator)) {
        $scriptPath = $PSCommandPath
        Start-Process PowerShell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        exit
    }
}

# Función para mostrar el banner con colores correctos
function Show-Banner {
    Clear-Host
    Write-Host "╔═════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ " -ForegroundColor Cyan -NoNewline
    Write-Host "ESKPA2 Games Fixer" -ForegroundColor White -BackgroundColor Black -NoNewline
    Write-Host "                                        ║" -ForegroundColor Cyan
    Write-Host "║ " -ForegroundColor Cyan -NoNewline
    Write-Host "By zHarper your daddy" -ForegroundColor Yellow -NoNewline
    Write-Host "                                      ║" -ForegroundColor Cyan
    Write-Host "╚═════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# Función mejorada para mostrar animación
function Show-SpinnerAnimation {
    param (
        [string]$Text,
        [int]$Seconds
    )

    $spinChars = "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($Seconds)

    Write-Host ""
    while ((Get-Date) -lt $endTime) {
        foreach ($spinChar in $spinChars) {
            Write-Host "`r$spinChar $Text" -ForegroundColor Cyan -NoNewline
            Start-Sleep -Milliseconds 80
            if ((Get-Date) -ge $endTime) {
                break
            }
        }
    }
    Write-Host "`r                                                                      " -NoNewline
    Write-Host "`r" -NoNewline
}

# Función mejorada para mostrar el menú de selección de juego
function Show-GameMenu {
    Write-Host ""
    Write-Host "╔═════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ " -ForegroundColor Cyan -NoNewline
    Write-Host "Selecciona un juego:" -ForegroundColor White -NoNewline
    Write-Host "                                         ║" -ForegroundColor Cyan
    Write-Host "║                                                             ║" -ForegroundColor Cyan
    Write-Host "║ " -ForegroundColor Cyan -NoNewline
    Write-Host "1. Schedule 1" -ForegroundColor Yellow -NoNewline
    Write-Host "                                                ║" -ForegroundColor Cyan
    Write-Host "║ " -ForegroundColor Cyan -NoNewline
    Write-Host "2. REPO" -ForegroundColor Yellow -NoNewline
    Write-Host "                                                      ║" -ForegroundColor Cyan
    Write-Host "╚═════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    do {
        Write-Host "Ingresa tu elección: " -ForegroundColor Green -NoNewline
        $choice = Read-Host
        
        if ($choice -match "^[1-2]$") {
            return [int]$choice
        } else {
            Write-Host "Opción inválida. Por favor ingresa 1 o 2." -ForegroundColor Red
        }
    } while ($true)
}

# Función mejorada para obtener carpetas según el juego seleccionado
function Get-GameFolders {
    param (
        [int]$GameChoice
    )

    switch ($GameChoice) {
        1 { return @("Schedule 1 ESKPA2 Uploaded", "Schedule 1") }
        2 { return @("R.E.P.O. ESKPA2 Uploaded", "R.E.P.O") }
        default { return @() }
    }
}

# Función mejorada para buscar carpetas (búsqueda más profunda y precisa)
function Find-GameFolders {
    param (
        [string[]]$FolderNames
    )
    
    $foundFolders = @()
    
    # Buscar en carpeta de Descargas (prioridad alta)
    $downloadsPath = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
    foreach ($folderName in $FolderNames) {
        $potentialPath = Join-Path -Path $downloadsPath -ChildPath $folderName
        if (Test-Path -Path $potentialPath -PathType Container) {
            $foundFolders += $potentialPath
        }
    }
    
    # Buscar en unidades principales con prioridad en carpetas comunes de juegos
    $commonGamePaths = @(
        "$env:ProgramFiles\Steam\steamapps\common",
        "$env:ProgramFiles (x86)\Steam\steamapps\common",
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Documents",
        "D:\Games",
        "D:\SteamLibrary\steamapps\common",
        "E:\Games",
        "E:\SteamLibrary\steamapps\common"
    )
    
    foreach ($basePath in $commonGamePaths) {
        if (Test-Path -Path $basePath) {
            foreach ($folderName in $FolderNames) {
                $potentialPath = Join-Path -Path $basePath -ChildPath $folderName
                if (Test-Path -Path $potentialPath -PathType Container) {
                    $foundFolders += $potentialPath
                }
            }
        }
    }
    
    # Búsqueda más profunda en todas las unidades (limitar la profundidad para velocidad)
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
    
    foreach ($drive in $drives) {
        $drivePath = "$($drive.Name):\"
        try {
            # Primo nivel
            $firstLevelDirs = Get-ChildItem -Path $drivePath -Directory
            foreach ($dir in $firstLevelDirs) {
                foreach ($folderName in $FolderNames) {
                    $potentialPath = Join-Path -Path $dir.FullName -ChildPath $folderName
                    if (Test-Path -Path $potentialPath -PathType Container) {
                        $foundFolders += $potentialPath
                    }
                }
                
                # Segundo nivel (solo carpetas específicas donde es probable encontrar juegos)
                $commonSubfolders = @("Games", "Steam", "Program Files", "Program Files (x86)", "Users")
                if ($commonSubfolders -contains $dir.Name) {
                    try {
                        $secondLevelDirs = Get-ChildItem -Path $dir.FullName -Directory
                        foreach ($subDir in $secondLevelDirs) {
                            foreach ($folderName in $FolderNames) {
                                $potentialPath = Join-Path -Path $subDir.FullName -ChildPath $folderName
                                if (Test-Path -Path $potentialPath -PathType Container) {
                                    $foundFolders += $potentialPath
                                }
                            }
                            
                            # Tercer nivel (limitado a carpetas específicas)
                            if (@("steamapps", "common", "Documents", "Downloads") -contains $subDir.Name) {
                                try {
                                    $thirdLevelDirs = Get-ChildItem -Path $subDir.FullName -Directory
                                    foreach ($subSubDir in $thirdLevelDirs) {
                                        foreach ($folderName in $FolderNames) {
                                            $potentialPath = Join-Path -Path $subSubDir.FullName -ChildPath $folderName
                                            if (Test-Path -Path $potentialPath -PathType Container) {
                                                $foundFolders += $potentialPath
                                            }
                                        }
                                    }
                                } catch {}
                            }
                        }
                    } catch {}
                }
            }
        } catch {}
    }
    
    # Buscar en ubicaciones específicas
    $specificPaths = @(
        "$env:USERPROFILE",
        "C:\Users\Public\Documents",
        "C:\Users\Public\Downloads"
    )
    
    foreach ($specificPath in $specificPaths) {
        if (Test-Path -Path $specificPath) {
            foreach ($folderName in $FolderNames) {
                $potentialPath = Join-Path -Path $specificPath -ChildPath $folderName
                if (Test-Path -Path $potentialPath -PathType Container) {
                    $foundFolders += $potentialPath
                }
            }
        }
    }
    
    # Eliminar duplicados y devolver resultados únicos
    return $foundFolders | Select-Object -Unique
}

# Función para agregar exclusiones de seguridad
function Add-SecurityExclusion {
    param (
        [string]$FolderPath
    )
    
    try {
        Add-MpPreference -ExclusionPath $FolderPath -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Función principal
function Start-GameFixer {
    # Verificar y solicitar privilegios de administrador
    Request-AdminPrivileges
    
    # Mostrar banner
    Show-Banner
    
    # Mostrar menú y obtener selección
    $gameChoice = Show-GameMenu
    
    # Obtener los nombres de carpetas para el juego seleccionado
    $folderNames = Get-GameFolders -GameChoice $gameChoice
    
    # Mostrar carpetas a buscar
    Write-Host ""
    Write-Host "Buscando las siguientes carpetas:" -ForegroundColor White
    foreach ($folder in $folderNames) {
        Write-Host "• $folder" -ForegroundColor Cyan
    }
    
    # Buscar carpetas
    Show-SpinnerAnimation -Text "Buscando carpetas en el sistema (esto puede tardar unos momentos)..." -Seconds 3
    $foundFolders = Find-GameFolders -FolderNames $folderNames
    
    # Mostrar resultados
    Write-Host ""
    if ($foundFolders.Count -eq 0) {
        Write-Host "No se encontraron las carpetas especificadas." -ForegroundColor Red
        Write-Host ""
        Write-Host "Comprueba que las carpetas existen y que tienes acceso a ellas." -ForegroundColor Yellow
        Write-Host "Puedes intentar ejecutar la aplicación de nuevo o buscar manualmente." -ForegroundColor Yellow
    } else {
        Write-Host "Se encontraron las siguientes carpetas:" -ForegroundColor Green
        for ($i = 0; $i -lt $foundFolders.Count; $i++) {
            Write-Host "$($i+1). $($foundFolders[$i])" -ForegroundColor White
        }
        
        # Agregar exclusiones
        Write-Host ""
        Write-Host "Agregando carpetas a las exclusiones de Seguridad de Windows..." -ForegroundColor Yellow
        $successCount = 0
        
        foreach ($folder in $foundFolders) {
            Show-SpinnerAnimation -Text "Procesando $(Split-Path -Path $folder -Leaf)" -Seconds 1
            $result = Add-SecurityExclusion -FolderPath $folder
            
            if ($result) {
                Write-Host "✓ Exclusión agregada: $folder" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "✗ No se pudo agregar la exclusión: $folder" -ForegroundColor Red
            }
        }
        
        # Mostrar resumen
        Write-Host ""
        Write-Host "╔═════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║ " -ForegroundColor Cyan -NoNewline
        Write-Host "Proceso completado" -ForegroundColor White -NoNewline
        Write-Host "                                         ║" -ForegroundColor Cyan
        Write-Host "║ " -ForegroundColor Cyan -NoNewline
        Write-Host "Agregadas " -ForegroundColor White -NoNewline
        Write-Host "$successCount" -ForegroundColor Green -NoNewline
        Write-Host " de " -ForegroundColor White -NoNewline
        Write-Host "$($foundFolders.Count)" -ForegroundColor Yellow -NoNewline
        Write-Host " carpetas a las exclusiones" -ForegroundColor White -NoNewline
        Write-Host "        ║" -ForegroundColor Cyan
        Write-Host "╚═════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    }
    
    # Esperar a que el usuario presione una tecla
    Write-Host ""
    Write-Host "Presiona cualquier tecla para salir..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Iniciar la aplicación
Start-GameFixer
