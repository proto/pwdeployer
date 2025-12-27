<#
.SYNOPSIS
    pwdeployer - v0.0.1a
    PowerShell Deployment Orchestrator: gestione avanzata di progetti PowerShell.

.DESCRIPTION
    pwdeployer automatizza:
    - Creazione guidata della configurazione (project.json)
    - Versionamento semantico (SemVer)
    - Backup automatici pre-deploy
    - Deploy intelligente di file e moduli
    - Generazione automatica di changelog e header

    STRUTTURA DEL PROGETTO:
    - SRC_DEPLOY/       (file da deployare)
    - Modules/          (moduli PowerShell)
    - DEV_BACKUP/       (backup automatici)
    - project.json      (configurazione)
    - CHANGELOG.md     (storia delle modifiche)

.PARAMETER Note
    Nota descrittiva per il changelog.

.PARAMETER Force
    Forza lo svuotamento di SRC_DEPLOY senza conferma.

.PARAMETER SkipBackup
    Salta il backup pre-deploy.

.PARAMETER NewVersion
    Nuova versione del progetto (formato SemVer).

.PARAMETER Help
    Mostra questo messaggio di help e esce.

.EXAMPLE
    .\pwdeployer.ps1
    Avvia il wizard di configurazione.

.EXAMPLE
    .\pwdeployer.ps1 -Note "Aggiunto modulo Utility" -NewVersion "1.0.0"
    Esegue deploy con nota e nuova versione.

.EXAMPLE
    .\pwdeployer.ps1 -Help
    Mostra questo messaggio di help.

.NOTES
    File:        pwdeployer.ps1
    Version:     v0.0.1a
    Author:      proto
    License:     MIT
    Requirements: PowerShell 7+
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Note,

    [Parameter(Mandatory = $false)]
    [Switch]$Force,

    [Parameter(Mandatory = $false)]
    [Switch]$SkipBackup,

    [Parameter(Mandatory = $false)]
    [Switch]$Help,

    [Parameter(Mandatory = $false)]
    [string]$NewVersion
)

# Mostra help se richiesto
if ($Help) {
    # Mostra l'help senza riferimenti a percorsi completi
    Write-Host @"

pwdeployer - v0.0.1a
PowerShell Deployment Orchestrator

USAGE:
    .\pwdeployer.ps1 [parametri]

PARAMETERS:
    -Note <string>
        Nota descrittiva per il changelog.

    -Force
        Forza lo svuotamento di SRC_DEPLOY senza conferma.

    -SkipBackup
        Salta il backup pre-deploy.

    -NewVersion <string>
        Nuova versione del progetto (formato SemVer).

    -Help
        Mostra questo messaggio di help.

EXAMPLES:
    .\pwdeployer.ps1
        Avvia il wizard di configurazione.

    .\pwdeployer.ps1 -Note "Aggiunto modulo Utility" -NewVersion "1.0.0"
        Esegue deploy con nota e nuova versione.

    .\pwdeployer.ps1 -Help
        Mostra questo messaggio di help.

"@
    exit 0
}

# --- 1. RILEVAMENTO PROGETTO ---
$projectRoot = $PWD
$jsonPath = Join-Path -Path $projectRoot -ChildPath "project.json"

