from fastapi import APIRouter, Depends, HTTPException, Path

from app.core.database import get_db
from app.schemas.table import TableScanOut
from app.services.settings_service import get_app_settings

router = APIRouter(prefix="/tables", tags=["QR tables"])


def _context(table, cfg):
    return {
        "table": {"id": table["_id"], "number": table["number"], "name": table.get("name"),
                  "code": table["code"]},
        "restaurant_name": cfg["restaurant_name"],
        "is_accepting_orders": cfg["is_accepting_orders"],
        "currency": cfg["currency"],
    }


@router.get("/numbers", response_model=list[int])
async def list_table_numbers(db=Depends(get_db)):
    """Table numbers a customer may type in (used to populate the picker on the single-QR flow)."""
    numbers = await db.tables.find({"is_active": True}, {"number": 1}).sort("number", 1).to_list(500)
    return [t["number"] for t in numbers]


@router.get("/by-number/{number}", response_model=TableScanOut)
async def table_by_number(number: int = Path(ge=1, le=9999), db=Depends(get_db)):
    """Single-QR flow: the customer types their table number and we return the same context as a scan."""
    table = await db.tables.find_one({"number": number, "is_active": True})
    if not table:
        raise HTTPException(404, f"Table {number} was not found. Please check the number on your table.")
    cfg = await get_app_settings(db)
    return _context(table, cfg)


@router.get("/scan/{code}", response_model=TableScanOut)
async def scan_table(code: str, db=Depends(get_db)):
    """Called when a customer scans a table QR code. Returns the table + restaurant context."""
    table = await db.tables.find_one({"code": code, "is_active": True})
    if not table:
        raise HTTPException(404, "This QR code is not valid. Please ask a staff member for help.")
    cfg = await get_app_settings(db)
    return _context(table, cfg)
