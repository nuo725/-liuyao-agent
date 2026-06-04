from __future__ import annotations

import json
import os
import re
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


DETERMINISTIC_REPLACEMENTS = {
    "一定会": "可能会",
    "必然": "可能",
    "注定": "倾向于",
    "保证": "提醒",
    "吉凶": "变化",
    "大吉": "较顺",
    "大凶": "压力较大",
    "好运": "较有支持感",
    "坏运": "阻力较多",
    "分数": "状态",
    "评分": "状态观察",
}


@dataclass(frozen=True)
class LlmResult:
    text: str
    model: str
    provider: str
    used_remote: bool
    followups: list[str]
    safety_notes: list[str]
    repair_attempts: int = 0


class SiliconFlowClient:
    """Minimal SiliconFlow chat client using Python stdlib only."""

    def __init__(self) -> None:
        self.enabled = os.environ.get("LIUYAO_LLM_ENABLED", "").lower() in {"1", "true", "yes"}
        self.api_key = os.environ.get("SILICONFLOW_API_KEY", "").strip()
        self.base_url = os.environ.get("SILICONFLOW_BASE_URL", "https://api.siliconflow.cn/v1").rstrip("/")
        self.model = os.environ.get("LIUYAO_LLM_MODEL", "Qwen/Qwen3-32B")
        self.timeout_seconds = int(os.environ.get("LIUYAO_LLM_TIMEOUT", "60"))

    def available(self) -> bool:
        return self.enabled and bool(self.api_key)

    def complete(
        self,
        *,
        question: str,
        tag: str,
        hexagram_name: str,
        moving_lines: list[int],
        knowledge_sources: list[dict[str, str]],
        reading: dict[str, Any] | None = None,
        followup_message: str | None = None,
    ) -> LlmResult | None:
        if not self.available():
            return None
        prompt = self._build_prompt(
            question=question,
            tag=tag,
            hexagram_name=hexagram_name,
            moving_lines=moving_lines,
            knowledge_sources=knowledge_sources,
            reading=reading,
            followup_message=followup_message,
        )
        messages = [self._system_message(), {"role": "user", "content": prompt}]
        text = self._chat_completion(messages)
        parsed = parse_structured_content(text or "")
        repair_attempts = 0
        while parsed is None and text and repair_attempts < 2:
            repair_attempts += 1
            text = self._chat_completion(
                [
                    self._system_message(),
                    {"role": "user", "content": self._repair_prompt(text)},
                ]
            )
            parsed = parse_structured_content(text or "")
        if parsed is None:
            return None
        answer = neutralize_text(parsed["answer"])
        if not answer:
            return None
        return LlmResult(
            text=answer,
            model=self.model,
            provider="siliconflow",
            used_remote=True,
            followups=parsed["followups"],
            safety_notes=parsed["safetyNotes"],
            repair_attempts=repair_attempts,
        )

    def _chat_completion(self, messages: list[dict[str, str]]) -> str | None:
        payload = {"model": self.model, "messages": messages, "temperature": 0.7, "stream": False}
        request = urllib.request.Request(
            f"{self.base_url}/chat/completions",
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout_seconds) as response:
                raw = response.read().decode("utf-8")
        except (urllib.error.URLError, TimeoutError, OSError):
            return None
        try:
            data = json.loads(raw)
            return str(data["choices"][0]["message"]["content"])
        except (KeyError, IndexError, TypeError, json.JSONDecodeError):
            return None

    def _system_message(self) -> dict[str, str]:
        return {
            "role": "system",
            "content": (
                "你是一个中性的六爻解读助手。只做反思性解释，不做预测、评分、吉凶裁决，"
                "不替代医疗、法律、金融等专业建议。必须只输出 JSON。"
            ),
        }

    def _repair_prompt(self, invalid_text: str) -> str:
        return (
            "下面内容不是合格 JSON 或字段不符合要求。请修复为严格 JSON，不要输出解释。\n\n"
            "必须格式：{\"answer\":\"...\",\"followups\":[\"...\"],\"safetyNotes\":[\"...\"]}\n"
            "要求：answer 为非空字符串；followups 为 1-3 个短问题；safetyNotes 为数组；"
            "不得包含一定、注定、必然、吉凶、评分、好运坏运等裁决表达。\n\n"
            f"原内容：{invalid_text[:2000]}"
        )

    def _build_prompt(
        self,
        *,
        question: str,
        tag: str,
        hexagram_name: str,
        moving_lines: list[int],
        knowledge_sources: list[dict[str, str]],
        reading: dict[str, Any] | None,
        followup_message: str | None,
    ) -> str:
        refs = "\n".join(
            f"- {item.get('title', '')}（{item.get('source', '')}）：{item.get('excerpt', '')}"
            for item in knowledge_sources
        )
        moving = ", ".join(str(item) for item in moving_lines) if moving_lines else "无"
        observations = "\n".join(f"- {item}" for item in (reading or {}).get("observations", []))
        if followup_message:
            task = f"请基于同一会话继续回应用户追问：{followup_message}"
        else:
            task = "请生成首轮完整解读。"
        return (
            f"用户问题：{question}\n"
            f"标签：{tag}\n"
            f"卦象摘要：{hexagram_name}\n"
            f"动爻：{moving}\n\n"
            f"结构化六爻观察：\n{observations or '无'}\n\n"
            f"可参考的本地六爻资料：\n{refs or '无'}\n\n"
            f"{task}\n"
            "要求：\n"
            "1. 不说一定、注定、必然，不做吉凶和分数判断。\n"
            "2. 解释卦象和标签如何提示当前处境。\n"
            "3. 给出轻量、可观察的小行动，不替用户做决定。\n"
            "4. 语言自然，不堆术语。\n"
            "5. 只输出严格 JSON，不要 Markdown，不要代码块。\n"
            "JSON schema：{\"answer\":\"string\",\"followups\":[\"string\"],\"safetyNotes\":[\"string\"]}"
        )


