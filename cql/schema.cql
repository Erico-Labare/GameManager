-- GameManager : création du keyspace
CREATE KEYSPACE IF NOT EXISTS gamemanager
WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'datacenter1': 2
}
AND durable_writes = true;

-- Sessions de jeu, regroupées par jeu et par jour
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
