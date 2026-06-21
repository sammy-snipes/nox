from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.core.dependencies import get_current_device
from app.db.database import get_db
from app.models.device import Device
from app.schemas.blocklist import (
    AddAppRequest,
    AddDomainRequest,
    BlockedAppResponse,
    BlockedDomainResponse,
    BlocklistResponse,
)
from app.services import blocklist_service

router = APIRouter(prefix="/api/v1/blocklist", tags=["blocklist"])


@router.get("", response_model=BlocklistResponse)
async def get_blocklist(
    device: Device = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    return await blocklist_service.get_blocklist(db, device.id)


@router.post("/domains", response_model=BlockedDomainResponse, status_code=201)
async def add_domain(
    body: AddDomainRequest,
    device: Device = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    return await blocklist_service.add_domain(db, device.id, body.domain)


@router.delete("/domains/{domain_id}", status_code=204)
async def remove_domain(
    domain_id: UUID,
    device: Device = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    await blocklist_service.remove_domain(db, device.id, domain_id)


@router.post("/apps", response_model=BlockedAppResponse, status_code=201)
async def add_app(
    body: AddAppRequest,
    device: Device = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    return await blocklist_service.add_app(
        db, device.id, body.bundle_id, body.display_name
    )


@router.delete("/apps/{app_id}", status_code=204)
async def remove_app(
    app_id: UUID,
    device: Device = Depends(get_current_device),
    db: AsyncSession = Depends(get_db),
):
    await blocklist_service.remove_app(db, device.id, app_id)
