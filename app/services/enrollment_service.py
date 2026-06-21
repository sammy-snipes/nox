import logging
import plistlib
import uuid
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import MDM_IDENTITY, MDM_ORGANIZATION, NANOMDM_URL
from app.models.device import Device

logger = logging.getLogger(__name__)


def generate_enrollment_profile(device_id: UUID, server_url: str) -> bytes:
    """Build a .mobileconfig enrollment profile for NanoMDM."""
    payload_uuid = str(uuid.uuid4())
    profile_uuid = str(uuid.uuid4())

    mdm_payload = {
        "PayloadType": "com.apple.mdm",
        "PayloadVersion": 1,
        "PayloadIdentifier": f"{MDM_IDENTITY}.mdm.{payload_uuid}",
        "PayloadUUID": payload_uuid,
        "PayloadDisplayName": "Nox MDM Enrollment",
        "PayloadOrganization": MDM_ORGANIZATION,
        "ServerURL": f"{server_url}/mdm/connect",
        "CheckInURL": f"{server_url}/mdm/checkin",
        "CheckOutWhenRemoved": True,
        "Topic": MDM_IDENTITY,
        "ServerCapabilities": ["com.apple.mdm.per-user-connections"],
        "AccessRights": 8191,  # Full access
        "SignMessage": True,
    }

    profile = {
        "PayloadType": "Configuration",
        "PayloadVersion": 1,
        "PayloadIdentifier": f"{MDM_IDENTITY}.enrollment.{profile_uuid}",
        "PayloadUUID": profile_uuid,
        "PayloadDisplayName": "Nox Device Enrollment",
        "PayloadDescription": f"nox_device_id:{device_id}",
        "PayloadOrganization": MDM_ORGANIZATION,
        "PayloadContent": [mdm_payload],
    }

    return plistlib.dumps(profile, fmt=plistlib.FMT_XML)


async def handle_enrollment_webhook(
    db: AsyncSession,
    udid: str,
    push_magic: str,
    push_token: str,
    device_token: str,
) -> Device:
    """Create or update a device record when NanoMDM reports a new enrollment."""
    result = await db.execute(
        select(Device).where(Device.device_token == device_token)
    )
    device = result.scalar_one_or_none()

    if device is None:
        # Device should already exist from /register, but handle edge case
        device = Device(
            device_token=device_token,
            udid=udid,
            push_magic=push_magic,
            push_token=push_token,
            enrolled=True,
        )
        db.add(device)
    else:
        device.udid = udid
        device.push_magic = push_magic
        device.push_token = push_token
        device.enrolled = True

    await db.commit()
    await db.refresh(device)

    logger.info("Device %s enrolled (token=%s)", udid, device_token)
    return device