# Creazione project.json se mancante
if (-not (Test-Path -Path $jsonPath)) {
    Write-Host "`n[pwdeployer] Configurazione guidata del progetto" -ForegroundColor Cyan
    Write-Host "Premere Invio per accettare i valori predefiniti." -ForegroundColor Gray

    # Nome progetto
    $appName = Read-Host "`nNome del progetto (Progetto)"
    if ([string]::IsNullOrWhiteSpace($appName)) { $appName = "Progetto" }

    # Versione con validazione
    do {
        $version = Read-Host "Versione iniziale (0.0.0-alpha)"
        if ([string]::IsNullOrWhiteSpace($version)) { $version = "0.0.0-alpha" }
        if ($version -notmatch '^\d+\.\d+\.\d+(?:-[a-zA-Z]+)?$') {
            Write-Host "Formato non valido. Usare X.Y.Z o X.Y.Z-suffix (es: 1.0.0-alpha)" -ForegroundColor Red
        }
    } while ($version -notmatch '^\d+\.\d+\.\d+(?:-[a-zA-Z]+)?$')

    # Altri campi con default
    $codeName = Read-Host "Nome in codice (CodiceProgetto)"
    if ([string]::IsNullOrWhiteSpace($codeName)) { $codeName = "CodiceProgetto" }

    $description = Read-Host "Descrizione (Backend PowerShell)"
    if ([string]::IsNullOrWhiteSpace($description)) { $description = "Backend PowerShell" }

    $author = Read-Host "Autore (proto)"
    if ([string]::IsNullOrWhiteSpace($author)) { $author = "meh" }

    $license = Read-Host "Licenza (MIT)"
    if ([string]::IsNullOrWhiteSpace($license)) { $license = "MIT" }

    $devPath = Read-Host "Percorso sviluppo (.)"
    if ([string]::IsNullOrWhiteSpace($devPath)) { $devPath = "." }

    $prodPath = Read-Host "Percorso produzione (app_data)"
    if ([string]::IsNullOrWhiteSpace($prodPath)) { $prodPath = "app_data" }

    # Creazione del file con ordine specifico
    $config = [ordered]@{
        Project = [ordered]@{
            AppName = $appName
            Version = $version
            CodeName = $codeName
            Build = "$(Get-Date -Format 'yyyyMMdd').01"
            Description = $description
            Author = $author
            License = $license
            ReleaseDate = Get-Date -Format "yyyy-MM-dd"
            Environment = "DEVELOPMENT"
            Paths = [ordered]@{
                DEVELOPMENT = $devPath
                PRODUCTION = $prodPath
            }
        }
    }

    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Force
    Write-Host "`n[OK] project.json creato con successo!" -ForegroundColor Green
    Write-Host "Ecco la configurazione salvata:"
    Get-Content -Path $jsonPath | Write-Host
}

# Caricamento configurazione
$config = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
$currentAppName = $config.Project.AppName
$currentVersion = $config.Project.Version

# Validazione versione
if ($currentVersion -notmatch '^\d+\.\d+\.\d+(?:-[a-zA-Z]+)?$') {
    Write-Host "[WARN] Formato versione non valido in project.json" -ForegroundColor Yellow
}

# --- 2. NOTA DI DEPLOY ---
$deployNote = $Note
if (-not $SkipBackup -and [string]::IsNullOrEmpty($deployNote)) {
    $deployNote = Read-Host "`nNota per il deploy (v.$currentVersion):"
}
if (-not $SkipBackup -and [string]::IsNullOrWhiteSpace($deployNote)) {
    Throw "[ERR] Nota obbligatoria per il deploy."
}

# Aggiornamento versione
if ($NewVersion) {
    if ($NewVersion -notmatch '^\d+\.\d+\.\d+(?:-[a-zA-Z]+)?$') {
        Throw "[ERR] Formato versione non valido. Usare X.Y.Z o X.Y.Z-suffix"
    }
    $config.Project.Version = $NewVersion
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Force
    $currentVersion = $NewVersion
}

# --- 3. FUNZIONI UTILITY ---
function Update-Changelog {
    param($Root, $Message, $Version, $AppName, $DeployedFiles)
    $logPath = Join-Path $Root "CHANGELOG.md"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $entry = "`n## [$Version] - $timestamp`n- $Message`n"
    if ($DeployedFiles) { $entry += "`n### File:`n" + ($DeployedFiles -join "`n") + "`n" }
    try {
        if (-not (Test-Path $logPath)) {
            "# CHANGELOG - $AppName`n$entry" | Set-Content $logPath -Encoding UTF8
        } else {
            $old = Get-Content $logPath -Raw
            $old = $old -replace "^# CHANGELOG.*?\r?\n", ""
            "# CHANGELOG - $AppName`n$entry$old" | Set-Content $logPath -Encoding UTF8
        }
    } catch {
        Write-Host "[ERR] Changelog: $_" -ForegroundColor Red
    }
}

