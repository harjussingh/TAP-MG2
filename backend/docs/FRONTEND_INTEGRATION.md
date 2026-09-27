# RoboKitchen — Frontend Integration Guide

How to connect the customer app, the Staff panel and the Admin panel to the backend.
Every path below is relative to the base URL:

```
Local:       http://localhost:8000/api/v1
Production:  https://<your-render-app>.onrender.com/api/v1
Swagger UI:  http://localhost:8000/docs   (try every endpoint in the browser)
```

> **Desktop vs mobile panels.** The Staff and Admin panels use exactly the same `/staff/*` and `/admin/*`
> endpoints whether the client chooses the web/desktop layout or the mobile layout. Layout is purely a
> frontend decision; nothing in this guide changes.

---

## 1. Headers you will use

| Header | When | Value |
|---|---|---|
| `Authorization` | Logged-in customer, staff, admin | `Bearer <access_token>` |
| `X-Session-Id` | **Always** from the customer app (guest cart identity) | A UUID you generate once and keep in `localStorage` |
| `X-Order-Token` | Guest viewing/cancelling/reviewing their order | `order_access_token` returned by checkout |
| `X-Kitchen-Key` | Robot / kitchen controller only (never in a browser) | `KITCHEN_API_KEY` |

Errors always look like `{"detail": "..."}` (422 validation errors: `{"detail": [ {loc, msg, type} ]}`).
Money is always **integer cents** — format with `(cents / 100).toFixed(2)`.

## 2. Drop-in API client (plain JavaScript, works in React/Vue/React Native)

```javascript
// api.js
const BASE = import.meta.env?.VITE_API_URL ?? "http://localhost:8000/api/v1";

export const store = {
  get access()  { return localStorage.getItem("rk_access"); },
  get refresh() { return localStorage.getItem("rk_refresh"); },
  setTokens(t)  { localStorage.setItem("rk_access", t.access_token); localStorage.setItem("rk_refresh", t.refresh_token); },
  clear()       { localStorage.removeItem("rk_access"); localStorage.removeItem("rk_refresh"); },
  get sessionId() {
    let id = localStorage.getItem("rk_session");
    if (!id) { id = crypto.randomUUID(); localStorage.setItem("rk_session", id); }
    return id;
  },
  orderToken(orderId)        { return localStorage.getItem(`rk_order_${orderId}`); },
  saveOrderToken(orderId, t) { localStorage.setItem(`rk_order_${orderId}`, t); },
};

let refreshing = null; // share one refresh call between parallel 401s

async function refreshTokens() {
  if (!store.refresh) throw new Error("no refresh token");
  refreshing ??= fetch(`${BASE}/auth/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token: store.refresh }),
  }).then(async r => {
    if (!r.ok) { store.clear(); throw new Error("session expired"); }
    store.setTokens(await r.json());
  }).finally(() => { refreshing = null; });
  return refreshing;
}

export async function api(path, { method = "GET", body, orderId, headers = {}, raw = false } = {}, retry = true) {
  const h = { "X-Session-Id": store.sessionId, ...headers };
  if (body !== undefined) h["Content-Type"] = "application/json";
  if (store.access) h.Authorization = `Bearer ${store.access}`;
  if (orderId && store.orderToken(orderId)) h["X-Order-Token"] = store.orderToken(orderId);

  const res = await fetch(`${BASE}${path}`, { method, headers: h, body: body !== undefined ? JSON.stringify(body) : undefined });

  if (res.status === 401 && retry && store.refresh) {
    await refreshTokens();
    return api(path, { method, body, orderId, headers, raw }, false);
  }
  if (raw) return res;
  const data = res.status === 204 ? null : await res.json().catch(() => null);
  if (!res.ok) {
    const d = data?.detail;
    const msg = Array.isArray(d) ? d.map(e => e.msg).join(", ") : d || res.statusText;
    throw Object.assign(new Error(msg), { status: res.status, data });
  }
  return data;
}

