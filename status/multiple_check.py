#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Check-only tool for Multipass Airdrop (Multiple.cc)
Outputs lines in the format:
    private_key;address;amountMTP
If there is no allocation (API 500 or missing data) -> amount = 0
"""

import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests
from dotenv import load_dotenv
from eth_account import Account

load_dotenv()

CLAIM_API_URL = os.getenv("CLAIM_API_URL", "https://multipass.multiple.cc/api/reward/airdrop/signature")
AUTH_HEADER = os.getenv("CLAIM_AUTH_HEADER")
RAW_COOKIE = os.getenv("CLAIM_COOKIE")
KEYS_FILE = os.getenv("KEYS_FILE", "keys.txt")
MAX_WORKERS = int(os.getenv("MAX_WORKERS", "8"))

HEADERS = {"User-Agent": "claim-check/1.1"}
if AUTH_HEADER:
    HEADERS["Authorization"] = AUTH_HEADER
if RAW_COOKIE:
    HEADERS["Cookie"] = RAW_COOKIE

session = requests.Session()

def load_keys(path: str):
    if not os.path.exists(path):
        print(f"no keys file: {path}", file=sys.stderr)
        sys.exit(1)
    keys = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            keys.append(s)
    # dedupe keeping order
    seen = set()
    deduped = []
    for k in keys:
        k_norm = k.lower()
        if k_norm in seen:
            continue
        seen.add(k_norm)
        deduped.append(k)
    return deduped

def addr_from_pk(pk: str) -> str:
    _pk = pk[2:] if pk.startswith("0x") else pk
    acct = Account.from_key(bytes.fromhex(_pk))
    return acct.address

def fetch_amount(addr: str) -> int:
    """Return reward_amount in WEI. If no allocation -> 0"""
    try:
        r = session.get(CLAIM_API_URL, params={"user_address": addr}, headers=HEADERS, timeout=20)
        if r.status_code == 500:
            return 0
        r.raise_for_status()
        data = r.json().get("data", {})
        amt_str = data.get("reward_amount")
        if amt_str is None:
            return 0
        return int(amt_str)
    except Exception:
        return 0

def process_key(pk: str) -> str:
    addr = addr_from_pk(pk)
    amount_wei = fetch_amount(addr)
    amount_mtp = int(amount_wei // 10**18)  # округляем до целых токенов
    return f"{pk};{addr};{amount_mtp}"

def main():
    keys = load_keys(KEYS_FILE)
    results = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futs = [ex.submit(process_key, pk) for pk in keys]
        for fut in as_completed(futs):
            results.append(fut.result())

    # preserve original order
    order_map = {k: i for i, k in enumerate(keys)}
    results.sort(key=lambda line: order_map.get(line.split(";")[0], 1e12))

    for line in results:
        print(line)

    with open("claim_check_output.csv", "w", encoding="utf-8") as f:
        for line in results:
            f.write(line + "\n")

if __name__ == "__main__":
    main()
