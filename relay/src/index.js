// The Phone Use push relay (docs/PUSH-RELAY.md). It holds the APNs key, so released PCs can push to the
// companion app without it. The app registers its push tokens under an id (rid) and a key (R) that it and
// its PC derive from their pairing key; the PC signs each push with R and names a token slot, never a token.
// Payloads come from fixed templates plus the PC's sealed blob, which this relay can't read.

const HOSTS = { production: "https://api.push.apple.com", sandbox: "https://api.sandbox.push.apple.com" };
const CLOCK_SKEW = 60; // seconds
const KEEP = 30 * 86400; // a registration lasts 30 days without a refresh
const REFRESH = 7 * 86400; // rewrite an unchanged registration after a week, so it doesn't expire
const MAX_SEALED = 2048;

const ALERTS = {
  ask: { title: "Phone Use", body: "An agent asks to use your iPhone" },
  warning: { title: "Phone Use", body: "Phone Use needs your attention" },
  start: { title: "Phone Use", body: "Mirroring to your computer" },
};

// kind -> token slot, push type, priority
const KINDS = {
  "activity-start": { slot: "push_to_start", type: "liveactivity" },
  "activity-update": { slot: "activity", type: "liveactivity" },
  "activity-end": { slot: "activity", type: "liveactivity" },
  session: { slot: "device", type: "alert" },
  unlock: { slot: "device", type: "alert" },
  "request-over": { slot: "device", type: "background", priority: 5 },
};

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
const fail = (status, error) => json({ error }, status);

const enc = new TextEncoder();
const hex = (buf) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
const b64url = (bytes) =>
  btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const unb64url = (s) => {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  return Uint8Array.from(atob(s + "=".repeat((4 - (s.length % 4)) % 4)), (c) => c.charCodeAt(0));
};
const sha256 = (data) => crypto.subtle.digest("SHA-256", typeof data === "string" ? enc.encode(data) : data);

async function hmacHex(keyBytes, text) {
  const k = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", k, enc.encode(text)));
}

function sameText(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

// The companion API's signature (docs/COMPANION.md, "Signing requests"), keyed with R.
async function verify(req, url, body, keyBytes) {
  const t = req.headers.get("x-pu-time"), nonce = req.headers.get("x-pu-nonce"), sig = req.headers.get("x-pu-sig");
  if (!t || !nonce || !sig) return false;
  if (Math.abs(Date.now() / 1000 - Number(t)) > CLOCK_SKEW) return false;
  const msg = `${req.method}\n${url.pathname}${url.search}\n${t}\n${nonce}\n${hex(await sha256(body))}`;
  return sameText(await hmacHex(keyBytes, msg), sig.toLowerCase());
}

// ---- APNs ----
let jwtCache = { token: null, iat: 0 };

async function apnsJwt(env) {
  const now = Math.floor(Date.now() / 1000);
  if (jwtCache.token && now - jwtCache.iat < 2700) return jwtCache.token;
  // One JWT for every isolate: Apple refuses a key whose token changes more often than every 20 minutes.
  const shared = await env.PHONES.get("_jwt", "json");
  if (shared && now - shared.iat < 2400) return (jwtCache = shared).token;
  const pem = env.APNS_KEY.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const key = await crypto.subtle.importKey("pkcs8", unb64url(pem.replace(/\+/g, "-").replace(/\//g, "_")),
    { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const head = b64url(enc.encode(JSON.stringify({ alg: "ES256", kid: env.APNS_KEY_ID })));
  const claims = b64url(enc.encode(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: now })));
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(`${head}.${claims}`));
  jwtCache = { token: `${head}.${claims}.${b64url(sig)}`, iat: now };
  await env.PHONES.put("_jwt", JSON.stringify(jwtCache), { expirationTtl: 3600 });
  return jwtCache.token;
}

async function apnsSend(env, apnsEnv, token, payload, topic, type, priority) {
  try {
    const r = await fetch(`${HOSTS[apnsEnv] || HOSTS.production}/3/device/${token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${await apnsJwt(env)}`,
        "apns-topic": topic,
        "apns-push-type": type,
        "apns-priority": String(priority),
      },
      body: JSON.stringify(payload),
    });
    const text = await r.text();
    let reason = "";
    try { reason = text ? JSON.parse(text).reason || "" : ""; } catch { reason = text.slice(0, 100); }
    return [r.status, reason];
  } catch (e) {
    return [0, `${e.name}: ${e.message}`];
  }
}