export const money = cents => `$${(cents / 100).toFixed(2)}`;
```

Refresh tokens **rotate**: every `/auth/refresh` returns a new pair and invalidates the old refresh token.
Always save the new pair (the client above does). Replaying an old refresh token logs the user out everywhere.

---

## 3. Customer app — screen by screen

### 3.1 QR scan / landing
The QR printed on each table points to `FRONTEND_URL/?table=<code>`.

```javascript
const code = new URLSearchParams(location.search).get("table");
if (code) {
  const { table } = await api(`/tables/scan/${code}`);          // 404 if code unknown/inactive
  await api("/cart/context", { method: "PUT", body: { table_code: code, order_type: "dine_in" } });
  showBanner(`Ordering for ${table.name}`);
}
// No QR → takeaway:
// await api("/cart/context", { method: "PUT", body: { order_type: "takeaway" } });
```

### 3.2 Menu / home
| UI | Call |
|---|---|
| Category tabs | `GET /menu/categories` |
| Item grid | `GET /menu/items?category_id=&search=&dietary=vegan&exclude_allergens=peanut&featured=true&page=1&size=20` |
| Item detail | `GET /menu/items/{id or slug}` |
| Ratings under item | `GET /reviews/menu-items/{id}/summary` and `GET /reviews/menu-items/{id}` |

Paged responses: `{ items, total, page, size, pages }`. Hide/grey items where `is_available === false`.

### 3.3 Custom bowl builder
The bowl is the menu item with `item_type === "custom_bowl"`. Its `option_groups` drive the steps
(base → protein → veggies → sauce → toppings). Each group has `min_select`/`max_select` and `options[]`
with `ingredient_id`, `name`, `price_cents`, `calories`, `allergens`, `is_available`.

Show live price and calories while the user picks — ask the server, don't calculate on the client:

```javascript
const selections = [
  { group_key: "base",    ingredient_id: "ing_…", quantity: 1 },
  { group_key: "protein", ingredient_id: "ing_…", quantity: 1 },
];
const quote = await api("/menu/price-quote", { method: "POST", body: { menu_item_id: bowl.id, quantity: 1, selections } });
// quote.unit_price_cents, quote.line_total_cents, quote.calories, quote.allergens
// 422 with a readable message if a group's min/max rule is broken or an ingredient is sold out
```
Debounce this call (~250 ms) as the user taps options.

### 3.4 Cart
```javascript
await api("/cart/items", { method: "POST", body: { menu_item_id, quantity: 1, selections, special_instructions: "no onions" } });
const cart = await api("/cart");                                   // items, totals, table, order_type, item_count
await api(`/cart/items/${lineId}`, { method: "PATCH", body: { quantity: 3 } });
await api(`/cart/items/${lineId}`, { method: "DELETE" });
await api("/cart", { method: "DELETE" });                           // empty cart
```
`cart.totals` = `{ subtotal_cents, tax_cents, service_fee_cents, total_cents, … }`. Lines with a problem
(e.g. ingredient sold out since added) come back with `error` set and `cart.has_errors === true` — show it and block checkout.

### 3.5 Login / register (optional for customers — guests can order)
```javascript
const t = await api("/auth/login", { method: "POST", body: { email, password } });
store.setTokens(t);                          // t.user has role, loyalty_points, loyalty_tier…
await api("/cart/merge", { method: "POST" }); // IMPORTANT: moves the guest cart into the account
```
| Screen | Call |
|---|---|
| Register | `POST /auth/register {email, password, full_name, phone?, marketing_opt_in?}` → same token response; a verification email is sent |
| Verify email page (`/verify-email?token=`) | `POST /auth/verify-email {token}` |
| Forgot password | `POST /auth/forgot-password {email}` (always 200) |
| Reset page (`/reset-password?token=`) | `POST /auth/reset-password {token, new_password}` |
| Logout | `POST /auth/logout {refresh_token}` then `store.clear()` |
| Profile | `GET/PATCH /users/me`, `POST /users/me/change-password`, `DELETE /users/me` |

Password rule: 8–72 chars with at least one letter and one number.

### 3.6 Checkout & payment
```javascript
const { order, order_access_token, payment } = await api("/orders/checkout", {
  method: "POST",
  body: {
    payment_method: "card",           // "card" | "cash" | "pay_at_counter"
    tip_cents: 100,
    redeem_points: 0,                 // logged-in users only
    customer_name: "Sam",             // required for guests
    customer_email: "sam@example.com",
    notes: null,
  },
});
store.saveOrderToken(order.id, order_access_token);   // keep it — guests need it to track/review

