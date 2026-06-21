from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.models.device import Device


async def get_current_device(
    x_device_token: str = Header(...),
    db: AsyncSession = Depends(get_db),
) -> Device:
    """Look up the device by its client-generated token.

    Every protected endpoint should depend on this.
    Returns 401 if the token is missing or does not match a registered device.
    """
    result = await db.execute(
        select(Device).where(Device.device_token == x_device_token)
    )
    device = result.scalar_one_or_none()
    if device is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unknown device token",
        )
    return device