// ---- payloads ----
// The plain fields the app needs even when it can't decrypt (the state machine, the step count, request ids);
// the agent's action, warnings and the PC's name are only ever in `sealed`.
const ID = /^[A-Za-z0-9_-]{1,64}$/;
const WORD = /^[a-z]{1,16}$/;
const num = (v) => (typeof v === "number" && isFinite(v) ? v : null);

function contentState(b) {
  const c = b.state || {};
  return {
    sealed: b.sealed,
    state: WORD.test(c.state) ? c.state : "driving",
    phase: WORD.test(c.phase) ? c.phase : null,
    steps: Math.max(0, Math.min(1e6, c.steps | 0)),
    requestId: ID.test(c.requestId || "") ? c.requestId : "",
    deadline: num(c.deadline),
    startedAt: num(c.startedAt) ?? Date.now() / 1000,
    updatedAt: num(c.updatedAt) ?? Date.now() / 1000,
    frame: c.frame | 0,
  };
}

function buildPayload(kind, b) {
  if (kind.startsWith("activity-")) {
    const aps = {
      timestamp: Math.floor(num(b.timestamp) ?? Date.now() / 1000),
      "relevance-score": 100,
      "content-state": contentState(b),
    };
    if (kind === "activity-start") {
      Object.assign(aps, {
        event: "start",
        "attributes-type": "AgentActivityAttributes",
        attributes: { pcName: "", sealed: typeof b.attributes === "string" ? b.attributes.slice(0, MAX_SEALED) : "" },
        alert: ALERTS[b.alert] || ALERTS.start,
      });
    } else if (kind === "activity-update") {
      aps.event = "update";
      if (ALERTS[b.alert]) aps.alert = { ...ALERTS[b.alert], sound: "default" };
    } else {
      aps.event = "end";
      aps["dismissal-date"] = Math.floor(num(b.dismissal_date) ?? Date.now() / 1000);
    }
    return { aps };
  }
  const id = ID.test(b.id || "") ? b.id : "";
  if (kind === "session") {
    return {
      aps: { alert: ALERTS.ask, category: "SESSION", sound: "default", "interruption-level": "time-sensitive",
             "mutable-content": 1 },
      session_id: id, sealed: b.sealed,
    };
  }
  if (kind === "unlock") {
    return {
      aps: { alert: { title: "Unlock the iPhone?", body: "An agent asks to enter your saved passcode." },
             category: "UNLOCK", sound: "default", "mutable-content": 1 },
      unlock_id: id, sealed: b.sealed,
    };
  }
  return { aps: { "content-available": 1 }, request_over: { kind: b.over === "unlock" ? "unlock" : "session", id } };
}

// ---- handlers ----
async function register(req, env, url, rid, body) {
  const ip = req.headers.get("cf-connecting-ip") || "";
  if (!(await env.REGISTER_LIMIT.limit({ key: ip })).success) return fail(429, "too many registrations");
  let b;
  try { b = JSON.parse(new TextDecoder().decode(body)); } catch { return fail(400, "bad JSON"); }
  let rec = await env.PHONES.get(`p:${rid}`, "json");
  let keyBytes;
  if (!rec) {
    if (typeof b.key !== "string") return fail(404, "not registered");
    keyBytes = unb64url(b.key);
    if (keyBytes.length !== 32 || hex(await sha256(keyBytes)).slice(0, 32) !== rid) return fail(400, "key doesn't match id");
    rec = { key: b.key, token_env: {} };
  } else {
    keyBytes = unb64url(rec.key);
  }
  if (!(await verify(req, url, body, keyBytes))) return fail(401, "bad signature");
  if (b.bundle_id && b.bundle_id !== env.BUNDLE_ID) return fail(400, "unknown app");

  const before = JSON.stringify(rec);
  rec.token_env = rec.token_env || {};
  if (b.env && b.env !== rec.env) {
    rec.env = b.env === "sandbox" ? "sandbox" : "production";
    rec.token_env = {};
  }
  for (const k of ["device", "push_to_start"]) {
    if (typeof b[k] === "string" && /^[0-9a-f]{16,200}$/i.test(b[k]) && b[k] !== rec[k]) {
      rec[k] = b[k];
      delete rec.token_env[k];
    }
  }
  const a = b.activity;
  if (a && typeof a.id === "string" && typeof a.token === "string" && /^[0-9a-f]{16,200}$/i.test(a.token)
      && (!rec.activity || rec.activity.token !== a.token || rec.activity.id !== a.id)) {
    rec.activity = { id: a.id.slice(0, 100), token: a.token };
    delete rec.token_env.activity;
  }
  const now = Math.floor(Date.now() / 1000);
  if (JSON.stringify(rec) !== before || now - (rec.updated || 0) > REFRESH) {
    rec.updated = now;
    await env.PHONES.put(`p:${rid}`, JSON.stringify(rec), { expirationTtl: KEEP });
  }
  return json({ ok: true });
}