function Invoke-Backup {
    param($Root, $Version)
    $backupDir = Join-Path $Root "DEV_BACKUP"
    if (-not (Test-Path $backupDir)) { New-Item $backupDir -Type Directory -Force | Out-Null }
    $items = Get-ChildItem $Root -Exclude "DEV_BACKUP", "SRC_DEPLOY", "Modules"
    if ($items) {
        $zipName = "backup_v$Version_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
        try {
            Compress-Archive $items -DestinationPath (Join-Path $backupDir $zipName) -Force -ErrorAction Stop
            Write-Host "[OK] Backup creato: $zipName" -ForegroundColor Green
        } catch {
            Write-Host "[ERR] Backup: $_" -ForegroundColor Red
        }
    }
}

function Update-Header {
    param($FilePath, $Version, $Description)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $header = @"
<#
.SYNOPSIS
    $($FilePath.Split('\')[-1].Split('.')[0]) - v$Version
.DESCRIPTION
    $Description
.VERSION
    $Version
.UPDATE
    $timestamp
#>
"@
    $content = Get-Content $FilePath -Raw
    $content = $content -replace "<#.*?#>", ""
    $header + "`n" + $content | Set-Content $FilePath -Encoding UTF8
}

function Move-Items {
    param($Root)
    $stagingPath = Join-Path $Root "SRC_DEPLOY"
    $deployedFiles = @()

    # Crea cartelle se non esistono
    @("SRC_DEPLOY", "Modules", "DEV_BACKUP") | ForEach-Object {
        $dir = Join-Path $Root $_
        if (-not (Test-Path $dir)) { New-Item $dir -Type Directory -Force | Out-Null }
    }

    if (Test-Path $stagingPath) {
        $stagingFiles = Get-ChildItem $stagingPath
        if ($stagingFiles) {
            Write-Host "File in SRC_DEPLOY: $($stagingFiles.Name -join ', ')" -ForegroundColor Yellow
            Write-Host "`n[pwdeployer] Deploy v.$currentVersion in corso..." -ForegroundColor Cyan

            foreach ($file in $stagingFiles) {
                try {
                    if ($file.Name -notlike "*.*.*.ps1") {
                        $dest = Join-Path $Root $file.Name
                        Copy-Item $file.FullName $dest -Force
                        $log = "    [OK] -> Root\$($file.Name)"
                        Write-Host $log -ForegroundColor Green
                    } else {
                        $parts = $file.Name.Split(".")
                        if ($parts.Count -eq 4) {
                            $targetDir = Join-Path $Root "Modules\$($parts[0])\$($parts[1])"
                            if (-not (Test-Path $targetDir)) { New-Item $targetDir -Type Directory -Force | Out-Null }
                            $dest = Join-Path $targetDir "$($parts[2]).ps1"
                            Copy-Item $file.FullName $dest -Force
                            $log = "    [OK] -> Modules\$($parts[0])\$($parts[1])\$($parts[2]).ps1"
                            Write-Host $log -ForegroundColor Green
                        }
                    }

                    if ($file.Extension -eq ".ps1") {
                        Update-Header $dest $currentVersion $deployNote
                        $log += "`n    [HEADER] Header aggiunto"
                        Write-Host "    [HEADER] Header aggiunto" -ForegroundColor Cyan
                    }
                    $deployedFiles += $log
                } catch {
                    Write-Host "[ERR] $($file.Name): $_" -ForegroundColor Red
                }
            }

            if ($stagingFiles.Count -gt 0 -and ($Force -or (Read-Host "`nSvuotare SRC_DEPLOY? (s/y/n)") -match '^[sSyY]$')) {
                Remove-Item "$stagingPath\*" -Recurse -Force -ErrorAction Stop
                Write-Host "[OK] SRC_DEPLOY svuotato" -ForegroundColor Green
            }
        }
    }
    return $deployedFiles
}

# --- 4. ESECUZIONE ---
if (-not $SkipBackup) { Invoke-Backup $projectRoot $currentVersion }
$deployedFiles = Move-Items $projectRoot
Update-Changelog $projectRoot $deployNote $currentVersion $currentAppName $deployedFiles
Write-Host "`n[pwdeployer] Deploy completato (v.$currentVersion)" -ForegroundColor Cyan
