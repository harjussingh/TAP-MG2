# RoboKitchen Backend (v2)

Backend for the RoboKitchen robotic-kitchen ordering system:

* **Customer app** (QR table ordering, menu, custom bowl builder, cart, guest or account checkout, live order tracking, reviews, saved bowls, loyalty points)
* **Staff panel** (live order board, status changes, cash/counter payments, sold-out toggles, kitchen job monitoring)
* **Admin panel** (dashboard KPIs, CSV reports, menu/ingredient/category management, tables and QR codes, users and roles, reviews moderation, refunds, business settings, audit log)
* **Robot kitchen API** (job queue the robot controller polls or listens to over WebSocket)

Stack: **FastAPI · MongoDB (Motor) · optional Redis · JWT · SMTP email · Stripe (or mock payments) · WebSockets**.

> **Desktop vs mobile Admin/Staff panels:** the backend does not depend on that decision. Both layouts use exactly the same `/staff/*` and `/admin/*` endpoints, so frontend work can continue whichever design the client confirms.

---

## 1. Quick start (2 minutes, no database needed)

```bash
python -m venv venv
source venv/bin/activate            # Windows: venv\Scripts\activate
pip install -r requirements-dev.txt
cp .env.example .env
make demo                           # or: MONGODB_URL=mongomock:// SEED_ON_STARTUP=true uvicorn app.main:app --reload
```

Open **http://localhost:8000/api/v1/docs** (Swagger). The demo uses an in-memory database with sample data:

| Role | Email | Password |
|---|---|---|
| Admin | admin@robokitchen.com | Admin12345 |
| Staff | staff@robokitchen.com | Staff12345 |
| Customer (250 points) | customer@robokitchen.com | Customer123 |

In Swagger click **Authorize**, paste the `access_token` from `POST /auth/login`, and try the endpoints.
Get a table QR code from `GET /admin/tables` (the `code` field) to test `GET /tables/scan/{code}`.

## 2. Run with a real database

### Option A: MongoDB Atlas (free M0 cluster)
1. Create a cluster at mongodb.com/atlas, add a database user, and allow your IP under *Network Access*.
2. *Connect → Drivers* → copy the `mongodb+srv://...` string into `MONGODB_URL` in `.env`.
3. Load demo data once (optional) and start:
```bash
python -m scripts.seed_data            # or: python -m scripts.seed_data --reset  (wipes everything)
uvicorn app.main:app --reload
```
4. For production, create your own admin instead of the demo accounts:
```bash
python -m scripts.create_admin owner@restaurant.com "StrongPass123" "Owner Name"
```

Indexes are created automatically on startup; you never need to create collections by hand.

### Option B: Docker (API + MongoDB + Redis + Mailhog)
```bash
cp .env.example .env
docker compose up -d --build
docker compose exec api python -m scripts.seed_data
```
API: http://localhost:8000 · Emails: http://localhost:8025 (Mailhog catches every email).

## 3. Configuration you must know

| Variable | Purpose |
|---|---|
| `SECRET_KEY` | JWT signing key. **Must** be changed in production (the app refuses to start otherwise). |
| `MONGODB_URL` | Atlas / local URL, or `mongomock://` for the in-memory demo. |
| `FRONTEND_URL` | Used in email links (`/verify-email`, `/reset-password`, `/orders/{id}`) and in table QR codes (`/?table=CODE`). |
| `ALLOWED_ORIGINS` | Comma-separated list of frontend origins (CORS). |
| `SMTP_*` | Empty `SMTP_HOST` = emails are printed in the server log (handy in development). Gmail needs an App Password. |
| `PAYMENT_PROVIDER` | `mock` (default, a fake "confirm payment" endpoint) or `stripe`. |
| `KITCHEN_API_KEY` | Shared secret the robot controller sends in `X-Kitchen-Key`. |
| `REDIS_URL` | Optional. Required only if you run several workers/instances (shared rate limits + WebSocket broadcasts). |

Tax rate, service fee, loyalty rules and "accepting orders" are **runtime settings**: admins change them with `PATCH /admin/settings` without a redeploy. The `.env` values are only defaults.

## 4. Project structure

```
app/
  main.py                  app factory, middleware, router registration, /health
  core/                    config, MongoDB + indexes, JWT/bcrypt, Redis, rate limit, WebSocket manager
  models/enums.py          roles, order/payment/kitchen statuses
  schemas/                 Pydantic request/response models (these define the API contract)
  services/                business logic: pricing, cart, orders, kitchen, loyalty, payments, email, seed
  api/deps.py              auth dependencies (current user, roles, guest session, kitchen key, order access)
  api/routes/              auth, users, tables, menu, cart, orders, payments, reviews, recipes, loyalty,
                           staff, kitchen, admin_menu, admin, ws (WebSockets)
  templates/emails/        verification, password reset, order confirmation, order ready
scripts/                   seed_data, create_admin, export_openapi
tests/                     end-to-end tests (run against an in-memory MongoDB)
docs/                      API.md, DATABASE.md, FRONTEND_INTEGRATION.md, openapi.json
```

## 5. Documentation

* **[docs/API.md](docs/API.md)**: every endpoint, who can call it, request/response examples, errors, WebSockets.
* **[docs/DATABASE.md](docs/DATABASE.md)**: all 16 MongoDB collections with fields, indexes and relationships.
* **[docs/FRONTEND_INTEGRATION.md](docs/FRONTEND_INTEGRATION.md)**: how each prototype screen connects to the API, with ready-to-use JavaScript.
* **docs/openapi.json**: import into Postman/Insomnia, or generate a typed client (`npx openapi-typescript docs/openapi.json -o api.d.ts`). Regenerate with `make openapi`.

## 6. Tests

```bash
make test        # 10 end-to-end tests: auth, roles, bowl pricing, guest dine-in order -> robot -> ready ->
                 # review, card payment + loyalty, cancellation refunds, sold-out ingredients, admin CRUD
```

## 7. Deployment

* **Render**: `render.yaml` is included (New → Blueprint). Set `MONGODB_URL`, `FRONTEND_URL` and `ALLOWED_ORIGINS` in the dashboard.
* **Railway / Fly / any Docker host**: use the `Dockerfile`; it honours `$PORT` and `$WEB_CONCURRENCY`.
* Production checklist: strong `SECRET_KEY` and `KITCHEN_API_KEY`, `DEBUG=false`, real `ALLOWED_ORIGINS`, HTTPS in front, `PAYMENT_PROVIDER=stripe` with the webhook configured, Atlas IP allow-list restricted, and `REDIS_URL` if you run more than one worker.

## 8. What changed from the v1 backend document

* v1 described files (models, routes, services) that were never written; v2 is complete, runnable and tested.
* `TrustedHostMiddleware` was given URLs instead of host names (it would reject every request in production), so it was removed. Run behind your platform's proxy instead.
* `uuid==1.30` in requirements shadowed Python's built-in `uuid` module, so it was removed. Unused Celery/Flower, beanie and prometheus packages were also removed; email is sent with FastAPI background tasks.
* `python-jose` + `passlib` were replaced by `PyJWT` + `bcrypt` (both maintained).
* Money is stored as **integer cents** everywhere (no float rounding errors).
* Prices are always recalculated on the server, so the client can never set a price.
* The API is versioned under `/api/v1`.

## 9. Ideas for later
Push notifications (FCM), per-ingredient stock counts from the robot's dispensers, promo codes, multi-restaurant support (add `restaurant_id` to every collection), and Sentry for error tracking.
