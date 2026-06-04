from __future__ import annotations

import json
import hashlib
import hmac
import os
import re
import time
import uuid
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

from knowledge import LiuyaoKnowledgeBase
from liuyao_engine import build_reading
from llm import SiliconFlowClient, metadata, neutralize_text
from share_render import render_share_card
from storage import SQLiteStateStore
from validation import (
    ValidationErrorInfo,
    choice,
    hexagram_lines,
    moving_lines as validate_moving_lines,
    non_empty_string,
    optional_string,
)


API_PREFIX = "/api/v1"
HOST = os.environ.get("ZHOUYI_BACKEND_HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT") or os.environ.get("ZHOUYI_BACKEND_PORT") or 3000)
STRICT_AUTH = os.environ.get("ZHOUYI_STRICT_AUTH", "").lower() in {"1", "true", "yes"}
ROOT_DIR = Path(__file__).resolve().parent
DATA_DIR = Path(os.environ.get("ZHOUYI_DATA_DIR", ROOT_DIR / "data"))
DB_FILE = DATA_DIR / "dev_store.sqlite3"
SHARE_OUTPUT_DIR = DATA_DIR / "share_cards"
LEGACY_DATA_FILE = DATA_DIR / "dev_store.json"
KNOWLEDGE_DIR = ROOT_DIR.parent / "六爻"
ALLOWED_IMAGE_MIMES = {"image/jpeg", "image/png", "image/webp"}
STATE_STORE = SQLiteStateStore(DB_FILE)
KNOWLEDGE_BASE = LiuyaoKnowledgeBase(KNOWLEDGE_DIR)
LLM_CLIENT = SiliconFlowClient()
AGREEMENT_VERSION = "ua_2026_04_15"
PRIVACY_VERSION = "pp_2026_04_15"
PAYMENT_CALLBACK_SECRET = os.environ.get("ZHOUYI_PAYMENT_CALLBACK_SECRET", "dev_callback_secret")
BILLING_PLANS = [
    {"id": "plan_month", "days": 30, "priceCents": 2900, "currency": "CNY", "title": "Monthly VIP"},
    {"id": "plan_quarter", "days": 90, "priceCents": 7900, "currency": "CNY", "title": "Quarterly VIP"},
    {"id": "plan_year", "days": 365, "priceCents": 19900, "currency": "CNY", "title": "Yearly VIP"},
]
ACCESS_TOKEN_TTL_SECONDS = 2 * 60 * 60
REFRESH_TOKEN_TTL_SECONDS = 30 * 24 * 60 * 60


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def future_iso(seconds: int) -> str:
    return (datetime.now(timezone.utc) + timedelta(seconds=seconds)).isoformat().replace("+00:00", "Z")