def neutralize_text(text: str) -> str:
    cleaned = text
    cleaned = re.sub(r"\b100\s*分\b", "状态较明显", cleaned)
    cleaned = re.sub(r"\b\d{1,3}\s*分\b", "一个可观察的状态", cleaned)
    cleaned = re.sub(r"100\s*分", "状态较明显", cleaned)
    cleaned = re.sub(r"\d{1,3}\s*分", "一个可观察的状态", cleaned)
    for source, target in DETERMINISTIC_REPLACEMENTS.items():
        cleaned = cleaned.replace(source, target)
    return cleaned.strip()


def parse_structured_content(raw: str) -> dict[str, Any] | None:
    parsed = _load_json_object(raw)
    if not isinstance(parsed, dict):
        return None
    answer = parsed.get("answer")
    followups = parsed.get("followups")
    safety_notes = parsed.get("safetyNotes")
    if not isinstance(answer, str) or not answer.strip():
        return None
    if not isinstance(followups, list):
        return None
    clean_followups = [str(item).strip() for item in followups if str(item).strip()]
    if not clean_followups:
        return None
    if len(clean_followups) > 3:
        clean_followups = clean_followups[:3]
    if safety_notes is None:
        safety_notes = []
    if not isinstance(safety_notes, list):
        return None
    clean_safety_notes = [str(item).strip() for item in safety_notes if str(item).strip()]
    neutral_answer = neutralize_text(answer)
    if not neutral_answer:
        return None
    return {
        "answer": neutral_answer,
        "followups": [neutralize_text(item) for item in clean_followups],
        "safetyNotes": [neutralize_text(item) for item in clean_safety_notes],
    }


def _load_json_object(raw: str) -> Any:
    text = raw.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?", "", text, flags=re.IGNORECASE).strip()
        text = re.sub(r"```$", "", text).strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", text, flags=re.DOTALL)
        if not match:
            return None
        try:
            return json.loads(match.group(0))
        except json.JSONDecodeError:
            return None


def metadata(result: LlmResult | None) -> dict[str, Any]:
    if result is None:
        return {"provider": "local", "usedRemote": False}
    return {
        "provider": result.provider,
        "model": result.model,
        "usedRemote": result.used_remote,
        "followups": result.followups,
        "safetyNotes": result.safety_notes,
        "repairAttempts": result.repair_attempts,
    }