if (payment.requires_action) {
  if (payment.provider === "mock") {
    // Demo mode: show a fake "Pay" button, then:
    await api(`/payments/${order.id}/mock-confirm`, { method: "POST", orderId: order.id });
  } else if (payment.provider === "stripe") {
    const stripe = Stripe(payment.publishable_key);
    const { error } = await stripe.confirmCardPayment(payment.client_secret, { payment_method: { card: cardElement } });
    if (error) return showError(error.message);
    // The backend marks the order paid from the Stripe webhook — just go to tracking.
  }
}
navigate(`/orders/${order.id}`);
```
Cash / pay-at-counter orders are `confirmed` immediately and go straight to the robot queue; staff mark them paid.
Card orders sit in `pending_payment` until payment succeeds. `GET /payments/config` tells the app which provider is active.

### 3.7 Live order tracking (WebSocket)
```javascript
export function trackOrder(orderId, onUpdate) {
  const wsBase = BASE.replace(/^http/, "ws");
  const token = store.orderToken(orderId) ?? store.access;
  let ws, ping, stopped = false, delay = 1000;

  const open = () => {
    ws = new WebSocket(`${wsBase}/ws/orders/${orderId}?token=${encodeURIComponent(token)}`);
    ws.onopen = () => { delay = 1000; ping = setInterval(() => ws.send("ping"), 25000); };
    ws.onmessage = e => {
      if (e.data === "pong") return;
      const msg = JSON.parse(e.data);        // { event, data }
      // event: "order.snapshot" (on connect) | "order.updated" | "order.created"
      onUpdate(msg.data);                    // full order: status, estimated_ready_at, status_history…
    };
    ws.onclose = () => { clearInterval(ping); if (!stopped) setTimeout(open, delay = Math.min(delay * 2, 30000)); };
  };
  open();
  return () => { stopped = true; ws.close(); };
}
```
Progress bar mapping: `confirmed` = "In queue" → `preparing` = "Robot is cooking" → `ready` = "Ready for pickup / on its way" → `completed`.
Fallback without WebSocket: poll `GET /orders/{id}` every 5 s (pass `orderId` so the guest token is sent).

Cancel (only while `pending_payment`/`confirmed`): `POST /orders/{id}/cancel {reason?}` — card payments and redeemed points are refunded automatically.

### 3.8 After the meal
| UI | Call |
|---|---|
| Rate order | `POST /reviews {order_id, rating 1-5, comment?, tags?, item_ratings?:[{menu_item_id, rating}]}` (guest: pass `orderId` so `X-Order-Token` is sent). Only for `completed` orders, once. |
| Order history | `GET /orders/me` (logged in) |
| Reorder | `POST /orders/{id}/reorder` → fills the cart, reports anything no longer available |
| Save bowl as favourite | `POST /recipes {name, menu_item_id, selections, special_instructions?}` |
| My saved bowls | `GET /recipes` (live price + availability warnings) → `POST /recipes/{id}/add-to-cart` |
| Loyalty card | `GET /loyalty/summary` (points, tier, next tier, redeemable value) · `GET /loyalty/transactions` |

---

## 4. Staff panel (desktop or mobile — same API)

Login with a staff/admin account using the same `/auth/login`. Check `user.role` is `staff` or `admin`.

| Screen | Call |
|---|---|
| Live order board (columns) | `GET /staff/orders?status=confirmed&status=preparing&status=ready` · counts: `GET /staff/orders/summary` |
| Order detail | `GET /staff/orders/{id}` |
| Move order | `PATCH /staff/orders/{id}/status {status, note?}` — invalid moves return 409 |
| Mark cash paid | `POST /staff/orders/{id}/mark-paid` |
| Cancel | `POST /staff/orders/{id}/cancel {reason?}` |
| Robot queue | `GET /staff/kitchen/jobs` · retry failed: `POST /staff/kitchen/jobs/{id}/retry` · override: `POST /staff/kitchen/jobs/{id}/status` |
| Sold-out toggles | `GET /staff/ingredients` + `PATCH /staff/ingredients/{id}/availability {is_available}` · same for `/staff/menu-items` |

Real-time board:
```javascript
const ws = new WebSocket(`${wsBase}/ws/staff?token=${encodeURIComponent(store.access)}`);
ws.onmessage = e => {
  if (e.data === "pong") return;
  const { event, data } = JSON.parse(e.data);
  // "order.created" → play a sound, add card
  // "order.updated" → move the card to data.status column
  // "job.updated" / "job.failed" → update robot status / show alert
};
setInterval(() => ws.readyState === 1 && ws.send("ping"), 25000);
```
The access token lasts `ACCESS_TOKEN_EXPIRE_MINUTES`; when the socket closes with an auth error, refresh and reconnect.

## 5. Admin panel (desktop or mobile — same API)

| Screen | Call |
|---|---|
| Dashboard KPIs & charts | `GET /admin/dashboard?date_from=&date_to=` (defaults to today; revenue, orders, avg ticket, top items, status breakdown) |
| Export | `GET /admin/reports/orders.csv?date_from=&date_to=` (use `raw: true`, then `res.blob()`) |
| Menu: categories | `GET/POST /admin/categories`, `PATCH/DELETE /admin/categories/{id}` |
| Menu: ingredients | `POST /admin/ingredients`, `PATCH/DELETE /admin/ingredients/{id}` (list via `/staff/ingredients`) |
| Menu: items & bowl options | `GET/POST /admin/menu-items`, `PATCH/DELETE /admin/menu-items/{id}` |
| Orders & refunds | `GET /admin/orders?status=&payment_status=&order_number=&date_from=&date_to=` · `POST /admin/orders/{id}/refund {reason?}` |
| Users & staff accounts | `GET/POST /admin/users`, `GET/PATCH /admin/users/{id}` (role, active) · `POST /admin/users/{id}/loyalty-adjust {points, reason}` |
| Reviews moderation | `GET /admin/reviews` · `PATCH /admin/reviews/{id} {is_visible?, staff_reply?}` |
| Tables & QR codes | `GET/POST /admin/tables`, `PATCH/DELETE /admin/tables/{id}`, `POST /admin/tables/{id}/regenerate-code`, QR image: `GET /admin/tables/{id}/qr.png` |
| Settings | `GET/PATCH /admin/settings` (tax rate, service fee, loyalty rules, pause ordering) |
| Audit log | `GET /admin/audit-logs` |

Showing the QR image (needs the auth header, so fetch it as a blob):
```javascript
const res = await api(`/admin/tables/${id}/qr.png`, { raw: true });
img.src = URL.createObjectURL(await res.blob());
```

## 6. Robot / kitchen controller (server-to-server)

```
GET  /kitchen/jobs?status=queued                 X-Kitchen-Key: <key>
POST /kitchen/jobs/claim?station=robot-A         → next job (204 if queue empty)
POST /kitchen/jobs/{id}/status {status: "cooking"|"done"|"failed", progress?, message?}
WS   /ws/kitchen?key=<key>                       → "job.created" pushes instead of polling
```
Each job contains every ingredient with its `dispenser_code`, so the robot needs no other lookups.
`cooking` automatically sets the order to `preparing`; `done` sets it to `ready` and notifies the customer.

## 7. CORS & environments

Add every frontend origin (local dev, Figma-exported site, production domain) to `ALLOWED_ORIGINS` in `.env`,
as a comma-separated list. Set `FRONTEND_URL` to the customer app's URL — it is used in QR codes and email links
(`/verify-email?token=`, `/reset-password?token=`, `/orders/{id}`), so the frontend needs those three routes.

## 8. Checklist for the frontend team

- [ ] Generate and persist `X-Session-Id` on first load; send it on every customer request.
- [ ] Call `POST /cart/merge` right after login/register.
- [ ] Save `order_access_token` per order; send as `X-Order-Token` for guest order pages.
- [ ] Never compute prices on the client — show `price-quote` / `cart.totals` values.
- [ ] Format cents → currency only at render time.
- [ ] Handle 409 (invalid state change), 422 (validation / sold out), 429 (rate limited, retry later).
- [ ] WebSockets: send `"ping"` every ~25 s and reconnect with back-off.
