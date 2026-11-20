#!/usr/bin/env python3
"""Parse README.md API tables into explorer/public/data/apis.json."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = ROOT / "README.md"
OUT = ROOT / "explorer" / "public" / "data" / "apis.json"

PARTNER_HOSTS = (
    "ipstack.com",
    "marketstack.com",
    "weatherstack.com",
    "numverify.com",
    "fixer.io",
    "aviationstack.com",
    "zenserp.com",
    "screenshotlayer.com",
    "exchangerate.host",
    "mailboxlayer.com",
    "positionstack.com",
    "mediastack.com",
    "countrylayer.com",
    "serpstack.com",
    "scrapestack.com",
    "apilayer.com",
)

ROW_RE = re.compile(
    r"^\|\s*\[([^\]]+)\]\(([^)]+)\)\s*\|\s*(.*?)\s*\|\s*`?([^|`]*?)`?\s*\|\s*(Yes|No)\s*\|\s*(Yes|No|Unknown)"
)
FEAT_RE = re.compile(r"^\|\s*\[([^\]]+)\]\(([^)]+)\)\s*\|\s*(.*?)\s*\|")


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def is_partner(url: str) -> bool:
    lower = url.lower()
    return any(host in lower for host in PARTNER_HOSTS)


def main() -> None:
    lines = README.read_text(encoding="utf-8").splitlines()
    category = None
    apis = []
    featured = []

    for line in lines:
        if line.startswith("### ") and not line.startswith("### APIs Covered"):
            category = line[4:].strip()
            continue

        if "utm_source=Github" in line and line.startswith("| ["):
            m = FEAT_RE.match(line)
            if m:
                featured.append(
                    {
                        "name": m.group(1).strip(),
                        "url": m.group(2).strip(),
                        "description": m.group(3).strip(),
                        "partner": True,
                        "label": "Partner",
                    }
                )

        if category is None:
            continue
        if line.startswith("| ---") or line.startswith("|:---") or line.startswith("API |"):
            continue

        m = ROW_RE.match(line)
        if not m:
            continue

        name, url, desc, auth, https, cors = m.groups()
        auth = (auth or "No").strip() or "No"
        apis.append(
            {
                "id": f"{slug(category)}-{slug(name)}",
                "name": name.strip(),
                "url": url.strip(),
                "description": desc.strip(),
                "auth": auth,
                "https": https == "Yes",
                "cors": cors,
                "category": category,
                "partner": is_partner(url),
            }
        )

    seen = set()
    featured_unique = []
    for item in featured:
        if item["name"] in seen:
            continue
        seen.add(item["name"])
        featured_unique.append(item)

    payload = {
        "generatedFrom": "README.md",
        "count": len(apis),
        "categories": sorted({a["category"] for a in apis}),
        "featuredPartners": featured_unique[:12],
        "apis": apis,
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(apis)} APIs / {len(payload['categories'])} categories to {OUT}")


if __name__ == "__main__":
    main()
