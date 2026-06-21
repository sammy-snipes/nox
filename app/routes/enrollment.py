from fastapi import APIRouter, Depends, Request
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import NANOMDM_URL
from app.core.dependencies import get_current_device
from app.db.database import get_db
from app.models.device import Device
from app.services import enrollment_service

router = APIRouter(prefix="/api/v1/enroll", tags=["enrollment"])


@router.get("/profile")
async def get_enrollment_profile(
    request: Request,
    device: Device = Depends(get_current_device),
):
    server_url = NANOMDM_URL
    profile_bytes = enrollment_service.generate_enrollment_profile(
        device.id, server_url
    )
    return Response(
        content=profile_bytes,
        media_type="application/x-apple-aspen-config",
        headers={
            "Content-Disposition": 'attachment; filename="nox-enroll.mobileconfig"'
        },
    )


@router.post("/webhook")
async def enrollment_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Called by NanoMDM when a device completes enrollment."""
    body = await request.json()

    udid = body["udid"]
    push_magic = body.get("push_magic", "")
    push_token = body.get("push_token", "")
    device_token = body["device_token"]

    device = await enrollment_service.handle_enrollment_webhook(
        db, udid, push_magic, push_token, device_token
    )
    return {"device_id": str(device.id), "udid": device.udid}
