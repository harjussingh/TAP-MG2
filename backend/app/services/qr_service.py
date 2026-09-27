import io

import qrcode

from app.core.config import settings


def table_scan_url(code: str) -> str:
    return f"{settings.FRONTEND_URL}/?table={code}"


def qr_png(data: str) -> bytes:
    img = qrcode.make(data, box_size=10, border=2)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()
