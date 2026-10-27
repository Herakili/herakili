#!/usr/bin/env python3
"""Minimal Warcraft Logs API v2 client (client-credentials flow) for checking Herakili priorities against raid logs.

Credentials: ~/.config/wcl/credentials with WCL_CLIENT_ID=... and WCL_CLIENT_SECRET=... (never printed or stored here).
Sites: "vanilla" (Classic Era / Hardcore), "fresh" (Anniversary), "classic", "sod", "www".

    from wcl import WCL
    api = WCL("vanilla")
    api.query("{ rateLimitData { limitPerHour pointsSpentThisHour } }")
"""
import base64, json, os, sys, time, urllib.error, urllib.parse, urllib.request

CRED_FILE = os.path.expanduser("~/.config/wcl/credentials")
TOKEN_CACHE = os.path.expanduser("~/.cache/wcl/token.json")


def _credentials():
    creds = {}
    with open(CRED_FILE) as f:
        for line in f:
            if "=" in line:
                k, v = line.strip().split("=", 1)
                creds[k] = v
    cid, secret = creds.get("WCL_CLIENT_ID"), creds.get("WCL_CLIENT_SECRET")
    if not cid or not secret or cid.startswith("PASTE_"):
        sys.exit(f"No Warcraft Logs credentials in {CRED_FILE}")
    return cid, secret


def _token():
    try:
        with open(TOKEN_CACHE) as f:
            cached = json.load(f)
        if cached["expires"] > time.time() + 300:
            return cached["token"]
    except (OSError, ValueError, KeyError):
        pass
    cid, secret = _credentials()
    req = urllib.request.Request(
        "https://www.warcraftlogs.com/oauth/token",
        data=urllib.parse.urlencode({"grant_type": "client_credentials"}).encode(),
        headers={"Authorization": "Basic " + base64.b64encode(f"{cid}:{secret}".encode()).decode(),
                 "User-Agent": "Herakili-analysis"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    os.makedirs(os.path.dirname(TOKEN_CACHE), exist_ok=True)
    fd = os.open(TOKEN_CACHE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"token": data["access_token"], "expires": time.time() + data.get("expires_in", 3600)}, f)
    return data["access_token"]


class WCL:
    def __init__(self, site="vanilla"):
        self.url = f"https://{site}.warcraftlogs.com/api/v2/client"

    def query(self, q, variables=None, retries=4):
        body = json.dumps({"query": q, "variables": variables or {}}).encode()
        for attempt in range(retries):
            req = urllib.request.Request(self.url, data=body, headers={
                "Authorization": "Bearer " + _token(), "Content-Type": "application/json",
                "User-Agent": "Herakili-analysis"})
            try:
                with urllib.request.urlopen(req, timeout=60) as r:
                    data = json.load(r)
            except urllib.error.HTTPError as e:
                if e.code == 429 and attempt < retries - 1:
                    time.sleep(30 * (attempt + 1))
                    continue
                raise SystemExit(f"HTTP {e.code} from {self.url}: {e.read()[:300]!r}")
            if data.get("errors"):
                raise SystemExit(f"GraphQL errors: {json.dumps(data['errors'])[:600]}")
            return data["data"]


if __name__ == "__main__":
    for site in sys.argv[1:] or ["vanilla"]:
        d = WCL(site).query("{ rateLimitData { limitPerHour pointsSpentThisHour pointsResetIn } }")
        print(site, d["rateLimitData"])
