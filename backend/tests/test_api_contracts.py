from __future__ import annotations

import json
import hashlib
import hmac
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"
SERVER = BACKEND / "server.py"
PORT = "39031"
BASE = f"http://127.0.0.1:{PORT}/api/v1"


def request(method: str, path: str, body: dict | None = None, headers: dict | None = None) -> tuple[int, dict]:
    data = None
    req_headers = {"Content-Type": "application/json"}
    if headers:
        req_headers.update(headers)
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE}{path}",
        data=data,
        headers=req_headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode("utf-8"))


def raw_request(path: str, headers: dict | None = None) -> tuple[int, str, bytes]:
    req = urllib.request.Request(f"{BASE}{path}", headers=headers or {}, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return resp.status, resp.headers.get("Content-Type", ""), resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.headers.get("Content-Type", ""), exc.read()


def request_headers(method: str, path: str, headers: dict[str, str]) -> tuple[int, dict[str, str], dict]:
    req = urllib.request.Request(f"{BASE}{path}", headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return resp.status, dict(resp.headers.items()), json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return exc.code, dict(exc.headers.items()), json.loads(exc.read().decode("utf-8"))


def request_bytes(method: str, path: str, data: bytes, headers: dict[str, str]) -> tuple[int, dict]:
    req = urllib.request.Request(
        f"{BASE}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode("utf-8"))


class BackendApiContractsTest(unittest.TestCase):
    proc: subprocess.Popen | None = None
    tmpdir: str = ""

    @classmethod
    def setUpClass(cls) -> None:
        cls.tmpdir = tempfile.mkdtemp(prefix="zhouyi_backend_test_")
        env = os.environ.copy()
        env["ZHOUYI_BACKEND_PORT"] = PORT
        env["ZHOUYI_STRICT_AUTH"] = "true"
        env["ZHOUYI_DATA_DIR"] = cls.tmpdir
        cls.proc = subprocess.Popen(
            [sys.executable, str(SERVER)],
            cwd=str(ROOT),
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        deadline = time.time() + 8
        while time.time() < deadline:
            try:
                status, payload = request("GET", "/liuyao/app/health")
                if status == 200 and payload.get("success"):
                    return
            except OSError:
                pass
            time.sleep(0.2)
        raise RuntimeError("Backend test server did not start")

    @classmethod
    def tearDownClass(cls) -> None:
        if cls.proc:
            cls.proc.terminate()
            try:
                cls.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                cls.proc.kill()
        if cls.tmpdir:
            shutil.rmtree(cls.tmpdir, ignore_errors=True)

    def login(self, user_id: str = "user_contract") -> str:
        status, payload = request(
            "POST",
            "/auth/phone/login",
            {"userId": user_id, "username": "Contract Test"},
        )
        self.assertEqual(status, 200, payload)
        token = payload["data"]["session"]["accessToken"]
        self.assertTrue(token.startswith("dev_"))
        return token

    def auth_headers(self, token: str, key: str | None = None) -> dict[str, str]:
        headers = {"Authorization": f"Bearer {token}"}
        if key:
            headers["Idempotency-Key"] = key
        return headers

    def test_strict_auth_requires_token(self) -> None:
        status, payload = request("GET", "/profile/me")
        self.assertEqual(status, 401)
        self.assertEqual(payload["error"]["code"], "40101")

    def test_request_id_is_echoed_for_tracing(self) -> None:
        status, headers, payload = request_headers("GET", "/liuyao/app/health", {"X-Request-Id": "trace-contract-1"})
        self.assertEqual(status, 200, payload)
        self.assertEqual(headers.get("X-Request-Id"), "trace-contract-1")

    def test_auth_test_login_gate_returns_session(self) -> None:
        status, payload = request(
            "POST",
            "/auth/test-login",
            {"userId": "user_test_login_contract", "username": "Test Login"},
        )
        self.assertEqual(status, 200, payload)
        session = payload["data"]["session"]
        self.assertEqual(session["user"]["id"], "user_test_login_contract")
        self.assertTrue(session["accessToken"].startswith("dev_"))
        self.assertTrue(session["refreshToken"].startswith("refresh_"))

    def test_login_profile_logout_revokes_token(self) -> None:
        token = self.login("user_auth_contract")
        status, payload = request("GET", "/profile/me", headers=self.auth_headers(token))
        self.assertEqual(status, 200, payload)
        self.assertEqual(payload["data"]["profile"]["id"], "user_auth_contract")

        status, payload = request("POST", "/auth/logout", headers=self.auth_headers(token))
        self.assertEqual(status, 200, payload)

        status, payload = request("GET", "/profile/me", headers=self.auth_headers(token))
        self.assertEqual(status, 401)
        self.assertEqual(payload["error"]["code"], "40101")

    def test_auth_refresh_rotates_tokens_and_expires_cleanly(self) -> None:
        status, login = request(
            "POST",
            "/auth/phone/login",
            {"userId": "user_refresh_contract", "username": "Refresh Contract"},
        )
        self.assertEqual(status, 200, login)
        session = login["data"]["session"]
        access_token = session["accessToken"]
        refresh_token = session["refreshToken"]
        self.assertTrue(refresh_token.startswith("refresh_"))
        expires_at = datetime.fromisoformat(session["expiresAt"].replace("Z", "+00:00"))
        self.assertGreater(expires_at, datetime.now(timezone.utc))

        status, refreshed = request("POST", "/auth/refresh", {"refreshToken": refresh_token})
        self.assertEqual(status, 200, refreshed)
        refreshed_session = refreshed["data"]["session"]
        self.assertEqual(refreshed_session["user"]["id"], "user_refresh_contract")
        self.assertNotEqual(refreshed_session["accessToken"], access_token)
        self.assertNotEqual(refreshed_session["refreshToken"], refresh_token)

        status, old_access = request("GET", "/profile/me", headers=self.auth_headers(access_token))
        self.assertEqual(status, 401)
        self.assertEqual(old_access["error"]["code"], "40101")

        status, reused = request("POST", "/auth/refresh", {"refreshToken": refresh_token})
        self.assertEqual(status, 401)
        self.assertEqual(reused["error"]["code"], "40102")

        new_access = refreshed_session["accessToken"]
        new_refresh = refreshed_session["refreshToken"]
        status, profile = request("GET", "/profile/me", headers=self.auth_headers(new_access))
        self.assertEqual(status, 200, profile)

        status, logged_out = request("POST", "/auth/logout", headers=self.auth_headers(new_access))
        self.assertEqual(status, 200, logged_out)
        status, revoked_refresh = request("POST", "/auth/refresh", {"refreshToken": new_refresh})
        self.assertEqual(status, 401)
        self.assertEqual(revoked_refresh["error"]["code"], "40102")

    def test_auth_agreement_and_account_security_endpoints(self) -> None:
        status, agreement = request("GET", "/auth/agreement-version")
        self.assertEqual(status, 200, agreement)
        self.assertIn("agreementVersion", agreement["data"])

        status, privacy = request("GET", "/auth/privacy-version")
        self.assertEqual(status, 200, privacy)
        self.assertIn("privacyVersion", privacy["data"])

        status, login = request(
            "POST",
            "/auth/phone/login",
            {
                "userId": "user_account_contract",
                "username": "Account Contract",
                "phone": "13800000000",
                "code": "123456",
                "agreementVersion": agreement["data"]["agreementVersion"],
                "privacyVersion": privacy["data"]["privacyVersion"],
            },
        )
        self.assertEqual(status, 200, login)
        token = login["data"]["session"]["accessToken"]

        status, account = request("GET", "/auth/account-info", headers=self.auth_headers(token))
        self.assertEqual(status, 200, account)
        self.assertEqual(account["data"]["account"]["phone"], "13800000000")
        self.assertGreaterEqual(len(account["data"]["account"]["agreementConsents"]), 1)

        status, changed = request(
            "POST",
            "/auth/change-password",
            {"newPassword": "new-secret", "confirmPassword": "new-secret"},
            self.auth_headers(token),
        )
        self.assertEqual(status, 200, changed)
        self.assertTrue(changed["data"]["updated"])

        status, bound = request(
            "POST",
            "/auth/phone-bindchange",
            {"phone": "13900000000"},
            self.auth_headers(token),
        )
        self.assertEqual(status, 200, bound)
        self.assertEqual(bound["data"]["phone"], "13900000000")

    def test_auth_social_login_and_password_recovery_validation(self) -> None:
        status, bad_social = request(
            "POST",
            "/auth/social/login",
            {"provider": "weibo", "authCode": "code"},
        )
        self.assertEqual(status, 400)
        self.assertEqual(bad_social["error"]["code"], "40001")

        status, social = request(
            "POST",
            "/auth/social/login",
            {"userId": "user_social_contract", "provider": "wechat", "authCode": "wechat-code"},
        )
        self.assertEqual(status, 200, social)
        self.assertEqual(social["data"]["session"]["user"]["id"], "user_social_contract")

        status, sent = request("POST", "/auth/phone/send-code", {"phone": "13700000000"})
        self.assertEqual(status, 200, sent)

        status, bad_recovery = request(
            "POST",
            "/auth/password/recovery",
            {
                "phone": "13700000000",
                "code": "000000",
                "newPassword": "new-secret",
                "confirmPassword": "new-secret",
            },
        )
        self.assertEqual(status, 400)
        self.assertEqual(bad_recovery["error"]["code"], "40001")

        status, recovered = request(
            "POST",
            "/auth/password/recovery",
            {
                "phone": "13700000000",
                "code": "123456",
                "newPassword": "new-secret",
                "confirmPassword": "new-secret",
            },
        )
        self.assertEqual(status, 200, recovered)
        self.assertTrue(recovered["data"]["updated"])

    def test_auth_send_code_rate_limit(self) -> None:
        phone = "13600000000"
        for _ in range(5):
            status, sent = request("POST", "/auth/phone/send-code", {"phone": phone})
            self.assertEqual(status, 200, sent)

        status, limited = request("POST", "/auth/phone/send-code", {"phone": phone})
        self.assertEqual(status, 429)
        self.assertEqual(limited["error"]["code"], "42901")

    def test_billing_order_flow_is_idempotent_and_updates_vip(self) -> None:
        token = self.login("user_billing_contract")
        headers = self.auth_headers(token)

        status, plans = request("GET", "/billing/plans", headers=headers)
        self.assertEqual(status, 200, plans)
        self.assertGreaterEqual(len(plans["data"]["plans"]), 1)

        status, bad_plan = request(
            "POST",
            "/billing/order/create",
            {"planId": "plan_missing"},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(bad_plan["error"]["code"], "40001")

        status, created = request(
            "POST",
            "/billing/order/create",
            {"planId": "plan_month"},
            self.auth_headers(token, "billing-order-contract"),
        )
        self.assertEqual(status, 200, created)
        self.assertTrue(created["data"]["created"])
        order_id = created["data"]["order"]["orderId"]

        status, duplicate = request(
            "POST",
            "/billing/order/create",
            {"planId": "plan_month"},
            self.auth_headers(token, "billing-order-contract"),
        )
        self.assertEqual(status, 200, duplicate)
        self.assertFalse(duplicate["data"]["created"])
        self.assertEqual(duplicate["data"]["order"]["orderId"], order_id)

        status, confirmed = request(
            "POST",
            "/billing/order/confirm",
            {"orderId": order_id, "paymentResult": "success"},
            headers,
        )
        self.assertEqual(status, 200, confirmed)
        self.assertEqual(confirmed["data"]["order"]["status"], "paid")
        self.assertTrue(confirmed["data"]["account"]["isVip"])
        self.assertGreaterEqual(confirmed["data"]["account"]["followupBalance"], 4)

        status, detail = request("GET", f"/billing/order/{order_id}", headers=headers)
        self.assertEqual(status, 200, detail)
        self.assertEqual(detail["data"]["order"]["status"], "paid")

    def test_billing_payment_callback_requires_valid_signature(self) -> None:
        token = self.login("user_billing_callback_contract")
        status, created = request(
            "POST",
            "/billing/order/create",
            {"planId": "plan_month"},
            self.auth_headers(token, "billing-callback-order"),
        )
        self.assertEqual(status, 200, created)
        order_id = created["data"]["order"]["orderId"]

        status, rejected = request(
            "POST",
            "/billing/order/callback",
            {"orderId": order_id, "status": "paid", "signature": "bad-signature"},
        )
        self.assertEqual(status, 403)
        self.assertEqual(rejected["error"]["code"], "40301")

        signature = hmac.new(
            b"dev_callback_secret",
            f"{order_id}:paid".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        status, accepted = request(
            "POST",
            "/billing/order/callback",
            {"orderId": order_id, "status": "paid", "signature": signature},
        )
        self.assertEqual(status, 200, accepted)
        self.assertEqual(accepted["data"]["order"]["status"], "paid")
        self.assertTrue(accepted["data"]["account"]["isVip"])

        refund_signature = hmac.new(
            b"dev_callback_secret",
            f"{order_id}:refunded".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        status, refunded = request(
            "POST",
            "/billing/order/callback",
            {"orderId": order_id, "status": "refunded", "signature": refund_signature},
        )
        self.assertEqual(status, 200, refunded)
        self.assertEqual(refunded["data"]["order"]["status"], "refunded")
        self.assertFalse(refunded["data"]["account"]["isVip"])

    def test_credit_consumption_for_cast_and_followup(self) -> None:
        token = self.login("user_credit_contract")
        start_body = {
            "question": "我现在要不要换工作",
            "tag": "career",
            "lines": [1, 0, 1, 1, 0, 1],
            "movingLines": [2, 5],
        }
        status, first = request(
            "POST",
            "/liuyao/app/chat/start",
            start_body,
            self.auth_headers(token, "cast-contract-1"),
        )
        self.assertEqual(status, 200, first)
        self.assertEqual(first["data"]["credit"]["account"]["castBalance"], 0)
        self.assertEqual(first["data"]["reply"]["meta"]["provider"], "local")
        self.assertIn("Local Liuyao references", first["data"]["reply"]["text"])
        self.assertIn("reading", first["data"]["reply"]["meta"])
        self.assertIn("reading", first["data"]["summary"])
        self.assertEqual(first["data"]["reply"]["meta"]["reading"]["movingLines"], [2, 5])
        session_id = first["data"]["session"]["sessionId"]

        status, second = request(
            "POST",
            "/liuyao/app/chat/start",
            start_body,
            self.auth_headers(token, "cast-contract-2"),
        )
        self.assertEqual(status, 409)
        self.assertEqual(second["error"]["code"], "40901")

        status, follow = request(
            "POST",
            "/liuyao/app/chat/continue",
            {"sessionId": session_id, "message": "这周我先做什么"},
            self.auth_headers(token, "follow-contract-1"),
        )
        self.assertEqual(status, 200, follow)
        self.assertEqual(follow["data"]["credit"]["account"]["followupBalance"], 0)

        status, failed_follow = request(
            "POST",
            "/liuyao/app/chat/continue",
            {"sessionId": session_id, "message": "还能再说一点吗"},
            self.auth_headers(token, "follow-contract-2"),
        )
        self.assertEqual(status, 409)
        self.assertEqual(failed_follow["error"]["code"], "40901")

    def test_credit_consume_validates_type_amount_and_idempotency(self) -> None:
        token = self.login("user_credit_consume_contract")
        headers = self.auth_headers(token)

        status, bad_type = request(
            "POST",
            "/credit/consume",
            {"type": "fortune", "amount": 1},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(bad_type["error"]["code"], "40001")

        status, bad_amount = request(
            "POST",
            "/credit/consume",
            {"type": "cast", "amount": 2},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(bad_amount["error"]["code"], "40001")

        status, consumed = request(
            "POST",
            "/credit/consume",
            {"type": "cast", "amount": 1, "sessionId": "credit_consume_contract"},
            self.auth_headers(token, "credit-consume-idempotent"),
        )
        self.assertEqual(status, 200, consumed)
        self.assertEqual(consumed["data"]["account"]["castBalance"], 0)

        status, duplicate = request(
            "POST",
            "/credit/consume",
            {"type": "cast", "amount": 1, "sessionId": "credit_consume_contract"},
            self.auth_headers(token, "credit-consume-idempotent"),
        )
        self.assertEqual(status, 200, duplicate)
        self.assertEqual(duplicate["data"]["account"]["castBalance"], 0)

    def test_knowledge_search(self) -> None:
        status, payload = request("GET", "/knowledge/search?q=%E5%8A%A8%E7%88%BB&tag=choice&limit=2")
        self.assertEqual(status, 200, payload)
        self.assertGreaterEqual(len(payload["data"]["items"]), 1)
        self.assertIn("source", payload["data"]["items"][0])

    def test_invalid_ritual_payload_does_not_consume_credit(self) -> None:
        token = self.login("user_validation_contract")
        headers = self.auth_headers(token, "invalid-cast-contract")
        status, payload = request(
            "POST",
            "/liuyao/app/chat/start",
            {"question": "问题有效", "tag": "career", "lines": [1, 0, 1], "movingLines": [2]},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(payload["error"]["code"], "40001")

        status, account = request("GET", "/credit/account", headers=self.auth_headers(token))
        self.assertEqual(status, 200, account)
        self.assertEqual(account["data"]["account"]["castBalance"], 1)

    def test_empty_followup_does_not_consume_credit(self) -> None:
        token = self.login("user_followup_validation_contract")
        start_body = {
            "question": "我该怎么理解当前选择",
            "tag": "choice",
            "lines": [1, 0, 1, 1, 0, 1],
            "movingLines": [2],
        }
        status, first = request(
            "POST",
            "/liuyao/app/chat/start",
            start_body,
            self.auth_headers(token, "valid-cast-before-empty-followup"),
        )
        self.assertEqual(status, 200, first)
        session_id = first["data"]["session"]["sessionId"]

        status, payload = request(
            "POST",
            "/liuyao/app/chat/continue",
            {"sessionId": session_id, "message": "   "},
            self.auth_headers(token, "invalid-empty-followup"),
        )
        self.assertEqual(status, 400)
        self.assertEqual(payload["error"]["code"], "40001")

        status, account = request("GET", "/credit/account", headers=self.auth_headers(token))
        self.assertEqual(status, 200, account)
        self.assertEqual(account["data"]["account"]["followupBalance"], 1)

    def test_ritual_completion_today_and_chat_alias(self) -> None:
        user_id = "user_ritual_completion_contract"
        token = self.login(user_id)
        headers = self.auth_headers(token, "ritual-completion-cast")
        status, performed = request(
            "POST",
            "/ritual/perform",
            {
                "question": "How should I pace this week?",
                "tag": "reflection",
                "lines": [1, 0, 1, 1, 0, 1],
                "movingLines": [2],
            },
            headers,
        )
        self.assertEqual(status, 200, performed)
        session_id = performed["data"]["sessionId"]

        status, anonymous_full = request("GET", f"/ritual/session/{session_id}/full-read")
        self.assertEqual(status, 401)
        self.assertEqual(anonymous_full["error"]["code"], "40101")

        status, full_read = request(
            "GET",
            f"/ritual/session/{session_id}/full-read",
            headers=self.auth_headers(token),
        )
        self.assertEqual(status, 200, full_read)
        self.assertEqual(full_read["data"]["sessionId"], session_id)

        status, completion = request(
            "GET",
            f"/ritual/user/{user_id}/completion-today",
            headers=self.auth_headers(token),
        )
        self.assertEqual(status, 200, completion)
        self.assertTrue(completion["data"]["completed"])
        self.assertIsNotNone(completion["data"]["lastCompletedAt"])

        status, chat = request(
            "POST",
            f"/ritual/session/{session_id}/chat",
            {"message": "What should I observe first?"},
            self.auth_headers(token, "ritual-completion-chat"),
        )
        self.assertEqual(status, 200, chat)
        self.assertIn("reply", chat["data"])

        status, history = request(
            "GET",
            f"/ritual/session/{session_id}/chat-history",
            headers=self.auth_headers(token),
        )
        self.assertEqual(status, 200, history)
        self.assertGreaterEqual(len(history["data"]["messages"]), 2)

        status, _, anonymous_stream = raw_request(f"/ritual/session/{session_id}/chat/stream")
        self.assertEqual(status, 401)
        self.assertIn(b"40101", anonymous_stream)

        status, content_type, stream = raw_request(
            f"/ritual/session/{session_id}/followup/stream",
            headers=self.auth_headers(token),
        )
        self.assertEqual(status, 200)
        self.assertIn("text/event-stream", content_type)
        self.assertIn(b"event: chunk", stream)
        self.assertIn(b'"delta"', stream)
        self.assertIn(b"event: done", stream)
        self.assertIn(session_id.encode("utf-8"), stream)

        status, content_type, missing_stream = raw_request("/ritual/session/sess_missing/interpretation/stream")
        self.assertEqual(status, 200)
        self.assertIn("text/event-stream", content_type)
        self.assertIn(b"event: error", missing_stream)
        self.assertIn(b"40401", missing_stream)

        status, missing_tag_profile = request(
            "GET",
            "/ritual/session/sess_missing/tag-profile",
            headers=self.auth_headers(token),
        )
        self.assertEqual(status, 404)
        self.assertEqual(missing_tag_profile["error"]["code"], "40401")

        status, missing_tag_timeline = request(
            "GET",
            "/ritual/session/sess_missing/tag-timeline",
            headers=self.auth_headers(token),
        )
        self.assertEqual(status, 404)
        self.assertEqual(missing_tag_timeline["error"]["code"], "40401")

    def test_invalid_support_category(self) -> None:
        token = self.login("user_support_validation_contract")
        status, payload = request(
            "POST",
            "/support/feedback",
            {"category": "fortune", "content": "hello"},
            self.auth_headers(token),
        )
        self.assertEqual(status, 400)
        self.assertEqual(payload["error"]["code"], "40001")

        status, bad_client = request(
            "POST",
            "/support/feedback",
            {"category": "bug", "content": "hello", "client": {"platform": "desktop"}},
            self.auth_headers(token),
        )
        self.assertEqual(status, 400)
        self.assertEqual(bad_client["error"]["code"], "40001")

    def test_support_feedback_faq_and_ticket_status(self) -> None:
        token = self.login("user_support_contract")
        headers = self.auth_headers(token)

        status, faq = request("GET", "/support/faq")
        self.assertEqual(status, 200, faq)
        self.assertGreaterEqual(len(faq["data"]["items"]), 1)

        status, created = request(
            "POST",
            "/support/feedback",
            {"category": "bug", "content": "contract feedback", "client": {"platform": "android"}},
            headers,
        )
        self.assertEqual(status, 200, created)
        ticket_id = created["data"]["ticketId"]

        status, detail = request("GET", f"/support/ticket/{ticket_id}", headers=headers)
        self.assertEqual(status, 200, detail)
        self.assertEqual(detail["data"]["ticket"]["ticketId"], ticket_id)
        self.assertEqual(detail["data"]["ticket"]["status"], "open")

    def test_support_feedback_rate_limit(self) -> None:
        token = self.login("user_support_rate_contract")
        headers = self.auth_headers(token)
        for idx in range(5):
            status, created = request(
                "POST",
                "/support/feedback",
                {"category": "suggestion", "content": f"rate contract {idx}"},
                headers,
            )
            self.assertEqual(status, 200, created)

        status, limited = request(
            "POST",
            "/support/feedback",
            {"category": "suggestion", "content": "rate contract limited"},
            headers,
        )
        self.assertEqual(status, 429)
        self.assertEqual(limited["error"]["code"], "42901")

    def test_neutrality_guard_filters_prediction_words(self) -> None:
        sys.path.insert(0, str(BACKEND))
        from llm import neutralize_text

        text = neutralize_text("这件事一定会大吉，给你100分保证成功。")
        self.assertNotIn("一定会", text)
        self.assertNotIn("大吉", text)
        self.assertNotIn("100分", text)
        self.assertNotIn("保证", text)

    def test_llm_structured_parser(self) -> None:
        sys.path.insert(0, str(BACKEND))
        from llm import parse_structured_content

        raw = """
        ```json
        {
          "answer": "这不是保证，只是提醒你观察当前节奏。",
          "followups": ["我该先看什么？", "什么可以暂缓？"],
          "safetyNotes": ["不替代专业建议"]
        }
        ```
        """
        parsed = parse_structured_content(raw)
        self.assertIsNotNone(parsed)
        assert parsed is not None
        self.assertIn("answer", parsed)
        self.assertEqual(len(parsed["followups"]), 2)
        self.assertNotIn("保证", parsed["answer"])

        self.assertIsNone(parse_structured_content('{"answer":"","followups":["x"],"safetyNotes":[]}'))
        self.assertIsNone(parse_structured_content('{"answer":"ok","safetyNotes":[]}'))

    def test_share_card_render_returns_served_svg(self) -> None:
        token = self.login("user_share_contract")
        status, payload = request(
            "POST",
            "/share/card/render",
            {
                "cardId": "card_contract",
                "theme": "warm",
                "text": "这是一张中性的反思分享卡。",
                "tag": "reflection",
                "hexagramName": "Qian",
            },
            self.auth_headers(token),
        )
        self.assertEqual(status, 200, payload)
        self.assertEqual(payload["data"]["mime"], "image/svg+xml")
        self.assertTrue(payload["data"]["imageUrl"].endswith(".svg"))
        static_path = payload["data"]["imageUrl"].split("/api/v1", 1)[1]
        status, content_type, raw = raw_request(static_path)
        self.assertEqual(status, 200)
        self.assertIn("image/svg+xml", content_type)
        self.assertIn(b"<svg", raw)

    def test_share_save_publish_and_external_share_contracts(self) -> None:
        token = self.login("user_share_flow_contract")

        status, invalid_theme = request(
            "POST",
            "/share/card/render",
            {"cardId": "card_invalid_theme", "theme": "neon", "text": "invalid theme"},
        )
        self.assertEqual(status, 400)
        self.assertEqual(invalid_theme["error"]["code"], "40001")

        save_body = {
            "cardId": "card_share_flow",
            "theme": "cool",
            "text": "A saved neutral share draft.",
            "backgroundImageUrl": "https://cdn.local/bg/share.jpg",
        }
        status, saved = request(
            "POST",
            "/share/card/save",
            save_body,
            self.auth_headers(token, "share-save-flow"),
        )
        self.assertEqual(status, 200, saved)
        self.assertTrue(saved["data"]["created"])

        status, duplicate_save = request(
            "POST",
            "/share/card/save",
            save_body,
            self.auth_headers(token, "share-save-flow"),
        )
        self.assertEqual(status, 200, duplicate_save)
        self.assertFalse(duplicate_save["data"]["created"])
        self.assertEqual(duplicate_save["data"]["draftId"], "card_share_flow")

        status, missing_card = request(
            "POST",
            "/share/community/publish",
            {"shareText": "missing card should fail"},
            self.auth_headers(token),
        )
        self.assertEqual(status, 400)
        self.assertEqual(missing_card["error"]["code"], "40001")

        status, unknown_card = request(
            "POST",
            "/share/community/publish",
            {"cardId": "card_does_not_exist", "shareText": "unknown card should fail"},
            self.auth_headers(token),
        )
        self.assertEqual(status, 404)
        self.assertEqual(unknown_card["error"]["code"], "40401")

        publish_body = {"cardId": "card_share_flow", "shareText": "share flow publish"}
        status, published = request(
            "POST",
            "/share/community/publish",
            publish_body,
            self.auth_headers(token, "share-publish-flow"),
        )
        self.assertEqual(status, 200, published)
        self.assertTrue(published["data"]["created"])
        post_id = published["data"]["postId"]

        status, duplicate_publish = request(
            "POST",
            "/share/community/publish",
            publish_body,
            self.auth_headers(token, "share-publish-flow"),
        )
        self.assertEqual(status, 200, duplicate_publish)
        self.assertFalse(duplicate_publish["data"]["created"])
        self.assertEqual(duplicate_publish["data"]["postId"], post_id)

        status, external = request(
            "POST",
            "/share/external",
            {"channel": "wechat", "cardId": "card_share_flow", "url": "https://orbit.local/share/card_share_flow"},
        )
        self.assertEqual(status, 200, external)
        self.assertEqual(external["data"]["payload"]["channel"], "wechat")
        self.assertEqual(external["data"]["payload"]["cardId"], "card_share_flow")

    def test_profile_update_and_account_delete_validation(self) -> None:
        token = self.login("user_profile_contract")
        headers = self.auth_headers(token)

        status, bad_birthday = request(
            "PUT",
            "/profile/me",
            {"birthday": "04/16/2026"},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(bad_birthday["error"]["code"], "40001")

        status, impossible_birthday = request(
            "PUT",
            "/profile/me",
            {"birthday": "1996-13-40"},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(impossible_birthday["error"]["code"], "40001")

        status, future_birthday = request(
            "PUT",
            "/profile/me",
            {"birthday": "2999-01-01"},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(future_birthday["error"]["code"], "40001")

        status, updated = request(
            "PUT",
            "/profile/me",
            {"username": "Profile Contract", "birthday": "1996-05-20", "gender": "not_disclosed"},
            headers,
        )
        self.assertEqual(status, 200, updated)
        self.assertEqual(updated["data"]["profile"]["birthday"], "1996-05-20")

        status, bad_delete = request(
            "DELETE",
            "/profile/me",
            {"confirmText": "delete"},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(bad_delete["error"]["code"], "40001")

        status, scheduled = request(
            "DELETE",
            "/profile/me",
            {"confirmText": "注销", "coolingOffDays": 7},
            headers,
        )
        self.assertEqual(status, 200, scheduled)
        self.assertTrue(scheduled["data"]["scheduled"])

        status, cancelled = request(
            "POST",
            "/profile/me/delete-cancel",
            headers=headers,
        )
        self.assertEqual(status, 200, cancelled)
        self.assertTrue(cancelled["data"]["cancelled"])

    def test_media_upload_validation_profile_and_multipart(self) -> None:
        token = self.login("user_media_contract")
        headers = self.auth_headers(token)

        status, anonymous = request(
            "POST",
            "/media/upload",
            {"mime": "image/jpeg", "size": 1024},
        )
        self.assertEqual(status, 401)
        self.assertEqual(anonymous["error"]["code"], "40101")

        status, bad_mime = request(
            "POST",
            "/media/upload",
            {"mime": "image/gif", "size": 1024},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(bad_mime["error"]["code"], "40001")

        status, oversized = request(
            "POST",
            "/profile/me/avatar",
            {"mime": "image/jpeg", "size": 6 * 1024 * 1024},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(oversized["error"]["code"], "40001")

        status, avatar = request(
            "POST",
            "/profile/me/avatar",
            {"mime": "image/png", "size": 2048, "width": 128, "height": 128},
            headers,
        )
        self.assertEqual(status, 200, avatar)
        self.assertTrue(avatar["data"]["avatarUrl"].endswith(".png"))

        status, community = request(
            "POST",
            "/community/media/upload",
            {"mime": "image/webp", "size": 4096, "width": 1080, "height": 1350},
            headers,
        )
        self.assertEqual(status, 200, community)
        self.assertEqual(community["data"]["mime"], "image/webp")
        self.assertEqual(community["data"]["purpose"], "community")

        boundary = "----codexboundary"
        multipart = (
            f"--{boundary}\r\n"
            'Content-Disposition: form-data; name="file"; filename="a.png"\r\n'
            "Content-Type: image/png\r\n\r\n"
            "fake-image-bytes\r\n"
            f"--{boundary}--\r\n"
        ).encode("utf-8")
        status, uploaded = request_bytes(
            "POST",
            "/media/upload",
            multipart,
            {
                **headers,
                "Content-Type": f"multipart/form-data; boundary={boundary}",
            },
        )
        self.assertEqual(status, 200, uploaded)
        self.assertEqual(uploaded["data"]["mime"], "image/png")
        self.assertEqual(uploaded["data"]["purpose"], "media")

    def test_notification_filters_detail_token_and_sync(self) -> None:
        token = self.login("user_message_contract")
        headers = self.auth_headers(token)
        status, registered = request(
            "POST",
            "/notifications/token",
            {"token": "push-token-contract", "platform": "android"},
            headers,
        )
        self.assertEqual(status, 200, registered)
        self.assertTrue(registered["data"]["registered"])

        status, post = request(
            "POST",
            "/feed/publish",
            {"shareText": "message contract post"},
            headers,
        )
        self.assertEqual(status, 200, post)

        status, unread = request("GET", "/notifications?read=false&type=interaction", headers=headers)
        self.assertEqual(status, 200, unread)
        self.assertGreaterEqual(unread["data"]["unreadCount"], 1)
        message_id = unread["data"]["messages"][0]["id"]

        status, polish = request("GET", "/notifications/ui-polish", headers=headers)
        self.assertEqual(status, 200, polish)
        self.assertTrue(polish["data"]["actions"]["markAllRead"])
        self.assertIn("interaction", polish["data"]["filters"])

        status, detail = request("GET", f"/notifications/{message_id}", headers=headers)
        self.assertEqual(status, 200, detail)
        self.assertEqual(detail["data"]["message"]["id"], message_id)

        status, marked = request("POST", f"/notifications/{message_id}/read", headers=headers)
        self.assertEqual(status, 200, marked)

        status, missing_read = request("POST", "/notifications/not_real/read", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_read["error"]["code"], "40401")

        status, missing_dismiss = request("POST", "/notifications/not_real/dismiss", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_dismiss["error"]["code"], "40401")

        status, synced = request(
            "PUT",
            "/notifications/state",
            {"dismissedIds": [message_id], "readIds": [message_id]},
            headers,
        )
        self.assertEqual(status, 200, synced)

        status, after = request("GET", f"/notifications/{message_id}", headers=headers)
        self.assertEqual(status, 404)

        status, unregistered = request(
            "DELETE",
            "/notifications/token",
            {"token": "push-token-contract"},
            headers,
        )
        self.assertEqual(status, 200, unregistered)
        self.assertFalse(unregistered["data"]["registered"])

    def test_feed_mine_only_returns_current_user_posts(self) -> None:
        token = self.login("user_feed_mine_contract")
        headers = self.auth_headers(token)
        status, mine_before = request("GET", "/feed/mine", headers=headers)
        self.assertEqual(status, 200, mine_before)

        status, post = request(
            "POST",
            "/feed/publish",
            {"shareText": "mine contract post"},
            headers,
        )
        self.assertEqual(status, 200, post)
        post_id = post["data"]["id"]

        status, mine = request("GET", "/feed/mine", headers=headers)
        self.assertEqual(status, 200, mine)
        ids = [item["id"] for item in mine["data"]["items"]]
        self.assertIn(post_id, ids)
        self.assertTrue(all(item["authorId"] == "user_feed_mine_contract" for item in mine["data"]["items"]))

    def test_profile_interactions_and_browse_are_user_scoped(self) -> None:
        token = self.login("user_profile_timeline_contract")
        headers = self.auth_headers(token)
        other_token = self.login("user_profile_timeline_other")
        other_headers = self.auth_headers(other_token)

        status, own_post = request(
            "POST",
            "/community/post",
            {"cardId": "card_profile_timeline_own", "shareText": "own timeline post"},
            headers,
        )
        self.assertEqual(status, 200, own_post)
        own_post_id = own_post["data"]["post"]["id"]

        status, other_post = request(
            "POST",
            "/community/post",
            {"cardId": "card_profile_timeline_other", "shareText": "other timeline post"},
            other_headers,
        )
        self.assertEqual(status, 200, other_post)
        other_post_id = other_post["data"]["post"]["id"]

        status, viewed = request("POST", f"/feed/{other_post_id}/view", headers=headers)
        self.assertEqual(status, 200, viewed)
        status, liked = request("POST", f"/community/post/{other_post_id}/like", headers=headers)
        self.assertEqual(status, 200, liked)
        status, comment = request(
            "POST",
            f"/community/post/{other_post_id}/comments",
            {"text": "profile timeline comment"},
            headers,
        )
        self.assertEqual(status, 200, comment)

        status, interactions = request("GET", "/profile/me/interactions", headers=headers)
        self.assertEqual(status, 200, interactions)
        items = interactions["data"]["items"]
        publish_post_ids = [item.get("postId") for item in items if item.get("type") == "publish"]
        self.assertIn(own_post_id, publish_post_ids)
        self.assertNotIn(other_post_id, publish_post_ids)
        self.assertIn(other_post_id, [item.get("postId") for item in items if item.get("type") in {"like", "comment"}])

        status, browse = request("GET", "/profile/me/browse", headers=headers)
        self.assertEqual(status, 200, browse)
        self.assertEqual([item.get("postId") for item in browse["data"]["items"]], [other_post_id])

    def test_community_follow_hide_block_report_and_search(self) -> None:
        token = self.login("user_community_contract")
        headers = self.auth_headers(token)
        status, post = request(
            "POST",
            "/community/post",
            {"cardId": "card_community_contract", "shareText": "community contract searchable text", "authorId": "author_contract"},
            headers,
        )
        self.assertEqual(status, 200, post)
        post_id = post["data"]["post"]["id"]
        author_id = post["data"]["post"]["authorId"]

        status, followed = request("POST", f"/community/author/{author_id}/follow", headers=headers)
        self.assertEqual(status, 200, followed)

        status, author = request("GET", f"/community/author/{author_id}", headers=headers)
        self.assertEqual(status, 200, author)
        self.assertEqual(author["data"]["author"]["id"], author_id)
        self.assertTrue(author["data"]["author"]["viewerState"]["followed"])
        self.assertGreaterEqual(author["data"]["author"]["postCount"], 1)

        status, missing_author = request("GET", "/community/author/does_not_exist_contract", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_author["error"]["code"], "40401")

        status, feed = request("GET", "/community/feed", headers=headers)
        self.assertEqual(status, 200, feed)
        item = next(item for item in feed["data"]["items"] if item["id"] == post_id)
        self.assertTrue(item["viewerState"]["followedAuthor"])

        status, deep_feed = request("GET", "/community/feed?tab=deep", headers=headers)
        self.assertEqual(status, 200, deep_feed)
        self.assertEqual(deep_feed["data"]["tab"], "deep")

        status, bad_tab = request("GET", "/community/feed?tab=hot", headers=headers)
        self.assertEqual(status, 400)
        self.assertEqual(bad_tab["error"]["code"], "40001")

        status, bad_report = request(
            "POST",
            f"/community/post/{post_id}/report",
            {"reason": "fortune"},
            headers,
        )
        self.assertEqual(status, 400)
        self.assertEqual(bad_report["error"]["code"], "40001")

        status, report = request(
            "POST",
            f"/community/post/{post_id}/report",
            {"reason": "spam", "detail": "contract test"},
            headers,
        )
        self.assertEqual(status, 200, report)

        status, search = request("GET", "/community/search?q=searchable", headers=headers)
        self.assertEqual(status, 200, search)
        self.assertGreaterEqual(len(search["data"]["posts"]), 1)

        status, typed_search = request("GET", "/community/search?q=searchable&type=post&pageSize=1", headers=headers)
        self.assertEqual(status, 200, typed_search)
        self.assertEqual(typed_search["data"]["type"], "post")
        self.assertGreaterEqual(len(typed_search["data"]["items"]), 1)

        status, missing_post = request("GET", "/community/post/feed_missing_contract", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_post["error"]["code"], "40401")

        status, missing_comments = request("GET", "/community/post/feed_missing_contract/comments", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_comments["error"]["code"], "40401")

        status, missing_comment_create = request(
            "POST",
            "/community/post/feed_missing_contract/comments",
            {"text": "missing"},
            headers,
        )
        self.assertEqual(status, 404)
        self.assertEqual(missing_comment_create["error"]["code"], "40401")

        status, missing_action = request("POST", "/community/post/feed_missing_contract/like", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_action["error"]["code"], "40401")

        status, hidden = request("POST", f"/community/post/{post_id}/hide", headers=headers)
        self.assertEqual(status, 200, hidden)
        status, after_hide = request("GET", "/community/feed", headers=headers)
        self.assertEqual(status, 200, after_hide)
        self.assertNotIn(post_id, [item["id"] for item in after_hide["data"]["items"]])

        status, blocked = request("POST", f"/community/author/{author_id}/block", headers=headers)
        self.assertEqual(status, 200, blocked)

    def test_community_publish_report_and_tag_subscribe_are_retry_safe(self) -> None:
        token = self.login("user_community_retry_contract")
        status, missing_card = request(
            "POST",
            "/community/post",
            {"shareText": "missing card should fail"},
            self.auth_headers(token),
        )
        self.assertEqual(status, 400)
        self.assertEqual(missing_card["error"]["code"], "40001")

        status, first = request(
            "POST",
            "/community/post",
            {"cardId": "card_retry_contract", "shareText": "retry safe community post #retry"},
            self.auth_headers(token, "community-publish-retry"),
        )
        self.assertEqual(status, 200, first)
        self.assertTrue(first["data"]["created"])
        post_id = first["data"]["postId"]

        status, duplicate = request(
            "POST",
            "/community/post",
            {"cardId": "card_retry_contract", "shareText": "retry safe community post #retry"},
            self.auth_headers(token, "community-publish-retry"),
        )
        self.assertEqual(status, 200, duplicate)
        self.assertFalse(duplicate["data"]["created"])
        self.assertEqual(duplicate["data"]["postId"], post_id)

        headers = self.auth_headers(token)
        for _ in range(2):
            status, reported = request(
                "POST",
                f"/community/post/{post_id}/report",
                {"reason": "spam", "detail": "retry"},
                headers,
            )
            self.assertEqual(status, 200, reported)

        status, detail = request("GET", f"/community/post/{post_id}", headers=headers)
        self.assertEqual(status, 200, detail)
        self.assertEqual(detail["data"]["post"]["metrics"]["reports"], 1)

        status, comment = request(
            "POST",
            f"/community/post/{post_id}/comments",
            {"text": "retry safe comment"},
            self.auth_headers(token, "community-comment-retry"),
        )
        self.assertEqual(status, 200, comment)
        self.assertTrue(comment["data"]["created"])

        status, duplicate_comment = request(
            "POST",
            f"/community/post/{post_id}/comments",
            {"text": "retry safe comment"},
            self.auth_headers(token, "community-comment-retry"),
        )
        self.assertEqual(status, 200, duplicate_comment)
        self.assertFalse(duplicate_comment["data"]["created"])
        self.assertEqual(duplicate_comment["data"]["comment"]["id"], comment["data"]["comment"]["id"])

        status, comments = request("GET", f"/community/post/{post_id}/comments", headers=headers)
        self.assertEqual(status, 200, comments)
        self.assertEqual(len(comments["data"]["items"]), 1)

        status, subscribed = request(
            "POST",
            "/community/tags/subscribe",
            {"tag": "#retry"},
            headers,
        )
        self.assertEqual(status, 200, subscribed)
        self.assertTrue(subscribed["data"]["subscribed"])

    def test_community_publish_rate_limit(self) -> None:
        token = self.login("user_community_rate_contract")
        headers = self.auth_headers(token)
        for idx in range(10):
            status, posted = request(
                "POST",
                "/community/post",
                {"cardId": f"card_rate_{idx}", "shareText": f"rate limited post {idx}"},
                headers,
            )
            self.assertEqual(status, 200, posted)

        status, limited = request(
            "POST",
            "/community/post",
            {"cardId": "card_rate_limited", "shareText": "rate limited post"},
            headers,
        )
        self.assertEqual(status, 429)
        self.assertEqual(limited["error"]["code"], "42901")

    def test_activity_join_submit_leaderboard_and_tag_distribution(self) -> None:
        token = self.login("user_activity_contract")
        headers = self.auth_headers(token)
        activity_id = "act_cold_joke_001"

        status, missing_activity = request("GET", "/activity/not_real_activity", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_activity["error"]["code"], "40401")

        status, missing_join = request("POST", "/activity/not_real_activity/join", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_join["error"]["code"], "40401")

        status, missing_join_status = request("GET", "/activity/not_real_activity/join-status", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_join_status["error"]["code"], "40401")

        status, missing_leaderboard = request("GET", "/activity/not_real_activity/leaderboard", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_leaderboard["error"]["code"], "40401")

        status, missing_distribution = request("GET", "/activity/not_real_activity/tag-distribution", headers=headers)
        self.assertEqual(status, 404)
        self.assertEqual(missing_distribution["error"]["code"], "40401")

        status, joined = request("POST", f"/activities/{activity_id}/join", headers=headers)
        self.assertEqual(status, 200, joined)
        self.assertEqual(joined["data"]["joinStatus"], "approved")
        first_count = joined["data"]["participantCount"]

        status, join_status = request("GET", f"/activity/{activity_id}/join-status", headers=headers)
        self.assertEqual(status, 200, join_status)
        self.assertEqual(join_status["data"]["joinStatus"], "approved")

        second_token = self.login("user_activity_contract_second")
        second_headers = self.auth_headers(second_token)
        status, second_join = request("POST", f"/activities/{activity_id}/join", headers=second_headers)
        self.assertEqual(status, 200, second_join)
        self.assertEqual(second_join["data"]["participantCount"], first_count + 1)

        status, duplicate_join = request("POST", f"/activities/{activity_id}/join", headers=second_headers)
        self.assertEqual(status, 200, duplicate_join)
        self.assertEqual(duplicate_join["data"]["participantCount"], first_count + 1)

        status, post = request(
            "POST",
            "/community/post",
            {"cardId": "card_activity_contract", "shareText": "activity contract searchable text #contract_activity"},
            headers,
        )
        self.assertEqual(status, 200, post)
        post_id = post["data"]["post"]["id"]

        status, liked = request("POST", f"/community/post/{post_id}/like", headers=headers)
        self.assertEqual(status, 200, liked)
        status, reported = request(
            "POST",
            f"/community/post/{post_id}/report",
            {"reason": "spam", "detail": "activity leaderboard signal"},
            headers,
        )
        self.assertEqual(status, 200, reported)

        submit_body = {"postId": post_id, "tag": "contract_activity"}
        status, submitted = request(
            "POST",
            f"/activities/{activity_id}/submit",
            submit_body,
            self.auth_headers(token, "activity-submit-contract-1"),
        )
        self.assertEqual(status, 200, submitted)
        self.assertTrue(submitted["data"]["created"])
        submission_id = submitted["data"]["submission"]["id"]

        status, duplicate = request(
            "POST",
            f"/activity/{activity_id}/submit",
            submit_body,
            self.auth_headers(token, "activity-submit-contract-2"),
        )
        self.assertEqual(status, 200, duplicate)
        self.assertFalse(duplicate["data"]["created"])
        self.assertEqual(duplicate["data"]["submission"]["id"], submission_id)

        status, leaderboard = request(
            "GET",
            f"/activities/{activity_id}/leaderboard?tag=contract_activity&pageSize=5",
            headers=headers,
        )
        self.assertEqual(status, 200, leaderboard)
        self.assertIn(post_id, [item["id"] for item in leaderboard["data"]["items"]])
        self.assertEqual(leaderboard["data"]["tag"], "contract_activity")
        self.assertEqual(leaderboard["data"]["likeKing"]["postId"], post_id)
        self.assertEqual(leaderboard["data"]["likeKing"]["score"], 1)
        self.assertEqual(leaderboard["data"]["downvoteKing"]["postId"], post_id)
        self.assertEqual(leaderboard["data"]["downvoteKing"]["score"], 1)

        status, distribution = request(
            "GET",
            f"/activity/{activity_id}/tag-distribution?tag=contract_activity",
            headers=headers,
        )
        self.assertEqual(status, 200, distribution)
        self.assertEqual(distribution["data"]["total"], 1)
        self.assertEqual(distribution["data"]["items"][0]["tag"], "contract_activity")

        status, auto_post = request(
            "POST",
            "/community/post",
            {"cardId": "card_activity_auto_contract", "shareText": "auto linked activity #contract_auto_activity"},
            headers,
        )
        self.assertEqual(status, 200, auto_post)
        auto_post_id = auto_post["data"]["post"]["id"]
        status, auto_leaderboard = request(
            "GET",
            f"/activity/{activity_id}/leaderboard?tag=contract_auto_activity",
            headers=headers,
        )
        self.assertEqual(status, 200, auto_leaderboard)
        self.assertIn(auto_post_id, [item["id"] for item in auto_leaderboard["data"]["items"]])

        status, auto_distribution = request(
            "GET",
            f"/activity/{activity_id}/tag-distribution?tag=contract_auto_activity",
            headers=headers,
        )
        self.assertEqual(status, 200, auto_distribution)
        self.assertEqual(auto_distribution["data"]["total"], 1)

    def test_match_unlock_is_idempotent_by_device_day(self) -> None:
        headers = {"X-Device-Id": "device-contract-match"}
        status, locked = request("GET", "/match/same-frequency", headers=headers)
        self.assertEqual(status, 403)
        self.assertEqual(locked["error"]["code"], "40301")

        status, unlocked = request(
            "POST",
            "/match/unlock",
            {"trigger": "shake"},
            headers,
        )
        self.assertEqual(status, 200, unlocked)
        self.assertTrue(unlocked["data"]["unlocked"])
        first_token = unlocked["data"]["unlockToken"]

        status, duplicate = request(
            "POST",
            "/match/unlock",
            {"trigger": "shake"},
            headers,
        )
        self.assertEqual(status, 200, duplicate)
        self.assertEqual(duplicate["data"]["unlockToken"], first_token)

        status, radar = request("GET", "/match/radar/status", headers=headers)
        self.assertEqual(status, 200, radar)
        self.assertEqual(radar["data"]["unlockToken"], first_token)

        status, same_frequency = request("GET", "/match/same-frequency?tab=users", headers=headers)
        self.assertEqual(status, 200, same_frequency)
        self.assertEqual(same_frequency["data"]["tab"], "users")
        self.assertGreaterEqual(len(same_frequency["data"]["items"]), 1)

        status, bad_tab = request("GET", "/match/same-frequency?tab=nearby", headers=headers)
        self.assertEqual(status, 400)
        self.assertEqual(bad_tab["error"]["code"], "40001")

    def test_liuyao_engine_returns_structured_neutral_reading(self) -> None:
        sys.path.insert(0, str(BACKEND))
        from liuyao_engine import build_reading

        reading = build_reading([1, 0, 1, 1, 0, 1], [2, 5], "career").to_json()
        self.assertEqual(reading["movingLines"], [2, 5])
        self.assertIn("original", reading)
        self.assertIn("changed", reading)
        self.assertIn("tagFocus", reading)
        self.assertIn("not a prediction", reading["neutralReminder"])


if __name__ == "__main__":
    unittest.main()
