from __future__ import annotations

import html
import re
import uuid
from pathlib import Path
from typing import Any


THEMES = {
    "warm": {"bg": "#f7efe3", "fg": "#31261d", "muted": "#7a6552", "accent": "#b86b3b"},
    "cool": {"bg": "#e8f1f0", "fg": "#1f2d2f", "muted": "#536a6d", "accent": "#317c83"},
    "dark": {"bg": "#191816", "fg": "#f4eadc", "muted": "#c8bba8", "accent": "#d69b55"},
}


def render_share_card(
    *,
    output_dir: Path,
    card_id: str,
    theme: str,
    text: str,
    tag: str | None = None,
    hexagram_name: str | None = None,
) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    normalized_theme = theme if theme in THEMES else "warm"
    palette = THEMES[normalized_theme]
    safe_card_id = re.sub(r"[^a-zA-Z0-9_-]+", "_", card_id or "card")
    filename = f"{safe_card_id}_{uuid.uuid4().hex[:8]}.svg"
    path = output_dir / filename
    svg = _svg(
        palette=palette,
        card_id=card_id,
        text=text,
        tag=tag or "reflection",
        hexagram_name=hexagram_name or "Reflection",
    )
    path.write_text(svg, encoding="utf-8")
    return {
        "fileName": filename,
        "path": str(path),
        "mime": "image/svg+xml",
        "width": 1080,
        "height": 1440,
        "theme": normalized_theme,
    }


def _svg(*, palette: dict[str, str], card_id: str, text: str, tag: str, hexagram_name: str) -> str:
    lines = _wrap(text or "A quiet reflective note.", width=24, max_lines=9)
    rendered_lines = "\n".join(
        f'<text x="92" y="{505 + index * 54}" class="body">{html.escape(line)}</text>'
        for index, line in enumerate(lines)
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1440" viewBox="0 0 1080 1440">
  <style>
    .title {{ font: 700 68px serif; fill: {palette['fg']}; }}
    .subtitle {{ font: 400 34px sans-serif; fill: {palette['muted']}; }}
    .body {{ font: 400 38px sans-serif; fill: {palette['fg']}; }}
    .footer {{ font: 400 28px sans-serif; fill: {palette['muted']}; }}
  </style>
  <rect width="1080" height="1440" fill="{palette['bg']}"/>
  <rect x="54" y="54" width="972" height="1332" rx="36" fill="none" stroke="{palette['accent']}" stroke-width="3"/>
  <circle cx="878" cy="178" r="74" fill="{palette['accent']}" opacity="0.16"/>
  <text x="92" y="170" class="subtitle">Zhouyi Reflection</text>
  <text x="92" y="270" class="title">{html.escape(hexagram_name)}</text>
  <text x="92" y="340" class="subtitle">Tag · {html.escape(tag)}</text>
  <g transform="translate(92 410)" stroke="{palette['accent']}" stroke-width="18" stroke-linecap="round">
    <line x1="0" y1="0" x2="220" y2="0"/>
    <line x1="0" y1="42" x2="86" y2="42"/><line x1="134" y1="42" x2="220" y2="42"/>
    <line x1="0" y1="84" x2="220" y2="84"/>
  </g>
  {rendered_lines}
  <text x="92" y="1260" class="footer">Card · {html.escape(card_id or 'local')}</text>
  <text x="92" y="1310" class="footer">Reflective context, not a prediction or score.</text>
</svg>
"""


def _wrap(text: str, *, width: int, max_lines: int) -> list[str]:
    normalized = re.sub(r"\s+", " ", text).strip()
    if not normalized:
        return []
    lines: list[str] = []
    current = ""
    for char in normalized:
        current += char
        if len(current) >= width:
            lines.append(current)
            current = ""
            if len(lines) >= max_lines:
                return lines
    if current and len(lines) < max_lines:
        lines.append(current)
    return lines
