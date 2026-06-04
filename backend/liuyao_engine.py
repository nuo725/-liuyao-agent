from __future__ import annotations

from dataclasses import dataclass
from typing import Any


TRIGRAMS = {
    "111": {"name": "Qian", "element": "metal", "image": "heaven"},
    "000": {"name": "Kun", "element": "earth", "image": "earth"},
    "010": {"name": "Kan", "element": "water", "image": "water"},
    "101": {"name": "Li", "element": "fire", "image": "fire"},
    "001": {"name": "Zhen", "element": "wood", "image": "thunder"},
    "100": {"name": "Gen", "element": "earth", "image": "mountain"},
    "011": {"name": "Dui", "element": "metal", "image": "lake"},
    "110": {"name": "Xun", "element": "wood", "image": "wind"},
}

HEXAGRAM_NAMES = {
    "111111": ("1", "Qian"),
    "000000": ("2", "Kun"),
    "010001": ("3", "Zhun"),
    "100010": ("4", "Meng"),
    "010111": ("5", "Xu"),
    "111010": ("6", "Song"),
    "000010": ("7", "Shi"),
    "010000": ("8", "Bi"),
    "110111": ("9", "Xiao Xu"),
    "111011": ("10", "Lu"),
    "000111": ("11", "Tai"),
    "111000": ("12", "Pi"),
    "111101": ("13", "Tong Ren"),
    "101111": ("14", "Da You"),
    "000100": ("15", "Qian"),
    "001000": ("16", "Yu"),
    "011001": ("17", "Sui"),
    "100110": ("18", "Gu"),
    "000011": ("19", "Lin"),
    "110000": ("20", "Guan"),
    "101001": ("21", "Shi He"),
    "100101": ("22", "Bi"),
    "100000": ("23", "Bo"),
    "000001": ("24", "Fu"),
    "111001": ("25", "Wu Wang"),
    "100111": ("26", "Da Xu"),
    "100001": ("27", "Yi"),
    "011110": ("28", "Da Guo"),
    "010010": ("29", "Kan"),
    "101101": ("30", "Li"),
    "011100": ("31", "Xian"),
    "001110": ("32", "Heng"),
    "111100": ("33", "Dun"),
    "001111": ("34", "Da Zhuang"),
    "101000": ("35", "Jin"),
    "000101": ("36", "Ming Yi"),
    "110101": ("37", "Jia Ren"),
    "101011": ("38", "Kui"),
    "010100": ("39", "Jian"),
    "001010": ("40", "Jie"),
    "100011": ("41", "Sun"),
    "110001": ("42", "Yi"),
    "011111": ("43", "Guai"),
    "111110": ("44", "Gou"),
    "011000": ("45", "Cui"),
    "000110": ("46", "Sheng"),
    "011010": ("47", "Kun"),
    "010110": ("48", "Jing"),
    "011101": ("49", "Ge"),
    "101110": ("50", "Ding"),
    "001001": ("51", "Zhen"),
    "100100": ("52", "Gen"),
    "110100": ("53", "Jian"),
    "001011": ("54", "Gui Mei"),
    "001101": ("55", "Feng"),
    "101100": ("56", "Lu"),
    "110110": ("57", "Xun"),
    "011011": ("58", "Dui"),
    "110010": ("59", "Huan"),
    "010011": ("60", "Jie"),
    "110011": ("61", "Zhong Fu"),
    "001100": ("62", "Xiao Guo"),
    "010101": ("63", "Ji Ji"),
    "101010": ("64", "Wei Ji"),
}

TAG_FOCUS = {
    "career": {"useGodHint": "official/parent/resource themes", "attention": "role, responsibility, pacing"},
    "relationship": {"useGodHint": "self-other and response line themes", "attention": "boundary, reciprocity, timing"},
    "emotion": {"useGodHint": "self line and moving pressure themes", "attention": "inner state, pause, regulation"},
    "choice": {"useGodHint": "moving line and changed hexagram themes", "attention": "tradeoff, reversibility, next step"},
    "reflection": {"useGodHint": "self line, response line, moving line themes", "attention": "what is stable and what is changing"},
}


