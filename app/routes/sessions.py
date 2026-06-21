from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_device
from app.db.database import get_db
from app.models.device import Device
from app.schemas.session import (
    SessionResponse,
    StartSessionRequest,
    UnblockRequestSchema,
)
from app.services import session_service

router = APIRouter(prefix="/api/v1/sessions", tags=["sessions"])


@router.post("", response_model=SessionResponse, status_code=201)
async def start_session(
    body: StartSessionRequest,
    device: Device = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    return await session_service.start_session(
        db, device.id, body.ends_at, body.unlock_method
    )


@router.get("/active", response_model=SessionResponse)
async def get_active_session(
    device: Device = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    session = await session_service.get_active_session(db, device.id)
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active session",
        )
    return session


@router.post("/{session_id}/unblock", status_code=200)
async def request_unblock(
    session_id: UUID,
    body: UnblockRequestSchema,
    device: Device = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    await session_service.request_unblock(db, device.id, session_id, body.unlock_text)
    return {"detail": "Session unblocked successfully"}
