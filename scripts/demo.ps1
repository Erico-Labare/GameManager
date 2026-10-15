$ErrorActionPreference = "Stop"

# Se placer a la racine du projet.
$ProjectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $ProjectRoot

try {
    Write-Host "GAMEMANAGER - DEMONSTRATION CASSANDRA" -ForegroundColor Cyan
    Write-Host ""

    # 1. Preparation des donnees
    Write-Host "1. PREPARATION DES DONNEES" -ForegroundColor Cyan

    docker exec cassandra1 cqlsh -e "TRUNCATE gamemanager.sessions_by_game_day;"

    if ($LASTEXITCODE -ne 0) {
        throw "Impossible de vider la table Cassandra."
    }

    Get-Content ".\cql\sample_data.cql" -Raw |
        docker exec -i cassandra1 cqlsh

    if ($LASTEXITCODE -ne 0) {
        throw "Le chargement des donnees a echoue."
    }

    Write-Host "Jeu de donnees charge." -ForegroundColor Green

    # 2. Verification du cluster
    Write-Host ""
    Write-Host "2. ETAT DU CLUSTER" -ForegroundColor Cyan

    docker exec cassandra1 nodetool status

    if ($LASTEXITCODE -ne 0) {
        throw "Impossible de consulter l'etat du cluster."
    }
}
finally {
    Pop-Location
}