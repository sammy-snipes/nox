from functools import lru_cache
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import get_rds_credentials


class Base(DeclarativeBase):
    pass


@lru_cache(maxsize=1)
def get_database_url() -> str:
    creds = get_rds_credentials()
    return (
        f"postgresql+asyncpg://{creds['username']}:{creds['password']}"
        f"@{creds['host']}/{creds['dbname']}"
    )


@lru_cache(maxsize=1)
def _engine():
    return create_async_engine(
        get_database_url(),
        pool_size=5,
        max_overflow=10,
    )


@lru_cache(maxsize=1)
def _session_factory():
    return async_sessionmaker(
        bind=_engine(),
        class_=AsyncSession,
        expire_on_commit=False,
    )


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with _session_factory()() as session:
        yield session
