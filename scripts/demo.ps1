$ErrorActionPreference = "Stop"

# Se placer a la racine du projet.
$ProjectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $ProjectRoot

function Show-Section($Title) {
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * 78) -ForegroundColor Cyan
}

function Show-SubSection($Title) {
    Write-Host ""
    Write-Host ("-" * 68) -ForegroundColor DarkCyan
    Write-Host $Title -ForegroundColor DarkCyan
    Write-Host ("-" * 68) -ForegroundColor DarkCyan
}

function Show-Explanation($Text) {
    Write-Host "  $Text" -ForegroundColor Gray
}

function Show-Command($Command) {
    Write-Host "  > $Command" -ForegroundColor Yellow
}

function Invoke-Cassandra {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CqlshArgs
    )

    docker exec cassandra1 cqlsh @CqlshArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Une commande cqlsh a echoue."
    }
}

function Invoke-Nodetool {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$NodetoolArgs
    )

    docker exec cassandra1 nodetool @NodetoolArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Une commande nodetool a echoue."
    }
}

try {
    Show-Section "GAMEMANAGER - DEMONSTRATION CASSANDRA"

    Show-Explanation "Scenario : consulter les sessions d'un jeu pour une journee."
    Show-Explanation "Mecanisme 1 : placement des partitions sur les noeuds du cluster."
    Show-Explanation "Mecanisme 2 : ordre des sessions defini par le schema CQL."
    Show-Explanation "Les donnees utilisees sont fictives."
    Show-Explanation "Cluster cible : cassandra1 et cassandra2."

    # ------------------------------------------------------------
    # 1. Preparation reproductible
    # ------------------------------------------------------------

    Show-Section "1. PREPARATION DES DONNEES"

    Show-Explanation "On repart d'un jeu de donnees connu."
    Show-Command "TRUNCATE gamemanager.sessions_by_game_day;"

    Invoke-Cassandra @(
        "-e",
        "TRUNCATE gamemanager.sessions_by_game_day;"
    )

    Show-Explanation "La table est videe, puis les INSERT du fichier sample_data.cql"
    Show-Explanation "sont executes pour reconstruire le jeu de demonstration."

    Show-Command "Get-Content .\cql\sample_data.cql -Raw | docker exec -i cassandra1 cqlsh"

    Get-Content ".\cql\sample_data.cql" -Raw |
        docker exec -i cassandra1 cqlsh

    if ($LASTEXITCODE -ne 0) {
        throw "Le chargement de cql/sample_data.cql a echoue."
    }

    Write-Host ""
    Write-Host "  Jeu de donnees charge." -ForegroundColor Green

    # ------------------------------------------------------------
    # 2. Mecanisme 1 : etat et repartition du cluster
    # ------------------------------------------------------------

    Show-Section "2. MECANISME 1 - PARTITIONNEMENT PHYSIQUE"

    Show-SubSection "2.1 Etat des noeuds : nodetool status"

    Show-Command "docker exec cassandra1 nodetool status"

    Show-Explanation "Cette commande presente les noeuds connus du cluster."
    Show-Explanation "UN signifie Up/Normal : le noeud est operationnel."
    Show-Explanation "Les deux noeuds doivent apparaitre en UN."
    Show-Explanation "La colonne Owns indique une propriete effective estimee,"
    Show-Explanation "qui tient compte de la replication ; ce n'est pas un compteur de lignes."
    Write-Host ""

    Invoke-Nodetool @("status")

    Show-SubSection "2.2 Espace de tokens : nodetool ring"

    Show-Command "docker exec cassandra1 nodetool ring"

    Show-Explanation "Cassandra transforme la cle de partition en token."
    Show-Explanation "Les tokens sont situes dans l'espace de hachage du cluster."
    Show-Explanation "Le ring montre les tokens et les noeuds auxquels ils sont associes."
    Show-Explanation "Un noeud possede plusieurs tokens : il ne correspond pas a une seule partition."
    Show-Explanation "Le placement des tokens permet de distribuer les partitions entre les noeuds."
    Write-Host ""

    Invoke-Nodetool @("ring")

    Show-SubSection "2.3 Relier la partition GameManager aux noeuds"

    Show-Explanation "La cle de partition est composee de game_id et activity_date."
    Show-Explanation "Valeurs de demonstration : minecraft et 2026-10-12."
    Show-Explanation "La representation textuelle utilisee pour calculer le token"
    Show-Explanation "correspond aux valeurs de la cle de partition, pas aux lignes completees."
    Show-Explanation "La commande getendpoints indique les endpoints responsables"
    Show-Explanation "de la partition correspondant a la cle fournie."
    Write-Host ""

    Show-Command 'docker exec cassandra1 nodetool getendpoints gamemanager sessions_by_game_day "minecraft:2026-10-12"'

    Show-Explanation "Attention : getendpoints attend une cle de partition au format"
    Show-Explanation "approprie a la version Cassandra et a la representation de la cle."
    Show-Explanation "Pour une cle composite, ne supposez pas que la concatenation"
    Show-Explanation "avec un deux-points est une representation valide."
    Show-Explanation "La commande ci-dessous est donc lancee seulement si le format"
    Show-Explanation "de cle utilise par votre version a ete valide."

    # Le format de la cle composite doit etre verifie pour votre version.
    # Ne pas interrompre toute la demo si cette commande est incompatible.
    docker exec cassandra1 nodetool getendpoints `
        gamemanager sessions_by_game_day "minecraft:2026-10-12"

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  getendpoints n'a pas accepte la representation de la cle." -ForegroundColor Yellow
        Show-Explanation "La sortie de nodetool status et ring reste disponible."
        Show-Explanation "Ne presentez pas cette commande comme une preuve si elle echoue."
        Show-Explanation "Validez le format de la cle avec la version Cassandra utilisee."
    }

    # ------------------------------------------------------------
    # 3. Rappel du modele CQL
    # ------------------------------------------------------------

    Show-Section "3. MODELE CQL - CLE DE PARTITION ET CLUSTERING"

    Show-Explanation "Fichier consulte : cql/schema.cql"
    Show-Explanation "Extrait essentiel :"
    Write-Host ""

    Write-Host "  PRIMARY KEY (" -ForegroundColor Yellow
    Write-Host "      (game_id, activity_date)," -ForegroundColor Yellow
    Write-Host "      started_at," -ForegroundColor Yellow
    Write-Host "      session_id" -ForegroundColor Yellow
    Write-Host "  )" -ForegroundColor Yellow
    Write-Host "  WITH CLUSTERING ORDER BY (" -ForegroundColor Yellow
    Write-Host "      started_at DESC," -ForegroundColor Yellow
    Write-Host "      session_id ASC" -ForegroundColor Yellow
    Write-Host "  );" -ForegroundColor Yellow

    Show-SubSection "Interpretation du schema"

    Show-Explanation "(game_id, activity_date) : cle de partition."
    Show-Explanation "started_at : premiere colonne de clustering."
    Show-Explanation "DESC : sessions ordonnees de la plus recente a la plus ancienne."
    Show-Explanation "session_id : distingue les sessions ayant la meme heure de debut."
    Show-Explanation "Le partitionnement et le clustering ont des roles differents."

    # ------------------------------------------------------------
    # 4. Mecanisme 2 : clustering order
    # ------------------------------------------------------------

    Show-Section "4. MECANISME 2 - CLUSTERING ORDER"

    Show-Explanation "Besoin metier : consulter les sessions recentes d'un jeu pour un jour."
    Show-Explanation "La requete cible une partition en renseignant toute sa cle."
    Show-Explanation "Elle ne comporte volontairement aucun ORDER BY."
    Show-Explanation "Aucun tri applicatif n'est ajoute par Python."
    Show-Explanation "L'ordre est defini dans le schema avec started_at DESC."

    Show-SubSection "Requete CQL executee"

    Show-Command "SELECT started_at, player_id, duration_seconds"
    Show-Command "FROM gamemanager.sessions_by_game_day"
    Show-Command "WHERE game_id = 'minecraft'"
    Show-Command "  AND activity_date = '2026-10-12';"

    Write-Host ""
    Invoke-Cassandra @(
        "-e",
        "SELECT started_at, player_id, duration_seconds FROM gamemanager.sessions_by_game_day WHERE game_id = 'minecraft' AND activity_date = '2026-10-12';"
    )

    Show-Explanation "Verifier les heures affichees : elles doivent etre decroissantes."
    Show-Explanation "Le resultat attendu est 18:42, 18:35, 18:21 puis 17:55."
    Show-Explanation "C'est une observation du comportement du schema, pas un tri Python."

    # ------------------------------------------------------------
    # 5. Application metier : comparaison des resultats
    # ------------------------------------------------------------
    Show-Section "5. Application GameManager - Comparaison possible"

    Show-Explanation "La demonstration technique Cassandra est terminee."
    Show-Explanation "L'application Python est separee de ce script."
    Show-Explanation "Elle represente l'utilisation des mecanismes depuis le besoin metier."
    Write-Host ""

    Show-Explanation "Fichier de l'application : app/main.py"
    Show-Explanation "Commande a lancer depuis la racine du projet :"
    Write-Host ""
    Write-Host "python app/main.py" -ForegroundColor Yellow
    Write-Host ""

    Show-Explanation "Saisir les parametres suivants pour comparer les resultats :"
    Write-Host "  Jeu  : minecraft" -ForegroundColor Yellow
    Write-Host "  Date : 2026-10-12" -ForegroundColor Yellow
    Write-Host ""

    Show-Explanation "Les quatre sessions obtenues doivent correspondre a celles"
    Show-Explanation "affichees precedemment par la requete CQL."
    Show-Explanation "L'application utilise le meme schema et ne trie pas les lignes"
    Show-Explanation "en Python : elle affiche les resultats retournes par Cassandra."
    Write-Host ""

    Show-Explanation "Cette application constitue une illustration fonctionnelle"
    Show-Explanation "du besoin metier ; les mecanismes Cassandra ont ete expliques"
    Show-Explanation "et observes dans les sections precedentes."

    # ------------------------------------------------------------
    # 6. Bilan
    # ------------------------------------------------------------
    Show-Section "Fin de la demonstration technique"

    Show-Explanation "Mecanisme 1 : nodetool status et nodetool ring montrent"
    Show-Explanation "l'etat des noeuds et l'organisation des tokens du cluster."
    Show-Explanation "La cle de partition du schema permet de determiner le token"
    Show-Explanation "associe a une partition logique."
    Write-Host ""

    Show-Explanation "Mecanisme 2 : CLUSTERING ORDER BY definit l'ordre des sessions"
    Show-Explanation "dans une partition, sans tri applicatif."
    Write-Host ""

    Show-Explanation "Pour verifier l'utilisation fonctionnelle de ces mecanismes,"
    Show-Explanation "lancer separement python app/main.py."
    Show-Explanation "Le POC illustre ces mecanismes dans un cluster local de deux noeuds."

}
finally {
    Pop-Location
}