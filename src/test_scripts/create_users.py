import random
import secrets
import requests
from faker import Faker

s = requests.Session()
fake = Faker()

host = "http://localhost:5000"

for i in range(1_000_000):
    print(i)
    response = s.post(
        host + "/api/v1/auth/signup",
        json={
            "name": fake.name(),
            "email": fake.email(),
            "password": secrets.token_urlsafe(random.randint(8, 300)),
        },
    )

    if response.status_code != 201:
        print(response.json())
