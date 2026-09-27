# RoboKitchen API Reference (v1)

Base URL: `http://localhost:8000/api/v1` · Interactive docs: `/api/v1/docs` (Swagger) and `/api/v1/redoc`.
This file is the human-readable guide; `docs/openapi.json` is the exact machine-readable contract.

## Conventions

| Topic | Rule |
|---|---|
| Format | JSON in, JSON out. Timestamps are ISO-8601 UTC (`2026-09-21T10:15:00Z`). |
| Money | **Integer cents** everywhere (`1495` = $14.95). Divide by 100 only for display. |
| IDs | Strings with a prefix: `usr_…`, `itm_…`, `ing_…`, `ord_…`, `job_…`, `tbl_…`, `rcp_…`, `rev_…`. |
| Pagination | `?page=1&size=20` → `{ "items": [...], "total": 42, "page": 1, "size": 20, "pages": 3 }` |
| Errors | `{ "detail": "Human readable message" }`. Validation errors (422) return a list in `detail`. |

### Status codes
`200` OK · `201` created · `204` nothing to return (kitchen queue empty) · `400` bad request / invalid token link · `401` not logged in or token expired · `403` wrong role · `404` not found (also used when you may not see an order) · `409` conflict (item sold out, invalid status change, duplicate) · `422` validation · `423` account temporarily locked · `429` rate limited.

### Authentication headers

| Who | Header |
|---|---|
| Logged-in user (customer/staff/admin) | `Authorization: Bearer <access_token>` (valid 30 min; refresh with `/auth/refresh`) |
| Guest cart | `X-Session-Id: <random id generated once by the app>` (8–100 chars: letters, digits, `-`, `_`) |
| Guest viewing their order | `X-Order-Token: <order_access_token from checkout>` |
| Robot kitchen controller | `X-Kitchen-Key: <KITCHEN_API_KEY>` |

Roles: `customer` < `staff` < `admin`. Staff endpoints accept staff and admin; admin endpoints accept admin only.

---

## 1. Auth: `/auth`

