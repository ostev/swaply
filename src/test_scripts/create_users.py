from pathlib import Path
import random
import secrets
import requests
from faker import Faker

s = requests.Session()
fake = Faker()

host = "http://localhost:5000"

secrets_dir = Path(__file__).parent.parent.parent.resolve() / "secrets"

with open(secrets_dir / "csrf_header_value") as file:
    csrf_header_value = file.read()

for i in range(1000):
    print(i)
    response = s.post(
        host + "/api/v1/auth/signup",
        json={
            "name": fake.name(),
            "email": fake.email(),
            "password": secrets.token_urlsafe(random.randint(8, 300)),
        },
        headers={"X-CSRF-Token": csrf_header_value}
    )

    if response.status_code != 201:
        print(response.json())
