"""Email sending via SMTP (Gmail, SendGrid SMTP, Mailgun SMTP, SES SMTP, Mailhog...).

If SMTP_HOST is empty the email is written to the application log instead, which is
convenient in development (copy the verification / reset link from the console).
"""
import logging
from email.message import EmailMessage
from email.utils import formataddr
from pathlib import Path

import aiosmtplib
from jinja2 import Environment, FileSystemLoader, select_autoescape

from app.core.config import settings

logger = logging.getLogger(__name__)
_env = Environment(
    loader=FileSystemLoader(Path(__file__).resolve().parent.parent / "templates" / "emails"),
    autoescape=select_autoescape(["html"]),
)


def _money(cents: int) -> str:
    return f"{cents / 100:,.2f}"


_env.filters["money"] = _money


async def send_email(to: str, subject: str, template: str, context: dict) -> None:
    html = _env.get_template(template).render(
        app_name=settings.EMAIL_FROM_NAME, frontend_url=settings.FRONTEND_URL, **context
    )
    if not settings.SMTP_HOST:
        logger.info("[EMAIL - console mode] to=%s subject=%s context=%s", to, subject,
                    {k: v for k, v in context.items() if isinstance(v, (str, int))})
        return
    msg = EmailMessage()
    msg["From"] = formataddr((settings.EMAIL_FROM_NAME, settings.EMAIL_FROM))
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content("Please view this email in an HTML-capable email client.")
    msg.add_alternative(html, subtype="html")
    try:
        await aiosmtplib.send(
            msg,
            hostname=settings.SMTP_HOST,
            port=settings.SMTP_PORT,
            username=settings.SMTP_USER or None,
            password=settings.SMTP_PASSWORD or None,
            start_tls=settings.SMTP_STARTTLS and not settings.SMTP_SSL,
            use_tls=settings.SMTP_SSL,
            timeout=20,
        )
        logger.info("Email sent to %s (%s)", to, subject)
    except Exception:  # noqa: BLE001
        logger.exception("Failed to send email to %s", to)


async def send_verification_email(email: str, name: str, token: str) -> None:
    link = f"{settings.FRONTEND_URL}/verify-email?token={token}"
    await send_email(email, "Verify your email", "verification.html", {"name": name, "link": link})


async def send_password_reset_email(email: str, name: str, token: str) -> None:
    link = f"{settings.FRONTEND_URL}/reset-password?token={token}"
    await send_email(email, "Reset your password", "password_reset.html",
                     {"name": name, "link": link, "minutes": settings.PASSWORD_RESET_EXPIRE_MINUTES})


async def send_order_confirmation(order: dict) -> None:
    email = (order.get("customer") or {}).get("email")
    if not email:
        return
    await send_email(email, f"Order #{order['order_number']} received", "order_confirmation.html", {
        "name": order["customer"].get("name") or "there",
        "order": order,
        "currency": order.get("currency", "usd").upper(),
        "track_link": f"{settings.FRONTEND_URL}/orders/{order['_id']}",
    })


async def send_order_ready(order: dict) -> None:
    email = (order.get("customer") or {}).get("email")
    if not email:
        return
    await send_email(email, f"Order #{order['order_number']} is ready!", "order_ready.html", {
        "name": order["customer"].get("name") or "there",
        "order_number": order["order_number"],
        "table": (order.get("table") or {}).get("number"),
    })
