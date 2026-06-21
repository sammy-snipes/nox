from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.models.device import Device
from app.schemas.device import DeviceResponse, RegisterDeviceRequest

router = APIRouter(prefix="/api/v1/device", tags=["device"])


@router.post("/register", response_model=DeviceResponse, status_code=201)
async def register_device(
    body: RegisterDeviceRequest,
    db: AsyncSession = Depends(get_db),
):
    """Register a new device with a client-generated device token (UUID).

    Called once on first app launch. If the device_token already exists,
    returns the existing record.
    """
    result = await db.execute(
        select(Device).where(Device.device_token == body.device_token)
    )
    existing = result.scalar_one_or_none()
    if existing is not None:
        return DeviceResponse.model_validate(existing)

    device = Device(device_token=body.device_token)
    db.add(device)
    await db.commit()
    await db.refresh(device)
    return DeviceResponse.model_validate(device)
