# The push relay

The Cloudflare Worker that sends Apple push notifications for PCs without an APNs key
([docs/PUSH-RELAY.md](../docs/PUSH-RELAY.md)). It runs at `https://phoneuse-push.lxe.workers.dev`, on
the account in `wrangler.toml`, with one KV namespace (`PHONES`) and the APNs key as the secret `APNS_KEY`.

## Deploy

```
cd relay
CLOUDFLARE_API_TOKEN=… npx wrangler deploy
```

The key, once (or to replace it): `npx wrangler secret put APNS_KEY < AuthKey_XXXXXXXXXX.p8`, and set
`APNS_KEY_ID` in `wrangler.toml` to the key's id.

## Operate

- Logs: `npx wrangler tail` shows one line per push (the `rid`'s first 8 characters, kind, APNs status).
- Stop every push: set `PAUSED = "1"` in `wrangler.toml` and deploy.
- Stop one pairing: `npx wrangler kv key put --binding PHONES "block:<rid>" 1 --remote`.

## Test

`phoneuse/relay.py` has `register()` and `unregister()`, which do what the app does, so a script can register
fake tokens under a random pairing key and push to them. Apple answers `BadDeviceToken` for each push, which
shows the relay reached APNs.
