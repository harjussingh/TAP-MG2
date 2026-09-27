"""Robot kitchen controller API (authenticated with the X-Kitchen-Key header)."""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response

from app.api.deps import verify_kitchen_key
from app.core.database import get_db
from app.schemas.admin import KitchenJobStatusIn
from app.services import kitchen_service

router = APIRouter(prefix="/kitchen", tags=["Robot kitchen"], dependencies=[Depends(verify_kitchen_key)])


@router.get("/jobs")
async def list_jobs(status: Optional[list[str]] = Query(None), db=Depends(get_db)):
    query = {"status": {"$in": status or kitchen_service.ACTIVE_JOB_STATUSES}}
    docs = await db.kitchen_jobs.find(query).sort([("priority", -1), ("created_at", 1)]).to_list(200)
    return [kitchen_service.job_out(d) for d in docs]


@router.post("/jobs/claim")
async def claim_next_job(station: str = Query("robot-1", max_length=40), db=Depends(get_db)):
    """Atomically take the next queued job. Returns 204 when the queue is empty."""
    job = await kitchen_service.claim_next(db, station)
    if not job:
        return Response(status_code=204)
    return kitchen_service.job_out(job)


@router.get("/jobs/{job_id}")
async def get_job(job_id: str, db=Depends(get_db)):
    job = await db.kitchen_jobs.find_one({"_id": job_id})
    if not job:
        raise HTTPException(404, "Job not found")
    return kitchen_service.job_out(job)


@router.post("/jobs/{job_id}/status")
async def update_job(job_id: str, data: KitchenJobStatusIn, db=Depends(get_db)):
    """Report progress: cooking -> done (or failed). Order status follows automatically."""
    if data.status not in ("cooking", "done", "failed"):
        raise HTTPException(422, "status must be cooking, done or failed")
    job = await db.kitchen_jobs.find_one({"_id": job_id})
    if not job:
        raise HTTPException(404, "Job not found")
    job = await kitchen_service.set_job_status(db, job, data.status, data.message, data.progress)
    return kitchen_service.job_out(job)
