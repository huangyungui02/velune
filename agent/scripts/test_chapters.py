from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.soulers.services.ai.chapters import generate_chapters_content


async def main() -> None:
    while True:
        souler_name = input("souler name (empty to quit): ").strip()
        if not souler_name:
            return

        chapters = await generate_chapters_content(souler_name=souler_name, lang="zh")
        print(
            json.dumps(
                {"chapters": [chapter.model_dump() for chapter in chapters]},
                ensure_ascii=False,
                indent=2,
            )
        )


if __name__ == "__main__":
    asyncio.run(main())
