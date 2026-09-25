from tests.conftest import API, KITCHEN, bowl_selections, pick

GUEST = {"X-Session-Id": "guest-session-0001"}


def test_menu_and_price_quote(client, bowl):
    cats = client.get(f"{API}/menu/categories").json()
    assert len(cats) == 4
    paged = client.get(f"{API}/menu/items", params={"size": 2, "page": 2}).json()
    assert len(paged["items"]) == 2 and paged["total"] == 8 and paged["pages"] == 4
    assert client.get(f"{API}/menu/items", params={"search": "salmon"}).json()["total"] >= 1
    vegan = client.get(f"{API}/menu/items", params={"dietary": "vegan"}).json()["items"]
    assert all("vegan" in i["dietary_tags"] for i in vegan)

    q = client.post(f"{API}/menu/price-quote", json={"menu_item_id": bowl["id"], "selections": bowl_selections(bowl)})
    assert q.status_code == 200, q.text
    # base 10.95 + salmon 2.50 + avocado 1.50
    assert q.json()["unit_price_cents"] == 1095 + 250 + 150

    missing = client.post(f"{API}/menu/price-quote", json={"menu_item_id": bowl["id"], "selections": [pick(bowl, "base")]})
    assert missing.status_code == 422 and "protein" in missing.json()["detail"].lower()


def test_guest_dine_in_cash_order_full_lifecycle(client, bowl, staff_h, admin_h):
    tables = client.get(f"{API}/admin/tables", headers=admin_h).json()
    code = tables[0]["code"]
    scan = client.get(f"{API}/tables/scan/{code}")
    assert scan.status_code == 200 and scan.json()["table"]["number"] == 1
    assert client.get(f"{API}/admin/tables/{tables[0]['id']}/qr.png", headers=admin_h).headers["content-type"] == "image/png"

    client.put(f"{API}/cart/context", json={"table_code": code, "order_type": "dine_in"}, headers=GUEST)
    r = client.post(f"{API}/cart/items", json={"menu_item_id": bowl["id"], "quantity": 2,
                                               "selections": bowl_selections(bowl)}, headers=GUEST)
    assert r.status_code == 201, r.text
    cart = r.json()
    assert cart["item_count"] == 2 and cart["table"]["number"] == 1
    subtotal = 2 * (1095 + 250 + 150)
    assert cart["totals"]["subtotal_cents"] == subtotal
    assert cart["totals"]["tax_cents"] == round(subtotal * 0.08)

    # guest must give a name
    assert client.post(f"{API}/orders/checkout", json={"payment_method": "cash"}, headers=GUEST).status_code == 422
    r = client.post(f"{API}/orders/checkout", json={"payment_method": "cash", "customer_name": "Sam",
                                                    "customer_email": "sam@example.com"}, headers=GUEST)
    assert r.status_code == 201, r.text
    order = r.json()["order"]
    token = r.json()["order_access_token"]
    assert order["status"] == "confirmed" and order["estimated_ready_at"]
    assert client.get(f"{API}/cart", headers=GUEST).json()["item_count"] == 0

    # guest can see it only with the token
    assert client.get(f"{API}/orders/{order['id']}").status_code == 404
    assert client.get(f"{API}/orders/{order['id']}", headers={"X-Order-Token": token}).status_code == 200

    # Websocket snapshot
    with client.websocket_connect(f"{API}/ws/orders/{order['id']}?token={token}") as ws:
        assert ws.receive_json()["event"] == "order.snapshot"

    # staff board shows it
    board = client.get(f"{API}/staff/orders", headers=staff_h).json()
    assert any(o["id"] == order["id"] for o in board["items"])

    # robot claims and cooks
    job = client.post(f"{API}/kitchen/jobs/claim", params={"station": "robot-A"}, headers=KITCHEN).json()
    assert job["order_id"] == order["id"] and job["items"][0]["components"]
    client.post(f"{API}/kitchen/jobs/{job['id']}/status", json={"status": "cooking"}, headers=KITCHEN)
    assert client.get(f"{API}/orders/{order['id']}", headers=staff_h).json()["status"] == "preparing"
    # customer can no longer cancel
    assert client.post(f"{API}/orders/{order['id']}/cancel", json={}, headers={"X-Order-Token": token}).status_code == 409
    client.post(f"{API}/kitchen/jobs/{job['id']}/status", json={"status": "done"}, headers=KITCHEN)
    assert client.get(f"{API}/orders/{order['id']}", headers=staff_h).json()["status"] == "ready"

    client.post(f"{API}/staff/orders/{order['id']}/mark-paid", headers=staff_h)
    done = client.patch(f"{API}/staff/orders/{order['id']}/status", json={"status": "completed"}, headers=staff_h)
    assert done.status_code == 200 and done.json()["status"] == "completed"
    bad = client.patch(f"{API}/staff/orders/{order['id']}/status", json={"status": "preparing"}, headers=staff_h)
    assert bad.status_code == 409

    rv = client.post(f"{API}/reviews", json={"order_id": order["id"], "rating": 5, "comment": "Great",
                                             "item_ratings": [{"menu_item_id": bowl["id"], "rating": 5}]},
                     headers={"X-Order-Token": token})
    assert rv.status_code == 201, rv.text
    assert client.get(f"{API}/reviews/menu-items/{bowl['id']}/summary").json()["rating_avg"] == 5.0

    dash = client.get(f"{API}/admin/dashboard", headers=admin_h)
    assert dash.status_code == 200, dash.text
    assert dash.json()["orders_completed"] >= 1
    assert client.get(f"{API}/admin/reports/orders.csv", headers=admin_h).status_code == 200


