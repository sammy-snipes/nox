from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class AddDomainRequest(BaseModel):
    domain: str


class AddAppRequest(BaseModel):
    bundle_id: str
    display_name: str


class BlockedDomainResponse(BaseModel):
    id: UUID
    domain: str
    created_at: datetime

    model_config = {"from_attributes": True}


class BlockedAppResponse(BaseModel):
    id: UUID
    bundle_id: str
    display_name: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class BlocklistResponse(BaseModel):
    domains: list[BlockedDomainResponse]
    apps: list[BlockedAppResponse]
