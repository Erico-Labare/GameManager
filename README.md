# GameManager — Démonstrateur Apache Cassandra

## Table des matières

- [1. Présentation du projet](#1-présentation-du-projet)
- [2. Architecture technique](#2-architecture-technique)
- [3. Structure du projet](#3-structure-du-projet)
- [4. Prérequis](#4-prérequis)
- [5. Installation et configuration](#5-installation-et-configuration)
  - [5.1. Vérifier Docker](#51-vérifier-docker)
  - [5.2. Démarrer le cluster Cassandra](#52-démarrer-le-cluster-cassandra)
  - [5.3. Créer le schéma CQL](#53-créer-le-schéma-cql)
  - [5.4. Préparer l'environnement Python](#54-préparer-lenvironnement-python)
  - [5.5. Charger les données de démonstration](#55-charger-les-données-de-démonstration)
- [6. Modèle de données Cassandra](#6-modèle-de-données-cassandra)
  - [6.1. Keyspace et réplication](#61-keyspace-et-réplication)
  - [6.2. Table des sessions](#62-table-des-sessions)
  - [6.3. Clé de partition](#63-clé-de-partition)
  - [6.4. Colonnes de clustering](#64-colonnes-de-clustering)
  - [6.5. Types de données](#65-types-de-données)
- [7. Utilisation de l'application Python](#7-utilisation-de-lapplication-python)
- [8. Démonstration automatisée](#8-démonstration-automatisée)
  - [8.1. Lancement](#81-lancement)
  - [8.2. Déroulement de la démonstration](#82-déroulement-de-la-démonstration)
  - [8.3. Comprendre le partitionnement physique](#83-comprendre-le-partitionnement-physique)
  - [8.4. Comprendre l'ordre de clustering](#84-comprendre-lordre-de-clustering)
  - [8.5. Résultats attendus](#85-résultats-attendus)
- [9. Fichiers importants](#9-fichiers-importants)
- [10. Arrêter et redémarrer l'environnement](#10-arrêter-et-redémarrer-lenvironnement)
- [11. Dépannage](#11-dépannage)
- [12. Limites et perspectives](#12-limites-et-perspectives)
- [13. Conclusion](#13-conclusion)

## 1. Présentation du projet

GameManager est un prototype d'application de suivi de l'activité des joueurs de jeux vidéo, développé avec Python et Apache Cassandra.

Le scénario métier consiste à permettre à un administrateur de consulter les sessions d'un jeu pour une journée donnée, de la plus récente à la plus ancienne.

Le projet est organisé autour de deux composants complémentaires :

- **La démonstration technique (`scripts/demo.ps1`)** : elle présente les mécanismes Cassandra étudiés, les commandes exécutées, le schéma CQL et les résultats observés.
- **L'application métier (`app/main.py`)** : elle représente l'utilisation fonctionnelle de Cassandra pour répondre au besoin de consultation des sessions.

Deux mécanismes sont étudiés :

- **Le partitionnement physique du cluster** : observation de l'état des nœuds avec `nodetool status` et de l'organisation des tokens avec `nodetool ring`, en lien avec la clé de partition du schéma.
- **Le clustering order** : vérification que les sessions d'une même partition sont retournées dans l'ordre défini par `CLUSTERING ORDER BY`, sans tri applicatif.

La démonstration technique et l'application sont volontairement séparées. Le script PowerShell explique les mécanismes et présente les résultats CQL ; l'application Python peut être lancée indépendamment pour retrouver les mêmes données et illustrer le besoin métier.

Les données utilisées sont fictives. Ce projet constitue un prototype pédagogique et non une application destinée à la production.

## 2. Architecture technique

| Composant | Rôle |
|---|---|
| Apache Cassandra 5.0.9 | Stockage distribué des sessions |
| `cassandra1` et `cassandra2` | Deux nœuds Cassandra dans un même cluster |
| Docker Desktop et Docker Compose | Déploiement et gestion des conteneurs |
| Python | Application en ligne de commande |
| `cassandra-driver` | Connexion entre Python et Cassandra |
| CQL | Définition du schéma et interrogation des données |
| PowerShell | Exécution des commandes et orchestration de la démonstration |

Le cluster est nommé `GameManagerCluster`. Les deux nœuds sont configurés dans le datacenter logique `datacenter1`.

Le keyspace `gamemanager` utilise `NetworkTopologyStrategy` avec un facteur de réplication de 2 dans ce datacenter.

Les deux nœuds étant exécutés dans des conteneurs sur une seule machine, le projet permet d'illustrer le fonctionnement d'un cluster Cassandra à plusieurs nœuds, mais ne démontre pas la résilience à la panne de l'hôte physique ni les performances à grande échelle.

## 3. Structure du projet

```text
GameManager/
├── .venv/                   # Environnement virtuel Python local
├── app/
│   └── main.py              # Application Python en ligne de commande
├── cql/
│   ├── schema.cql           # Keyspace et table Cassandra
│   └── sample_data.cql      # Données fictives de démonstration
├── docs/                    # Documentation complémentaire
├── scripts/
│   └── demo.ps1             # Scénario de démonstration automatisé
├── .gitignore
├── docker-compose.yml       # Configuration du cluster Cassandra
├── README.md
└── requirements.txt         # Dépendances Python du projet
```

Les commandes ci-dessous sont prévues pour Windows avec PowerShell et doivent être exécutées depuis la racine du projet, sauf indication contraire.

## 4. Prérequis

Avant de commencer, disposer des éléments suivants :

- Windows avec PowerShell.
- Docker Desktop, avec le moteur Linux démarré.
- Docker Compose v2.
- Python et `pip`.
- Un environnement virtuel Python.
- Git, si le projet est récupéré depuis un dépôt.

Le pilote Python utilisé pendant le développement est `cassandra-driver 3.30.1`. L'environnement testé utilise Python 3.14.0, avec `pyasyncore 1.0.5` comme dépendance complémentaire pour résoudre un problème de compatibilité rencontré avec cette version de Python.

## 5. Installation et configuration

### 5.1. Vérifier Docker

Dans PowerShell :

```powershell
docker --version
docker compose version
docker info
```

La commande `docker info` doit retourner les informations du moteur Docker sans erreur de connexion.

Si le moteur n'est pas démarré, ouvrir Docker Desktop et attendre qu'il soit opérationnel.

### 5.2. Démarrer le cluster Cassandra

À la racine du projet :

```powershell
docker compose up -d
```

Vérifier l'état des conteneurs :

```powershell
docker compose ps
```

Puis consulter l'état du cluster :

```powershell
docker exec cassandra1 nodetool status
```

Les deux nœuds doivent apparaître avec le statut `UN` :

- `U` signifie *Up* : le nœud est actif.
- `N` signifie *Normal* : le nœud fonctionne dans l'état normal du cluster.

Le démarrage initial de Cassandra peut prendre un certain temps. Si les nœuds ne sont pas encore opérationnels, patienter puis relancer la commande de vérification.

Pour consulter les journaux en cas de problème :

```powershell
docker compose logs --tail 100 cassandra1
docker compose logs --tail 100 cassandra2
```

La configuration du projet utilise des volumes Docker pour conserver les données Cassandra entre les redémarrages.

### 5.3. Créer le schéma CQL

Le fichier `cql/schema.cql` contient la définition du keyspace et de la table.

Exécuter :

```powershell
Get-Content .\cql\schema.cql -Raw |
    docker exec -i cassandra1 cqlsh
```

La commande transmet le contenu du fichier à `cqlsh`, le client en ligne de commande de Cassandra.

Vérifier ensuite que le keyspace existe :

```powershell
docker exec cassandra1 cqlsh -e "DESCRIBE KEYSPACE gamemanager;"
```

Pour afficher la définition de la table :

```powershell
docker exec cassandra1 cqlsh -e "DESCRIBE TABLE gamemanager.sessions_by_game_day;"
```

Le schéma est défini avec `IF NOT EXISTS`, ce qui permet de rejouer les instructions sans tenter de recréer les objets déjà présents.

Cette clause ne met cependant pas à jour un schéma existant. En cas de modification de la clé primaire ou de la définition de la table, il faut vérifier que la structure présente dans Cassandra correspond bien à celle attendue par le projet.

### 5.4. Préparer l'environnement Python

Créer un environnement virtuel s'il n'existe pas déjà :

```powershell
python -m venv .venv
```

L'activer :

```powershell
.\.venv\Scripts\Activate.ps1
```

Si PowerShell bloque l'activation du script, utiliser directement l'interpréteur de l'environnement virtuel :

```powershell
.\.venv\Scripts\python.exe -m pip install --upgrade pip
```

Installer les dépendances :

```powershell
python -m pip install cassandra-driver pyasyncore
```

Si le fichier `requirements.txt` contient les versions et dépendances nécessaires, il est également possible d'utiliser :

```powershell
python -m pip install -r requirements.txt
```

Vérifier que le pilote Cassandra est disponible :

```powershell
python -c "import cassandra; print(cassandra.__version__)"
```

La version attendue du pilote dans l'environnement de développement est `3.30.1`.

### 5.5. Charger les données de démonstration

Le fichier `cql/sample_data.cql` contient huit sessions fictives.

Pour charger les données :

```powershell
Get-Content .\cql\sample_data.cql -Raw |
    docker exec -i cassandra1 cqlsh
```

Vérifier le contenu de la table :

```powershell
docker exec cassandra1 cqlsh -e "SELECT game_id, activity_date, started_at, player_id FROM gamemanager.sessions_by_game_day;"
```

Le jeu de données comprend :

| Jeu | Date | Nombre de sessions |
|---|---|---:|
| `minecraft` | 2026-10-12 | 4 |
| `minecraft` | 2026-10-13 | 2 |
| `stardew_valley` | 2026-10-12 | 2 |
| **Total** | | **8** |

Les insertions peuvent être rejouées sans créer de lignes supplémentaires lorsque les valeurs de clé primaire sont identiques. Cassandra identifie les lignes par leur clé primaire.

Le script de démonstration repart néanmoins explicitement d'une table vide avant de charger le jeu de données, afin que les résultats soient reproductibles.

## 6. Modèle de données Cassandra

### 6.1. Keyspace et réplication

Le keyspace `gamemanager` utilise la stratégie de réplication suivante :

```sql
CREATE KEYSPACE IF NOT EXISTS gamemanager
WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'datacenter1': 2
}
AND durable_writes = true;
```

`NetworkTopologyStrategy` permet de définir le facteur de réplication par datacenter.

Ici, `datacenter1: 2` demande deux répliques de chaque partition dans ce datacenter. Avec deux nœuds opérationnels dans le cluster, Cassandra peut placer ces répliques sur les deux nœuds, selon l'affectation des tokens et la configuration effective du cluster.

La réplication signifie qu'une partition logique peut être stockée sur plusieurs nœuds. Elle ne signifie pas que chaque nœud possède nécessairement la moitié des données.

### 6.2. Table des sessions

La table `gamemanager.sessions_by_game_day` est définie dans `cql/schema.cql`.

```sql
CREATE TABLE IF NOT EXISTS gamemanager.sessions_by_game_day (
    game_id text,
    activity_date date,
    started_at timestamp,
    session_id uuid,
    player_id text,
    ended_at timestamp,
    duration_seconds int,
    PRIMARY KEY (
        (game_id, activity_date),
        started_at,
        session_id
    )
) WITH CLUSTERING ORDER BY (
    started_at DESC,
    session_id ASC
);
```

Cette table est conçue pour répondre à une requête précise : récupérer les sessions d'un jeu pour une journée donnée, de la plus récente à la plus ancienne.

### 6.3. Clé de partition

La clé de partition est composée de deux colonnes :

```sql
(game_id, activity_date)
```

Ces colonnes identifient la partition logique correspondant à un jeu et à une journée.

Par exemple, la recherche des sessions de Minecraft du 12 octobre 2026 renseigne les deux colonnes par égalité :

```sql
WHERE game_id = 'minecraft'
  AND activity_date = '2026-10-12'
```

Une autre combinaison de jeu et de date correspond à une autre partition logique.

La clé de partition est également utilisée par Cassandra pour déterminer le token associé à la partition, puis les nœuds responsables de son stockage et de sa réplication.

**À retenir :** une partition logique est définie par sa clé de partition. Elle ne doit pas être confondue avec un nœud physique : plusieurs partitions peuvent être associées à un même nœud, et une partition peut être répliquée sur plusieurs nœuds.

### 6.4. Colonnes de clustering

Les colonnes de clustering sont :

```sql
started_at,
session_id
```

Leur ordre est défini par :

```sql
WITH CLUSTERING ORDER BY (
    started_at DESC,
    session_id ASC
);
```

`started_at DESC` définit l'ordre des sessions au sein de chaque partition : les heures de début les plus récentes apparaissent en premier.

`session_id ASC` complète la clé primaire et permet de distinguer les sessions ayant la même clé de partition et la même heure de début.

Les colonnes de partition et de clustering ont donc des rôles distincts :

- La clé de partition permet de cibler le groupe de données.
- Les colonnes de clustering organisent les lignes à l'intérieur de ce groupe.

La requête applicative n'a pas besoin d'effectuer un tri supplémentaire en Python. L'ordre attendu est défini par le schéma CQL.

### 6.5. Types de données

| Colonne | Type CQL | Utilité |
|---|---|---|
| `game_id` | `text` | Identifiant du jeu |
| `activity_date` | `date` | Journée de consultation |
| `started_at` | `timestamp` | Heure de début de session |
| `session_id` | `uuid` | Identifiant de session |
| `player_id` | `text` | Identifiant du joueur |
| `ended_at` | `timestamp` | Heure de fin de session |
| `duration_seconds` | `int` | Durée de session en secondes |

Le modèle est conçu à partir de la requête métier prévue. Il n'est pas destiné à couvrir toutes les requêtes possibles sur les sessions.

## 7. Utilisation de l'application Python

L'application métier se trouve dans `app/main.py`.

Elle est indépendante du script de démonstration `scripts/demo.ps1`. Elle peut être lancée avant ou après la démonstration technique, dès lors que le cluster Cassandra est démarré, que le schéma existe et que les données ont été chargées.

Depuis la racine du projet :

```powershell
python app/main.py
```

L'application se connecte à Cassandra sur `127.0.0.1:9042`, puis ouvre une session sur le keyspace `gamemanager`.

Elle demande ensuite :

1. L'identifiant du jeu.
2. La date à consulter, au format `AAAA-MM-JJ`.

Exemple :

```text
Identifiant du jeu (ex. minecraft) : minecraft
Date a consulter (AAAA-MM-JJ, ex. 2026-10-12) : 2026-10-12
```

La requête CQL utilise une requête préparée :

```sql
SELECT started_at, player_id, duration_seconds
FROM sessions_by_game_day
WHERE game_id = ?
  AND activity_date = ?
```

Les marqueurs `?` sont remplacés par les valeurs transmises séparément au pilote Cassandra lors de l'exécution.

Cette requête renseigne les deux colonnes de la clé de partition. L'application affiche les sessions retournées par Cassandra et contrôle l'ordre observé sans modifier les résultats ni effectuer de tri.

### Comparaison avec la démonstration technique

Pour comparer les résultats avec ceux du script `scripts/demo.ps1`, saisir :

- Jeu : `minecraft`
- Date : `2026-10-12`

Les quatre sessions doivent correspondre à celles affichées par la requête CQL exécutée pendant la démonstration.

Cette comparaison permet de vérifier que l'application exploite le même schéma et retrouve les mêmes données. La démonstration des mécanismes repose toutefois sur les observations techniques réalisées dans le script PowerShell, et non sur la seule exécution de l'application.

## 8. Démonstration automatisée

Le script `scripts/demo.ps1` présente les mécanismes Cassandra étudiés dans le POC. Il est distinct de l'application métier `app/main.py`.

Depuis la racine du projet, exécuter :

```powershell
.\scripts\demo.ps1
```

Le script déroule les étapes suivantes :

1. Vide la table de démonstration pour repartir d'un état connu.
2. Recharge les données depuis `cql/sample_data.cql`.
3. Affiche la commande `nodetool status` pour vérifier l'état des nœuds du cluster.
4. Affiche `nodetool ring` pour observer les tokens associés aux nœuds et expliquer leur rôle dans la répartition des partitions.
5. Présente la clé primaire définie dans `cql/schema.cql` et relie la clé de partition à l'organisation du cluster.
6. Exécute une requête CQL sur les sessions de Minecraft du 12 octobre 2026 et montre leur ordre décroissant sans `ORDER BY`.
7. Présente le chemin vers l'application Python et les paramètres permettant de comparer les résultats.

**Le script PowerShell ne lance pas automatiquement l'application Python.** Cette séparation permet de distinguer la démonstration technique des mécanismes Cassandra de leur utilisation dans le programme métier.

### Comparer les résultats avec l'application

Après la démonstration, ou dans un autre terminal pendant son exécution, lancer :

```powershell
python app/main.py
```

Saisir `minecraft`, puis `2026-10-12`. Les quatre sessions retournées doivent correspondre à celles observées pendant la démonstration CQL.

### Prérequis

Le script suppose que Docker est démarré, que les conteneurs Cassandra existent et sont opérationnels, et que le keyspace et la table ont été créés.

Le schéma doit donc être installé au préalable. Le script recharge lui-même les données de démonstration.

**Attention :** le script exécute `TRUNCATE` sur `gamemanager.sessions_by_game_day` avant de recharger les données. Toute donnée préexistante dans cette table sera supprimée. Ne pas utiliser ce script tel quel sur une base contenant des données à conserver.

### 8.1. Résultats attendus

Pour Minecraft le 12 octobre 2026, quatre sessions doivent apparaître dans l'ordre suivant :

| Heure de début | Joueur |
|---|---|
| 18:42 | `player_042` |
| 18:35 | `player_017` |
| 18:21 | `player_008` |
| 17:55 | `player_031` |

### 8.2. Ce que la démonstration permet de vérifier

- **État du cluster** : `nodetool status` indique l'état des nœuds Cassandra.
- **Organisation des tokens** : `nodetool ring` permet d'observer les tokens associés aux nœuds et d'expliquer leur rôle dans la répartition des partitions.
- **Lien avec le modèle de données** : la clé de partition `(game_id, activity_date)` permet d'identifier la partition logique ciblée par la requête métier.
- **Clustering order** : les sessions d'une même partition apparaissent dans l'ordre défini par `started_at DESC`, sans tri applicatif.

La démonstration ne constitue pas un benchmark et ne prouve pas, à elle seule, la répartition physique exacte d'une partition particulière ou la réplication effective de chaque ligne. Elle met en relation le schéma CQL, les commandes d'observation du cluster et les résultats de consultation.

## 9. Fichiers importants

### `docker-compose.yml`

Décrit le cluster Cassandra, les deux conteneurs, le réseau Docker, les volumes persistants et les paramètres de configuration.

### `cql/schema.cql`

Définit le keyspace et la table. Toute modification de la clé primaire ou de l'ordre de clustering doit être répercutée dans ce fichier et vérifiée dans le schéma effectivement déployé.

### `cql/sample_data.cql`

Contient les insertions des huit sessions fictives utilisées par la démonstration.

### `app/main.py`

Application métier en ligne de commande. Elle permet de rechercher les sessions d'un jeu pour une date, d'exécuter une requête préparée et d'afficher les résultats retournés par Cassandra. Elle ne réalise aucun tri applicatif.

### `scripts/demo.ps1`

Script de démonstration technique. Il prépare les données, affiche l'état du cluster et l'organisation des tokens, présente le schéma CQL et exécute les requêtes nécessaires à l'observation des mécanismes étudiés. Il indique comment lancer l'application métier, sans l'exécuter automatiquement.

### `requirements.txt`

Décrit les dépendances Python du projet. Il doit rester cohérent avec les dépendances réellement nécessaires à l'application et l'environnement Python utilisé.

### `.gitignore`

Permet d'exclure du dépôt les fichiers locaux qui ne doivent pas être versionnés, notamment l'environnement virtuel Python et les fichiers temporaires.

## 10. Arrêter et redémarrer l'environnement

Arrêter les conteneurs sans supprimer les volumes :

```powershell
docker compose down
```

Redémarrer le cluster :

```powershell
docker compose up -d
```

Les volumes Docker permettent de conserver les données entre ces opérations.

Pour supprimer également les volumes persistants :

```powershell
docker compose down -v
```

**Attention :** cette dernière commande supprime les volumes associés au projet et les données Cassandra qu'ils contiennent. Elle ne doit être utilisée que si une réinitialisation complète est souhaitée.

## 11. Dépannage

### Cassandra ne répond pas

Vérifier l'état des conteneurs :

```powershell
docker compose ps
```

Puis consulter les journaux :

```powershell
docker compose logs --tail 100 cassandra1
docker compose logs --tail 100 cassandra2
```

Si le démarrage vient d'être lancé, attendre que Cassandra soit opérationnel avant d'utiliser `cqlsh` ou l'application Python.

### Le pilote Python n'est pas reconnu

Vérifier que l'environnement virtuel est activé, puis installer les dépendances :

```powershell
python -m pip install cassandra-driver pyasyncore
```

Si plusieurs versions de Python sont installées, vérifier que l'interpréteur utilisé est bien celui de `.venv`.

### Le keyspace ou la table n'existe pas

Rejouer le schéma :

```powershell
Get-Content .\cql\schema.cql -Raw |
    docker exec -i cassandra1 cqlsh
```

Puis vérifier la définition de la table :

```powershell
docker exec cassandra1 cqlsh -e "DESCRIBE TABLE gamemanager.sessions_by_game_day;"
```

Si une ancienne définition de la table est présente, `IF NOT EXISTS` ne la remplace pas. Il faut alors examiner le schéma existant avant de décider d'une migration ou d'une recréation de la table.

### Aucune session n'est trouvée

Vérifier les valeurs saisies, notamment le format de la date, et s'assurer que les données ont été chargées.

Exemple de vérification :

```powershell
docker exec cassandra1 cqlsh -e "SELECT started_at, player_id FROM gamemanager.sessions_by_game_day WHERE game_id = 'minecraft' AND activity_date = '2026-10-12';"
```

Cette requête fournit directement les sessions correspondant au jeu et à la date attendus.

### Erreur de syntaxe CQL sur les marqueurs de paramètres

Dans une requête préparée avec `session.prepare(query)`, utiliser les marqueurs `?`, puis transmettre les valeurs séparément à `session.execute()`.

Exemple :

```python
query = """
    SELECT started_at, player_id, duration_seconds
    FROM sessions_by_game_day
    WHERE game_id = ?
      AND activity_date = ?
"""

prepared_query = session.prepare(query)
rows = session.execute(
    prepared_query,
    (game_id, activity_date),
)
```

### La commande `nodetool getendpoints` échoue

Cette commande attend le keyspace, la table et la clé de partition selon le format accepté par la version utilisée.

Dans GameManager, la clé de partition associe deux colonnes, `game_id` et `activity_date`. Une simple concaténation de ces valeurs n'est pas nécessairement une représentation valide pour `nodetool`.

Vérifier d'abord la syntaxe disponible dans le conteneur :

```powershell
docker exec cassandra1 nodetool help getendpoints
```

Ne pas confondre un problème de format d'argument avec une panne du cluster. Utiliser `nodetool status` pour vérifier l'état des nœuds et `nodetool ring` pour examiner l'anneau de tokens, tout en gardant à l'esprit que ces commandes ne confirment pas à elles seules les répliques d'une clé donnée.

### Le script PowerShell s'arrête en erreur

Vérifier que le script est lancé depuis la racine du projet et que les conteneurs sont opérationnels. Contrôler également que les fichiers `cql/schema.cql`, `cql/sample_data.cql` et `app/main.py` existent aux emplacements attendus.

## 12. Limites et perspectives

Le prototype présente plusieurs limites :

- Les sessions sont fictives et peu nombreuses.
- La consultation est conçue pour un seul jeu et une seule journée à la fois.
- Une consultation sur plusieurs jours nécessiterait plusieurs partitions ou une autre table conçue pour ce besoin.
- L'application est une interface en ligne de commande.
- L'authentification, la gestion avancée des fuseaux horaires, la supervision de production et les tests de charge ne sont pas implémentés.
- Le cluster de démonstration utilise deux conteneurs sur une seule machine : il ne prouve pas la tolérance à la panne de l'hôte.
- L'affichage des tokens ne permet pas de connaître directement le nombre de lignes stockées sur chaque nœud.
- La vérification de la localisation des répliques par `nodetool getendpoints` dépend du format de clé accepté par la commande.
- Aucun benchmark comparatif n'a été réalisé.

Des évolutions possibles seraient l'ajout de requêtes métier supplémentaires avec des tables dénormalisées adaptées, une gestion plus complète des erreurs, des tests automatisés, une vérification reproductible des répliques et un déploiement sur plusieurs machines.

## 13. Conclusion

GameManager illustre le lien entre un modèle de données Cassandra et un besoin métier précis.

La clé de partition `(game_id, activity_date)` cible les sessions correspondant au jeu et à la journée recherchés. Les commandes `nodetool status` et `nodetool ring` permettent d'observer respectivement l'état du cluster et l'organisation de ses tokens. La colonne de clustering `started_at DESC` définit l'ordre des sessions au sein de la partition.

Le projet distingue deux objectifs complémentaires :

- `scripts/demo.ps1` démontre les mécanismes Cassandra et explique les commandes et résultats observés.
- `app/main.py` représente l'utilisation fonctionnelle du modèle pour consulter les sessions.

Cette séparation facilite la compréhension du POC : la démonstration explique comment Cassandra organise et retourne les données, tandis que l'application montre comment ces données peuvent être exploitées pour répondre au besoin métier.