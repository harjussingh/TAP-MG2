from tests.conftest import API


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200 and r.json()["database"] == "ok"


def test_register_login_refresh_logout(client):
    r = client.post(f"{API}/auth/register", json={"email": "New@Example.com", "password": "Passw0rd!",
                                                  "full_name": "New Person"})
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["user"]["email"] == "new@example.com" and body["access_token"]

    dup = client.post(f"{API}/auth/register", json={"email": "new@example.com", "password": "Passw0rd!",
                                                    "full_name": "Again"})
    assert dup.status_code == 409

    weak = client.post(f"{API}/auth/register", json={"email": "w@example.com", "password": "password",
                                                     "full_name": "Weak"})
    assert weak.status_code == 422

    bad = client.post(f"{API}/auth/login", json={"email": "new@example.com", "password": "wrong-pass1"})
    assert bad.status_code == 401

    r = client.post(f"{API}/auth/login", json={"email": "new@example.com", "password": "Passw0rd!"})
    tokens = r.json()
    me = client.get(f"{API}/auth/me", headers={"Authorization": f"Bearer {tokens['access_token']}"})
    assert me.status_code == 200 and me.json()["full_name"] == "New Person"

    r2 = client.post(f"{API}/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r2.status_code == 200
    # old refresh token is rotated -> reuse is rejected
    assert client.post(f"{API}/auth/refresh", json={"refresh_token": tokens["refresh_token"]}).status_code == 401


def test_password_reset_flow(client):
    from app.core.database import get_db  # noqa
    client.post(f"{API}/auth/register", json={"email": "reset@example.com", "password": "Passw0rd!",
                                              "full_name": "Reset Me"})
    assert client.post(f"{API}/auth/forgot-password", json={"email": "reset@example.com"}).status_code == 200
    # Use the service directly to obtain a raw token (in real life it arrives by email)
    import asyncio
    from app.services.auth_token_service import create_auth_token
    from datetime import timedelta
    db = get_db()

    async def make():
        user = await db.users.find_one({"email": "reset@example.com"})
        return await create_auth_token(db, user["_id"], "reset_password", timedelta(minutes=5))

    token = client.portal.call(make) if hasattr(client, "portal") and client.portal else asyncio.run(make())
    r = client.post(f"{API}/auth/reset-password", json={"token": token, "new_password": "NewPassw0rd"})
    assert r.status_code == 200, r.text
    assert client.post(f"{API}/auth/reset-password", json={"token": token, "new_password": "NewPassw0rd"}).status_code == 400
    assert client.post(f"{API}/auth/login", json={"email": "reset@example.com", "password": "NewPassw0rd"}).status_code == 200


def test_roles_are_enforced(client, customer_h, staff_h):
    assert client.get(f"{API}/admin/dashboard", headers=customer_h).status_code == 403
    assert client.get(f"{API}/admin/dashboard", headers=staff_h).status_code == 403
    assert client.get(f"{API}/staff/orders", headers=customer_h).status_code == 403
    assert client.get(f"{API}/staff/orders").status_code == 401
    assert client.get(f"{API}/kitchen/jobs").status_code == 422
    assert client.get(f"{API}/kitchen/jobs", headers={"X-Kitchen-Key": "nope"}).status_code == 401
