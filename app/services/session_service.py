import logging
from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.session import BlockSession, UnblockRequest
from app.schemas.session import SessionResponse
from app.services.mdm_service import UNLOCK_TEXT

logger = logging.getLogger(__name__)


async def start_session(
    db: AsyncSession,
    device_id: UUID,
    ends_at: datetime | None,
    unlock_method: str,
) -> SessionResponse:
    # Only one active session at a time
    existing = await db.execute(
        select(BlockSession).where(
            BlockSession.device_id == device_id, BlockSession.is_active.is_(True)
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An active block session already exists",
        )

    session = BlockSession(
        device_id=device_id,
        ends_at=ends_at,
        unlock_method=unlock_method,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)

    # Push restrictions when a session starts
    try:
        from app.services.mdm_service import push_restrictions

        await push_restrictions(db, device_id)
    except Exception:
        logger.exception("Failed to push restrictions on session start for device %s", device_id)

    return SessionResponse.model_validate(session)


async def get_active_session(
    db: AsyncSession, device_id: UUID
) -> SessionResponse | None:
    result = await db.execute(
        select(BlockSession).where(
            BlockSession.device_id == device_id, BlockSession.is_active.is_(True)
        )
    )
    session = result.scalar_one_or_none()
    if session is None:
        return None
    return SessionResponse.model_validate(session)


async def request_unblock(
    db: AsyncSession, device_id: UUID, session_id: UUID, unlock_text: str
) -> None:
    # Fetch the session
    result = await db.execute(
        select(BlockSession).where(
            BlockSession.id == session_id,
            BlockSession.device_id == device_id,
            BlockSession.is_active.is_(True),
        )
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active session not found",
        )

    # Create the unblock request record
    unblock = UnblockRequest(
        device_id=device_id,
        session_id=session_id,
        unlock_text=unlock_text,
    )
    db.add(unblock)

    # Verify typed text matches the required paragraph
    normalised_input = " ".join(unlock_text.strip().split()).lower()
    normalised_target = " ".join(UNLOCK_TEXT.strip().split()).lower()

    if normalised_input != normalised_target:
        unblock.status = "rejected"
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Typed text does not match the required paragraph. Keep typing.",
        )

    # Text matches -- deactivate the session
    unblock.status = "completed"
    unblock.completed_at = datetime.now(timezone.utc)
    session.is_active = False
    await db.commit()

    # Push a relaxed (empty) profile to remove restrictions
    try:
        from app.services.mdm_service import push_restrictions

        await push_restrictions(db, device_id)
    except Exception:
        logger.exception("Failed to push relaxed profile for device %s", device_id)