@dataclass(frozen=True)
class HexagramReading:
    original: dict[str, Any]
    changed: dict[str, Any] | None
    movingLines: list[int]
    lowerTrigram: dict[str, Any]
    upperTrigram: dict[str, Any]
    changedLowerTrigram: dict[str, Any] | None
    changedUpperTrigram: dict[str, Any] | None
    tagFocus: dict[str, str]
    observations: list[str]
    neutralReminder: str

    def to_json(self) -> dict[str, Any]:
        return {
            "original": self.original,
            "changed": self.changed,
            "movingLines": self.movingLines,
            "lowerTrigram": self.lowerTrigram,
            "upperTrigram": self.upperTrigram,
            "changedLowerTrigram": self.changedLowerTrigram,
            "changedUpperTrigram": self.changedUpperTrigram,
            "tagFocus": self.tagFocus,
            "observations": self.observations,
            "neutralReminder": self.neutralReminder,
        }


def build_reading(lines: list[int], moving_lines: list[int], tag: str) -> HexagramReading:
    normalized = _normalize_lines(lines)
    moving = sorted({line for line in moving_lines if 1 <= line <= 6})
    changed_lines = [
        1 - value if (index + 1) in moving else value
        for index, value in enumerate(normalized)
    ]
    original = _hexagram(normalized)
    changed = _hexagram(changed_lines) if moving else None
    lower = _trigram(normalized[:3])
    upper = _trigram(normalized[3:])
    changed_lower = _trigram(changed_lines[:3]) if moving else None
    changed_upper = _trigram(changed_lines[3:]) if moving else None
    tag_focus = TAG_FOCUS.get(tag, TAG_FOCUS["reflection"])
    observations = _observations(original, changed, moving, lower, upper, tag_focus)
    return HexagramReading(
        original=original,
        changed=changed,
        movingLines=moving,
        lowerTrigram=lower,
        upperTrigram=upper,
        changedLowerTrigram=changed_lower,
        changedUpperTrigram=changed_upper,
        tagFocus=tag_focus,
        observations=observations,
        neutralReminder="This reading is reflective context, not a prediction, score, or decision command.",
    )


def _normalize_lines(lines: list[int]) -> list[int]:
    result = [1 if int(value) else 0 for value in lines[:6]]
    if len(result) < 6:
        result.extend([0] * (6 - len(result)))
    return result


def _hexagram(lines: list[int]) -> dict[str, Any]:
    signature = "".join(str(value) for value in lines)
    hid, name = HEXAGRAM_NAMES.get(signature, ("0", "Unknown"))
    return {"id": hid, "name": name, "signature": signature, "lines": lines}


def _trigram(lines: list[int]) -> dict[str, Any]:
    signature = "".join(str(value) for value in lines)
    meta = TRIGRAMS.get(signature, {"name": "Unknown", "element": "unknown", "image": "unknown"})
    return {"signature": signature, **meta}


def _observations(
    original: dict[str, Any],
    changed: dict[str, Any] | None,
    moving: list[int],
    lower: dict[str, Any],
    upper: dict[str, Any],
    tag_focus: dict[str, str],
) -> list[str]:
    observations = [
        f"Original hexagram {original['name']} frames the current situation as a field to observe.",
        f"Lower trigram {lower['name']} points to the inner/base layer; upper trigram {upper['name']} points to the outer/context layer.",
        f"For this tag, watch {tag_focus['attention']} before making the question heavier.",
    ]
    if moving:
        observations.append(
            f"Moving lines {', '.join(str(item) for item in moving)} mark the parts of the situation that deserve attention first."
        )
    else:
        observations.append("No moving lines were provided, so the reading should emphasize the current pattern rather than transition.")
    if changed:
        observations.append(f"Changed hexagram {changed['name']} is treated as a transition lens, not a fixed outcome.")
    return observations