| Method | Path | Access | Description |
|---|---|---|---|
| POST | `/auth/register` | Public | Create a customer account and send a verification email. Returns tokens unless `REQUIRE_EMAIL_VERIFICATION=true`. |
| POST | `/auth/login` | Public | Email + password → tokens. 5 failed attempts lock the account for 15 min. |
| POST | `/auth/refresh` | Public | `{refresh_token}` → new token pair. Refresh tokens are single-use (rotation); reusing an old one logs the user out everywhere. |
| POST | `/auth/logout` | Public | `{refresh_token}` → revokes it. |
| POST | `/auth/logout-all` | User | Revoke every session of the user. |
| POST | `/auth/verify-email` | Public | `{token}` from the email link. |
| POST | `/auth/resend-verification` | Public | `{email}`. Always returns 200. |
| POST | `/auth/forgot-password` | Public | `{email}`. Always returns 200 (doesn't reveal whether the account exists). |
| POST | `/auth/reset-password` | Public | `{token, new_password}`. Logs out all sessions. |
| GET | `/auth/me` | User | Current user. |

Passwords: 8–72 characters with at least one letter and one number.

```http
POST /auth/login
{ "email": "customer@robokitchen.com", "password": "Customer123" }
```
```json
{
  "access_token": "eyJ...", "refresh_token": "eyJ...", "token_type": "bearer", "expires_in": 1800,
  "user": { "id": "usr_…", "email": "customer@robokitchen.com", "full_name": "Demo Customer", "role": "customer",
            "email_verified": true, "loyalty_points": 250, "lifetime_points": 250, "loyalty_tier": "bronze",
            "dietary_preferences": [], "allergens": [], "marketing_opt_in": false, "created_at": "…" }
}
```

## 2. Profile: `/users`

| Method | Path | Access | Description |
|---|---|---|---|
| GET | `/users/me` | User | Profile. |
| PATCH | `/users/me` | User | `full_name`, `phone`, `dietary_preferences[]`, `allergens[]`, `marketing_opt_in`. |
| POST | `/users/me/change-password` | User | `{current_password, new_password}`. |
| DELETE | `/users/me` | User | Deletes and anonymises the account (orders are kept for accounting). |

## 3. QR tables: `/tables`

| Method | Path | Access | Description |
|---|---|---|---|
| GET | `/tables/scan/{code}` | Public | Called when the QR is scanned. Returns `{table:{id,number,name}, restaurant_name, is_accepting_orders, currency}`. |

The printed QR points to `FRONTEND_URL/?table=CODE`. The frontend reads `table` from the URL, calls this endpoint, then `PUT /cart/context`.

## 4. Menu: `/menu` (public)

| Method | Path | Description |
|---|---|---|
| GET | `/menu/categories` | Active categories, sorted. |
| GET | `/menu/items` | Filters: `category_id`, `category_slug`, `search`, `tags`, `dietary` (e.g. `vegan`), `exclude_allergens` (e.g. `peanut`), `item_type` (`standard`/`custom_bowl`), `featured`, `include_unavailable`, `page`, `size`. |
| GET | `/menu/items/{id_or_slug}` | One item, with option groups fully expanded (names, prices, calories, allergens, availability). |
| GET | `/menu/ingredients?group=protein` | Ingredient catalogue. |
| POST | `/menu/price-quote` | **Live bowl-builder price**: validates the selections and returns price, calories and allergens. |

### How customisation works
Every menu item can have `option_groups`. A custom bowl is simply an item with groups such as *base (min 1, max 2)*, *protein (1–2)*, *veggies (0–5)*, *sauce (1–2)*, *toppings (0–3)*. Each option refers to an **ingredient**. Marking an ingredient sold out instantly disables it in every item.

```json
// part of GET /menu/items/{id}
{
  "id": "itm_…", "name": "Build Your Own Bowl", "item_type": "custom_bowl", "base_price_cents": 1095,
  "option_groups": [
    { "key": "protein", "name": "Choose your protein", "min_select": 1, "max_select": 2,
      "options": [ { "ingredient_id": "ing_…", "name": "Salmon", "price_cents": 250, "calories": 210,
                     "allergens": ["fish"], "is_default": false, "is_available": true } ] }
  ]
}
```

```http
POST /menu/price-quote
{ "menu_item_id": "itm_…", "quantity": 1,
  "selections": [ { "group_key": "base", "ingredient_id": "ing_…", "quantity": 1 },
                  { "group_key": "protein", "ingredient_id": "ing_…", "quantity": 1 },
                  { "group_key": "sauce", "ingredient_id": "ing_…", "quantity": 1 } ] }
```
```json
{ "menu_item_id": "itm_…", "name": "Build Your Own Bowl", "quantity": 1, "unit_price_cents": 1345,
  "line_total_cents": 1345, "calories": 470, "allergens": ["fish", "soy"],
  "selections": [ { "group_key": "protein", "group_name": "Choose your protein", "ingredient_id": "ing_…",
                    "name": "Salmon", "quantity": 1, "price_cents": 250 } ] }
```
Rules: groups you don't send use their default options; `quantity` counts towards `max_select` ("double protein" = quantity 2); errors come back as 422 (rule broken) or 409 (sold out) with a readable `detail` you can show directly.

## 5. Cart: `/cart`
Works for guests (`X-Session-Id`) and logged-in users (Bearer). Every response is the full cart with **fresh server prices**.

| Method | Path | Description |
|---|---|---|
| GET | `/cart?redeem_points=&tip_cents=` | Cart plus totals. Pass points/tip to preview the checkout total. |
| POST | `/cart/items` | `{menu_item_id, quantity, selections[], special_instructions}`. Identical lines are merged. |
| PATCH | `/cart/items/{line_id}` | Change `quantity`, `selections` or `special_instructions`. |
| DELETE | `/cart/items/{line_id}` | Remove one line. |
| DELETE | `/cart` | Empty the cart. |
| PUT | `/cart/context` | `{table_code, order_type: "dine_in" \| "takeaway"}`. |
| POST | `/cart/merge` | After login: moves the guest cart (send both Bearer and `X-Session-Id`) into the account. |

```json
{
  "id": "cart_…", "item_count": 2, "order_type": "dine_in", "currency": "usd", "has_errors": false,
  "table": { "id": "tbl_…", "number": 1, "name": "Table 1" },
  "items": [ { "line_id": "ln_…", "menu_item_id": "itm_…", "name": "Build Your Own Bowl", "quantity": 2,
               "unit_price_cents": 1495, "line_total_cents": 2990, "selections": [ … ], "error": null } ],
  "totals": { "subtotal_cents": 2990, "discount_cents": 0, "points_redeemed": 0, "tax_rate": 0.08,
              "tax_cents": 239, "service_fee_cents": 0, "tip_cents": 0, "total_cents": 3229 }
}
```
If something became unavailable after it was added, that line gets an `error` message, `has_errors` becomes `true`, and checkout is blocked until the customer removes or edits it.

## 6. Orders: `/orders`

| Method | Path | Access | Description |
|---|---|---|---|
| POST | `/orders/checkout` | Guest or user | Creates the order from the cart. |
| GET | `/orders/me` | User | Order history (`?status=`). |
| GET | `/orders/{id}` | Owner / staff / guest with `X-Order-Token` | Order details. |
| POST | `/orders/{id}/cancel` | Owner / guest token | Only while `pending_payment`/`confirmed` and before the robot starts. Paid orders are refunded; redeemed points are returned. |
| POST | `/orders/{id}/reorder` | Owner / guest token | Copies the items back into the cart → `{added, skipped[]}`. |

```http
POST /orders/checkout
X-Session-Id: 3f9c…            (guest)   or   Authorization: Bearer …
{ "payment_method": "card", "tip_cents": 100, "redeem_points": 0,
  "customer_name": "Sam", "customer_email": "sam@example.com", "notes": "No cutlery" }
```
`customer_name` is required for guests. `redeem_points` is for logged-in users only (minimum 100; at most 50 % of the subtotal; 1 point = 1 cent by default).

```json
{
  "order": { "id": "ord_…", "order_number": 1001, "status": "pending_payment", "estimated_ready_at": null, … },
  "order_access_token": "V2x…",          // store it: guests need it to view, track, cancel and review
  "payment": { "provider": "stripe", "requires_action": true, "client_secret": "pi_…_secret_…",
               "publishable_key": "pk_test_…" }
}
```

### Order status flow
```
card:              pending_payment ──paid──▶ confirmed ─▶ preparing ─▶ ready ─▶ completed
cash/pay_at_counter:                         confirmed ─▶ preparing ─▶ ready ─▶ completed
any of pending_payment / confirmed / preparing ──▶ cancelled
```
* `confirmed` → a kitchen job is created and `estimated_ready_at` is calculated.
* `preparing` / `ready` are set **automatically** when the robot reports `cooking` / `done` (staff can also set them).
* `completed` is set by staff when the food is handed over; loyalty points are awarded then.

## 7. Payments: `/payments`

| Method | Path | Access | Description |
|---|---|---|---|
| GET | `/payments/config` | Public | `{provider, publishable_key, currency, methods}`. |
| POST | `/payments/{order_id}/mock-confirm` | Order viewer | **Only when `PAYMENT_PROVIDER=mock`**: simulates a successful card payment. |
| POST | `/payments/stripe/webhook` | Stripe | Set this URL in the Stripe dashboard for `payment_intent.succeeded` and `payment_intent.payment_failed`. |

Methods: `card` (online), `cash` (paid to staff), `pay_at_counter`. Cash/counter orders go to the kitchen immediately; staff record the payment with `/staff/orders/{id}/mark-paid`.

## 8. Reviews: `/reviews`

| Method | Path | Access | Description |
|---|---|---|---|
| POST | `/reviews` | Owner / guest token | `{order_id, rating 1-5, comment, tags[], item_ratings[{menu_item_id, rating}]}`. One per order, once it is `ready` or `completed`. |
| GET | `/reviews/me` | User | My reviews. |
| GET | `/reviews/menu-items/{id}` | Public | Visible reviews for a dish (paginated). |
| GET | `/reviews/menu-items/{id}/summary` | Public | `{rating_avg, rating_count}`. |

## 9. Saved recipes (saved bowls): `/recipes` (user)

| Method | Path | Description |
|---|---|---|
| POST | `/recipes` | `{name, menu_item_id, selections[], special_instructions}` (validated like a cart item). |
| GET | `/recipes` | List, with the **current** price and `is_available`/`unavailable_reason`. |
| GET / PATCH / DELETE | `/recipes/{id}` | Read, rename or edit, delete. |
| POST | `/recipes/{id}/add-to-cart?quantity=1` | One-tap reorder. |

## 10. Loyalty: `/loyalty` (user)

| Method | Path | Description |
|---|---|---|
| GET | `/loyalty/summary` | `{points, lifetime_points, tier, next_tier, points_to_next_tier, redeemable_value_cents, rules…}` |
| GET | `/loyalty/transactions` | History: `earn`, `redeem`, `refund`, `reverse`, `adjust`. |

Tiers use lifetime points: bronze 0, silver 500, gold 2000, platinum 5000 (configurable). Points earned = floor(dollars spent after discount) × `points_per_dollar` (10), awarded on completion.

## 11. Staff panel: `/staff` (staff, admin)

| Method | Path | Description |
|---|---|---|
| GET | `/staff/orders` | Live board. Default: `confirmed`, `preparing`, `ready` + `pending_payment`. Filters: `status` (repeatable), `table_number`, `include_unpaid`. Oldest first. |
| GET | `/staff/orders/summary` | Counts per status + kitchen queue/failed counts. |
| GET | `/staff/orders/{id}` | Details. |
| PATCH | `/staff/orders/{id}/status` | `{status, note}`. Transitions are validated (409 if not allowed). |
| POST | `/staff/orders/{id}/cancel` | `{reason}`. |
| POST | `/staff/orders/{id}/mark-paid` | Cash/counter payment received (also confirms a pending card order). |
| GET | `/staff/kitchen/jobs` | Robot jobs (default: queued, assigned, cooking, failed). |
| POST | `/staff/kitchen/jobs/{id}/retry` | Re-queue a failed job. |
| POST | `/staff/kitchen/jobs/{id}/status` | Manual override (e.g. finished by hand): `{status: cooking|done|failed}`. |
| GET | `/staff/menu-items` · `/staff/ingredients` | Everything, including unavailable. |
| PATCH | `/staff/menu-items/{id}/availability` · `/staff/ingredients/{id}/availability` | `{is_available}`: sold-out toggle. |

## 12. Robot kitchen: `/kitchen` (`X-Kitchen-Key`)

| Method | Path | Description |
|---|---|---|
| POST | `/kitchen/jobs/claim?station=robot-1` | Atomically takes the next queued job (priority, then oldest). `204` if the queue is empty. |
| GET | `/kitchen/jobs` · `/kitchen/jobs/{id}` | Inspect jobs. |
| POST | `/kitchen/jobs/{id}/status` | `{status: "cooking" | "done" | "failed", message, progress 0-100}`. Sending `cooking` again with a new `progress` just updates progress. |

```json
{ "id": "job_…", "order_id": "ord_…", "order_number": 1001, "table_number": 1, "order_type": "dine_in",
  "status": "assigned", "station": "robot-1", "attempts": 1,
  "items": [ { "line_id": "ln_…", "name": "Build Your Own Bowl", "quantity": 2, "special_instructions": null,
               "components": [ { "ingredient_id": "ing_…", "name": "Salmon", "group": "protein",
                                 "quantity": 1, "dispenser_code": "D09" } ] } ] }
```
Job flow: `queued → assigned → cooking → done`, with `failed` (retry → `queued`) and `cancelled` (order cancelled).

## 13. Admin panel: `/admin` (admin)

| Area | Endpoints |
|---|---|
| Dashboard | `GET /admin/dashboard?date_from=&date_to=` → revenue, orders by status/hour/type, top items, average order, rating, new customers, active orders, failed jobs (default: today UTC). |
| Reports | `GET /admin/reports/orders.csv?date_from=&date_to=` (default: last 30 days). |
| Categories | `GET/POST /admin/categories`, `PATCH/DELETE /admin/categories/{id}` |
| Ingredients | `POST /admin/ingredients`, `PATCH/DELETE /admin/ingredients/{id}` (delete also removes it from every item) |
| Menu items | `GET/POST /admin/menu-items`, `PATCH/DELETE /admin/menu-items/{id}` (full `option_groups` editing) |
| Tables & QR | `GET/POST /admin/tables`, `PATCH/DELETE /admin/tables/{id}`, `POST /admin/tables/{id}/regenerate-code`, `GET /admin/tables/{id}/qr.png` (printable PNG) |
| Users | `GET /admin/users?role=&search=`, `POST /admin/users` (create staff/admin), `GET/PATCH /admin/users/{id}` (role, active), `POST /admin/users/{id}/loyalty-adjust` |
| Orders | `GET /admin/orders?status=&payment_status=&order_number=&user_id=&date_from=&date_to=`, `POST /admin/orders/{id}/refund` |
| Reviews | `GET /admin/reviews?max_rating=&visible=`, `PATCH /admin/reviews/{id}` (`is_visible`, `staff_reply`) |
| Settings | `GET/PATCH /admin/settings`: restaurant name, tax rate, service fee, accepting orders on/off, average prep minutes, loyalty rules, tier thresholds |
| Audit log | `GET /admin/audit-logs?entity=&entity_id=`: who changed what and when |

Example: create a menu item with a customisation group:
```json
POST /admin/menu-items
{ "name": "Poke Bowl", "category_id": "cat_…", "item_type": "custom_bowl", "base_price_cents": 1195,
  "prep_time_seconds": 240, "tags": ["new"], "dietary_tags": [], "allergens": [],
  "option_groups": [
    { "key": "base", "name": "Base", "min_select": 1, "max_select": 1,
      "options": [ { "ingredient_id": "ing_rice", "is_default": true }, { "ingredient_id": "ing_quinoa", "price_cents": 100 } ] } ] }
```

## 14. WebSockets (real-time)

| URL | Auth (query string) | Receives |
|---|---|---|
| `ws://HOST/api/v1/ws/orders/{order_id}?token=…` | guest `order_access_token` **or** a JWT access token | `order.snapshot` (on connect), `order.updated`, `kitchen.progress` |
| `ws://HOST/api/v1/ws/staff?token=<JWT>` | staff/admin JWT | `order.created`, `order.updated`, `job.updated`, `job.failed`, `menu.availability`, `ingredient.availability` |
| `ws://HOST/api/v1/ws/kitchen?key=<KITCHEN_API_KEY>` | kitchen key | `job.created`, `job.updated`, `job.cancelled` |

Message format: `{ "event": "order.updated", "data": { …same shape as the REST object… } }`.
Send the text `ping` every ~25 s to keep the connection alive (server answers `pong`). Invalid auth closes the socket with code `4403`. After a reconnect, re-fetch over REST to catch up.

## 15. Health
`GET /health` → `{status, database, redis, version, environment}` (HTTP 503 if the database is down). `GET /` → name, version and docs URL.
