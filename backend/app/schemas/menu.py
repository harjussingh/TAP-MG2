from typing import Optional

from pydantic import BaseModel, Field, model_validator

from app.models.enums import MenuItemType


# ---------- Categories ----------
class CategoryIn(BaseModel):
    name: str = Field(min_length=1, max_length=60)
    slug: Optional[str] = Field(None, max_length=60)
    description: str = ""
    image_url: Optional[str] = None
    sort_order: int = 0
    is_active: bool = True


class CategoryUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=60)
    description: Optional[str] = None
    image_url: Optional[str] = None
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


class CategoryOut(BaseModel):
    id: str
    name: str
    slug: str
    description: str = ""
    image_url: Optional[str] = None
    sort_order: int = 0
    is_active: bool = True


# ---------- Ingredients (bowl-builder building blocks) ----------
class IngredientIn(BaseModel):
    name: str = Field(min_length=1, max_length=60)
    group: str = Field(description="base | protein | veggies | sauce | topping | ... (free text)")
    price_cents: int = Field(0, ge=0)
    calories: int = Field(0, ge=0)
    allergens: list[str] = []
    dietary_tags: list[str] = []
    image_url: Optional[str] = None
    is_available: bool = True
    dispenser_code: Optional[str] = Field(None, description="ID of the robot dispenser that holds this ingredient")


class IngredientUpdate(BaseModel):
    name: Optional[str] = None
    group: Optional[str] = None
    price_cents: Optional[int] = Field(None, ge=0)
    calories: Optional[int] = Field(None, ge=0)
    allergens: Optional[list[str]] = None
    dietary_tags: Optional[list[str]] = None
    image_url: Optional[str] = None
    is_available: Optional[bool] = None
    dispenser_code: Optional[str] = None


class IngredientOut(IngredientIn):
    id: str


# ---------- Menu items ----------
class OptionIn(BaseModel):
    ingredient_id: str
    price_cents: Optional[int] = Field(None, ge=0, description="Overrides the ingredient price for this item")
    is_default: bool = False


class OptionGroupIn(BaseModel):
    key: str = Field(min_length=1, max_length=40)
    name: str = Field(min_length=1, max_length=60)
    min_select: int = Field(0, ge=0)
    max_select: int = Field(1, ge=1)
    options: list[OptionIn] = []

    @model_validator(mode="after")
    def _check(self):
        if self.max_select < self.min_select:
            raise ValueError("max_select must be >= min_select")
        return self


class MenuItemIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    slug: Optional[str] = None
    description: str = ""
    category_id: str
    item_type: MenuItemType = MenuItemType.standard
    base_price_cents: int = Field(ge=0)
    image_url: Optional[str] = None
    tags: list[str] = []
    dietary_tags: list[str] = []
    allergens: list[str] = []
    calories: int = Field(0, ge=0)
    prep_time_seconds: int = Field(180, ge=0)
    is_available: bool = True
    is_featured: bool = False
    sort_order: int = 0
    option_groups: list[OptionGroupIn] = []


class MenuItemUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category_id: Optional[str] = None
    item_type: Optional[MenuItemType] = None
    base_price_cents: Optional[int] = Field(None, ge=0)
    image_url: Optional[str] = None
    tags: Optional[list[str]] = None
    dietary_tags: Optional[list[str]] = None
    allergens: Optional[list[str]] = None
    calories: Optional[int] = Field(None, ge=0)
    prep_time_seconds: Optional[int] = Field(None, ge=0)
    is_available: Optional[bool] = None
    is_featured: Optional[bool] = None
    sort_order: Optional[int] = None
    option_groups: Optional[list[OptionGroupIn]] = None


class OptionOut(BaseModel):
    ingredient_id: str
    name: str
    price_cents: int
    calories: int = 0
    allergens: list[str] = []
    dietary_tags: list[str] = []
    image_url: Optional[str] = None
    is_default: bool = False
    is_available: bool = True


class OptionGroupOut(BaseModel):
    key: str
    name: str
    min_select: int
    max_select: int
    options: list[OptionOut]


class MenuItemOut(BaseModel):
    id: str
    name: str
    slug: str
    description: str = ""
    category_id: str
    item_type: MenuItemType
    base_price_cents: int
    image_url: Optional[str] = None
    tags: list[str] = []
    dietary_tags: list[str] = []
    allergens: list[str] = []
    calories: int = 0
    prep_time_seconds: int = 180
    is_available: bool = True
    is_featured: bool = False
    sort_order: int = 0
    rating_avg: Optional[float] = None
    rating_count: int = 0
    option_groups: list[OptionGroupOut] = []


class AvailabilityIn(BaseModel):
    is_available: bool


# ---------- Pricing ----------
class SelectionIn(BaseModel):
    group_key: str
    ingredient_id: str
    quantity: int = Field(1, ge=1, le=5)


class PriceQuoteIn(BaseModel):
    menu_item_id: str
    quantity: int = Field(1, ge=1, le=20)
    selections: list[SelectionIn] = []


class PricedSelection(BaseModel):
    group_key: str
    group_name: str
    ingredient_id: str
    name: str
    quantity: int
    price_cents: int


class PricedLine(BaseModel):
    menu_item_id: str
    name: str
    image_url: Optional[str] = None
    item_type: MenuItemType = MenuItemType.standard
    quantity: int
    unit_price_cents: int
    line_total_cents: int
    selections: list[PricedSelection] = []
    calories: int = 0
    allergens: list[str] = []
    special_instructions: Optional[str] = None
