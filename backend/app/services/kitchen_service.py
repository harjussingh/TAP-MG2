"""Robot kitchen job queue."""
import logging

import httpx
from fastapi import HTTPException
from fastapi.encoders import jsonable_encoder
from pymongo import ReturnDocument

from app.core.config import settings
from app.core.websocket import ws_manager
from app.utils.helpers import doc_out, new_id, utcnow

logger = logging.getLogger(__name__)
ACTIVE_JOB_STATUSES = ["queued", "assigned", "cooking"]

# Which job transitions are allowed
JOB_TRANSITIONS = {
    "queued": {"assigned", "cooking", "failed", "cancelled"},
    "assigned": {"cooking", "done", "failed", "queued", "cancelled"},
    "cooking": {"done", "failed", "cancelled"},
    "failed": {"queued", "cancelled"},
    "done": set(),
    "cancelled": set(),
}


def job_out(job: dict) -> dict:
    return doc_out(job)


async def jobs_ahead(db) -> int:
    return await db.kitchen_jobs.count_documents({"status": {"$in": ACTIVE_JOB_STATUSES}})


async def create_job(db, order: dict) -> dict:
    now = utcnow()
    job = {
        "_id": new_id("job"),
        "order_id": order["_id"],
        "order_number": order["order_number"],
        "table_number": (order.get("table") or {}).get("number"),
        "order_type": order["order_type"],
        "status": "queued",
        "priority": 0,
        "station": None,
        "attempts": 0,
        "progress": 0,
        "message": None,
        "items": [
            {
                "line_id": li["line_id"],
                "menu_item_id": li["menu_item_id"],
                "name": li["name"],
                "quantity": li["quantity"],
                "special_instructions": li.get("special_instructions"),
                "components": [
                    {"ingredient_id": s["ingredient_id"], "name": s["name"], "group": s["group_key"],
                     "quantity": s["quantity"], "dispenser_code": s.get("dispenser_code")}
                    for s in li.get("selections", [])
                ],
            }
            for li in order["items"]
        ],
        "created_at": now, "updated_at": now,
        "assigned_at": None, "started_at": None, "completed_at": None,
    }
    await db.kitchen_jobs.insert_one(job)
    await ws_manager.publish("kitchen", "job.created", job_out(job))
    await notify_kitchen_webhook("job.created", job)
    return job


async def notify_kitchen_webhook(event: str, job: dict) -> None:
    if not settings.KITCHEN_WEBHOOK_URL:
        return
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            await client.post(settings.KITCHEN_WEBHOOK_URL,
                              json={"event": event, "job": jsonable_encoder(job_out(job))},
                              headers={"X-Kitchen-Key": settings.KITCHEN_API_KEY})
    except Exception as exc:  # noqa: BLE001
        logger.warning("Kitchen webhook failed: %s", exc)


async def claim_next(db, station: str) -> dict | None:
    now = utcnow()
    return await db.kitchen_jobs.find_one_and_update(
        {"status": "queued"},
        {"$set": {"status": "assigned", "station": station, "assigned_at": now, "updated_at": now},
         "$inc": {"attempts": 1}},
        sort=[("priority", -1), ("created_at", 1)],
        return_document=ReturnDocument.AFTER,
    )


async def set_job_status(db, job: dict, new_status: str, message: str | None = None,
                         progress: int | None = None) -> dict:
    """Changes a job status and propagates the effect to the order."""
    from app.services import order_service  # local import to avoid circular dependency

    current = job["status"]
    if new_status == current and progress is not None:
        await db.kitchen_jobs.update_one({"_id": job["_id"]}, {"$set": {"progress": progress, "updated_at": utcnow()}})
        job["progress"] = progress
        await ws_manager.publish(f"order:{job['order_id']}", "kitchen.progress", {"progress": progress})
        return job
    if new_status not in JOB_TRANSITIONS.get(current, set()):
        raise HTTPException(409, f"Cannot change job from '{current}' to '{new_status}'")

    now = utcnow()
    update = {"status": new_status, "updated_at": now, "message": message}
    if progress is not None:
        update["progress"] = progress
    if new_status == "cooking":
        update["started_at"] = now
    if new_status == "done":
        update["completed_at"] = now
        update["progress"] = 100
    if new_status == "queued":
        update.update(station=None, progress=0)
    res = await db.kitchen_jobs.update_one({"_id": job["_id"], "status": current}, {"$set": update})
    if res.modified_count == 0:
        raise HTTPException(409, "Job was modified concurrently, please retry")
    job.update(update)

    await ws_manager.publish("kitchen", "job.updated", job_out(job))
    await ws_manager.publish("staff", "job.updated", job_out(job))

    order = await db.orders.find_one({"_id": job["order_id"]})
    if order:
        if new_status == "cooking" and order["status"] == "confirmed":
            await order_service.change_status(db, order, "preparing", actor=None, note="Robot started cooking")
        elif new_status == "done" and order["status"] in ("confirmed", "preparing"):
            await order_service.change_status(db, order, "ready", actor=None, note="Robot finished cooking")
        elif new_status == "failed":
            await ws_manager.publish("staff", "job.failed",
                                     {"job_id": job["_id"], "order_number": job["order_number"], "message": message})
    return job


async def cancel_jobs_for_order(db, order_id: str) -> None:
    await db.kitchen_jobs.update_many(
        {"order_id": order_id, "status": {"$in": ["queued", "assigned", "failed"]}},
        {"$set": {"status": "cancelled", "updated_at": utcnow()}},
    )
    await ws_manager.publish("kitchen", "job.cancelled", {"order_id": order_id})
