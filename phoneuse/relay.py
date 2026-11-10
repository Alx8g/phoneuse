"""Pushes through the Phone Use push relay (docs/PUSH-RELAY.md), for PCs without an APNs key.

The relay holds the key. The app registers its push tokens there under an id and a key derived from its
pairing key; this PC signs each push with the same derived key, names a token slot instead of a token, and
seals everything the owner would see with another derived key that the relay never gets.

`send()` takes the same APNs payload that apns.send() does and turns it into the relay's request, so
companion.py builds one payload for both paths.
"""
import base64
import hashlib
import hmac
import http.client
import json
import os
import secrets
import ssl
import threading
import time
import urllib.parse

URL = os.environ.get("PHONEUSE_RELAY", "https://phoneuse-push.lxe.workers.dev")

_lock = threading.Lock()
_conn = None


def _hkdf(key, info):
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.kdf.hkdf import HKDF
    return HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=info).derive(key)


def keys(pairing_key):
    """(relay key R, relay id, push seal key S) for one pairing."""
    r = _hkdf(pairing_key, b"phoneuse relay")
    return r, hashlib.sha256(r).hexdigest()[:32], _hkdf(pairing_key, b"phoneuse push seal")


def seal(s_key, obj, ad):
    """AES-256-GCM over the JSON of obj: base64 of nonce(12) | ciphertext | tag(16)."""
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    nonce = secrets.token_bytes(12)
    raw = json.dumps(obj, separators=(",", ":")).encode()
    return base64.b64encode(nonce + AESGCM(s_key).encrypt(nonce, raw, ad.encode())).decode()


def unseal(s_key, sealed, ad):  # for tests: the app does this side
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    raw = base64.b64decode(sealed)
    return json.loads(AESGCM(s_key).decrypt(raw[:12], raw[12:], ad.encode()))


def _ssl_context():
    ctx = ssl.create_default_context()
    paths = ssl.get_default_verify_paths()
    # The Mac app's relocatable Python has no CA directory of its own; macOS keeps one at /etc/ssl/cert.pem
    if not (paths.cafile or (paths.capath and os.path.isdir(paths.capath))) and os.path.exists("/etc/ssl/cert.pem"):
        ctx.load_verify_locations("/etc/ssl/cert.pem")
    return ctx


def request(method, path, r_key, body=None):
    """One signed request to the relay over a kept-open HTTPS connection (the standard library's, so the Mac
    app needs no extra module). Returns (status, json)."""
    global _conn
    raw = json.dumps(body).encode() if body is not None else b""
    t, nonce = str(int(time.time())), secrets.token_hex(16)
    msg = f"{method}\n{path}\n{t}\n{nonce}\n{hashlib.sha256(raw).hexdigest()}".encode()
    headers = {"X-PU-Time": t, "X-PU-Nonce": nonce, "X-PU-Sig": hmac.new(r_key, msg, hashlib.sha256).hexdigest(),
               "Content-Type": "application/json", "User-Agent": "phoneuse"}
    u = urllib.parse.urlsplit(URL)
    with _lock:
        for attempt in (0, 1):  # a kept-open connection the server closed fails once; then a new one
            try:
                if _conn is None:
                    _conn = http.client.HTTPSConnection(u.hostname, u.port or 443, timeout=10, context=_ssl_context())
                _conn.request(method, u.path.rstrip("/") + path, body=raw, headers=headers)
                r = _conn.getresponse()
                data = r.read()
                try:
                    return r.status, json.loads(data)
                except ValueError:
                    return r.status, {"error": data[:200].decode(errors="replace")}
            except (OSError, http.client.HTTPException) as e:
                if _conn:
                    _conn.close()
                _conn = None
                if attempt:
                    return 0, {"error": f"{type(e).__name__}: {e}"}


def register(pairing_key, fields, first=False):
    """What the app does: register its tokens. For tests and the mock."""
    r, rid, _ = keys(pairing_key)
    body = dict(fields)
    if first:
        body["key"] = base64.urlsafe_b64encode(r).rstrip(b"=").decode()
    return request("PUT", f"/v1/phones/{rid}", r, body)


def unregister(pairing_key):
    r, rid, _ = keys(pairing_key)
    return request("DELETE", f"/v1/phones/{rid}", r)


# What stays plain: the app needs these to work even when it can't decrypt (see docs/PUSH-RELAY.md, "Payload
# privacy"). The agent's action, a warning's text and the PC's name are sealed.
PLAIN = ("state", "phase", "steps", "requestId", "deadline", "startedAt", "updatedAt", "frame")


def relay_request(payload, push_type, s_key, priority=10):
    """The relay's request body for one APNs payload (as companion.py builds it)."""
    aps = payload.get("aps", {})
    if push_type == "liveactivity":
        event = aps.get("event")
        kind = {"start": "activity-start", "update": "activity-update", "end": "activity-end"}[event]
        cs = aps.get("content-state", {})
        body = {"kind": kind, "timestamp": aps.get("timestamp"), "priority": priority,
                "state": {k: cs[k] for k in PLAIN if cs.get(k) is not None},
                "sealed": seal(s_key, {k: v for k, v in cs.items() if k not in PLAIN}, "activity")}
        if event == "start":
            body["attributes"] = seal(s_key, aps.get("attributes", {}), "attributes")
        elif aps.get("alert") and event == "update":
            body["alert"] = "ask" if cs.get("state") == "asking" else "warning"
        if event == "end":
            body["dismissal_date"] = aps.get("dismissal-date")
        return body
    if push_type == "background":
        over = payload.get("request_over", {})
        return {"kind": "request-over", "over": over.get("kind"), "id": over.get("id")}
    # an alert: a session or unlock request
    kind = "session" if aps.get("category") == "SESSION" else "unlock"
    return {"kind": kind, "id": payload.get("session_id") or payload.get("unlock_id"),
            "sealed": seal(s_key, aps.get("alert", {}), "alert")}


def send(pairing_key, payload, push_type, field, priority=10, activity_id=None):
    """Send one push through the relay. Returns (status, reason) like apns.send(): APNs's status when the
    relay reached Apple, or the relay's own status and error when it refused."""
    r, rid, s = keys(pairing_key)
    body = relay_request(payload, push_type, s, priority)
    if activity_id:
        body["activity_id"] = activity_id
    status, out = request("POST", f"/v1/push/{rid}", r, body)
    if status == 200:
        return out.get("status", 0), out.get("reason", "")
    return status, "relay: " + str(out.get("error", ""))
