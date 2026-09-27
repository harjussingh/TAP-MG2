from typing import Optional

from pydantic import BaseModel, Field


class TableIn(BaseModel):
    number: int = Field(ge=1)
    name: Optional[str] = Field(None, max_length=40)
    seats: int = Field(4, ge=1, le=50)
    zone: Optional[str] = Field(None, max_length=40)
    is_active: bool = True


class TableUpdate(BaseModel):
    number: Optional[int] = Field(None, ge=1)
    name: Optional[str] = None
    seats: Optional[int] = Field(None, ge=1, le=50)
    zone: Optional[str] = None
    is_active: Optional[bool] = None


class TableOut(BaseModel):
    id: str
    number: int
    name: Optional[str] = None
    code: str
    seats: int
    zone: Optional[str] = None
    is_active: bool
    scan_url: str


class TableRef(BaseModel):
    id: str
    number: int
    name: Optional[str] = None


class TableScanOut(BaseModel):
    table: TableRef
    restaurant_name: str
    is_accepting_orders: bool
    currency: str
