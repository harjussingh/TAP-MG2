import os

# Must be set before the app is imported.
os.environ.update({
    "MONGODB_URL": "mongomock://",
    "MONGODB_DB_NAME": "robokitchen_test",
    "REDIS_URL": "",
    "RATE_LIMIT_ENABLED": "false",
    "SEED_ON_STARTUP": "true",
    "PAYMENT_PROVIDER": "mock",
    "KITCHEN_API_KEY": "test-kitchen-key",
    "SMTP_HOST": "",
    "ENVIRONMENT": "test",
})

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

API = "/api/v1"
KITCHEN = {"X-Kitchen-Key": "test-kitchen-key"}


@pytest.fixture(scope="session")
def client():
    with TestClient(app) as c:
        yield c


def login(client, email, password):
    r = client.post(f"{API}/auth/login", json={"email": email, "password": password})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture(scope="session")
def admin_h(client):
    return login(client, "admin@robokitchen.com", "Admin12345")


@pytest.fixture(scope="session")
def staff_h(client):
    return login(client, "staff@robokitchen.com", "Staff12345")


@pytest.fixture(scope="session")
def customer_h(client):
    return login(client, "customer@robokitchen.com", "Customer123")


@pytest.fixture(scope="session")
def bowl(client):
    items = client.get(f"{API}/menu/items", params={"item_type": "custom_bowl"}).json()["items"]
    return items[0]


def pick(bowl, group_key, index=0):
    g = next(g for g in bowl["option_groups"] if g["key"] == group_key)
    return {"group_key": group_key, "ingredient_id": g["options"][index]["ingredient_id"], "quantity": 1}


def bowl_selections(bowl):
    return [pick(bowl, "base"), pick(bowl, "protein", 3), pick(bowl, "veggies", 3), pick(bowl, "sauce")]
