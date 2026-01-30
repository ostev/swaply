import random
import secrets
import datetime
import requests
from faker import Faker

fake = Faker()

s = requests.Session()

host = "http://localhost:5000"

s.post(
    host + "/api/v1/auth/login",
    json={"email": "user@gmail.com", "password": "12345678"},
)


def create_item_type():
    return {
        "name": fake.words(nb=random.randint(0, 100)),
        "price": random.random() * 1000,
        "quantity": random.randint(0, 1_000_000),
    }


def random_datetime_between(start_date, end_date):
    """
    Generates a random datetime object between two given datetime objects.
    """
    # Calculate the total difference (timedelta) in the range
    delta = end_date - start_date
    # Calculate total seconds in the range (includes days, seconds, microseconds)
    int_delta = delta.days * 24 * 60 * 60 + delta.seconds

    # Generate a random number of seconds within the total range
    random_second = random.randrange(int_delta)

    # Add the random timedelta to the start date
    return start_date + datetime.timedelta(seconds=random_second)


def create_listing():
    return {
        "name": " ".join(fake.words(nb=random.randint(0, 100))),
        "is_published": random.choice([False, True]),
        "items": [create_item_type() for _ in range(random.randint(0, 200))],
        "date": random_datetime_between(
            datetime.datetime.now(tz=datetime.UTC),
            datetime.datetime.now(tz=datetime.UTC) + datetime.timedelta(days=1_000_000),
        ).isoformat(),
        "tags": fake.words(nb=random.randint(0, 100)),
        "short_description": fake.paragraph(nb_sentences=random.randint(0, 100)),
        "description": fake.paragraph(nb_sentences=random.randint(0, 300)),
        "location": " ".join([fake.city() for _ in range(random.randint(0, 100))]),
    }


for i in range(1_000_000):
    print(i)
    s.post(host + "/api/v1/listings", json=create_listing())
