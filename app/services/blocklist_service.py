import logging
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.blocklist import BlockedApp, BlockedDomain
from app.schemas.blocklist import BlockedAppResponse, BlockedDomainResponse, BlocklistResponse

logger = logging.getLogger(__name__)


async def get_blocklist(db: AsyncSession, device_id: UUID) -> BlocklistResponse:
    domains_result = await db.execute(
        select(BlockedDomain).where(BlockedDomain.device_id == device_id)
    )
    apps_result = await db.execute(
        select(BlockedApp).where(BlockedApp.device_id == device_id)
    )

    domains = [
        BlockedDomainResponse.model_validate(d)
        for d in domains_result.scalars().all()
    ]
    apps = [
        BlockedAppResponse.model_validate(a)
        for a in apps_result.scalars().all()
    ]

    return BlocklistResponse(domains=domains, apps=apps)


async def add_domain(
    db: AsyncSession, device_id: UUID, domain: str
) -> BlockedDomainResponse:
    entry = BlockedDomain(device_id=device_id, domain=domain.lower().strip())
    db.add(entry)
    try:
        await db.commit()
    except Exception:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Domain already blocked",
        )
    await db.refresh(entry)

    # Push updated restrictions to device in background
    await _push_restrictions_safe(db, device_id)

    return BlockedDomainResponse.model_validate(entry)


async def remove_domain(
    db: AsyncSession, device_id: UUID, domain_id: UUID
) -> None:
    result = await db.execute(
        select(BlockedDomain).where(
            BlockedDomain.id == domain_id, BlockedDomain.device_id == device_id
        )
    )
    entry = result.scalar_one_or_none()
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Domain not found"
        )
    await db.delete(entry)
    await db.commit()

    await _push_restrictions_safe(db, device_id)


async def add_app(
    db: AsyncSession, device_id: UUID, bundle_id: str, display_name: str
) -> BlockedAppResponse:
    entry = BlockedApp(
        device_id=device_id,
        bundle_id=bundle_id.strip(),
        display_name=display_name.strip(),
    )
    db.add(entry)
    try:
        await db.commit()
    except Exception:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="App already blocked",
        )
    await db.refresh(entry)

    await _push_restrictions_safe(db, device_id)

    return BlockedAppResponse.model_validate(entry)


async def remove_app(
    db: AsyncSession, device_id: UUID, app_id: UUID
) -> None:
    result = await db.execute(
        select(BlockedApp).where(
            BlockedApp.id == app_id, BlockedApp.device_id == device_id
        )
    )
    entry = result.scalar_one_or_none()
    if entry is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="App not found"
        )
    await db.delete(entry)
    await db.commit()

    await _push_restrictions_safe(db, device_id)


async def _push_restrictions_safe(db: AsyncSession, device_id: UUID) -> None:
    """Best-effort push -- log errors but don't fail the request."""
    try:
        from app.services.mdm_service import push_restrictions

        await push_restrictions(db, device_id)
    except Exception:
        logger.exception("Failed to push restrictions for device %s", device_id)
