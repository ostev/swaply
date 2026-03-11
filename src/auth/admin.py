from pathlib import Path
import tomllib
import auth.user

import globals


def create_default(secrets_dir: Path):
    """
    Creates the default admin account using the credentials stored
    in a secrets file.
    """
    default_admin_path = secrets_dir / "admin.toml"

    with open(default_admin_path, "rb") as file:
        admin_details = tomllib.load(file)

        email = str(admin_details["email"])
        name = str(admin_details["name"])
        password = str(admin_details["password"])

    if (
        globals.db.run(
            lambda conn, cursor: cursor.execute(
                "SELECT COUNT(id) FROM users WHERE privilege_level = 1"
            ).fetchone()
        )[0]
        == 0
    ):
        auth.user.create(email, name, password, is_admin=True)
