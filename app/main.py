from datetime import date

from cassandra import InvalidRequest
from cassandra.cluster import Cluster, NoHostAvailable


CASSANDRA_HOST = "127.0.0.1"
CASSANDRA_PORT = 9042


def print_separator(char="-", width=68):
    print(char * width)


def get_game_id():
    """Demande à l'utilisateur quel jeu il souhaite consulter."""
    while True:
        game_id = input(
            "\nNom du jeu (ex. minecraft, stardew_valley) : "
        ).strip().lower()

        if game_id:
            return game_id

        print("Veuillez saisir le nom d'un jeu.")


def get_activity_date():
    """Demande une date et utilise la date du jour si elle est omise."""
    while True:
        today = date.today()
        date_input = input(
            f"Date des sessions (AAAA-MM-JJ, défaut : {today}) : "
        ).strip()

        if not date_input:
            return today

        try:
            return date.fromisoformat(date_input)
        except ValueError:
            print(
                "Format de date invalide. "
                "Veuillez utiliser le format AAAA-MM-JJ."
            )


def display_sessions(rows):
    """Affiche les sessions trouvées de manière lisible."""
    sessions = list(rows)

    if not sessions:
        print("\nAucune session n'a été trouvée pour cette recherche.")
        print("Essayez un autre jeu ou une autre date.")
        return

    print()
    print_separator("=")
    print(f"{'HEURE DE DÉBUT':<22} {'JOUEUR':<20} {'DURÉE':>12}")
    print_separator()

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

    print_separator()
    print(f"{len(sessions)} session(s) trouvée(s).")


def main():
    print_separator("=", 68)
    print("GAMEMANAGER")
    print("Consultez l'historique des sessions de jeu.")
    print_separator()

    cluster = None

    try:
        print("\nVeuillez préciser les critères de recherche.")
        game_id = get_game_id()
        activity_date = get_activity_date()

        print("\nRecherche en cours...")

        cluster = Cluster([CASSANDRA_HOST], port=CASSANDRA_PORT)
        session = cluster.connect("gamemanager")

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

        print()
        print_separator("=")
        print("RÉSULTATS DE LA RECHERCHE")
        print_separator()
        print(f"Jeu : {game_id}")
        print(f"Date : {activity_date.strftime('%d/%m/%Y')}")

        display_sessions(rows)

    except NoHostAvailable:
        print(
            "\nImpossible de se connecter au service de données."
        )
        print(
            "Veuillez réessayer ultérieurement ou contacter "
            "le support si le problème persiste."
        )

    except InvalidRequest:
        print(
            "\nLa recherche n'a pas pu être effectuée "
            "en raison d'un problème de configuration."
        )

    except KeyboardInterrupt:
        print("\n\nRecherche interrompue. À bientôt !")

    finally:
        if cluster is not None:
            cluster.shutdown()

    print("\nMerci d'avoir utilisé GameManager.")


if __name__ == "__main__":
    main()

