# ESKPA2 Games Fixer - Versión simplificada

# Comprobar privilegios de administrador
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Solicitar privilegios de administrador si no los tiene
function Request-AdminRights {
    if (-not (Test-Admin)) {
        $scriptPath = $PSCommandPath
        Start-Process PowerShell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        exit
    }
}

# Mostrar un mensaje simple al usuario
function Show-SimpleMessage {
    Clear-Host
    Write-Host "ESKPA2 Games Fixer"
    Write-Host "By zHarper"
    Write-Host "-----------------"
    Write-Host ""
}

# Función para buscar carpetas en todas las ubicaciones posibles
function Find-AllGameFolders {
    param (
        [string[]]$FolderNames
    )
    
    Write-Host "Buscando las siguientes carpetas:" 
    foreach ($folder in $FolderNames) {
        Write-Host "- $folder"
    }
    Write-Host ""
    
    $allFoundFolders = @()
    
    # PASO 1: Buscar en Descargas (alta prioridad)
    Write-Host "Buscando en Descargas..."
    $downloadsPath = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
    foreach ($folderName in $FolderNames) {
        $folderPath = Join-Path -Path $downloadsPath -ChildPath $folderName
        if (Test-Path -Path $folderPath -PathType Container) {
            $allFoundFolders += $folderPath
            Write-Host "Encontrada: $folderPath"
        }
    }
    
    # PASO 2: Buscar en todas las unidades disponibles
    Write-Host "Buscando en todas las unidades disponibles..."
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match "^\w:\\" }
    
    foreach ($drive in $drives) {
        $drivePath = $drive.Root
        Write-Host "Buscando en unidad $drivePath..."
        
        # Buscar recursivamente (con límite de profundidad)
        try {
            # Nivel 1 de directorios
            $firstLevelDirs = Get-ChildItem -Path $drivePath -Directory -ErrorAction SilentlyContinue
            
            foreach ($dir in $firstLevelDirs) {
                # Comprobar en este nivel
                foreach ($folderName in $FolderNames) {
                    $checkPath = Join-Path -Path $dir.FullName -ChildPath $folderName
                    if (Test-Path -Path $checkPath -PathType Container) {
                        $allFoundFolders += $checkPath
                        Write-Host "Encontrada: $checkPath"
                    }
                }
                
                # Profundizar un nivel más
                try {
                    $secondLevelDirs = Get-ChildItem -Path $dir.FullName -Directory -ErrorAction SilentlyContinue
                    foreach ($subDir in $secondLevelDirs) {
                        foreach ($folderName in $FolderNames) {
                            $checkPath = Join-Path -Path $subDir.FullName -ChildPath $folderName
                            if (Test-Path -Path $checkPath -PathType Container) {
                                $allFoundFolders += $checkPath
                                Write-Host "Encontrada: $checkPath"
                            }
                        }
                        
                        # Un nivel más de profundidad
                        try {
                            $thirdLevelDirs = Get-ChildItem -Path $subDir.FullName -Directory -ErrorAction SilentlyContinue
                            foreach ($subSubDir in $thirdLevelDirs) {
                                foreach ($folderName in $FolderNames) {
                                    $checkPath = Join-Path -Path $subSubDir.FullName -ChildPath $folderName
                                    if (Test-Path -Path $checkPath -PathType Container) {
                                        $allFoundFolders += $checkPath
                                        Write-Host "Encontrada: $checkPath"
                                    }
                                }
                            }
                        } catch {}
                    }
                } catch {}
            }
        } catch {}
    }
    
    # PASO 3: Buscar en ubicaciones específicas adicionales
    $additionalPaths = @(
        "$env:USERPROFILE\Desktop",
        "$env:USERPROFILE\Documents",
        "$env:PUBLIC\Documents",
        "$env:PUBLIC\Downloads",
        "C:\Games",
        "D:\Games",
        "E:\Games"
    )
    
    foreach ($path in $additionalPaths) {
        if (Test-Path -Path $path) {
            foreach ($folderName in $FolderNames) {
                $checkPath = Join-Path -Path $path -ChildPath $folderName
                if (Test-Path -Path $checkPath -PathType Container) {
                    $allFoundFolders += $checkPath
                    Write-Host "Encontrada: $checkPath"
                }
            }
        }
    }
    
    return $allFoundFolders
}

# Función para agregar exclusiones a Windows Defender
function Add-DefenderExclusion {
    param (
        [string]$FolderPath
    )
    
    try {
        Add-MpPreference -ExclusionPath $FolderPath -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

# Función principal con menú simplificado
function Start-GamesFixer {
    # Verificar privilegios
    Request-AdminRights
    
    # Mostrar mensaje simple
    Show-SimpleMessage
    
    # Menú simplificado
    Write-Host "Selecciona un juego:"
    Write-Host "1. Schedule 1"
    Write-Host "2. REPO"
    Write-Host ""
    
    $choice = Read-Host "Ingresa tu elección (1 o 2)"
    
    # Determinar las carpetas según la elección
    $gamefolders = @()
    if ($choice -eq "1") {
        $gamefolders = @("Schedule 1 ESKPA2 Uploaded", "Schedule 1")
    } elseif ($choice -eq "2") {
        $gamefolders = @("R.E.P.O. ESKPA2 Uploaded", "R.E.P.O")
    } else {
        Write-Host "Opción no válida. Saliendo."
        exit
    }
    
    # Buscar las carpetas
    Write-Host ""
    Write-Host "Iniciando búsqueda. Esto puede tardar unos minutos..."
    $foundFolders = Find-AllGameFolders -FolderNames $gamefolders
    
    # Procesar resultados
    Write-Host ""
    if ($foundFolders.Count -eq 0) {
        Write-Host "No se encontraron carpetas de juego."
    } else {
        Write-Host "Se encontraron $($foundFolders.Count) carpetas en total."
        Write-Host "Agregando exclusiones a Windows Security..."
        
        $successCount = 0
        foreach ($folder in $foundFolders) {
            Write-Host "Procesando: $folder"
            if (Add-DefenderExclusion -FolderPath $folder) {
                Write-Host "+ Exclusión agregada correctamente" 
                $successCount++
            } else {
                Write-Host "- Error al agregar exclusión"
            }
        }
        
        # Mostrar resumen
        Write-Host ""
        Write-Host "Proceso completado."
        Write-Host "Carpetas encontradas: $($foundFolders.Count)"
        Write-Host "Exclusiones agregadas correctamente: $successCount"
    }
    
    # Finalizar
    Write-Host ""
    Write-Host "Presiona Enter para salir..."
    Read-Host
}

# Ejecutar la función principal
Start-GamesFixer
