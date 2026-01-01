import requests

s = requests.Session()

host = "http://localhost:5000"

s.post(
    host + "/api/v1/auth/signup",
    json={"name": "Test user", "email": "user@gmail.com", "password": "12345678"},
)