async function unregister(req, env, url, rid, body) {
  const rec = await env.PHONES.get(`p:${rid}`, "json");
  if (!rec) return json({ ok: true });
  if (!(await verify(req, url, body, unb64url(rec.key)))) return fail(401, "bad signature");
  await env.PHONES.delete(`p:${rid}`);
  return json({ ok: true });
}

async function push(req, env, url, rid, body) {
  if (env.PAUSED) return fail(503, "the relay is paused");
  const rec = await env.PHONES.get(`p:${rid}`, "json");
  if (!rec) return fail(404, "not registered");
  if (!(await verify(req, url, body, unb64url(rec.key)))) return fail(401, "bad signature");
  if (await env.PHONES.get(`block:${rid}`)) return fail(403, "blocked");
  let b;
  try { b = JSON.parse(new TextDecoder().decode(body)); } catch { return fail(400, "bad JSON"); }
  const k = KINDS[b.kind];
  if (!k) return fail(400, "unknown kind");
  if (b.sealed !== undefined && (typeof b.sealed !== "string" || b.sealed.length > MAX_SEALED)) return fail(400, "sealed too long");
  const limiter = k.type === "liveactivity" ? env.ACTIVITY_LIMIT : env.ALERT_LIMIT;
  if (!(await limiter.limit({ key: rid })).success) return fail(429, "too many pushes");

  let token = rec[k.slot];
  if (k.slot === "activity") {
    if (!rec.activity || (b.activity_id && rec.activity.id !== b.activity_id)) return json({ status: 410, reason: "NoActivity" });
    token = rec.activity.token;
  }
  if (!token) return json({ status: 410, reason: "NoToken" });

  const topic = k.type === "liveactivity" ? `${env.BUNDLE_ID}.push-type.liveactivity` : env.BUNDLE_ID;
  const priority = k.priority || (b.priority === 5 ? 5 : 10);
  const payload = buildPayload(b.kind, b);
  const apnsEnv = (rec.token_env || {})[k.slot] || rec.env || "production";
  let r = await apnsSend(env, apnsEnv, token, payload, topic, k.type, priority);
  let changed = false;
  if (r[0] === 400 && r[1] === "BadDeviceToken") {
    // a token from another build can belong to the other APNs environment
    const other = apnsEnv === "sandbox" ? "production" : "sandbox";
    const r2 = await apnsSend(env, other, token, payload, topic, k.type, priority);
    if (r2[0] === 200) {
      rec.token_env = { ...(rec.token_env || {}), [k.slot]: other };
      changed = true;
    }
    r = r2[0] === 200 ? r2 : r;
  }
  const gone = r[0] === 410 || (r[0] === 400 && r[1] === "BadDeviceToken");
  if (gone || (b.kind === "activity-end" && r[0] === 200)) {
    if (k.slot === "activity") delete rec.activity; else delete rec[k.slot];
    changed = true;
  }
  if (changed) await env.PHONES.put(`p:${rid}`, JSON.stringify(rec), { expirationTtl: KEEP });
  console.log(JSON.stringify({ rid: rid.slice(0, 8), kind: b.kind, status: r[0], reason: r[1] }));
  return json({ status: r[0], reason: r[1] });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const m = url.pathname.match(/^\/v1\/(phones|push)\/([0-9a-f]{32})$/);
    if (!m) return url.pathname === "/" ? new Response("Phone Use push relay\n") : fail(404, "not found");
    const [, what, rid] = m;
    const body = new Uint8Array(await req.arrayBuffer());
    if (body.length > 8192) return fail(413, "too large");
    if (what === "phones" && req.method === "PUT") return register(req, env, url, rid, body);
    if (what === "phones" && req.method === "DELETE") return unregister(req, env, url, rid, body);
    if (what === "push" && req.method === "POST") return push(req, env, url, rid, body);
    return fail(405, "method not allowed");
  },
};
