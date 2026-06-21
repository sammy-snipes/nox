import json
import os
from functools import lru_cache

import boto3

# ---------------------------------------------------------------------------
# Constants (not secrets)
# ---------------------------------------------------------------------------
AWS_REGION = "us-east-1"
NANOMDM_URL = "http://localhost:9002"
MDM_IDENTITY = "com.nox.mdm"
MDM_ORGANIZATION = "Nox"


def _is_dev() -> bool:
    return os.getenv("ENV", "production").lower() == "dev"


# ---------------------------------------------------------------------------
# AWS Secrets Manager helpers
# ---------------------------------------------------------------------------
@lru_cache(maxsize=1)
def _secrets_client():
    return boto3.client("secretsmanager", region_name=AWS_REGION)


def _get_secret(secret_name: str) -> str:
    """Fetch a plain-text secret from AWS Secrets Manager."""
    client = _secrets_client()
    resp = client.get_secret_value(SecretId=secret_name)
    return resp["SecretString"]


def _get_secret_json(secret_name: str) -> dict:
    """Fetch and parse a JSON secret from AWS Secrets Manager."""
    return json.loads(_get_secret(secret_name))


# ---------------------------------------------------------------------------
# Public accessors -- each is cached after first call
# ---------------------------------------------------------------------------
@lru_cache(maxsize=1)
def get_apns_cert() -> str:
    if _is_dev():
        return os.environ.get("APNS_CERT", "")
    return _get_secret("nox/apns_cert")


@lru_cache(maxsize=1)
def get_mdm_signing() -> str:
    if _is_dev():
        return os.environ.get("MDM_SIGNING", "")
    return _get_secret("nox/mdm_signing")


@lru_cache(maxsize=1)
def get_rds_credentials() -> dict:
    """Return dict with keys: host, username, password, dbname."""
    if _is_dev():
        return {
            "host": os.environ.get("DB_HOST", "localhost"),
            "username": os.environ.get("DB_USER", "nox"),
            "password": os.environ.get("DB_PASSWORD", "nox"),
            "dbname": os.environ.get("DB_NAME", "nox"),
        }
    return _get_secret_json("nox/rds")
