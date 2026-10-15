from datetime import date

from cassandra.cluster import Cluster

CASSANDRA_HOST = "127.0.0.1"
CASSANDRA_PORT = 9042


def get_game_id():
    """Demande à l'utilisateur quel jeu il souhaite consulter."""
    return input(
        "Nom du jeu (ex. minecraft, stardew_valley) : "
    ).strip().lower()


def get_activity_date():
    """Demande la date des sessions."""
    today = date.today()
    date_input = input(
        f"Date des sessions (AAAA-MM-JJ, défaut : {today}) : "
    ).strip()

    if not date_input:
        return today

    return date.fromisoformat(date_input)


def display_sessions(rows):
    """Affiche les sessions trouvées."""
    sessions = list(rows)

    if not sessions:
        print("Aucune session trouvée.")
        return

    print(f"{'HEURE DE DÉBUT':<22} {'JOUEUR':<20} {'DURÉE':>12}")

    for row in sessions:
        started_at = (
            row.started_at.strftime("%H:%M:%S")
            if row.started_at
            else "Inconnue"
        )

        player_id = row.player_id or "Inconnu"
        duration = (
            f"{row.duration_seconds} s"
            if row.duration_seconds is not None
            else "Inconnue"
        )

        print(f"{started_at:<22} {player_id:<20} {duration:>12}")


def main():
    print("GAMEMANAGER")
    print("Consultez l'historique des sessions de jeu.")

    cluster = Cluster([CASSANDRA_HOST], port=CASSANDRA_PORT)

    try:
        game_id = get_game_id()
        activity_date = get_activity_date()

        session = cluster.connect("gamemanager")

        query = """
                SELECT started_at, player_id, duration_seconds
                FROM sessions_by_game_day
                WHERE game_id = ?
                  AND activity_date = ? \
                """

        prepared_query = session.prepare(query)
        rows = session.execute(
            prepared_query,
            (game_id, activity_date),
        )

        print(f"\nJeu : {game_id}")
        print(f"Date : {activity_date.strftime('%d/%m/%Y')}")

        display_sessions(rows)

    finally:
        cluster.shutdown()


if __name__ == "__main__":
    main()