def test_customer_card_order_with_points(client, bowl, customer_h, staff_h):
    client.delete(f"{API}/cart", headers=customer_h)
    client.put(f"{API}/cart/context", json={"table_code": None, "order_type": "takeaway"}, headers=customer_h)
    client.post(f"{API}/cart/items", json={"menu_item_id": bowl["id"], "selections": bowl_selections(bowl)},
                headers=customer_h)
    preview = client.get(f"{API}/cart", params={"redeem_points": 200}, headers=customer_h).json()
    assert preview["totals"]["discount_cents"] == 200

    r = client.post(f"{API}/orders/checkout", json={"payment_method": "card", "redeem_points": 200, "tip_cents": 100},
                    headers=customer_h)
    assert r.status_code == 201, r.text
    order, pay = r.json()["order"], r.json()["payment"]
    assert order["status"] == "pending_payment" and pay["provider"] == "mock"
    assert client.get(f"{API}/loyalty/summary", headers=customer_h).json()["points"] == 50

    paid = client.post(f"{API}/payments/{order['id']}/mock-confirm", headers=customer_h).json()
    assert paid["status"] == "confirmed" and paid["payment"]["status"] == "paid"

    job = client.post(f"{API}/kitchen/jobs/claim", headers=KITCHEN).json()
    client.post(f"{API}/kitchen/jobs/{job['id']}/status", json={"status": "done"}, headers=KITCHEN)
    client.patch(f"{API}/staff/orders/{order['id']}/status", json={"status": "completed"}, headers=staff_h)

    summary = client.get(f"{API}/loyalty/summary", headers=customer_h).json()
    expected_earned = ((1495 - 200) // 100) * 10
    assert summary["points"] == 50 + expected_earned
    assert client.get(f"{API}/orders/me", headers=customer_h).json()["total"] >= 1

    re = client.post(f"{API}/orders/{order['id']}/reorder", headers=customer_h).json()
    assert re["added"] == 1


def test_cancel_refunds_points_and_sold_out_ingredient(client, bowl, customer_h, staff_h):
    client.delete(f"{API}/cart", headers=customer_h)
    client.post(f"{API}/cart/items", json={"menu_item_id": bowl["id"], "selections": bowl_selections(bowl)},
                headers=customer_h)
    before = client.get(f"{API}/loyalty/summary", headers=customer_h).json()["points"]
    o = client.post(f"{API}/orders/checkout", json={"payment_method": "pay_at_counter", "redeem_points": 100},
                    headers=customer_h).json()["order"]
    c = client.post(f"{API}/orders/{o['id']}/cancel", json={"reason": "changed mind"}, headers=customer_h)
    assert c.status_code == 200 and c.json()["status"] == "cancelled"
    assert client.get(f"{API}/loyalty/summary", headers=customer_h).json()["points"] == before

    # staff marks salmon sold out -> the saved bowl can't be added
    salmon = pick(bowl, "protein", 3)["ingredient_id"]
    client.patch(f"{API}/staff/ingredients/{salmon}/availability", json={"is_available": False}, headers=staff_h)
    r = client.post(f"{API}/cart/items", json={"menu_item_id": bowl["id"], "selections": bowl_selections(bowl)},
                    headers=customer_h)
    assert r.status_code == 409 and "out of stock" in r.json()["detail"]
    client.patch(f"{API}/staff/ingredients/{salmon}/availability", json={"is_available": True}, headers=staff_h)


def test_saved_recipes(client, bowl, customer_h):
    r = client.post(f"{API}/recipes", json={"name": "My usual", "menu_item_id": bowl["id"],
                                            "selections": bowl_selections(bowl)}, headers=customer_h)
    assert r.status_code == 201, r.text
    rid = r.json()["id"]
    assert r.json()["current_price_cents"] == 1495
    cart = client.post(f"{API}/recipes/{rid}/add-to-cart", headers=customer_h).json()
    assert cart["item_count"] >= 1
    assert client.delete(f"{API}/recipes/{rid}", headers=customer_h).status_code == 200


def test_admin_menu_crud_and_settings(client, admin_h):
    cat = client.post(f"{API}/admin/categories", json={"name": "Desserts"}, headers=admin_h).json()
    ing = client.post(f"{API}/admin/ingredients", json={"name": "Mochi", "group": "topping", "price_cents": 200},
                      headers=admin_h).json()
    item = client.post(f"{API}/admin/menu-items", json={
        "name": "Mochi Cup", "category_id": cat["id"], "base_price_cents": 500,
        "option_groups": [{"key": "extra", "name": "Extra", "min_select": 0, "max_select": 2,
                           "options": [{"ingredient_id": ing["id"]}]}]}, headers=admin_h)
    assert item.status_code == 201, item.text
    assert item.json()["option_groups"][0]["options"][0]["price_cents"] == 200
    upd = client.patch(f"{API}/admin/menu-items/{item.json()['id']}", json={"base_price_cents": 550}, headers=admin_h)
    assert upd.json()["base_price_cents"] == 550

    s = client.patch(f"{API}/admin/settings", json={"tax_rate": 0.1}, headers=admin_h)
    assert s.json()["tax_rate"] == 0.1
    client.patch(f"{API}/admin/settings", json={"tax_rate": 0.08}, headers=admin_h)

    staff = client.post(f"{API}/admin/users", json={"email": "cook@robokitchen.com", "password": "Cook12345",
                                                    "full_name": "Cook", "role": "staff"}, headers=admin_h)
    assert staff.status_code == 201 and staff.json()["role"] == "staff"
    assert client.get(f"{API}/admin/audit-logs", headers=admin_h).json()["total"] > 0
