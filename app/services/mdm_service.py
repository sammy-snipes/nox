import logging
import plistlib
import uuid
from uuid import UUID

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import MDM_IDENTITY, MDM_ORGANIZATION, NANOMDM_URL
from app.models.blocklist import BlockedApp, BlockedDomain
from app.models.device import Device
from app.models.session import BlockSession

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# The long, punishing paragraph the user must type to unblock
# ---------------------------------------------------------------------------
UNLOCK_TEXT = (
    "I am choosing to unlock my device and disable the restrictions I set for "
    "myself. I understand that I put these blocks in place for a reason, and by "
    "removing them I am actively deciding to give in to distraction. Every second "
    "I spend mindlessly scrolling is a second I will never get back. My goals, my "
    "ambitions, and the person I want to become are all waiting on the other side "
    "of discipline. If I proceed, I accept full responsibility for the wasted time "
    "and the disappointment I will feel later. This moment of weakness does not "
    "define me, but only if I choose to stay the course. I am typing this paragraph "
    "because I need to feel the weight of this decision in my fingers, one keystroke "
    "at a time, so that I cannot pretend it was an accident."
)


def generate_restriction_profile(
    blocked_domains: list[str],
    blocked_apps: list[str],
) -> bytes:
    """Build a .mobileconfig XML plist that blocks the given domains and apps."""
    payload_uuid = str(uuid.uuid4())
    profile_uuid = str(uuid.uuid4())

    # Content filter payload -- blocks domains via managed Safari / DNS
    content_filter_payload = {
        "PayloadType": "com.apple.webcontent-filter",
        "PayloadVersion": 1,
        "PayloadIdentifier": f"{MDM_IDENTITY}.webfilter.{payload_uuid}",
        "PayloadUUID": payload_uuid,
        "PayloadDisplayName": "Nox Web Content Filter",
        "PayloadOrganization": MDM_ORGANIZATION,
        "FilterType": "BuiltIn",
        "FilterBrowsers": True,
        "FilterSockets": True,
        "AutoFilterEnabled": False,
        "BlacklistedURLs": blocked_domains,
    }

    payloads = [content_filter_payload]

    # App restriction payload -- hides apps by bundle ID
    if blocked_apps:
        app_payload_uuid = str(uuid.uuid4())
        app_restriction_payload = {
            "PayloadType": "com.apple.app.lock",
            "PayloadVersion": 1,
            "PayloadIdentifier": f"{MDM_IDENTITY}.apprestriction.{app_payload_uuid}",
            "PayloadUUID": app_payload_uuid,
            "PayloadDisplayName": "Nox App Restrictions",
            "PayloadOrganization": MDM_ORGANIZATION,
            "blockedAppBundleIDs": blocked_apps,
        }
        payloads.append(app_restriction_payload)

    profile = {
        "PayloadType": "Configuration",
        "PayloadVersion": 1,
        "PayloadIdentifier": f"{MDM_IDENTITY}.restrictions.{profile_uuid}",
        "PayloadUUID": profile_uuid,
        "PayloadDisplayName": "Nox Restrictions",
        "PayloadOrganization": MDM_ORGANIZATION,
        "PayloadContent": payloads,
    }

    return plistlib.dumps(profile, fmt=plistlib.FMT_XML)


async def push_restrictions(db: AsyncSession, device_id: UUID) -> None:
    """Fetch device's blocklist, generate profile, push via NanoMDM."""
    # Get the device
    result = await db.execute(
        select(Device).where(Device.id == device_id)
    )
    device = result.scalar_one_or_none()
    if device is None or not device.enrolled:
        logger.warning("No enrolled device for device_id %s -- skipping push", device_id)
        return

    # Check if there is an active session -- if not, push an empty profile
    session_result = await db.execute(
        select(BlockSession).where(
            BlockSession.device_id == device_id, BlockSession.is_active.is_(True)
        )
    )
    active_session = session_result.scalar_one_or_none()

    if active_session is None:
        # No active session: push empty restrictions (clears blocks)
        profile_bytes = generate_restriction_profile([], [])
    else:
        # Active session: push full blocklist
        domains_result = await db.execute(
            select(BlockedDomain.domain).where(BlockedDomain.device_id == device_id)
        )
        blocked_domains = [row[0] for row in domains_result.all()]

        apps_result = await db.execute(
            select(BlockedApp.bundle_id).where(BlockedApp.device_id == device_id)
        )
        blocked_apps = [row[0] for row in apps_result.all()]

        profile_bytes = generate_restriction_profile(blocked_domains, blocked_apps)

    # POST to NanoMDM
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{NANOMDM_URL}/v1/commands",
            json={
                "udid": device.udid,
                "command": {
                    "request_type": "InstallProfile",
                    "payload": profile_bytes.decode("utf-8"),
                },
            },
            timeout=10.0,
        )
        if response.status_code not in (200, 201):
            logger.error(
                "NanoMDM returned %s: %s", response.status_code, response.text
            )
            raise RuntimeError(f"NanoMDM push failed: {response.status_code}")

    logger.info("Pushed restrictions to device %s (device_id %s)", device.udid, device_id)
