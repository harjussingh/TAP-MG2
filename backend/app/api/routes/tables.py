from fastapi import APIRouter, Depends, HTTPException

from app.core.database import get_db
from app.schemas.table import TableScanOut
from app.services.settings_service import get_app_settings

router = APIRouter(prefix="/tables", tags=["QR tables"])


@router.get("/scan/{code}", response_model=TableScanOut)
async def scan_table(code: str, db=Depends(get_db)):
    """Called when a customer scans a table QR code. Returns the table + restaurant context."""
    table = await db.tables.find_one({"code": code, "is_active": True})
    if not table:
        raise HTTPException(404, "This QR code is not valid. Please ask a staff member for help.")
    cfg = await get_app_settings(db)
    return {
        "table": {"id": table["_id"], "number": table["number"], "name": table.get("name")},
        "restaurant_name": cfg["restaurant_name"],
        "is_accepting_orders": cfg["is_accepting_orders"],
        "currency": cfg["currency"],
    }
