"""Run SQL migrations in order."""
import asyncio
import glob
import os

import asyncpg

from app.db.database import get_database_url


async def run_migrations():
    url = get_database_url()
    # asyncpg uses different URL format than SQLAlchemy
    dsn = url.replace("postgresql+asyncpg://", "postgresql://")
    conn = await asyncpg.connect(dsn)

    # create migrations tracking table
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS _migrations (
            filename TEXT PRIMARY KEY,
            applied_at TIMESTAMPTZ DEFAULT now()
        )
    """)

    # get already applied
    applied = {row["filename"] for row in await conn.fetch("SELECT filename FROM _migrations")}

    # find and run new migrations
    migration_dir = os.path.join(os.path.dirname(__file__), "migrations")
    files = sorted(glob.glob(os.path.join(migration_dir, "*.sql")))

    for filepath in files:
        filename = os.path.basename(filepath)
        if filename in applied:
            continue

        print(f"applying {filename}...")
        with open(filepath) as f:
            sql = f.read()
        await conn.execute(sql)
        await conn.execute("INSERT INTO _migrations (filename) VALUES ($1)", filename)
        print(f"  done.")

    await conn.close()
    print("migrations complete.")


if __name__ == "__main__":
    asyncio.run(run_migrations())
