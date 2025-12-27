# Quick Start

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