def parse_iso(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def is_expired(value: Any) -> bool:
    expires_at = parse_iso(value)
    return bool(expires_at and expires_at <= datetime.now(timezone.utc))


def ok(data: Any = None) -> dict[str, Any]:
    return {"success": True, "data": data if data is not None else {}}


def fail(code: str, message: str) -> dict[str, Any]:
    return {"success": False, "error": {"code": code, "message": message}}


def parse_int(value: Any, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


class Store:
    def __init__(self) -> None:
        self.users: dict[str, dict[str, Any]] = {}
        self.tokens: dict[str, dict[str, Any]] = {}
        self.refresh_tokens: dict[str, dict[str, Any]] = {}
        self.agreement_consents: dict[str, list[dict[str, Any]]] = {}
        self.phone_codes: dict[str, dict[str, Any]] = {}
        self.profile_settings: dict[str, dict[str, Any]] = {}
        self.checkins: dict[str, dict[str, Any]] = {}
        self.sessions: dict[str, dict[str, Any]] = {}
        self.billing: dict[str, dict[str, Any]] = {}
        self.billing_orders: dict[str, dict[str, Any]] = {}
        self.credit_consumptions: dict[str, dict[str, Any]] = {}
        self.feed: list[dict[str, Any]] = []
        self.comments: dict[str, list[dict[str, Any]]] = {}
        self.community_state: dict[str, dict[str, Any]] = {}
        self.activities: dict[str, dict[str, Any]] = {}
        self.activity_submissions: dict[str, list[dict[str, Any]]] = {}
        self.tag_subscriptions: dict[str, set[str]] = {}
        self.notifications: dict[str, list[dict[str, Any]]] = {}
        self.notification_tokens: dict[str, list[dict[str, Any]]] = {}
        self.share_drafts: dict[str, dict[str, Any]] = {}
        self.match_unlocks: dict[str, dict[str, Any]] = {}
        self.rate_limits: dict[str, list[str]] = {}
        self.feedback_tickets: list[dict[str, Any]] = []
        self.deleted_accounts: dict[str, dict[str, Any]] = {}
        if not self._load():
            self._seed()
            self.save()

    def _load(self) -> bool:
        data = STATE_STORE.load()
        if data is None and LEGACY_DATA_FILE.exists():
            try:
                data = json.loads(LEGACY_DATA_FILE.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                data = None
        if data is None:
            return False
        self.users = dict(data.get("users") or {})
        self.tokens = dict(data.get("tokens") or {})
        self.refresh_tokens = dict(data.get("refresh_tokens") or {})
        self.agreement_consents = dict(data.get("agreement_consents") or {})
        self.phone_codes = dict(data.get("phone_codes") or {})
        self.profile_settings = dict(data.get("profile_settings") or {})
        self.checkins = dict(data.get("checkins") or {})
        self.sessions = dict(data.get("sessions") or {})
        self.billing = dict(data.get("billing") or {})
        self.billing_orders = dict(data.get("billing_orders") or {})
        self.credit_consumptions = dict(data.get("credit_consumptions") or {})
        self.feed = list(data.get("feed") or [])
        self.comments = dict(data.get("comments") or {})
        self.community_state = dict(data.get("community_state") or {})
        self.activities = dict(data.get("activities") or {})
        self.activity_submissions = dict(data.get("activity_submissions") or {})
        raw_subscriptions = dict(data.get("tag_subscriptions") or {})
        self.tag_subscriptions = {
            user_id: set(tags if isinstance(tags, list) else [])
            for user_id, tags in raw_subscriptions.items()
        }
        self.notifications = dict(data.get("notifications") or {})
        self.notification_tokens = dict(data.get("notification_tokens") or {})
        self.share_drafts = dict(data.get("share_drafts") or {})
        self.match_unlocks = dict(data.get("match_unlocks") or {})
        self.rate_limits = dict(data.get("rate_limits") or {})
        self.feedback_tickets = list(data.get("feedback_tickets") or [])
        self.deleted_accounts = dict(data.get("deleted_accounts") or {})
        return True

    def save(self) -> None:
        payload = {
            "users": self.users,
            "tokens": self.tokens,
            "refresh_tokens": self.refresh_tokens,
            "agreement_consents": self.agreement_consents,
            "phone_codes": self.phone_codes,
            "profile_settings": self.profile_settings,
            "checkins": self.checkins,
            "sessions": self.sessions,
            "billing": self.billing,
            "billing_orders": self.billing_orders,
            "credit_consumptions": self.credit_consumptions,
            "feed": self.feed,
            "comments": self.comments,
            "community_state": self.community_state,
            "activities": self.activities,
            "activity_submissions": self.activity_submissions,
            "tag_subscriptions": {k: sorted(v) for k, v in self.tag_subscriptions.items()},
            "notifications": self.notifications,
            "notification_tokens": self.notification_tokens,
            "share_drafts": self.share_drafts,
            "match_unlocks": self.match_unlocks,
            "rate_limits": self.rate_limits,
            "feedback_tickets": self.feedback_tickets,
            "deleted_accounts": self.deleted_accounts,
        }
        STATE_STORE.save(payload)

    def _seed(self) -> None:
        self.users["user_demo"] = {
            "id": "user_demo",
            "username": "Orbit Demo",
            "bio": "A local test account for backend integration.",
            "city": "Chengdu",
            "gender": "not_disclosed",
            "birthday": None,
            "avatarUrl": "",
            "coverUrl": "",
            "shortId": "demo0001",
            "createdAt": now_iso(),
        }
        self.profile_settings["user_demo"] = self.default_settings()
        self.activities["act_cold_joke_001"] = {
            "id": "act_cold_joke_001",
            "title": "Cold Joke Challenge",
            "description": "A campaign shell that can attach tag identity to submissions.",
            "imageUrl": "https://picsum.photos/seed/activity-cold-joke/1200/800",
            "dateText": "Apr 17 - Apr 24",
            "status": "open",
            "participantCount": 128,
            "joinLimit": 500,
            "tags": ["cold_joke", "light_mood"],
            "content": "Reserved backend surface for campaign submissions and tag distribution.",
            "organizer": {"id": "system", "name": "Zhouyi App"},
            "joined": False,
            "joinStatus": "none",
        }
        card = make_card(
            question="How should I understand my current pace?",
            tag="emotion",
            lines=[1, 0, 1, 1, 0, 1],
            moving_lines=[2, 5],
            session_id="seed_card",
        )
        self.feed.append(
            {
                "id": "feed_seed_1",
                "cardId": card["id"],
                "card": {**card, "question": ""},
                "shareText": "A neutral reading about slowing down before choosing.",
                "coverImageUrl": "https://picsum.photos/seed/zhouyi-feed/1200/900",
                "authorId": "user_seed",
                "authorUsername": "Orbit",
                "authorHandle": "orbit",
                "authorAvatarUrl": "",
                "createdAt": now_iso(),
                "status": "published",
            "metrics": {"likes": 12, "favorites": 4, "views": 188, "comments": 0, "reports": 0, "downvotes": 0},
                "viewerState": {"liked": False, "favorited": False, "followedAuthor": False},
            }
        )
        self.notifications["user_demo"] = [
            {
                "id": "notif_seed_1",
                "type": "system",
                "title": "Backend scaffold ready",
                "body": "Local API routes are available for frontend integration.",
                "data": {"targetId": None, "targetType": None},
                "createdAt": now_iso(),
                "read": False,
            }
        ]
        token = "dev_seed_user_demo"
        self.tokens[token] = {
            "userId": "user_demo",
            "issuedAt": now_iso(),
            "expiresAt": future_iso(ACCESS_TOKEN_TTL_SECONDS),
            "revoked": False,
        }

    def default_settings(self) -> dict[str, Any]:
        return {
            "pushEnabled": True,
            "vibrationEnabled": True,
            "ambientSoundEnabled": True,
            "publicProfile": True,
        }

    def ensure_user(self, user_id: str | None = None) -> dict[str, Any]:
        uid = user_id or f"user_{uuid.uuid4().hex[:8]}"
        if uid not in self.users:
            self.users[uid] = {
                "id": uid,
                "username": "Guest",
                "bio": None,
                "city": None,
                "gender": "not_disclosed",
                "birthday": None,
                "avatarUrl": None,
                "coverUrl": None,
                "shortId": uuid.uuid4().hex[:8],
                "createdAt": now_iso(),
            }
        self.profile_settings.setdefault(uid, self.default_settings())
        self.notifications.setdefault(uid, [])
        return self.users[uid]

    def ensure_account(self, user_id: str) -> dict[str, Any]:
        if user_id not in self.billing:
            self.billing[user_id] = {
                "userId": user_id,
                "castBalance": 1,
                "followupBalance": 1,
                "castExpireDate": None,
                "followupExpireDate": None,
                "lastCheckinDate": now_iso(),
                "lastResetDate": now_iso(),
                "isVip": False,
                "vipExpireDate": None,
            }
        self.reset_account_if_needed(self.billing[user_id])
        return self.billing[user_id]

    def reset_account_if_needed(self, account: dict[str, Any]) -> None:
        today = datetime.now(timezone.utc).date().isoformat()
        last_reset = str(account.get("lastResetDate") or "")[:10]
        if last_reset == today:
            return
        if account.get("isVip"):
            account["castBalance"] = max(int(account.get("castBalance", 0)), 2)
            account["followupBalance"] = max(int(account.get("followupBalance", 0)), 4)
        else:
            account["castBalance"] = max(int(account.get("castBalance", 0)), 1)
            account["followupBalance"] = max(int(account.get("followupBalance", 0)), 1)
        account["lastResetDate"] = now_iso()

    def issue_session(self, user_id: str) -> dict[str, str]:
        issued_at = now_iso()
        access_token = f"dev_{uuid.uuid4().hex}"
        refresh_token = f"refresh_{uuid.uuid4().hex}"
        access_expires_at = future_iso(ACCESS_TOKEN_TTL_SECONDS)
        refresh_expires_at = future_iso(REFRESH_TOKEN_TTL_SECONDS)
        self.tokens[access_token] = {
            "userId": user_id,
            "issuedAt": issued_at,
            "expiresAt": access_expires_at,
            "refreshToken": refresh_token,
            "revoked": False,
        }
        self.refresh_tokens[refresh_token] = {
            "userId": user_id,
            "issuedAt": issued_at,
            "expiresAt": refresh_expires_at,
            "accessToken": access_token,
            "revoked": False,
        }
        return {
            "accessToken": access_token,
            "refreshToken": refresh_token,
            "expiresAt": access_expires_at,
            "refreshExpiresAt": refresh_expires_at,
        }

    def refresh_session(self, refresh_token: str | None) -> dict[str, str] | None:
        if not refresh_token:
            return None
        session = self.refresh_tokens.get(refresh_token)
        if not session or session.get("revoked") or is_expired(session.get("expiresAt")):
            return None
        previous_access = session.get("accessToken")
        if previous_access in self.tokens:
            self.tokens[str(previous_access)]["revoked"] = True
        session["revoked"] = True
        return self.issue_session(str(session.get("userId") or ""))

    def user_id_for_token(self, token: str | None) -> str | None:
        if not token:
            return None
        session = self.tokens.get(token)
        if not session or session.get("revoked"):
            return None
        if is_expired(session.get("expiresAt")):
            session["revoked"] = True
            return None
        user_id = session.get("userId")
        return str(user_id) if user_id else None

    def revoke_token(self, token: str | None) -> None:
        if token and token in self.tokens:
            self.tokens[token]["revoked"] = True
            refresh_token = self.tokens[token].get("refreshToken")
            if refresh_token in self.refresh_tokens:
                self.refresh_tokens[str(refresh_token)]["revoked"] = True


HEXAGRAMS = [
    ("1", "Qian", "111111"),
    ("2", "Kun", "000000"),
    ("11", "Tai", "111000"),
    ("12", "Pi", "000111"),
    ("29", "Kan", "010010"),
    ("30", "Li", "101101"),
    ("52", "Gen", "001001"),
    ("58", "Dui", "110110"),
]


def choose_hexagram(lines: list[int]) -> dict[str, str]:
    normalized = "".join("1" if int(x) else "0" for x in (lines or [1, 0, 1, 1, 0, 1]))
    total = sum((idx + 1) * int(v) for idx, v in enumerate(normalized))
    hid, name, symbol = HEXAGRAMS[total % len(HEXAGRAMS)]
    return {"id": hid, "name": name, "symbol": symbol}


def derive_tag(question: str, explicit: str | None = None) -> tuple[str, list[str]]:
    text = (question or "").lower()
    if explicit and explicit != "other":
        primary = explicit
    elif any(word in text for word in ["job", "career", "work", "business"]):
        primary = "career"
    elif any(word in text for word in ["love", "friend", "relationship", "partner"]):
        primary = "relationship"
    elif any(word in text for word in ["choose", "choice", "switch", "decide"]):
        primary = "choice"
    elif any(word in text for word in ["anxious", "sad", "emotion", "mood"]):
        primary = "emotion"
    else:
        primary = "reflection"
    secondary = ["pace", "boundary"] if primary in {"career", "choice"} else ["clarity", "self_observation"]
    return primary, secondary


def make_reply(question: str, lines: list[int], moving_lines: list[int], tag: str) -> str:
    hexagram = choose_hexagram(lines)
    reading = build_reading(lines, moving_lines, tag).to_json()
    moving = ", ".join(str(x) for x in moving_lines) if moving_lines else "none"
    snippets = KNOWLEDGE_BASE.search(question, tag, limit=2)
    knowledge_text = ""
    if snippets:
        joined = "\n".join(f"- {item.title}（{item.source}）：{item.text}" for item in snippets)
        knowledge_text = f"\n\nLocal Liuyao references:\n{joined}"
    return (
        f"This is a neutral reflective reading for: {question or 'the current question'}.\n\n"
        f"The pattern maps to {hexagram['name']} with moving lines: {moving}. "
        "Treat it as a mirror for attention, not as a fixed prediction. "
        f"The current identity tag is {tag}, which points to a theme worth revisiting.\n\n"
        f"Structured Liuyao note: {reading['observations'][0]} {reading['observations'][-1]}\n\n"
        "A useful next step is to name one concrete action, one boundary, and one thing to observe "
        "before making the situation heavier than it needs to be."
        f"{knowledge_text}"
    )


def knowledge_source_dicts(question: str, tag: str, limit: int = 2) -> list[dict[str, str]]:
    return [
        {"source": item.source, "title": item.title, "excerpt": item.text}
        for item in KNOWLEDGE_BASE.search(question, tag, limit=limit)
    ]


def generate_reply(
    *,
    question: str,
    lines: list[int],
    moving_lines: list[int],
    tag: str,
    followup_message: str | None = None,
) -> tuple[str, dict[str, Any]]:
    hexagram = choose_hexagram(lines)
    reading = build_reading(lines, moving_lines, tag).to_json()
    sources = knowledge_source_dicts(question, tag, limit=2)
    remote = LLM_CLIENT.complete(
        question=question,
        tag=tag,
        hexagram_name=hexagram["name"],
        moving_lines=moving_lines,
        knowledge_sources=sources,
        reading=reading,
        followup_message=followup_message,
    )
    if remote:
        meta = metadata(remote)
        meta["reading"] = {"original": reading["original"], "changed": reading["changed"], "movingLines": reading["movingLines"]}
        return remote.text, meta
    if followup_message:
        text = (
            f"Continue from the same tag identity: {tag}. "
            "Use the follow-up as a prompt for observation rather than a final answer. "
            "Name the next observable step and keep the interpretation non-prescriptive."
        )
    else:
        text = make_reply(question, lines, moving_lines, tag)
    meta = metadata(None)
    meta["reading"] = {"original": reading["original"], "changed": reading["changed"], "movingLines": reading["movingLines"]}
    return neutralize_text(text), meta


def make_card(
    question: str,
    tag: str,
    lines: list[int],
    moving_lines: list[int],
    session_id: str,
) -> dict[str, Any]:
    primary, secondary = derive_tag(question, tag)
    reading = build_reading(lines, moving_lines, primary).to_json()
    summary = f"A reflective {primary} tag emerged from this ritual."
    reply_text, reply_meta = generate_reply(
        question=question,
        lines=lines,
        moving_lines=moving_lines,
        tag=primary,
    )
    return {
        "id": f"card_{session_id}",
        "question": question,
        "tag": primary,
        "pattern": {"lines": lines, "movingLines": moving_lines},
        "content": {
            "summary": summary,
            "focusPoints": [
                "Notice what the question is asking you to protect.",
                "Separate immediate emotion from the next practical step.",
            ],
            "afterglow": "Keep the result readable and non-final.",
            "followupDirections": [
                "What is the smallest next step?",
                "What should be paused for now?",
                "What does this tag remind me to revisit?",
            ],
            "rawResponse": None,
            "microActions": "Write one sentence about the boundary you need today.",
            "body": reply_text,
            "quoteText": "Change is observed before it is forced.",
            "quoteSource": "Local reflection",
            "visualBlocks": [
                {"icon": "tag", "title": "Tag", "text": primary},
                {"icon": "spark", "title": "Support", "text": ", ".join(secondary)},
            ],
        },
        "riskLevel": "low",
        "createdAt": now_iso(),
        "authorId": None,
        "needsClarification": False,
        "reading": reading,
        "knowledgeSources": knowledge_source_dicts(question, primary, limit=2),
        "replyMeta": reply_meta,
    }


def make_session(
    question: str,
    tag: str,
    lines: list[int],
    moving_lines: list[int],
    user_id: str = "user_demo",
) -> dict[str, Any]:
    session_id = f"sess_{uuid.uuid4().hex[:10]}"
    primary, secondary = derive_tag(question, tag)
    card = make_card(question, primary, lines, moving_lines, session_id)
    session = {
        "sessionId": session_id,
        "userId": user_id,
        "question": question,
        "pattern": {"lines": lines, "movingLines": moving_lines},
        "card": card,
        "tagProfile": {
            "primaryTag": primary,
            "secondaryTags": secondary,
            "explanation": f"{primary} is used as a readable identity marker for this ritual, not a score or verdict.",
            "source": "ritual",
            "createdAt": now_iso(),
        },
        "timeline": [
            {
                "id": f"tag_{uuid.uuid4().hex[:8]}",
                "tag": primary,
                "eventType": "generated",
                "sourceId": session_id,
                "summary": f"Generated from ritual question: {question}",
                "createdAt": now_iso(),
            }
        ],
        "messages": [
            {"id": "msg_question", "type": "question", "content": question, "createdAt": now_iso()},
            {"id": "msg_answer", "type": "answer", "content": card["content"]["body"], "createdAt": now_iso()},
        ],
        "createdAt": now_iso(),
        "updatedAt": now_iso(),
    }
    store.sessions[session_id] = session
    store.save()
    return session


store = Store()


class Handler(BaseHTTPRequestHandler):
    server_version = "ZhouyiBackend/0.1"

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:
        self.route("GET")

    def do_POST(self) -> None:
        self.route("POST")

    def do_PUT(self) -> None:
        self.route("PUT")

    def do_DELETE(self) -> None:
        self.route("DELETE")

    def route(self, method: str) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        query = {k: v[-1] for k, v in parse_qs(parsed.query).items()}
        body = self._read_json() if method in {"POST", "PUT", "DELETE"} else {}

        try:
            if not path.startswith(API_PREFIX):
                self._json(404, fail("40401", "API prefix must be /api/v1"))
                return
            route = path[len(API_PREFIX) :] or "/"

            if route == "/liuyao/app/health" and method == "GET":
                self._json(200, ok({"status": "ok", "time": now_iso()}))
            elif method == "GET" and re.fullmatch(r"/static/share/[^/]+\.svg", route):
                self._serve_share_asset(route.rsplit("/", 1)[-1])
            elif route == "/liuyao/app/llm/status" and method == "GET":
                self._json(
                    200,
                    ok(
                        {
                            "enabled": LLM_CLIENT.enabled,
                            "available": LLM_CLIENT.available(),
                            "provider": "siliconflow",
                            "model": LLM_CLIENT.model,
                            "baseUrl": LLM_CLIENT.base_url,
                        }
                    ),
                )
            elif route == "/liuyao/app/chat/start" and method == "POST":
                self._start_chat(body)
            elif route == "/liuyao/app/chat/continue" and method == "POST":
                self._continue_chat(body)
            elif method == "GET" and re.fullmatch(r"/liuyao/app/chat/session/[^/]+", route):
                self._get_agent_session(route.rsplit("/", 1)[-1])
            elif route in {"/ritual/perform", "/ritual/start"} and method == "POST":
                self._ritual_perform(body)
            elif method == "GET" and re.fullmatch(r"/ritual/user/[^/]+/completion-today", route):
                self._ritual_completion_today(route.split("/")[3])
            elif method == "GET" and re.fullmatch(r"/ritual/session/[^/]+", route):
                self._ritual_session(route.rsplit("/", 1)[-1])
            elif method == "POST" and re.fullmatch(r"/ritual/session/[^/]+/(continue|chat)", route):
                self._continue_chat({"sessionId": route.split("/")[3], "message": body.get("message", "")})
            elif method == "GET" and re.fullmatch(r"/ritual/session/[^/]+/preview", route):
                self._ritual_session(route.split("/")[3])
            elif method == "GET" and re.fullmatch(r"/ritual/session/[^/]+/full-read", route):
                self._ritual_full_read(route.split("/")[3])
            elif method == "GET" and re.fullmatch(r"/ritual/session/[^/]+/tag-profile", route):
                self._tag_profile(route.split("/")[3])
            elif method == "GET" and re.fullmatch(r"/ritual/session/[^/]+/tag-timeline", route):
                self._tag_timeline(route.split("/")[3], query)
            elif method == "GET" and re.fullmatch(r"/ritual/session/[^/]+/tag-explanation", route):
                self._tag_explanation(route.split("/")[3])
            elif method == "GET" and re.fullmatch(r"/ritual/session/[^/]+/chat-history", route):
                self._chat_history(route.split("/")[3])
            elif method == "GET" and re.fullmatch(r"/ritual/session/[^/]+/interpretation/stream", route):
                self._sse("interpretation", route.split("/")[3], require_auth=False)
            elif method == "GET" and re.fullmatch(r"/ritual/session/[^/]+/(chat|followup)/stream", route):
                self._sse("followup", route.split("/")[3], require_auth=True)
            elif route.startswith("/auth/"):
                self._auth(method, route, body)
            elif route.startswith("/billing/") or route.startswith("/credit/"):
                self._billing(method, route, query, body)
            elif route.startswith("/profile"):
                self._profile(method, route, query, body)
            elif route.startswith("/notifications"):
                self._notifications(method, route, query, body)
            elif route.startswith("/feed"):
                self._feed(method, route, query, body)
            elif route.startswith("/activities") or route.startswith("/activity"):
                self._activities(method, route, query, body)
            elif route.startswith("/community"):
                self._community(method, route, query, body)
            elif route.startswith("/share"):
                self._share(method, route, body)
            elif route.startswith("/match"):
                self._match(method, route, query, body)
            elif route.startswith("/support"):
                self._support(method, route, body)
            elif route.startswith("/media"):
                self._media(method, route, body)
            elif route.startswith("/knowledge"):
                self._knowledge(method, route, query)
            else:
                self._json(404, fail("40401", f"Route not implemented: {method} {route}"))
        except Exception as exc:  # keep local backend debuggable
            self._json(500, fail("50000", str(exc)))

    def _start_chat(self, body: dict[str, Any]) -> None:
        user_id = self._current_user_id(body, {})
        if user_id is None:
            return
        question = non_empty_string(body.get("question"), "question", max_length=300)
        lines = hexagram_lines(body.get("lines"))
        moving_lines = validate_moving_lines(body.get("movingLines", []))
        if self._validation_failed(question, lines, moving_lines):
            return
        consumed = self._consume_credit(user_id, "cast", body.get("sessionId"))
        if consumed is None:
            return
        session = make_session(question, str(body.get("tag") or "other"), lines, moving_lines, user_id=user_id)
        self._json(
            200,
            ok(
                {
                    "mode": "normal_reading",
                    "needsClarification": False,
                    "session": self._session_info(session),
                    "summary": self._hex_summary(lines, moving_lines),
                    "reply": {
                        "text": session["card"]["content"]["body"],
                        "model": body.get("model"),
                        "usage": self._usage(),
                        "meta": session["card"].get("replyMeta", {"provider": "local", "usedRemote": False}),
                    },
                    "evaluation": {
                        "confidence": "medium",
                        "suggestedQuestionType": session["tagProfile"]["primaryTag"],
                        "reasons": ["Local backend scaffold generated a neutral reflective response."],
                        "warnings": ["Not a production divination or advice engine."],
                    },
                    "credit": {"account": consumed},
                }
            ),
        )

    def _continue_chat(self, body: dict[str, Any]) -> None:
        session_id = str(body.get("sessionId") or "")
        session = store.sessions.get(session_id)
        if not session:
            self._json(404, fail("40401", "Session not found"))
            return
        user_id = self._current_user_id(body, {}, require=STRICT_AUTH)
        if user_id is None:
            return
        if STRICT_AUTH and session.get("userId") not in {None, user_id}:
            self._json(403, fail("40301", "Session does not belong to current user"))
            return
        message = non_empty_string(body.get("message"), "message", max_length=800)
        if self._validation_failed(message):
            return
        consumed = self._consume_credit(user_id, "followup", session_id)
        if consumed is None:
            return
        reply, reply_meta = generate_reply(
            question=session.get("question") or "",
            lines=session.get("pattern", {}).get("lines") or [1, 0, 1, 1, 0, 1],
            moving_lines=session.get("pattern", {}).get("movingLines") or [],
            tag=session["tagProfile"]["primaryTag"],
            followup_message=message,
        )
        session["messages"].append({"id": f"msg_{uuid.uuid4().hex[:8]}", "type": "question", "content": message, "createdAt": now_iso()})
        session["messages"].append({"id": f"msg_{uuid.uuid4().hex[:8]}", "type": "answer", "content": reply, "createdAt": now_iso()})
        session["updatedAt"] = now_iso()
        store.save()
        self._json(200, ok({"session": self._session_info(session), "reply": {"text": reply, "usage": self._usage(), "meta": reply_meta}, "credit": {"account": consumed}}))

    def _get_agent_session(self, session_id: str) -> None:
        session = store.sessions.get(session_id)
        if not session:
            self._json(404, fail("40401", "Session not found"))
            return
        self._json(200, ok(self._session_info(session)))

    def _ritual_perform(self, body: dict[str, Any]) -> None:
        user_id = self._current_user_id(body, {})
        if user_id is None:
            return
        question = non_empty_string(body.get("question"), "question", max_length=300)
        lines = hexagram_lines(body.get("lines"))
        moving_lines = validate_moving_lines(body.get("movingLines", []))
        if self._validation_failed(question, lines, moving_lines):
            return
        consumed = self._consume_credit(user_id, "cast", body.get("sessionId"))
        if consumed is None:
            return
        session = make_session(question, str(body.get("tag") or "other"), lines, moving_lines, user_id=user_id)
        self._json(200, ok({"sessionId": session["sessionId"], "pattern": session["pattern"], "card": session["card"]["content"], "credit": {"account": consumed}}))

    def _ritual_session(self, session_id: str) -> None:
        session = store.sessions.get(session_id)
        if not session:
            self._json(404, fail("40401", "Session not found"))
            return
        self._json(200, ok(session))

    def _ritual_full_read(self, session_id: str) -> None:
        session = store.sessions.get(session_id)
        if not session:
            self._json(404, fail("40401", "Session not found"))
            return
        user_id = self._current_user_id({}, {}, require=STRICT_AUTH)
        if user_id is None:
            return
        if STRICT_AUTH and session.get("userId") not in {None, user_id}:
            self._json(403, fail("40301", "Session does not belong to current user"))
            return
        self._json(200, ok(session))

    def _tag_profile(self, session_id: str) -> None:
        session = store.sessions.get(session_id)
        if not session:
            self._json(404, fail("40401", "Session not found"))
            return
        self._json(200, ok(session["tagProfile"]))

    def _tag_timeline(self, session_id: str, query: dict[str, str]) -> None:
        session = store.sessions.get(session_id)
        if not session:
            self._json(404, fail("40401", "Session not found"))
            return
        timeline = session["timeline"]
        page_size = parse_int(query.get("pageSize"), 20)
        self._json(200, ok({"items": timeline[:page_size], "hasMore": False, "nextPage": 2}))

    def _tag_explanation(self, session_id: str) -> None:
        session = store.sessions.get(session_id)
        if not session:
            self._json(404, fail("40401", "Session not found"))
            return
        profile = session["tagProfile"]
        self._json(200, ok({"tag": profile["primaryTag"], "explanation": profile["explanation"], "secondaryTags": profile["secondaryTags"]}))

    def _chat_history(self, session_id: str) -> None:
        session = store.sessions.get(session_id)
        if not session:
            self._json(404, fail("40401", "Session not found"))
            return
        user_id = self._current_user_id({}, {}, require=STRICT_AUTH)
        if user_id is None:
            return
        if STRICT_AUTH and session.get("userId") not in {None, user_id}:
            self._json(403, fail("40301", "Session does not belong to current user"))
            return
        self._json(200, ok({"messages": session["messages"] if session else []}))

    def _ritual_completion_today(self, user_id: str) -> None:
        today = datetime.now(timezone.utc).date().isoformat()
        completed = [
            session
            for session in store.sessions.values()
            if session.get("userId") == user_id
            and str(session.get("createdAt") or "")[:10] == today
        ]
        latest = max((str(item.get("createdAt") or "") for item in completed), default=None)
        self._json(200, ok({"userId": user_id, "completed": bool(completed), "lastCompletedAt": latest}))

    def _auth(self, method: str, route: str, body: dict[str, Any]) -> None:
        if method == "POST" and route == "/auth/phone/send-code":
            phone = non_empty_string(body.get("phone"), "phone", max_length=30)
            if self._validation_failed(phone):
                return
            if self._rate_limited(f"phone:{phone}", "auth_send_code", 5):
                return
            store.phone_codes[phone] = {"code": "123456", "sentAt": now_iso(), "ttlSeconds": 300}
            store.save()
            self._json(200, ok({"sent": True, "ttlSeconds": 300}))
        elif method == "GET" and route == "/auth/agreement-version":
            self._json(200, ok({"agreementVersion": AGREEMENT_VERSION}))
        elif method == "GET" and route == "/auth/privacy-version":
            self._json(200, ok({"privacyVersion": PRIVACY_VERSION}))
        elif method == "POST" and route == "/auth/agreement-consent":
            user_id = self._current_user_id(body, {}, require=False)
            if user_id is None:
                return
            consent = self._agreement_consent_payload(body)
            store.agreement_consents.setdefault(user_id, []).append(consent)
            store.save()
            self._json(200, ok({"consent": consent}))
        elif method == "POST" and route in {"/auth/phone/login", "/auth/social/login", "/auth/guest/upgrade", "/auth/test-login"}:
            if route == "/auth/social/login":
                provider = choice(body.get("provider"), "provider", {"wechat", "qq"})
                auth_code = non_empty_string(body.get("authCode"), "authCode", max_length=256)
                if self._validation_failed(provider, auth_code):
                    return
                body["provider"] = provider
            user = store.ensure_user(body.get("userId") or "user_demo")
            user["username"] = body.get("username") or user.get("username") or "Guest"
            if body.get("phone"):
                user["phone"] = str(body.get("phone"))
            if route == "/auth/social/login":
                user["socialProvider"] = body["provider"]
                user["socialLinkedAt"] = now_iso()
            if route == "/auth/phone/login":
                code = str(body.get("code") or "")
                if code and code != "123456":
                    self._json(400, fail("40001", "Invalid verification code"))
                    return
            consent = self._agreement_consent_payload(body)
            store.agreement_consents.setdefault(user["id"], []).append(consent)
            store.ensure_account(user["id"])
            session = self._make_auth_session(user)
            store.save()
            self._json(200, ok({"session": session}))
        elif method == "POST" and route == "/auth/refresh":
            refresh_token = non_empty_string(body.get("refreshToken"), "refreshToken", max_length=128)
            if self._validation_failed(refresh_token):
                return
            session_tokens = store.refresh_session(refresh_token)
            if not session_tokens:
                self._json(401, fail("40102", "Session expired"))
                return
            user = store.ensure_user(store.refresh_tokens[session_tokens["refreshToken"]]["userId"])
            store.save()
            self._json(200, ok({"session": {"user": user, **session_tokens}}))
        elif method == "GET" and route == "/auth/session":
            user_id = self._current_user_id()
            if user_id is None:
                return
            user = store.ensure_user(user_id)
            session = self._make_auth_session(user)
            store.save()
            self._json(200, ok({"session": session}))
        elif method == "POST" and route == "/auth/logout":
            store.revoke_token(self._bearer_token())
            store.save()
            self._json(200, ok({"loggedOut": True}))
        elif method == "POST" and route == "/auth/password/recovery":
            phone = non_empty_string(body.get("phone"), "phone", max_length=30)
            code = non_empty_string(body.get("code"), "code", max_length=12)
            password = non_empty_string(body.get("newPassword"), "newPassword", max_length=128)
            confirm = non_empty_string(body.get("confirmPassword"), "confirmPassword", max_length=128)
            if self._validation_failed(phone, code, password, confirm):
                return
            if code != "123456":
                self._json(400, fail("40001", "Invalid verification code"))
                return
            if password != confirm:
                self._json(400, fail("40001", "Passwords do not match"))
                return
            user = next((item for item in store.users.values() if item.get("phone") == phone), None)
            if user:
                user["passwordUpdatedAt"] = now_iso()
                store.save()
            self._json(200, ok({"updated": True}))
        elif method == "GET" and route == "/auth/account-info":
            user_id = self._current_user_id()
            if user_id is None:
                return
            user = store.ensure_user(user_id)
            self._json(200, ok({"account": self._account_info(user)}))
        elif method == "POST" and route == "/auth/change-password":
            user_id = self._current_user_id()
            if user_id is None:
                return
            password = non_empty_string(body.get("newPassword"), "newPassword", max_length=128)
            confirm = non_empty_string(body.get("confirmPassword"), "confirmPassword", max_length=128)
            if self._validation_failed(password, confirm):
                return
            if password != confirm:
                self._json(400, fail("40001", "Passwords do not match"))
                return
            user = store.ensure_user(user_id)
            user["passwordUpdatedAt"] = now_iso()
            store.save()
            self._json(200, ok({"updated": True}))
        elif method == "POST" and route in {"/auth/phone-bindchange", "/auth/phone/bind-change"}:
            user_id = self._current_user_id()
            if user_id is None:
                return
            phone = non_empty_string(body.get("phone"), "phone", max_length=30)
            if self._validation_failed(phone):
                return
            user = store.ensure_user(user_id)
            user["phone"] = phone
            user["phoneUpdatedAt"] = now_iso()
            store.save()
            self._json(200, ok({"phone": phone, "updated": True}))
        elif method == "POST" and route == "/auth/profile/update":
            user_id = self._current_user_id(body, {})
            if user_id is None:
                return
            user = store.ensure_user(user_id)
            allowed = {"username", "bio", "avatarUrl", "coverUrl", "gender", "city"}
            for key in allowed:
                if key in body:
                    user[key] = body[key]
            if "username" in body:
                username = non_empty_string(body.get("username"), "username", max_length=40)
                if self._validation_failed(username):
                    return
                user["username"] = username
            if "bio" in body:
                bio = optional_string(body.get("bio"), "bio", max_length=160)
                if self._validation_failed(bio):
                    return
                user["bio"] = bio
            store.save()
            self._json(200, ok({"profile": user}))
        elif method == "POST" and route == "/auth/profile/birth":
            user_id = self._current_user_id(body, {})
            if user_id is None:
                return
            user = store.ensure_user(user_id)
            birthday = str(body.get("birthday") or "")
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", birthday):
                self._json(400, fail("40001", "birthday must be YYYY-MM-DD"))
                return
            try:
                birthday_date = datetime.strptime(birthday, "%Y-%m-%d").date()
            except ValueError:
                self._json(400, fail("40001", "birthday must be a valid date"))
                return
            if birthday_date > datetime.now(timezone.utc).date():
                self._json(400, fail("40001", "birthday cannot be in the future"))
                return
            user["birthday"] = birthday
            store.save()
            self._json(200, ok({"profile": user}))
        else:
            self._json(404, fail("40401", f"Auth route not implemented: {route}"))

    def _billing(self, method: str, route: str, query: dict[str, str], body: dict[str, Any]) -> None:
        route = route.replace("/credit/", "/billing/", 1)
        if method == "POST" and route == "/billing/order/callback":
            order_id = non_empty_string(body.get("orderId"), "orderId", max_length=80)
            callback_status = choice(body.get("status"), "status", {"paid", "failed", "refunded"})
            signature = non_empty_string(body.get("signature"), "signature", max_length=128)
            if self._validation_failed(order_id, callback_status, signature):
                return
            expected = self._payment_signature(order_id, callback_status)
            if not hmac.compare_digest(signature, expected):
                self._json(403, fail("40301", "Invalid payment callback signature"))
                return
            order = store.billing_orders.get(order_id)
            if not order:
                self._json(404, fail("40401", "Order not found"))
                return
            account = store.ensure_account(str(order.get("userId")))
            if callback_status == "paid":
                self._mark_order_paid(order, account)
            elif callback_status == "failed":
                if order.get("status") not in {"paid", "refunded"}:
                    order["status"] = "failed"
                    order["updatedAt"] = now_iso()
            elif callback_status == "refunded":
                order["status"] = "refunded"
                order["refundedAt"] = now_iso()
                order["updatedAt"] = now_iso()
                self._reconcile_vip_after_refund(account)
            order["lastCallbackAt"] = now_iso()
            store.save()
            self._json(200, ok({"order": order, "account": account}))
            return
        user_id = self._current_user_id(body, query)
        if user_id is None:
            return
        account = store.ensure_account(user_id)
        if method == "GET" and route == "/billing/plans":
            self._json(200, ok({"plans": BILLING_PLANS}))
            return
        if method == "POST" and route == "/billing/order/create":
            plan_ids = {item["id"] for item in BILLING_PLANS}
            plan_id = choice(body.get("planId"), "planId", plan_ids)
            if self._validation_failed(plan_id):
                return
            idempotency_key = self.headers.get("Idempotency-Key", "").strip()
            if idempotency_key:
                existing = next(
                    (
                        order
                        for order in store.billing_orders.values()
                        if order.get("userId") == user_id
                        and order.get("idempotencyKey") == idempotency_key
                    ),
                    None,
                )
                if existing:
                    self._json(200, ok({"order": existing, "created": False}))
                    return
            plan = next(item for item in BILLING_PLANS if item["id"] == plan_id)
            order = {
                "orderId": f"ord_{uuid.uuid4().hex[:10]}",
                "userId": user_id,
                "planId": plan_id,
                "status": "created",
                "amountCents": plan["priceCents"],
                "currency": plan["currency"],
                "idempotencyKey": idempotency_key,
                "createdAt": now_iso(),
                "updatedAt": now_iso(),
            }
            store.billing_orders[order["orderId"]] = order
            store.save()
            self._json(200, ok({"order": order, "created": True}))
            return
        if method == "POST" and route == "/billing/order/confirm":
            order_id = non_empty_string(body.get("orderId"), "orderId", max_length=80)
            payment_result = choice(body.get("paymentResult") or "success", "paymentResult", {"success", "failed"})
            if self._validation_failed(order_id, payment_result):
                return
            order = store.billing_orders.get(order_id)
            if not order:
                self._json(404, fail("40401", "Order not found"))
                return
            if order.get("userId") != user_id:
                self._json(403, fail("40301", "Order does not belong to current user"))
                return
            if order.get("status") == "paid":
                self._json(200, ok({"order": order, "account": account}))
                return
            if order.get("status") not in {"created", "paying"}:
                self._json(409, fail("40901", "Order state invalid"))
                return
            if payment_result == "failed":
                order["status"] = "failed"
                order["updatedAt"] = now_iso()
                store.save()
                self._json(200, ok({"order": order, "account": account}))
                return
            self._mark_order_paid(order, account)
            store.save()
            self._json(200, ok({"order": order, "account": account}))
            return
        if method == "GET" and re.fullmatch(r"/billing/order/[^/]+", route):
            order_id = route.rsplit("/", 1)[-1]
            order = store.billing_orders.get(order_id)
            if not order:
                self._json(404, fail("40401", "Order not found"))
                return
            if order.get("userId") != user_id:
                self._json(403, fail("40301", "Order does not belong to current user"))
                return
            self._json(200, ok({"order": order}))
            return
        if method == "GET" and route == "/billing/account":
            self._json(200, ok({"account": account}))
            return
        if method == "POST" and route == "/billing/account/init":
            store.save()
            self._json(200, ok({"account": account}))
            return
        if method == "POST" and route == "/billing/consume":
            ctype = choice(body.get("type") or "cast", "type", {"cast", "followup"})
            amount = parse_int(body.get("amount"), 1)
            if self._validation_failed(ctype):
                return
            if amount != 1:
                self._json(400, fail("40001", "amount must be 1"))
                return
            consumed = self._consume_credit(user_id, ctype, body.get("sessionId"))
            if consumed is None:
                return
            self._json(200, ok({"account": consumed}))
            return
        elif method == "POST" and route == "/billing/reset":
            account["castBalance"] = 2 if account.get("isVip") else 1
            account["followupBalance"] = 4 if account.get("isVip") else 1
            account["lastResetDate"] = now_iso()
        elif method == "POST" and route == "/billing/checkin":
            account["castBalance"] += 1
            account["lastCheckinDate"] = now_iso()
        elif method == "POST" and route == "/billing/reward":
            account["followupBalance"] += 1
        elif method == "POST" and route in {"/billing/purchase/cast", "/billing/purchase/followup"}:
            amount = parse_int(body.get("amount"), 1)
            key = "castBalance" if route.endswith("/cast") else "followupBalance"
            account[key] += amount
        elif method == "POST" and route == "/billing/subscribe":
            account["isVip"] = True
        else:
            self._json(404, fail("40401", f"Billing route not implemented: {route}"))
            return
        store.save()
        self._json(200, ok({"account": account}))

    def _payment_signature(self, order_id: str, status: str) -> str:
        message = f"{order_id}:{status}".encode("utf-8")
        return hmac.new(PAYMENT_CALLBACK_SECRET.encode("utf-8"), message, hashlib.sha256).hexdigest()

    def _mark_order_paid(self, order: dict[str, Any], account: dict[str, Any]) -> None:
        if order.get("status") == "paid":
            return
        plan = next(item for item in BILLING_PLANS if item["id"] == order["planId"])
        order["status"] = "paid"
        order["paidAt"] = now_iso()
        order["updatedAt"] = now_iso()
        account["isVip"] = True
        account["vipExpireDate"] = (datetime.now(timezone.utc) + timedelta(days=int(plan["days"]))).isoformat().replace("+00:00", "Z")
        account["castBalance"] = max(int(account.get("castBalance", 0)), 2)
        account["followupBalance"] = max(int(account.get("followupBalance", 0)), 4)

    def _reconcile_vip_after_refund(self, account: dict[str, Any]) -> None:
        user_id = str(account.get("userId"))
        has_paid_order = any(
            order.get("userId") == user_id and order.get("status") == "paid"
            for order in store.billing_orders.values()
        )
        if not has_paid_order:
            account["isVip"] = False
            account["vipExpireDate"] = None

    def _consume_credit(self, user_id: str, credit_type: str, session_id: Any = None) -> dict[str, Any] | None:
        account = store.ensure_account(user_id)
        key = "followupBalance" if credit_type == "followup" else "castBalance"
        amount = 1
        idempotency_key = self.headers.get("Idempotency-Key", "").strip()
        if idempotency_key:
            existing = store.credit_consumptions.get(idempotency_key)
            if existing:
                return account
        if int(account.get(key, 0)) < amount:
            self._json(409, fail("40901", f"Insufficient {credit_type} balance"))
            return None
        account[key] = int(account.get(key, 0)) - amount
        if idempotency_key:
            store.credit_consumptions[idempotency_key] = {
                "userId": user_id,
                "type": credit_type,
                "sessionId": session_id,
                "amount": amount,
                "createdAt": now_iso(),
            }
        store.save()
        return account

    def _profile(self, method: str, route: str, query: dict[str, str], body: dict[str, Any]) -> None:
        user_id = self._current_user_id(body, query)
        if user_id is None:
            return
        profile = store.ensure_user(user_id)
        settings = store.profile_settings.setdefault(user_id, store.default_settings())
        if method == "GET" and route == "/profile/me":
            self._json(200, ok({"profile": profile, "settings": settings}))
        elif method == "PUT" and route == "/profile/me":
            allowed = {"username", "bio", "city", "gender", "birthday", "avatarUrl", "coverUrl"}
            if "username" in body:
                username = non_empty_string(body.get("username"), "username", max_length=40)
                if self._validation_failed(username):
                    return
                body["username"] = username
            if "bio" in body:
                bio = optional_string(body.get("bio"), "bio", max_length=160)
                if self._validation_failed(bio):
                    return
                body["bio"] = bio
            if "gender" in body and body.get("gender") is not None:
                gender = choice(body.get("gender"), "gender", {"male", "female", "not_disclosed"})
                if self._validation_failed(gender):
                    return
                body["gender"] = gender
            if "birthday" in body and body.get("birthday") is not None:
                birthday = str(body.get("birthday") or "")
                if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", birthday):
                    self._json(400, fail("40001", "birthday must be YYYY-MM-DD"))
                    return
                try:
                    birthday_date = datetime.strptime(birthday, "%Y-%m-%d").date()
                except ValueError:
                    self._json(400, fail("40001", "birthday must be a valid date"))
                    return
                if birthday_date > datetime.now(timezone.utc).date():
                    self._json(400, fail("40001", "birthday cannot be in the future"))
                    return
            for key in allowed:
                if key in body:
                    profile[key] = body[key]
            store.save()
            self._json(200, ok({"profile": profile, "settings": settings}))
        elif method == "POST" and route == "/profile/me/avatar":
            uploaded = self._upload_payload(body, "avatar")
            if uploaded is None:
                return
            profile["avatarUrl"] = uploaded["url"]
            store.save()
            self._json(200, ok({"avatarUrl": profile["avatarUrl"], "media": uploaded}))
        elif method == "POST" and route == "/profile/me/cover":
            uploaded = self._upload_payload(body, "cover")
            if uploaded is None:
                return
            profile["coverUrl"] = uploaded["url"]
            store.save()
            self._json(200, ok({"coverUrl": profile["coverUrl"], "media": uploaded}))
        elif method == "PUT" and route == "/profile/me/settings":
            settings.update({k: bool(v) for k, v in body.items() if k in settings})
            store.save()
            self._json(200, ok({"settings": settings}))
        elif method == "GET" and route == "/profile/me/share-card":
            self._json(200, ok({"shareUrl": f"https://orbit.local/u/{profile['shortId']}", "shareImageUrl": None}))
        elif method == "GET" and route == "/profile/me/checkin-calendar":
            calendar = self._checkin_calendar(user_id, query.get("month"))
            self._json(200, ok(calendar))
        elif method == "POST" and route == "/profile/me/checkin":
            calendar = self._checkin_calendar(user_id, None)
            today = datetime.now().day
            if today not in calendar["checkedDays"]:
                calendar["checkedDays"].append(today)
                calendar["checkedDays"].sort()
            calendar["hasCheckedInToday"] = True
            calendar["streak"] = self._streak(calendar["checkedDays"])
            store.checkins[user_id] = calendar
            account = store.ensure_account(user_id)
            account["castBalance"] += 1
            store.save()
            self._json(200, ok(calendar))
        elif method == "GET" and route == "/profile/me/tag-identity":
            self._json(200, ok(self._latest_tag_profile()))
        elif method == "GET" and route == "/profile/me/tag-timeline":
            entries = self._all_tag_timeline()
            self._json(200, ok(self._page(entries, query)))
        elif method == "GET" and route in {"/profile/me/interactions", "/profile/me/browse"}:
            items = self._profile_browse_history(user_id) if route.endswith("browse") else self._profile_interactions(user_id)
            self._json(200, ok(self._page(items, query)))
        elif method == "POST" and route == "/profile/me/delete-cancel":
            scheduled = store.deleted_accounts.pop(user_id, None)
            store.save()
            self._json(200, ok({"cancelled": bool(scheduled)}))
        elif method == "DELETE" and route == "/profile/me":
            if body.get("confirmText") != "注销":
                self._json(400, fail("40001", "confirmText must be 注销"))
                return
            store.deleted_accounts[user_id] = {
                "userId": user_id,
                "confirmText": body.get("confirmText"),
                "coolingOffDays": parse_int(body.get("coolingOffDays"), 7),
                "scheduledAt": now_iso(),
            }
            store.save()
            self._json(200, ok({"scheduled": True, "coolingOffDays": store.deleted_accounts[user_id]["coolingOffDays"]}))
        else:
            self._json(404, fail("40401", f"Profile route not implemented: {route}"))

    def _notifications(self, method: str, route: str, query: dict[str, str], body: dict[str, Any]) -> None:
        user_id = self._current_user_id(body, query)
        if user_id is None:
            return
        messages = store.notifications.setdefault(user_id, [])
        if method == "GET" and route == "/notifications":
            visible = self._filter_notifications(messages, query)
            paged = self._page(visible, query)
            payload = {
                "messages": paged["items"],
                "hasMore": paged["hasMore"],
                "nextPage": paged["nextPage"],
                "unreadCount": self._unread_count(messages),
                "count": self._unread_count(messages),
                "filters": {"type": query.get("type") or "all", "read": query.get("read") or "all"},
            }
            self._json(200, ok(payload))
        elif method == "GET" and route == "/notifications/unread-count":
            self._json(200, ok({"count": self._unread_count(messages), "unreadCount": self._unread_count(messages)}))
        elif method == "GET" and route == "/notifications/ui-polish":
            self._json(
                200,
                ok(
                    {
                        "actions": {
                            "markAllRead": True,
                            "swipeDismiss": True,
                            "tapForDetail": True,
                            "pullToRefresh": True,
                        },
                        "emptyStates": {
                            "all": "No messages yet.",
                            "filter": "No messages match this filter.",
                            "dismissed": "Dismissed messages are hidden from the center.",
                        },
                        "filters": ["all", "system", "interaction", "activity", "browse"],
                    }
                ),
            )
        elif method == "GET" and re.fullmatch(r"/notifications/[^/]+", route):
            notif_id = route.split("/")[2]
            item = self._find_notification(messages, notif_id)
            if not item:
                self._json(404, fail("40401", "Notification not found"))
                return
            self._json(200, ok({"message": item}))
        elif method == "POST" and route == "/notifications/read-all":
            for item in messages:
                item["read"] = True
            store.save()
            self._json(200, ok({"updated": True, "unreadCount": self._unread_count(messages)}))
        elif method == "POST" and re.fullmatch(r"/notifications/[^/]+/read", route):
            notif_id = route.split("/")[2]
            item = self._find_notification(messages, notif_id)
            if not item:
                self._json(404, fail("40401", "Notification not found"))
                return
            item["read"] = True
            store.save()
            self._json(200, ok({"updated": True, "unreadCount": self._unread_count(messages)}))
        elif (method == "POST" and re.fullmatch(r"/notifications/[^/]+/dismiss", route)) or (
            method == "DELETE" and re.fullmatch(r"/notifications/[^/]+", route) and route != "/notifications/token"
        ):
            notif_id = route.split("/")[2]
            item = self._find_notification(messages, notif_id)
            if not item:
                self._json(404, fail("40401", "Notification not found"))
                return
            item["dismissed"] = True
            store.save()
            self._json(200, ok({"dismissed": True, "unreadCount": self._unread_count(messages)}))
        elif method == "PUT" and route == "/notifications/state":
            read_ids = set(body.get("readIds") or [])
            dismissed_ids = set(body.get("dismissedIds") or [])
            for item in messages:
                if item["id"] in read_ids:
                    item["read"] = True
                if item["id"] in dismissed_ids:
                    item["dismissed"] = True
            store.save()
            self._json(200, ok({"synced": True, "unreadCount": self._unread_count(messages)}))
        elif method == "POST" and route == "/notifications/token":
            token = non_empty_string(body.get("token"), "token", max_length=512)
            platform = choice(body.get("platform"), "platform", {"android", "ios", "web"})
            if self._validation_failed(token, platform):
                return
            records = store.notification_tokens.setdefault(user_id, [])
            existing = next((item for item in records if item.get("token") == token), None)
            record = {"token": token, "platform": platform, "registeredAt": now_iso(), "active": True}
            if existing:
                existing.update(record)
            else:
                records.append(record)
            store.save()
            self._json(200, ok({"registered": True, "token": record}))
        elif method == "DELETE" and route == "/notifications/token":
            token = str(body.get("token") or "")
            records = store.notification_tokens.setdefault(user_id, [])
            for item in records:
                if not token or item.get("token") == token:
                    item["active"] = False
                    item["unregisteredAt"] = now_iso()
            store.save()
            self._json(200, ok({"registered": False}))
        elif (method == "DELETE" and route == "/notifications/clear") or (
            method == "POST" and route == "/notifications/clear"
        ):
            store.notifications[user_id] = []
            store.save()
            self._json(200, ok({"cleared": True, "unreadCount": 0, "count": 0}))
        else:
            self._json(404, fail("40401", f"Notification route not implemented: {route}"))

    def _feed(self, method: str, route: str, query: dict[str, str], body: dict[str, Any]) -> None:
        if method == "GET" and route in {"/feed/recommend", "/feed/mine"}:
            user_id = self._current_user_id(body, query, require=False)
            items = self._visible_feed(user_id or "user_demo")
            if route == "/feed/mine":
                items = [item for item in items if item.get("authorId") == (user_id or "user_demo")]
            self._json(200, ok(self._page(items, query)))
        elif method == "POST" and route == "/feed/publish":
            user_id = self._current_user_id(body, query)
            if user_id is None:
                return
            body.setdefault("authorId", user_id)
            item = self._make_feed_item(body)
            store.feed.insert(0, item)
            self._notify(item["authorId"], "interaction", "New post published", item.get("shareText") or "A share card was published.", "feed", item["id"])
            store.save()
            self._json(200, ok(item))
        elif method == "POST" and re.fullmatch(r"/feed/[^/]+/(like|unlike|favorite|unfavorite|report|view)", route):
            user_id = self._current_user_id(body, query, require=False) or "user_demo"
            self._mutate_feed_action(route, user_id=user_id, detail=body)
            store.save()
            self._json(200, ok({"accepted": True}))
        else:
            self._json(404, fail("40401", f"Feed route not implemented: {route}"))

    def _activities(self, method: str, route: str, query: dict[str, str], body: dict[str, Any]) -> None:
        normalized = route.replace("/activity/list", "/activities", 1)
        normalized = normalized.replace("/activity/", "/activities/", 1)
        if method == "GET" and normalized == "/activities":
            user_id = self._current_user_id(body, query, require=False) or "user_demo"
            activities = list(store.activities.values())
            status_filter = query.get("status")
            tag_filter = query.get("tag")
            if status_filter:
                activities = [item for item in activities if item.get("status") == status_filter]
            if tag_filter:
                activities = [item for item in activities if tag_filter in item.get("tags", [])]
            activities = [self._activity_view(item, user_id) for item in activities]
            self._json(200, ok({**self._page(activities, query), "activities": activities}))
        elif method == "GET" and re.fullmatch(r"/activities/[^/]+", normalized):
            user_id = self._current_user_id(body, query, require=False) or "user_demo"
            activity = store.activities.get(normalized.rsplit("/", 1)[-1])
            if not activity:
                self._json(404, fail("40401", "Activity not found"))
                return
            self._json(200, ok(self._activity_view(activity, user_id)))
        elif method == "POST" and re.fullmatch(r"/activities/[^/]+/join", normalized):
            user_id = self._current_user_id(body, {})
            if user_id is None:
                return
            activity_id = normalized.split("/")[2]
            activity = store.activities.get(activity_id)
            if not activity:
                self._json(404, fail("40401", "Activity not found"))
                return
            joined_users = set(activity.get("joinedUsers") or [])
            if user_id not in joined_users:
                activity["participantCount"] += 1
                joined_users.add(user_id)
            activity["joinedUsers"] = sorted(joined_users)
            activity["joinStatusByUser"] = {**(activity.get("joinStatusByUser") or {}), user_id: "approved"}
            self._notify(user_id, "activity", "Activity joined", activity["title"], "activity", activity_id)
            store.save()
            self._json(200, ok(self._activity_view(activity, user_id)))
        elif method == "GET" and re.fullmatch(r"/activities/[^/]+/join-status", normalized):
            user_id = self._current_user_id(body, query)
            if user_id is None:
                return
            activity = store.activities.get(normalized.split("/")[2])
            if not activity:
                self._json(404, fail("40401", "Activity not found"))
                return
            self._json(200, ok({"joinStatus": self._activity_view(activity, user_id).get("joinStatus", "none")}))
        elif method == "POST" and re.fullmatch(r"/activities/[^/]+/submit", normalized):
            user_id = self._current_user_id(body, {})
            if user_id is None:
                return
            activity_id = normalized.split("/")[2]
            activity = store.activities.get(activity_id)
            if not activity:
                self._json(404, fail("40401", "Activity not found"))
                return
            post_id = non_empty_string(body.get("postId"), "postId", max_length=80)
            tag = optional_string(body.get("tag") or "#cold_joke", "tag", max_length=80)
            if self._validation_failed(post_id, tag):
                return
            submissions = store.activity_submissions.setdefault(activity_id, [])
            idempotency_key = self.headers.get("Idempotency-Key")
            existing = next(
                (
                    item
                    for item in submissions
                    if item.get("postId") == post_id
                    or (idempotency_key and item.get("idempotencyKey") == idempotency_key)
                ),
                None,
            )
            if existing:
                self._json(200, ok({"submission": existing, "created": False}))
                return
            submission = {
                "id": f"sub_{uuid.uuid4().hex[:8]}",
                "activityId": activity_id,
                "postId": post_id,
                "tag": tag,
                "userId": user_id,
                "idempotencyKey": idempotency_key,
                "createdAt": now_iso(),
            }
            submissions.append(submission)
            activity["submissionCount"] = len(submissions)
            store.save()
            self._json(200, ok({"submission": submission, "created": True}))
        elif method == "GET" and re.fullmatch(r"/activities/[^/]+/leaderboard", normalized):
            activity_id = normalized.split("/")[2]
            if activity_id not in store.activities:
                self._json(404, fail("40401", "Activity not found"))
                return
            self._json(200, ok(self._leaderboard(activity_id, query)))
        elif method == "GET" and re.fullmatch(r"/activities/[^/]+/tag-distribution", normalized):
            activity_id = normalized.split("/")[2]
            if activity_id not in store.activities:
                self._json(404, fail("40401", "Activity not found"))
                return
            self._json(200, ok(self._tag_distribution(activity_id, query)))
        else:
            self._json(404, fail("40401", f"Activity route not implemented: {route}"))

    def _community(self, method: str, route: str, query: dict[str, str], body: dict[str, Any]) -> None:
        if method == "GET" and route in {"/community/feed", "/community/feed/by-tag", "/community/tag-feed"}:
            user_id = self._current_user_id(body, query, require=False) or "user_demo"
            tag = query.get("tag")
            tab = query.get("tab") or "recommended"
            if route == "/community/feed" and tab not in {"recommended", "deep"}:
                self._json(400, fail("40001", "Invalid community feed tab"))
                return
            feed = self._visible_feed(user_id)
            items = [item for item in feed if not tag or tag in json.dumps(item, ensure_ascii=False)]
            if route == "/community/feed":
                items = self._community_tab_items(items or feed, tab)
            payload = self._page(items or feed, query)
            payload["tab"] = tab
            self._json(200, ok(payload))
        elif method == "GET" and re.fullmatch(r"/community/post/[^/]+", route):
            post_id = route.rsplit("/", 1)[-1]
            post = self._find_post(post_id)
            if not post:
                self._json(404, fail("40401", "Post not found"))
                return
            self._json(200, ok({"post": post, "related": store.feed[:3]}))
        elif method == "GET" and re.fullmatch(r"/community/post/[^/]+/comments", route):
            post_id = route.split("/")[3]
            if not self._find_post(post_id):
                self._json(404, fail("40401", "Post not found"))
                return
            self._json(200, ok(self._page(store.comments.get(post_id, []), query)))
        elif method == "POST" and re.fullmatch(r"/community/post/[^/]+/comments", route):
            user_id = self._current_user_id(body, query)
            if user_id is None:
                return
            if self._rate_limited(user_id, "community_comment", 20):
                return
            text = non_empty_string(body.get("text"), "text", max_length=500)
            if self._validation_failed(text):
                return
            user = store.ensure_user(user_id)
            post_id = route.split("/")[3]
            post = self._find_post(post_id)
            if not post:
                self._json(404, fail("40401", "Post not found"))
                return
            idempotency_key = self.headers.get("Idempotency-Key", "").strip()
            comments = store.comments.setdefault(post_id, [])
            if idempotency_key:
                existing = next(
                    (
                        item
                        for item in comments
                        if item.get("authorId") == user_id
                        and item.get("idempotencyKey") == idempotency_key
                    ),
                    None,
                )
                if existing:
                    self._json(200, ok({"comment": existing, "created": False}))
                    return
            comment = {
                "id": f"c_{uuid.uuid4().hex[:8]}",
                "postId": post_id,
                "authorId": user_id,
                "authorUsername": body.get("authorUsername") or user.get("username") or "Guest",
                "authorAvatarUrl": body.get("authorAvatarUrl") or user.get("avatarUrl"),
                "text": text,
                "idempotencyKey": idempotency_key,
                "createdAt": now_iso(),
            }
            comments.append(comment)
            post.setdefault("metrics", {}).setdefault("comments", 0)
            post["metrics"]["comments"] += 1
            store.save()
            self._json(200, ok({"comment": comment, "created": True}))
        elif method == "POST" and route == "/community/post":
            card_id = non_empty_string(body.get("cardId") or body.get("card_id"), "cardId", max_length=80)
            share_text = optional_string(body.get("shareText") or body.get("text"), "shareText", max_length=1000)
            if self._validation_failed(card_id, share_text):
                return
            body["cardId"] = card_id
            if share_text is not None:
                body["shareText"] = share_text
            user_id = self._current_user_id(body, query)
            if user_id is None:
                return
            if self._rate_limited(user_id, "community_publish", 10):
                return
            idempotency_key = self.headers.get("Idempotency-Key", "").strip()
            if idempotency_key:
                existing = next(
                    (
                        item
                        for item in store.feed
                        if item.get("authorId") == user_id
                        and item.get("idempotencyKey") == idempotency_key
                    ),
                    None,
                )
                if existing:
                    self._json(200, ok({"post": existing, "postId": existing["id"], "created": False}))
                    return
            body.setdefault("authorId", user_id)
            body["idempotencyKey"] = idempotency_key
            item = self._make_feed_item(body)
            store.feed.insert(0, item)
            store.save()
            self._json(200, ok({"post": item, "postId": item["id"], "created": True}))
        elif method == "POST" and route == "/community/media/upload":
            user_id = self._current_user_id(body, query)
            if user_id is None:
                return
            uploaded = self._upload_payload(body, "community")
            if uploaded is None:
                return
            self._json(200, ok(uploaded))
        elif method == "POST" and re.fullmatch(r"/community/post/[^/]+/(like|unlike|favorite|unfavorite|report|hide)", route):
            user_id = self._current_user_id(body, query)
            if user_id is None:
                return
            if self._rate_limited(user_id, "community_action", 60):
                return
            if route.endswith("/report"):
                reason = choice(body.get("reason") or "other", "reason", {"porn", "spam", "abuse", "other"})
                detail_text = optional_string(body.get("detail"), "detail", max_length=500)
                if self._validation_failed(reason, detail_text):
                    return
                body["reason"] = reason
                body["detail"] = detail_text
            post_id = route.split("/")[3]
            if not self._find_post(post_id):
                self._json(404, fail("40401", "Post not found"))
                return
            self._mutate_feed_action(route.replace("/community/post", "/feed"), user_id=user_id, detail=body)
            store.save()
            self._json(200, ok({"accepted": True}))
        elif method == "GET" and re.fullmatch(r"/community/author/[^/]+", route):
            viewer_id = self._current_user_id(body, query, require=False) or "user_demo"
            author_id = route.rsplit("/", 1)[-1]
            author = self._community_author_profile(author_id, viewer_id)
            if not author:
                self._json(404, fail("40401", "Author not found"))
                return
            self._json(200, ok({"author": author}))
        elif method == "POST" and re.fullmatch(r"/community/author/[^/]+/(follow|unfollow|block|unblock)", route):
            user_id = self._current_user_id(body, query)
            if user_id is None:
                return
            if self._rate_limited(user_id, "community_action", 60):
                return
            author_id = route.split("/")[3]
            action = route.split("/")[4]
            state = self._community_state(user_id)
            if action == "follow":
                state["followedAuthors"].add(author_id)
                self._record_author_interaction(state, "follow", author_id)
            elif action == "unfollow":
                state["followedAuthors"].discard(author_id)
                self._record_author_interaction(state, "unfollow", author_id)
            elif action == "block":
                state["blockedAuthors"].add(author_id)
                self._record_author_interaction(state, "block", author_id)
            elif action == "unblock":
                state["blockedAuthors"].discard(author_id)
                self._record_author_interaction(state, "unblock", author_id)
            self._save_community_state(user_id, state)
            store.save()
            self._json(200, ok({"accepted": True, "authorId": author_id, "action": action}))
        elif method == "GET" and route == "/community/search":
            user_id = self._current_user_id(body, query, require=False) or "user_demo"
            q = (query.get("q") or "").lower()
            search_type = query.get("type") or "all"
            if search_type not in {"all", "post", "user", "activity"}:
                self._json(400, fail("40001", "Invalid search type"))
                return
            posts = [item for item in self._visible_feed(user_id) if q in json.dumps(item, ensure_ascii=False).lower()]
            users = [user for user in store.users.values() if q in json.dumps(user, ensure_ascii=False).lower()]
            activities = [item for item in store.activities.values() if q in json.dumps(item, ensure_ascii=False).lower()]
            if search_type == "post":
                payload = self._page(posts, query)
            elif search_type == "user":
                payload = self._page(users, query)
            elif search_type == "activity":
                payload = self._page(activities, query)
            else:
                mixed = [{"type": "post", **item} for item in posts]
                mixed.extend({"type": "user", **item} for item in users)
                mixed.extend({"type": "activity", **item} for item in activities)
                payload = self._page(mixed, query)
            self._json(
                200,
                ok(
                    {
                        **payload,
                        "type": search_type,
                        "posts": posts,
                        "users": users,
                        "activities": activities,
                        "query": query.get("q") or "",
                    }
                ),
            )
        elif method == "GET" and route == "/community/tag-feed":
            tag = query.get("tag") or "reflection"
            items = [item for item in store.feed if tag in json.dumps(item)]
            self._json(200, ok({"tag": tag, "items": items or store.feed, "hasMore": False, "nextPage": 2}))
        elif method == "POST" and route in {"/community/tag-subscribe", "/community/tags/subscribe"}:
            user_id = self._current_user_id(body, query)
            if user_id is None:
                return
            if self._rate_limited(user_id, "community_action", 60):
                return
            tag = str(body.get("tag") or "reflection")
            store.tag_subscriptions.setdefault(user_id, set()).add(tag)
            self._notify(user_id, "system", "Tag subscribed", f"You subscribed to {tag}.", "tag", tag)
            store.save()
            self._json(200, ok({"userId": user_id, "tag": tag, "subscribed": True}))
        else:
            self._json(404, fail("40401", f"Community route not implemented: {route}"))

    def _share(self, method: str, route: str, body: dict[str, Any]) -> None:
        if method == "POST" and route in {"/share/card/render", "/share/card/render-with-theme"}:
            card_id = str(body.get("cardId") or f"card_{uuid.uuid4().hex[:8]}")
            text = optional_string(body.get("text"), "text", max_length=1200)
            theme = choice(body.get("theme") or "warm", "theme", {"warm", "cool", "dark"})
            if self._validation_failed(text, theme):
                return
            rendered = render_share_card(
                output_dir=SHARE_OUTPUT_DIR,
                card_id=card_id,
                theme=theme,
                text=text or "A quiet reflective note.",
                tag=str(body.get("tag") or "reflection"),
                hexagram_name=str(body.get("hexagramName") or body.get("hexagram") or "Reflection"),
            )
            rendered["imageUrl"] = self._absolute_url(f"/api/v1/static/share/{rendered['fileName']}")
            rendered["backgroundImageUrl"] = body.get("backgroundImageUrl")
            self._json(200, ok(rendered))
        elif method == "POST" and route == "/share/card/save":
            user_id = self._current_user_id(body, {})
            if user_id is None:
                return
            draft_id = str(body.get("cardId") or f"draft_{uuid.uuid4().hex[:8]}")
            idempotency_key = self.headers.get("Idempotency-Key", "").strip()
            if idempotency_key:
                existing = next(
                    (
                        draft
                        for draft in store.share_drafts.values()
                        if draft.get("userId") == user_id
                        and draft.get("idempotencyKey") == idempotency_key
                    ),
                    None,
                )
                if existing:
                    self._json(200, ok({"draftId": existing["cardId"], "draft": existing, "created": False}))
                    return
            text = optional_string(body.get("text"), "text", max_length=1200)
            theme = choice(body.get("theme") or "warm", "theme", {"warm", "cool", "dark"})
            if self._validation_failed(text, theme):
                return
            store.share_drafts[draft_id] = {
                **body,
                "cardId": draft_id,
                "userId": user_id,
                "theme": theme,
                "text": text,
                "idempotencyKey": idempotency_key,
                "updatedAt": now_iso(),
            }
            store.save()
            self._json(200, ok({"draftId": draft_id, "draft": store.share_drafts[draft_id], "created": True}))
        elif method == "POST" and route == "/share/community/publish":
            user_id = self._current_user_id(body, {})
            if user_id is None:
                return
            card_id = non_empty_string(body.get("cardId") or body.get("card_id"), "cardId", max_length=80)
            share_text = optional_string(body.get("shareText") or body.get("text"), "shareText", max_length=1000)
            if self._validation_failed(card_id, share_text):
                return
            body["cardId"] = card_id
            if share_text is not None:
                body["shareText"] = share_text
            if not self._card_exists(card_id):
                self._json(404, fail("40401", "Card not found"))
                return
            idempotency_key = self.headers.get("Idempotency-Key", "").strip()
            if idempotency_key:
                existing = next(
                    (
                        item
                        for item in store.feed
                        if item.get("authorId") == user_id
                        and item.get("idempotencyKey") == idempotency_key
                    ),
                    None,
                )
                if existing:
                    self._json(200, ok({"postId": existing["id"], "post": existing, "created": False}))
                    return
            body.setdefault("authorId", user_id)
            body["idempotencyKey"] = idempotency_key
            item = self._make_feed_item(body)
            store.feed.insert(0, item)
            store.save()
            self._json(200, ok({"postId": item["id"], "post": item, "created": True}))
        elif method == "POST" and route == "/share/external":
            channel = choice(body.get("channel") or "system", "channel", {"wechat", "moments", "system"})
            if self._validation_failed(channel):
                return
            payload = {
                "channel": channel,
                "title": body.get("title") or "Zhouyi Share Card",
                "text": body.get("text") or body.get("shareText") or "",
                "url": body.get("url") or "https://orbit.local/share/demo",
                "cardId": body.get("cardId"),
                "imageUrl": body.get("imageUrl"),
            }
            self._json(200, ok({"payload": payload, **payload}))
        else:
            self._json(404, fail("40401", f"Share route not implemented: {route}"))

    def _match(self, method: str, route: str, query: dict[str, str], body: dict[str, Any]) -> None:
        device_id = str(body.get("deviceId") or query.get("deviceId") or self.headers.get("X-Device-Id") or "device_demo")
        today = datetime.now().date().isoformat()
        key = f"{device_id}:{today}"
        if method == "POST" and route == "/match/unlock":
            unlock = store.match_unlocks.setdefault(
                key,
                {
                    "unlocked": True,
                    "unlockToken": f"unlock_{uuid.uuid4().hex[:8]}",
                    "deviceId": device_id,
                    "trigger": body.get("trigger") or "shake",
                    "signature": "101101",
                    "unlockedAt": now_iso(),
                },
            )
            store.save()
            self._json(200, ok(unlock))
        elif method == "GET" and route == "/match/radar/status":
            unlock = store.match_unlocks.get(key)
            self._json(200, ok(unlock or {"unlocked": False, "signature": "101101", "unlockedAt": None}))
        elif method == "GET" and route == "/match/same-frequency":
            unlock = store.match_unlocks.get(key)
            if not unlock or not unlock.get("unlocked"):
                self._json(403, fail("40301", "Match unlock required"))
                return
            tab = query.get("tab") or "users"
            if tab not in {"users", "history"}:
                self._json(400, fail("40001", "Invalid same-frequency tab"))
                return
            items = self._same_frequency_history() if tab == "history" else self._same_frequency_users()
            payload = self._page(items, query)
            payload["tab"] = tab
            payload["signature"] = "101101"
            self._json(200, ok(payload))
        else:
            self._json(404, fail("40401", f"Match route not implemented: {route}"))

    def _support(self, method: str, route: str, body: dict[str, Any]) -> None:
        if method == "GET" and route == "/support/faq":
            self._json(
                200,
                ok(
                    {
                        "items": [
                            {
                                "id": "faq_credit",
                                "title": "Daily quota",
                                "answer": "Normal accounts receive one cast and one follow-up quota each day; VIP accounts receive a larger daily quota.",
                            },
                            {
                                "id": "faq_reading",
                                "title": "Reading scope",
                                "answer": "Readings are reflective summaries and do not replace professional advice or guarantee outcomes.",
                            },
                            {
                                "id": "faq_privacy",
                                "title": "Privacy",
                                "answer": "Local development data is stored in SQLite under the backend data directory.",
                            },
                        ]
                    }
                ),
            )
        elif method == "GET" and re.fullmatch(r"/support/(ticket|feedback)/[^/]+", route):
            user_id = self._current_user_id({}, {})
            if user_id is None:
                return
            ticket_id = route.rsplit("/", 1)[-1]
            ticket = next((item for item in store.feedback_tickets if item.get("ticketId") == ticket_id), None)
            if not ticket:
                self._json(404, fail("40401", "Ticket not found"))
                return
            if ticket.get("userId") != user_id:
                self._json(403, fail("40301", "Ticket does not belong to current user"))
                return
            self._json(200, ok({"ticket": ticket}))
        elif method == "POST" and route == "/support/feedback":
            user_id = self._current_user_id(body, {})
            if user_id is None:
                return
            category = choice(body.get("category") or "other", "category", {"bug", "suggestion", "abuse", "other"})
            content = non_empty_string(body.get("content"), "content", max_length=2000)
            if self._validation_failed(category, content):
                return
            client = body.get("client") or {}
            if not isinstance(client, dict):
                self._json(400, fail("40001", "client must be an object"))
                return
            platform = client.get("platform")
            if platform is not None and platform not in {"android", "ios"}:
                self._json(400, fail("40001", "client.platform must be android or ios"))
                return
            today = datetime.now(timezone.utc).date().isoformat()
            submitted_today = [
                item
                for item in store.feedback_tickets
                if item.get("userId") == user_id
                and str(item.get("createdAt") or "")[:10] == today
            ]
            if len(submitted_today) >= 5:
                self._json(429, fail("42901", "Feedback rate limit exceeded"))
                return
            ticket = {
                "ticketId": f"t_{uuid.uuid4().hex[:8]}",
                "userId": user_id or "guest",
                "category": category,
                "content": content,
                "contact": body.get("contact"),
                "client": client,
                "status": "open",
                "createdAt": now_iso(),
            }
            store.feedback_tickets.append(ticket)
            store.save()
            self._json(200, ok(ticket))
        else:
            self._json(404, fail("40401", f"Support route not implemented: {route}"))

    def _media(self, method: str, route: str, body: dict[str, Any]) -> None:
        if method == "POST" and route == "/media/upload":
            user_id = self._current_user_id(body, {})
            if user_id is None:
                return
            uploaded = self._upload_payload(body, str(body.get("purpose") or "media"))
            if uploaded is None:
                return
            self._json(200, ok(uploaded))
        else:
            self._json(404, fail("40401", f"Media route not implemented: {route}"))

    def _upload_payload(self, body: dict[str, Any], purpose: str) -> dict[str, Any] | None:
        limits = {
            "avatar": 5 * 1024 * 1024,
            "cover": 10 * 1024 * 1024,
            "community": 10 * 1024 * 1024,
            "media": 10 * 1024 * 1024,
            "background": 10 * 1024 * 1024,
        }
        max_size = limits.get(purpose, limits["media"])
        content_type = str(body.get("_contentType") or self.headers.get("Content-Type") or "")
        is_multipart = content_type.lower().startswith("multipart/form-data")
        raw = str(body.get("_raw") or "")
        mime = str(body.get("mime") or body.get("contentType") or "")
        if is_multipart and not mime:
            match = re.search(r"Content-Type:\s*([^\r\n;]+)", raw, flags=re.IGNORECASE)
            mime = match.group(1).strip() if match else "image/jpeg"
        mime = mime or "image/jpeg"
        size = parse_int(body.get("size") or body.get("fileSize") or body.get("_contentLength"), 0)
        if mime not in ALLOWED_IMAGE_MIMES:
            self._json(400, fail("40001", "Unsupported image mime type"))
            return None
        if size <= 0:
            self._json(400, fail("40001", "file size is required"))
            return None
        if size > max_size:
            self._json(400, fail("40001", f"file size exceeds {max_size} bytes"))
            return None
        ext = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}[mime]
        width = parse_int(body.get("width"), 128 if purpose == "avatar" else 1200)
        height = parse_int(body.get("height"), 128 if purpose == "avatar" else 900)
        media_id = f"media_{uuid.uuid4().hex[:10]}"
        return {
            "id": media_id,
            "url": f"https://cdn.local/{purpose}/{media_id}.{ext}",
            "width": width,
            "height": height,
            "mime": mime,
            "size": size,
            "purpose": purpose,
            "createdAt": now_iso(),
        }

    def _knowledge(self, method: str, route: str, query: dict[str, str]) -> None:
        if method == "GET" and route == "/knowledge/health":
            snippets = KNOWLEDGE_BASE.search("", "reflection", limit=5)
            self._json(
                200,
                ok(
                    {
                        "root": str(KNOWLEDGE_DIR),
                        "available": KNOWLEDGE_DIR.exists(),
                        "sampleCount": len(snippets),
                        "sources": sorted({item.source for item in snippets}),
                    }
                ),
            )
        elif method == "GET" and route == "/knowledge/search":
            snippets = KNOWLEDGE_BASE.search(
                query.get("q") or "",
                query.get("tag") or "reflection",
                limit=parse_int(query.get("limit"), 5),
            )
            self._json(
                200,
                ok(
                    {
                        "items": [
                            {"source": item.source, "title": item.title, "excerpt": item.text}
                            for item in snippets
                        ]
                    }
                ),
            )
        else:
            self._json(404, fail("40401", f"Knowledge route not implemented: {route}"))

    def _page(self, items: list[dict[str, Any]], query: dict[str, str]) -> dict[str, Any]:
        page = max(1, parse_int(query.get("page"), 1))
        page_size = max(1, min(100, parse_int(query.get("pageSize"), 20)))
        start = (page - 1) * page_size
        end = start + page_size
        return {
            "items": items[start:end],
            "hasMore": end < len(items),
            "nextPage": page + 1,
        }

    def _find_post(self, post_id: str) -> dict[str, Any] | None:
        return next((item for item in store.feed if item.get("id") == post_id), None)

    def _card_exists(self, card_id: str) -> bool:
        if card_id in store.share_drafts:
            return True
        if any(item.get("cardId") == card_id or item.get("card", {}).get("id") == card_id for item in store.feed):
            return True
        return any(session.get("card", {}).get("id") == card_id for session in store.sessions.values())

    def _make_feed_item(self, body: dict[str, Any]) -> dict[str, Any]:
        card = store.feed[0]["card"] if store.feed else make_card("", "reflection", [1, 0, 1, 1, 0, 1], [], "fallback")
        card_id = str(body.get("cardId") or body.get("card_id") or card.get("id") or f"card_{uuid.uuid4().hex[:8]}")
        return {
            "id": f"feed_{uuid.uuid4().hex[:8]}",
            "cardId": card_id,
            "card": {**card, "id": card_id, "question": ""},
            "shareText": body.get("shareText") or body.get("text"),
            "coverImageUrl": body.get("coverImageUrl") or body.get("backgroundImageUrl"),
            "authorId": body.get("authorId") or "user_demo",
            "authorUsername": body.get("authorUsername") or "Orbit Demo",
            "authorHandle": body.get("authorHandle") or "orbit_demo",
            "authorAvatarUrl": body.get("authorAvatarUrl") or "",
            "createdAt": now_iso(),
            "status": "published",
            "metrics": {"likes": 0, "favorites": 0, "views": 0, "comments": 0, "reports": 0, "downvotes": 0},
            "viewerState": {"liked": False, "favorited": False, "followedAuthor": False},
            "idempotencyKey": body.get("idempotencyKey") or "",
        }

    def _mutate_feed_action(self, route: str, *, user_id: str, detail: dict[str, Any] | None = None) -> None:
        parts = route.strip("/").split("/")
        if len(parts) < 3:
            return
        post_id = parts[1]
        action = parts[2]
        post = self._find_post(post_id)
        if not post:
            return
        state = self._community_state(user_id)
        metrics = post.setdefault("metrics", {})
        viewer = post.setdefault("viewerState", {})
        if action == "like" and not viewer.get("liked"):
            metrics["likes"] = int(metrics.get("likes", 0)) + 1
            viewer["liked"] = True
            state["likedPosts"].add(post_id)
            self._record_interaction(state, "like", post)
        elif action == "unlike" and viewer.get("liked"):
            metrics["likes"] = max(0, int(metrics.get("likes", 0)) - 1)
            viewer["liked"] = False
            state["likedPosts"].discard(post_id)
        elif action == "favorite" and not viewer.get("favorited"):
            metrics["favorites"] = int(metrics.get("favorites", 0)) + 1
            viewer["favorited"] = True
            state["favoritedPosts"].add(post_id)
            self._record_interaction(state, "favorite", post)
        elif action == "unfavorite" and viewer.get("favorited"):
            metrics["favorites"] = max(0, int(metrics.get("favorites", 0)) - 1)
            viewer["favorited"] = False
            state["favoritedPosts"].discard(post_id)
        elif action == "report":
            reason = (detail or {}).get("reason") or "other"
            existing_report = any(
                item.get("postId") == post_id and item.get("reason") == reason
                for item in state["reports"]
            )
            if not existing_report:
                metrics["reports"] = int(metrics.get("reports", 0)) + 1
                state["reports"].append(
                    {
                        "postId": post_id,
                        "reason": reason,
                        "detail": (detail or {}).get("detail"),
                        "createdAt": now_iso(),
                    }
                )
                self._record_interaction(state, "report", post, {"reason": reason})
        elif action == "view":
            metrics["views"] = int(metrics.get("views", 0)) + 1
            self._record_browse(state, post)
        elif action == "hide":
            state["hiddenPosts"].add(post_id)
            self._record_interaction(state, "hide", post)
        self._save_community_state(user_id, state)

    def _community_state(self, user_id: str) -> dict[str, Any]:
        raw = store.community_state.setdefault(
            user_id,
            {
                "followedAuthors": [],
                "blockedAuthors": [],
                "hiddenPosts": [],
                "likedPosts": [],
                "favoritedPosts": [],
                "viewedPosts": [],
                "interactions": [],
                "reports": [],
            },
        )
        return {
            "followedAuthors": set(raw.get("followedAuthors") or []),
            "blockedAuthors": set(raw.get("blockedAuthors") or []),
            "hiddenPosts": set(raw.get("hiddenPosts") or []),
            "likedPosts": set(raw.get("likedPosts") or []),
            "favoritedPosts": set(raw.get("favoritedPosts") or []),
            "viewedPosts": list(raw.get("viewedPosts") or []),
            "interactions": list(raw.get("interactions") or []),
            "reports": list(raw.get("reports") or []),
        }

    def _save_community_state(self, user_id: str, state: dict[str, Any]) -> None:
        store.community_state[user_id] = {
            "followedAuthors": sorted(state.get("followedAuthors") or []),
            "blockedAuthors": sorted(state.get("blockedAuthors") or []),
            "hiddenPosts": sorted(state.get("hiddenPosts") or []),
            "likedPosts": sorted(state.get("likedPosts") or []),
            "favoritedPosts": sorted(state.get("favoritedPosts") or []),
            "viewedPosts": list(state.get("viewedPosts") or []),
            "interactions": list(state.get("interactions") or []),
            "reports": list(state.get("reports") or []),
        }

    def _record_interaction(
        self,
        state: dict[str, Any],
        action: str,
        post: dict[str, Any],
        extra: dict[str, Any] | None = None,
    ) -> None:
        post_id = str(post.get("id"))
        interactions = state.setdefault("interactions", [])
        if any(item.get("type") == action and item.get("postId") == post_id for item in interactions):
            return
        interactions.append(
            {
                "id": f"evt_{uuid.uuid4().hex[:8]}",
                "type": action,
                "postId": post_id,
                "summary": post.get("shareText") or post.get("card", {}).get("content", {}).get("summary"),
                "createdAt": now_iso(),
                **(extra or {}),
            }
        )

    def _record_author_interaction(self, state: dict[str, Any], action: str, author_id: str) -> None:
        state.setdefault("interactions", []).append(
            {
                "id": f"evt_{uuid.uuid4().hex[:8]}",
                "type": action,
                "authorId": author_id,
                "summary": f"{action} author {author_id}",
                "createdAt": now_iso(),
            }
        )

    def _record_browse(self, state: dict[str, Any], post: dict[str, Any]) -> None:
        post_id = str(post.get("id"))
        viewed = [item for item in state.setdefault("viewedPosts", []) if item.get("postId") != post_id]
        viewed.insert(
            0,
            {
                "id": f"browse_{uuid.uuid4().hex[:8]}",
                "type": "browse",
                "postId": post_id,
                "summary": post.get("shareText") or post.get("card", {}).get("content", {}).get("summary"),
                "createdAt": now_iso(),
            },
        )
        state["viewedPosts"] = viewed[:100]

    def _profile_interactions(self, user_id: str) -> list[dict[str, Any]]:
        state = self._community_state(user_id)
        items = list(state.get("interactions") or [])
        for item in store.feed:
            if item.get("authorId") == user_id:
                items.append(
                    {
                        "id": f"publish_{item['id']}",
                        "type": "publish",
                        "postId": item["id"],
                        "summary": item.get("shareText") or item.get("card", {}).get("content", {}).get("summary"),
                        "createdAt": item.get("createdAt"),
                    }
                )
        for comments in store.comments.values():
            for comment in comments:
                if comment.get("authorId") == user_id:
                    items.append(
                        {
                            "id": f"comment_{comment['id']}",
                            "type": "comment",
                            "postId": comment.get("postId"),
                            "summary": comment.get("text"),
                            "createdAt": comment.get("createdAt"),
                        }
                    )
        return sorted(items, key=lambda item: item.get("createdAt") or "", reverse=True)

    def _profile_browse_history(self, user_id: str) -> list[dict[str, Any]]:
        state = self._community_state(user_id)
        return sorted(
            list(state.get("viewedPosts") or []),
            key=lambda item: item.get("createdAt") or "",
            reverse=True,
        )

    def _community_tab_items(self, items: list[dict[str, Any]], tab: str) -> list[dict[str, Any]]:
        if tab == "deep":
            return sorted(
                items,
                key=lambda item: (
                    len(str(item.get("shareText") or "")),
                    int(item.get("metrics", {}).get("comments", 0)),
                    item.get("createdAt", ""),
                ),
                reverse=True,
            )
        return sorted(items, key=lambda item: item.get("createdAt", ""), reverse=True)

    def _community_author_profile(self, author_id: str, viewer_id: str) -> dict[str, Any] | None:
        posts = [item for item in store.feed if item.get("authorId") == author_id]
        user = store.users.get(author_id)
        if not user and not posts:
            return None
        latest_post = posts[0] if posts else {}
        state = self._community_state(viewer_id)
        follower_count = sum(
            1
            for raw in store.community_state.values()
            if author_id in set(raw.get("followedAuthors") or [])
        )
        profile = {
            "id": author_id,
            "username": (user or {}).get("username") or latest_post.get("authorUsername") or "Author",
            "handle": (user or {}).get("shortId") or latest_post.get("authorHandle") or author_id,
            "avatarUrl": (user or {}).get("avatarUrl") or latest_post.get("authorAvatarUrl"),
            "bio": (user or {}).get("bio"),
            "postCount": len(posts),
            "followerCount": follower_count,
            "metrics": {
                "posts": len(posts),
                "likes": sum(int(item.get("metrics", {}).get("likes", 0)) for item in posts),
                "favorites": sum(int(item.get("metrics", {}).get("favorites", 0)) for item in posts),
            },
            "viewerState": {
                "followed": author_id in state["followedAuthors"],
                "blocked": author_id in state["blockedAuthors"],
            },
            "recentPosts": posts[:5],
        }
        return profile

    def _visible_feed(self, user_id: str) -> list[dict[str, Any]]:
        state = self._community_state(user_id)
        blocked = state["blockedAuthors"]
        hidden = state["hiddenPosts"]
        followed = state["followedAuthors"]
        items: list[dict[str, Any]] = []
        for item in store.feed:
            if item.get("id") in hidden or item.get("authorId") in blocked:
                continue
            clone = json.loads(json.dumps(item, ensure_ascii=False))
            viewer = clone.setdefault("viewerState", {})
            viewer["followedAuthor"] = clone.get("authorId") in followed
            items.append(clone)
        return items

    def _notify(
        self,
        user_id: str,
        msg_type: str,
        title: str,
        body: str | None,
        target_type: str | None,
        target_id: str | None,
    ) -> None:
        store.notifications.setdefault(user_id, []).insert(
            0,
            {
                "id": f"notif_{uuid.uuid4().hex[:8]}",
                "type": msg_type,
                "title": title,
                "body": body,
                "data": {"targetId": target_id, "targetType": target_type},
                "createdAt": now_iso(),
                "read": False,
            },
        )

    def _filter_notifications(self, messages: list[dict[str, Any]], query: dict[str, str]) -> list[dict[str, Any]]:
        msg_type = query.get("type")
        read_filter = query.get("read")
        visible = [item for item in messages if not item.get("dismissed")]
        if msg_type and msg_type != "all":
            visible = [item for item in visible if item.get("type") == msg_type]
        if read_filter == "true":
            visible = [item for item in visible if item.get("read") is True]
        elif read_filter == "false":
            visible = [item for item in visible if item.get("read") is not True]
        return visible

    def _rate_limited(self, user_id: str, scope: str, daily_limit: int) -> bool:
        today = datetime.now(timezone.utc).date().isoformat()
        key = f"{user_id}:{scope}:{today}"
        entries = store.rate_limits.setdefault(key, [])
        if len(entries) >= daily_limit:
            self._json(429, fail("42901", "Rate limit exceeded"))
            return True
        entries.append(now_iso())
        store.save()
        return False

    def _find_notification(self, messages: list[dict[str, Any]], notif_id: str) -> dict[str, Any] | None:
        return next((item for item in messages if item.get("id") == notif_id and not item.get("dismissed")), None)

    def _unread_count(self, messages: list[dict[str, Any]]) -> int:
        return sum(1 for item in messages if not item.get("read") and not item.get("dismissed"))

    def _checkin_calendar(self, user_id: str, month: str | None) -> dict[str, Any]:
        key_month = month or datetime.now().strftime("%Y-%m")
        stored = store.checkins.get(user_id)
        if stored and stored.get("month") == key_month:
            return stored
        today = datetime.now()
        days = [2, 4, 5, 7, 10] if key_month != today.strftime("%Y-%m") else [2, 4, 5, 7, min(today.day, 10)]
        calendar = {
            "month": key_month,
            "checkedDays": sorted(set(days)),
            "streak": self._streak(days),
            "hasCheckedInToday": today.day in days and key_month == today.strftime("%Y-%m"),
        }
        store.checkins[user_id] = calendar
        return calendar

    def _streak(self, checked_days: list[int]) -> int:
        days = set(checked_days)
        cursor = datetime.now().day
        streak = 0
        while cursor in days:
            streak += 1
            cursor -= 1
        return streak

    def _latest_tag_profile(self) -> dict[str, Any]:
        sessions = sorted(store.sessions.values(), key=lambda item: item.get("createdAt", ""), reverse=True)
        if sessions:
            return sessions[0]["tagProfile"]
        return {
            "primaryTag": "reflection",
            "secondaryTags": ["clarity", "self_observation"],
            "explanation": "No ritual tag has been generated yet; this is the neutral default profile.",
            "source": "ritual",
            "createdAt": now_iso(),
        }

    def _all_tag_timeline(self) -> list[dict[str, Any]]:
        entries: list[dict[str, Any]] = []
        for session in store.sessions.values():
            entries.extend(session.get("timeline", []))
        return sorted(entries, key=lambda item: item.get("createdAt", ""), reverse=True)

    def _activity_view(self, activity: dict[str, Any] | None, user_id: str) -> dict[str, Any]:
        if not activity:
            return {}
        joined_users = set(activity.get("joinedUsers") or [])
        status_by_user = activity.get("joinStatusByUser") or {}
        joined = user_id in joined_users
        return {
            **activity,
            "joined": joined,
            "joinStatus": status_by_user.get(user_id) or ("approved" if joined else "none"),
        }

    def _activity_posts(self, activity_id: str, tag_filter: str | None) -> list[dict[str, Any]]:
        submissions = store.activity_submissions.get(activity_id, [])
        if tag_filter:
            submissions = [item for item in submissions if item.get("tag") == tag_filter]
        post_ids = {s.get("postId") for s in submissions if s.get("postId")}
        posts_by_id = {item.get("id"): item for item in store.feed}
        posts = [posts_by_id[post_id] for post_id in post_ids if post_id in posts_by_id]
        if tag_filter:
            for item in store.feed:
                haystack = json.dumps(item, ensure_ascii=False)
                if tag_filter in haystack and item.get("id") not in post_ids:
                    posts.append(item)
        return posts

    def _leaderboard(self, activity_id: str, query: dict[str, str]) -> dict[str, Any]:
        tag_filter = query.get("tag")
        posts = self._activity_posts(activity_id, tag_filter)
        ranked = sorted(posts, key=lambda item: int(item.get("metrics", {}).get("likes", 0)), reverse=True)
        page = self._page(ranked, query)
        like_king = None
        if ranked:
            top = ranked[0]
            like_king = {"postId": top["id"], "authorId": top.get("authorId"), "score": top.get("metrics", {}).get("likes", 0)}
        downvote_ranked = sorted(
            posts,
            key=lambda item: max(
                int(item.get("metrics", {}).get("downvotes", 0)),
                int(item.get("metrics", {}).get("reports", 0)),
            ),
            reverse=True,
        )
        downvote_king = None
        if downvote_ranked:
            top = downvote_ranked[0]
            metrics = top.get("metrics", {})
            downvote_king = {
                "postId": top["id"],
                "authorId": top.get("authorId"),
                "score": max(int(metrics.get("downvotes", 0)), int(metrics.get("reports", 0))),
            }
        return {
            "activityId": activity_id,
            "tag": tag_filter,
            "likeKing": like_king,
            "downvoteKing": downvote_king,
            "items": page["items"],
            "hasMore": page["hasMore"],
            "nextPage": page["nextPage"],
        }

    def _tag_distribution(self, activity_id: str, query: dict[str, str]) -> dict[str, Any]:
        submissions = store.activity_submissions.get(activity_id, [])
        tag_filter = query.get("tag")
        if tag_filter:
            submissions = [item for item in submissions if item.get("tag") == tag_filter]
        counts: dict[str, int] = {}
        for submission in submissions:
            tag = str(submission.get("tag") or "untagged")
            counts[tag] = counts.get(tag, 0) + 1
        if tag_filter:
            submitted_post_ids = {item.get("postId") for item in submissions}
            scanned_count = sum(
                1
                for item in self._activity_posts(activity_id, tag_filter)
                if item.get("id") not in submitted_post_ids
            )
            counts[tag_filter] = counts.get(tag_filter, 0) + scanned_count
            if not counts:
                counts[tag_filter] = 0
        elif not counts:
            for item in store.feed:
                tag = item.get("card", {}).get("tag") or "reflection"
                counts[tag] = counts.get(tag, 0) + 1
        total = sum(counts.values())
        return {
            "activityId": activity_id,
            "total": total,
            "items": [
                {"tag": tag, "count": count, "ratio": round(count / total, 4) if total else 0}
                for tag, count in sorted(counts.items())
            ],
        }

    def _same_frequency_users(self) -> list[dict[str, Any]]:
        return [
            {
                "id": "u_same_1",
                "name": "Ruowen",
                "role": "Reflective listener",
                "signature": "101101",
                "avatarUrl": None,
                "bio": "Keeps decisions readable and grounded.",
                "matchedReason": "Shared pace and boundary tag.",
            },
            {
                "id": "u_same_2",
                "name": "Kongshan",
                "role": "Quiet observer",
                "signature": "101101",
                "avatarUrl": None,
                "bio": "Looks for clarity before action.",
                "matchedReason": "Shared reflection signature.",
            },
        ]

    def _same_frequency_history(self) -> list[dict[str, Any]]:
        return [
            {
                "id": "h_1",
                "name": "Wang Yangming",
                "role": "Longchang insight",
                "quote": "A quiet mind makes the next step visible.",
                "imageUrl": None,
            }
        ]

    def _validation_failed(self, *values: Any) -> bool:
        for value in values:
            if isinstance(value, ValidationErrorInfo):
                self._json(400, {"success": False, "error": value.to_payload()})
                return True
        return False

    def _agreement_consent_payload(self, body: dict[str, Any]) -> dict[str, Any]:
        return {
            "agreementVersion": str(body.get("agreementVersion") or AGREEMENT_VERSION),
            "privacyVersion": str(body.get("privacyVersion") or PRIVACY_VERSION),
            "consentedAt": str(body.get("consentedAt") or now_iso()),
        }

    def _account_info(self, user: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": user.get("id"),
            "username": user.get("username"),
            "phone": user.get("phone"),
            "phoneUpdatedAt": user.get("phoneUpdatedAt"),
            "passwordUpdatedAt": user.get("passwordUpdatedAt"),
            "agreementConsents": store.agreement_consents.get(str(user.get("id")), []),
        }

    def _serve_share_asset(self, filename: str) -> None:
        safe_name = re.sub(r"[^a-zA-Z0-9_.-]+", "", filename)
        path = SHARE_OUTPUT_DIR / safe_name
        if not path.exists() or path.suffix.lower() != ".svg":
            self._json(404, fail("40401", "Share asset not found"))
            return
        raw = path.read_bytes()
        self.send_response(200)
        self._cors()
        self._request_id_header()
        self.send_header("Content-Type", "image/svg+xml; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _absolute_url(self, path: str) -> str:
        host = self.headers.get("Host") or f"{HOST}:{PORT}"
        scheme = "http"
        return f"{scheme}://{host}{path}"

    def _bearer_token(self) -> str | None:
        header = self.headers.get("Authorization", "").strip()
        if not header.lower().startswith("bearer "):
            return None
        token = header[7:].strip()
        return token or None

    def _current_user_id(
        self,
        body: dict[str, Any] | None = None,
        query: dict[str, str] | None = None,
        *,
        require: bool | None = None,
    ) -> str | None:
        token_user_id = store.user_id_for_token(self._bearer_token())
        if token_user_id:
            store.ensure_user(token_user_id)
            return token_user_id
        body_user_id = (body or {}).get("userId")
        query_user_id = (query or {}).get("userId")
        if body_user_id or query_user_id:
            user_id = str(body_user_id or query_user_id)
            store.ensure_user(user_id)
            return user_id
        must_auth = STRICT_AUTH if require is None else require
        if must_auth:
            self._json(401, fail("40101", "Authentication required"))
            return None
        store.ensure_user("user_demo")
        return "user_demo"

    def _sse(self, event_name: str, session_id: str, *, require_auth: bool) -> None:
        session = store.sessions.get(session_id)
        if require_auth:
            user_id = self._current_user_id({}, {}, require=STRICT_AUTH)
            if user_id is None:
                return
            if STRICT_AUTH and session and session.get("userId") not in {None, user_id}:
                self._json(403, fail("40301", "Session does not belong to current user"))
                return
        text = session["card"]["content"]["body"] if session else ""
        self.send_response(200)
        self._cors()
        self._request_id_header()
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        if not session:
            self.wfile.write(
                "event: error\n"
                f"data: {json.dumps({'code': '40401', 'message': 'Session not found', 'sessionId': session_id})}\n\n"
                .encode("utf-8")
            )
            self.wfile.flush()
            return
        for chunk in [text[i : i + 48] for i in range(0, len(text), 48)]:
            self.wfile.write(f"event: chunk\ndata: {json.dumps({'delta': chunk, 'text': chunk})}\n\n".encode("utf-8"))
            self.wfile.flush()
            time.sleep(0.03)
        self.wfile.write(f"event: done\ndata: {json.dumps({'event': event_name, 'sessionId': session_id})}\n\n".encode("utf-8"))

    def _hex_summary(self, lines: list[int], moving_lines: list[int]) -> dict[str, Any]:
        changed = [1 - v if (idx + 1) in moving_lines else v for idx, v in enumerate(lines)]
        return {
            "originalHexagram": choose_hexagram(lines),
            "changedHexagram": choose_hexagram(changed),
            "movingLines": moving_lines,
            "reading": build_reading(lines, moving_lines, "reflection").to_json(),
        }

    def _session_info(self, session: dict[str, Any]) -> dict[str, Any]:
        return {
            "sessionId": session["sessionId"],
            "createdAt": session["createdAt"],
            "updatedAt": session["updatedAt"],
            "historyLength": len(session["messages"]),
        }

    def _usage(self) -> dict[str, int]:
        return {"inputTokens": 0, "outputTokens": 0, "totalTokens": 0}

    def _make_auth_session(self, user: dict[str, Any]) -> dict[str, Any]:
        return {"user": user, **store.issue_session(user["id"])}

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0:
            return {}
        content_type = self.headers.get("Content-Type", "")
        raw_bytes = self.rfile.read(length)
        if "application/json" not in content_type.lower():
            return {
                "_raw": raw_bytes[:2000].decode("utf-8", errors="ignore"),
                "_contentLength": length,
                "_contentType": content_type,
            }
        raw = raw_bytes.decode("utf-8", errors="replace")
        if not raw:
            return {}
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            return {"_raw": raw[:200], "_contentLength": length, "_contentType": content_type}
        return parsed if isinstance(parsed, dict) else {}

    def _json(self, status: int, payload: dict[str, Any]) -> None:
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self._cors()
        self._request_id_header()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, Idempotency-Key, X-Device-Id, X-Request-Id")

    def _request_id_header(self) -> None:
        request_id = self.headers.get("X-Request-Id", "").strip()
        if request_id:
            self.send_header("X-Request-Id", request_id[:128])

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"[{now_iso()}] {self.address_string()} {fmt % args}")


def main() -> None:
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Zhouyi backend listening on http://{HOST}:{PORT}{API_PREFIX}")
    server.serve_forever()


if __name__ == "__main__":
    main()
