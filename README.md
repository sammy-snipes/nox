# Nox

![Nyx, goddess of night — 10th century, Paris Psalter](nox.jpg)

Cold Turkey for iPhone. Block domains and apps with real MDM-level enforcement — no workarounds, no subscriptions.

## Design

Black and white. Monospace. Typewriter aesthetic. Dead minimal — the UI should look like what it's doing: removing features from your phone.

- Colors: `#000000` background, `#FFFFFF` text. No grays, no accents, no gradients.
- Font: System monospace (`SF Mono` / `Menlo`). Everything.
- No icons, no illustrations, no rounded corners, no shadows.
- Inputs are plain text fields with underline borders. Buttons are plain text with borders.
- Animations: none. Transitions: none. The app feels like a terminal.
- The type-to-unblock screen should feel punishing — small monospace text, no copy-paste, character counter, typos reset.

```
┌──────────────────────────┐
│                          │
│  nox                     │
│                          │
│  blocked domains         │
│  ─────────────────────   │
│  reddit.com          [x] │
│  tiktok.com          [x] │
│  twitter.com         [x] │
│                          │
│  + add domain            │
│                          │
│  blocked apps            │
│  ─────────────────────   │
│  Reddit              [x] │
│  TikTok              [x] │
│                          │
│  + add app               │
│                          │
│  [  unblock  ]           │
│                          │
└──────────────────────────┘
```

## How It Works

User downloads the iOS app, picks domains and apps to block, and enrolls their device into a self-hosted MDM server. The MDM pushes restriction profiles that iOS enforces at the OS level. To unblock, the user has to go through friction (type-to-unblock for MVP). The phone can't bypass it — the server decides when restrictions change.

## Architecture

```
┌─────────────┐       ┌──────────────────────────────────────┐
│   iPhone     │       │              EC2 (t3.micro)          │
│              │       │                                      │
│  Swift App ──────────── Python API (FastAPI :8000)          │
│              │       │    │                                  │
│  MDM Agent ◄─── APNs ◄── NanoMDM (Go binary :9002)         │
│              │       │    │                                  │
│              │       │    └── RDS Postgres (us-east-1)       │
└─────────────┘       └──────────────────────────────────────┘
```

Three components:

| Component | Language | Role |
|-----------|----------|------|
| **iOS App** | Swift / SwiftUI | Onboarding, blocklist UI, MDM enrollment trigger, unblock friction UX |
| **Python API** | Python / FastAPI | Auth, blocklist CRUD, generates MDM restriction profiles (XML plists), commands NanoMDM |
| **NanoMDM** | Go (prebuilt binary) | Handles MDM protocol, device enrollment, APNs push to devices |

## Data Model

```
users
  id            UUID PK
  email         TEXT UNIQUE
  created_at    TIMESTAMPTZ

devices
  id            UUID PK
  user_id       UUID FK → users
  udid          TEXT UNIQUE        -- device UDID from MDM enrollment
  push_magic    TEXT               -- APNs push magic token
  push_token    TEXT               -- APNs device token
  enrolled_at   TIMESTAMPTZ

blocked_domains
  id            UUID PK
  user_id       UUID FK → users
  domain        TEXT               -- e.g. "reddit.com"
  created_at    TIMESTAMPTZ
  UNIQUE(user_id, domain)

blocked_apps
  id            UUID PK
  user_id       UUID FK → users
  bundle_id     TEXT               -- e.g. "com.reddit.Reddit"
  display_name  TEXT               -- e.g. "Reddit"
  created_at    TIMESTAMPTZ
  UNIQUE(user_id, bundle_id)

block_sessions
  id            UUID PK
  user_id       UUID FK → users
  started_at    TIMESTAMPTZ
  ends_at       TIMESTAMPTZ NULL   -- NULL = indefinite
  is_active     BOOLEAN DEFAULT TRUE
  unlock_method TEXT               -- "type_to_unlock" for MVP

unblock_requests
  id            UUID PK
  user_id       UUID FK → users
  session_id    UUID FK → block_sessions
  requested_at  TIMESTAMPTZ
  completed_at  TIMESTAMPTZ NULL   -- NULL = not yet completed
  unlock_text   TEXT               -- what the user typed
  status        TEXT               -- "pending", "completed", "expired"
```

## API Endpoints

### Auth
- `POST /api/v1/auth/register` — create account (email + device)
- `POST /api/v1/auth/login` — login, returns JWT

### Blocklist
- `GET /api/v1/blocklist` — get user's blocked domains + apps
- `POST /api/v1/blocklist/domains` — add domain to blocklist
- `DELETE /api/v1/blocklist/domains/{id}` — request domain removal (triggers friction)
- `POST /api/v1/blocklist/apps` — add app bundle ID to blocklist
- `DELETE /api/v1/blocklist/apps/{id}` — request app removal (triggers friction)

### Block Sessions
- `POST /api/v1/sessions` — start a block session (optional end time)
- `GET /api/v1/sessions/active` — get current active session
- `POST /api/v1/sessions/{id}/unblock` — submit unblock request (type-to-unlock text)

### Enrollment
- `GET /api/v1/enroll/profile` — serves .mobileconfig enrollment profile for this user
- `POST /api/v1/enroll/webhook` — NanoMDM callback on successful enrollment

### MDM (internal)
- `POST /api/v1/mdm/push-profile/{device_id}` — push updated restriction profile to device

## MDM Restriction Profiles

When the blocklist changes (add/remove), the API generates an XML plist and tells NanoMDM to push it:

