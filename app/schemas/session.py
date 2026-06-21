from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class StartSessionRequest(BaseModel):
    ends_at: datetime | None = None
    unlock_method: str = "type_to_unlock"


class UnblockRequestSchema(BaseModel):
    unlock_text: str


class SessionResponse(BaseModel):
    id: UUID
    started_at: datetime
    ends_at: datetime | None
    is_active: bool
    unlock_method: str

    model_config = {"from_attributes": True}
