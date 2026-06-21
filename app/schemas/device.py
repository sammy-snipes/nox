from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class RegisterDeviceRequest(BaseModel):
    device_token: str


class DeviceResponse(BaseModel):
    id: UUID
    device_token: str
    enrolled: bool
    created_at: datetime

    model_config = {"from_attributes": True}