### WebContentFilter (domain blocking)
```xml
<dict>
    <key>PayloadType</key>
    <string>com.apple.webcontent-filter</string>
    <key>FilterType</key>
    <string>BuiltIn</string>
    <key>FilterBrowsers</key>
    <true/>
    <key>BlacklistedURLs</key>
    <array>
        <string>reddit.com</string>
        <string>tiktok.com</string>
    </array>
</dict>
```

### App Restrictions (app blocking)
```xml
<dict>
    <key>PayloadType</key>
    <string>com.apple.applicationaccess</string>
    <key>blacklistedAppBundleIDs</key>
    <array>
        <string>com.reddit.Reddit</string>
        <string>com.zhiliaoapp.musically</string>
    </array>
</dict>
```

## Unblock Flow (MVP: Type-to-Unlock)

1. User taps "Unblock" in the app
2. App shows a screen with a long paragraph of text (e.g. "I acknowledge that I am choosing to waste my time instead of doing something meaningful. I understand that this decision...")
3. User must type the paragraph character-for-character. Typos reset progress.
4. On completion, app sends `POST /api/v1/sessions/{id}/unblock` with the typed text
5. Backend verifies text matches, marks session inactive
6. Backend generates new (empty/relaxed) restriction profile
7. Backend pushes updated profile to device via NanoMDM → APNs
8. Device receives new profile, restrictions lifted

## Secrets (AWS Secrets Manager)

Same pattern as great-reads — fetched at runtime via `boto3` with `@lru_cache`:

| Secret ID | Content |
|-----------|---------|
| `nox/jwt_secret` | JWT signing key |
| `nox/apns_cert` | APNs push certificate (for MDM) |
| `nox/mdm_signing` | MDM profile signing cert + key |
| `nox/rds` | RDS host, username, password, dbname |

## Config Constants (`app/core/config.py`)

```python
AWS_REGION = "us-east-1"

# RDS host + credentials both come from secrets manager (nox/rds)
# No hardcoded host — single secret contains host, username, password, dbname

NANOMDM_URL = "http://localhost:9002"  # co-located on same EC2
NANOMDM_API_KEY = ""  # fetched from secrets manager

MDM_IDENTITY = "com.nox.mdm"
MDM_ORGANIZATION = "Nox"

JWT_ALGORITHM = "HS256"
JWT_TTL_DAYS = 365
```

## Project Structure

```
nox/
├── app/                          # Python backend (FastAPI)
│   ├── main.py                   # Entry point, lifespan, middleware
│   ├── core/
│   │   ├── config.py             # Settings, AWS secrets, constants
│   │   └── security.py           # JWT auth
│   ├── db/
│   │   ├── database.py           # SQLAlchemy async engine
│   │   └── migrations/           # Raw SQL migration files
│   ├── models/                   # SQLAlchemy ORM models
│   │   ├── user.py
│   │   ├── device.py
│   │   ├── blocklist.py
│   │   └── session.py
│   ├── schemas/                  # Pydantic schemas
│   │   ├── auth.py
│   │   ├── blocklist.py
│   │   └── session.py
│   ├── services/                 # Business logic
│   │   ├── auth_service.py
│   │   ├── blocklist_service.py
│   │   ├── session_service.py
│   │   ├── mdm_service.py        # Profile generation + NanoMDM communication
│   │   └── enrollment_service.py
│   └── routes/                   # FastAPI route handlers
│       ├── auth.py
│       ├── blocklist.py
│       ├── sessions.py
│       └── enrollment.py
│
├── ios/                          # Swift iOS app (Xcode project)
│   └── Nox/
│       ├── NoxApp.swift          # Entry point
│       ├── Views/                # SwiftUI views
│       │   ├── OnboardingView.swift
│       │   ├── BlocklistView.swift
│       │   ├── UnblockView.swift  # Type-to-unlock screen
│       │   └── SettingsView.swift
│       ├── Services/
│       │   ├── APIClient.swift   # HTTP client for Python API
│       │   └── EnrollmentService.swift  # MDM enrollment flow
│       └── Models/
│           ├── BlockedDomain.swift
│           └── BlockedApp.swift
│
├── scripts/
│   ├── deploy.sh                 # SSH/rsync deploy (same pattern as great-reads)
│   ├── nox.service               # systemd unit
│   └── setup_nanomdm.sh          # Download + configure NanoMDM binary
│
├── pyproject.toml
└── README.md
```

## EC2 Setup

Single `t3.micro` (or `t3.small`) running:
- Python API (gunicorn + uvicorn workers, port 8000)
- NanoMDM binary (port 9002)
- Both behind nginx (TLS termination)

## Apple Developer Requirements

Before building, need from Apple Developer account:
1. **MDM Push Certificate** — via [mdmcert.download](https://mdmcert.download) for MVP (signs CSR using their vendor cert). Migrate to own Apple MDM vendor cert once we have users.
2. **App ID** with appropriate entitlements
3. **APNs configuration** for push notifications to the app itself (separate from MDM push)

## MVP Scope

Phase 1 (ship it):
- [ ] Backend: auth, blocklist CRUD, MDM profile generation, NanoMDM integration
- [ ] iOS: onboarding, blocklist management, enrollment flow, type-to-unblock
- [ ] Infra: EC2, RDS, NanoMDM, nginx, deploy script

Phase 2 (later):
- [ ] Timed blocks / schedules
- [ ] Accountability partner (friend approves unblock)
- [ ] Nuclear mode (no unblock until date X)
- [ ] App search (search App Store to find bundle IDs easily)
- [ ] Multiple devices per user
