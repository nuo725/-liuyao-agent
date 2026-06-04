from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path


TAG_TERMS = {
    "career": ["事业", "工作", "官鬼", "父母", "财", "进退"],
    "relationship": ["感情", "关系", "世应", "妻财", "官鬼", "合"],
    "emotion": ["心", "忧", "静", "动", "空", "冲"],
    "choice": ["选择", "动爻", "变卦", "进退", "应期"],
    "reflection": ["用神", "世爻", "应爻", "动爻", "变卦"],
}


@dataclass(frozen=True)
class KnowledgeSnippet:
    source: str
    title: str
    text: str


class LiuyaoKnowledgeBase:
    """Tiny local retriever over the Liuyao markdown knowledge folder."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self._snippets: list[KnowledgeSnippet] | None = None

    def search(self, question: str, tag: str, limit: int = 2) -> list[KnowledgeSnippet]:
        snippets = self._load()
        terms = self._terms(question, tag)
        scored: list[tuple[int, KnowledgeSnippet]] = []
        for snippet in snippets:
            haystack = f"{snippet.title}\n{snippet.text}"
            score = sum(haystack.count(term) for term in terms)
            if score > 0:
                scored.append((score, snippet))
        scored.sort(key=lambda item: (-item[0], item[1].source, item[1].title))
        if scored:
            return [item[1] for item in scored[:limit]]
        return snippets[:limit]

    def _terms(self, question: str, tag: str) -> list[str]:
        terms = list(TAG_TERMS.get(tag, TAG_TERMS["reflection"]))
        terms.extend(re.findall(r"[\u4e00-\u9fff]{2,}", question or ""))
        return list(dict.fromkeys(terms))

    def _load(self) -> list[KnowledgeSnippet]:
        if self._snippets is not None:
            return self._snippets
        snippets: list[KnowledgeSnippet] = []
        if not self.root.exists():
            self._snippets = []
            return self._snippets
        for path in sorted(self.root.glob("*.md")):
            snippets.extend(self._read_file(path))
        self._snippets = snippets
        return snippets

    def _read_file(self, path: Path) -> list[KnowledgeSnippet]:
        try:
            raw = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            raw = path.read_text(encoding="gb18030", errors="ignore")
        source = path.name
        current_title = path.stem
        chunks: list[KnowledgeSnippet] = []
        buffer: list[str] = []

        def flush() -> None:
            text = " ".join(line.strip() for line in buffer if line.strip())
            buffer.clear()
            if len(text) >= 40:
                chunks.append(
                    KnowledgeSnippet(
                        source=source,
                        title=current_title,
                        text=text[:260],
                    )
                )

        for line in raw.splitlines():
            stripped = line.strip()
            if stripped.startswith("#"):
                flush()
                current_title = stripped.lstrip("#").strip() or path.stem
            elif stripped:
                buffer.append(stripped)
                if sum(len(item) for item in buffer) > 320:
                    flush()
        flush()
        return chunks
