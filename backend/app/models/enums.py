"""Enumerations shared by schemas, services and database documents."""
from enum import Enum


class UserRole(str, Enum):
    customer = "customer"
    staff = "staff"
    admin = "admin"


class OrderType(str, Enum):
    dine_in = "dine_in"
    takeaway = "takeaway"


class OrderStatus(str, Enum):
    pending_payment = "pending_payment"  # card order waiting for payment
    confirmed = "confirmed"              # paid (or pay-at-counter) and sent to the kitchen queue
    preparing = "preparing"              # robot started cooking
    ready = "ready"                      # ready for pickup / serving
    completed = "completed"              # handed to the customer
    cancelled = "cancelled"


ACTIVE_ORDER_STATUSES = [OrderStatus.confirmed.value, OrderStatus.preparing.value, OrderStatus.ready.value]


class PaymentMethod(str, Enum):
    card = "card"                    # online (Stripe or mock)
    cash = "cash"                    # paid to staff
    pay_at_counter = "pay_at_counter"


class PaymentStatus(str, Enum):
    unpaid = "unpaid"
    pending = "pending"
    paid = "paid"
    failed = "failed"
    refunded = "refunded"


class KitchenJobStatus(str, Enum):
    queued = "queued"
    assigned = "assigned"   # claimed by a robot station
    cooking = "cooking"
    done = "done"
    failed = "failed"
    cancelled = "cancelled"


class MenuItemType(str, Enum):
    standard = "standard"
    custom_bowl = "custom_bowl"


class LoyaltyTxnType(str, Enum):
    earn = "earn"
    redeem = "redeem"
    refund = "refund"       # redeemed points returned after a cancellation
    reverse = "reverse"     # earned points removed after a refund
    adjust = "adjust"       # manual admin adjustment


class LoyaltyTier(str, Enum):
    bronze = "bronze"
    silver = "silver"
    gold = "gold"
    platinum = "platinum"
