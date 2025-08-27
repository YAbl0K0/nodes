#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Multipass Airdrop batch claimer for BSC (Multiple.cc)
- Fetches signed claim params from:
  https://multipass.multiple.cc/api/reward/airdrop/signature?user_address=0x...
- Sends contract claim(index, amount, expireAt, signature) to proxy: 0x507d8ea248224e332CD8292Fadf527Df852f3632
- Checks gas cost in USD via Chainlink BNB/USD and aborts if above MAX_TX_FEE_USD
Tested with web3.py v6.*
"""

import os
import time
import random
from decimal import Decimal, getcontext

import requests
from dotenv import load_dotenv
from web3 import Web3
from eth_account import Account
from eth_account.signers.local import LocalAccount
from web3.exceptions import ContractLogicError

getcontext().prec = 40  # high precision for fee math
load_dotenv()

# ========= Settings =========
BSC_RPC = os.getenv("BSC_RPC", "https://bsc-dataseed.binance.org")
CHAIN_ID = int(os.getenv("CHAIN_ID", "56"))

# Contract (proxy) and minimal ABI for claim(index, amount, expireAt, signature)
CLAIM_CONTRACT = Web3.to_checksum_address("0x507d8ea248224e332CD8292Fadf527Df852f3632")
CLAIM_ABI = [{
    "name":"claim",
    "type":"function",
    "stateMutability":"nonpayable",
    "inputs":[
        {"name":"index","type":"uint256"},
        {"name":"amount","type":"uint256"},
        {"name":"expireAt","type":"uint256"},
        {"name":"signature","type":"bytes"}
    ],
    "outputs":[]
}]

# API endpoint discovered (GET with user_address)
CLAIM_API_URL = os.getenv("CLAIM_API_URL", "https://multipass.multiple.cc/api/reward/airdrop/signature")

# Optional headers/cookies if they ever become required
AUTH_HEADER = os.getenv("CLAIM_AUTH_HEADER")  # "Bearer ..."
RAW_COOKIE = os.getenv("CLAIM_COOKIE")        # "cf_clearance=...; session=..."

HEADERS = {"User-Agent": "multipass-claimer/1.1"}
if AUTH_HEADER:
    HEADERS["Authorization"] = AUTH_HEADER
if RAW_COOKIE:
    HEADERS["Cookie"] = RAW_COOKIE

# Gas settings
GAS_LIMIT = int(os.getenv("GAS_LIMIT", "260000"))
WAIT_TIMEOUT = int(os.getenv("WAIT_TIMEOUT", "180"))  # seconds to wait for receipt
TTL_WARN = int(os.getenv("TTL_WARN", "45"))           # warn if signature TTL is below this

# Gas USD threshold
MAX_TX_FEE_USD = Decimal(os.getenv("MAX_TX_FEE_USD", "0.05"))  # abort if estimated fee > this
# Chainlink BNB/USD oracle on BSC mainnet (8 decimals). Override via env if needed.
BNB_USD_ORACLE = Web3.to_checksum_address(os.getenv("BNB_USD_ORACLE", "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE"))
# Manual price override (skip oracle if set), e.g. BNB_USD_PRICE=600.12
BNB_USD_PRICE_OVERRIDE = os.getenv("BNB_USD_PRICE")

# Input file with private keys (one per line; with or without 0x)
KEYS_FILE = os.getenv("KEYS_FILE", "keys.txt")


# ========= Web3 setup =========
w3 = Web3(Web3.HTTPProvider(BSC_RPC))
if not w3.is_connected():
    raise SystemExit("RPC is not reachable. Check BSC_RPC")

contract = w3.eth.contract(address=CLAIM_CONTRACT, abi=CLAIM_ABI)
session = requests.Session()

# Chainlink AggregatorV3Interface minimal ABI
AGG_V3_ABI = [
    {"inputs": [], "name": "decimals", "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}], "stateMutability": "view", "type": "function"},
    {"inputs": [], "name": "latestRoundData", "outputs": [
        {"internalType": "uint80", "name": "roundId", "type": "uint80"},
        {"internalType": "int256", "name": "answer", "type": "int256"},
        {"internalType": "uint256", "name": "startedAt", "type": "uint256"},
        {"internalType": "uint256", "name": "updatedAt", "type": "uint256"},
        {"internalType": "uint80", "name": "answeredInRound", "type": "uint80"}
    ], "stateMutability": "view", "type": "function"}
]


def get_bnb_usd_price() -> Decimal:
    """Return BNB price in USD as Decimal. Uses override if provided; otherwise Chainlink oracle."""
    if BNB_USD_PRICE_OVERRIDE:
        return Decimal(BNB_USD_PRICE_OVERRIDE)

    oracle = w3.eth.contract(address=BNB_USD_ORACLE, abi=AGG_V3_ABI)
    decimals = oracle.functions.decimals().call()
    _, answer, _, updatedAt, _ = oracle.functions.latestRoundData().call()
    if int(answer) <= 0:
        raise RuntimeError("Invalid price from oracle")
    price = Decimal(int(answer)) / (Decimal(10) ** Decimal(decimals))
    # Optional: ensure price isn't too stale (e.g., older than 24h)
    now = int(time.time())
    if now - int(updatedAt) > 24 * 3600:
        print(f"[warn] Oracle price is older than 24h (updatedAt={updatedAt})")
    return price


def backoff_sleep(base: float, attempt: int) -> None:
    # simple exponential backoff with jitter
    delay = base * (2 ** attempt) * (0.8 + 0.4 * random.random())
    time.sleep(delay)


def fetch_claim_params(addr: str) -> dict:
    """
    Call: GET https://multipass.multiple.cc/api/reward/airdrop/signature?user_address=0x...
    Expected JSON:
      {
        "data": {
          "user_address": "0x...",
          "round": 1,
          "reward_amount": "36080000000000000000",
          "expiration_time": 1756299322,
          "signature": "0x..."
        }
      }
    """
    url = CLAIM_API_URL
    params = {"user_address": addr}

    # Retry 5 times on 429/5xx
    for attempt in range(5):
        resp = session.get(url, params=params, headers=HEADERS, timeout=25)
        if resp.status_code in (429, 500, 502, 503, 504):
            if attempt == 4:
                resp.raise_for_status()
            print(f"[{addr}] HTTP {resp.status_code} → retrying...")
            backoff_sleep(1.5, attempt)
            continue
        resp.raise_for_status()
        data = resp.json()
        break

    d = data.get("data") or {}
    # Map API fields to contract call
    index = int(d.get("round"))
    amount = int(d.get("reward_amount"))
    expireAt = int(d.get("expiration_time"))
    sig = d.get("signature")
    if not sig or not sig.startswith("0x"):
        raise ValueError("Invalid signature in API response")
    return {"index": index, "amount": amount, "expireAt": expireAt, "signature": sig}


def simulate_claim(addr: str, p: dict) -> None:
    """ eth_call to pre-catch obvious reverts (already claimed / not eligible / expired). """
    try:
        contract.functions.claim(
            p["index"], p["amount"], p["expireAt"], bytes.fromhex(p["signature"][2:])
        ).call({"from": addr})
    except ContractLogicError as e:
        # surface revert reason if available
        raise RuntimeError(f"simulate revert: {e}") from e


def load_keys(path: str) -> list[str]:
    if not os.path.exists(path):
        raise FileNotFoundError(f"No keys file: {path}")
    keys = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            if s.startswith("0x"):
                s = s[2:]
            if len(s) != 64:
                print(f"[warn] Unexpected private key length (skip): {s[:6]}...")
                continue
            keys.append(s)
    # deduplicate keeping order
    seen = set()
    uniq = []
    for k in keys:
        if k in seen:
            continue
        seen.add(k)
        uniq.append(k)
    return uniq


def estimate_fee_usd(addr: str, params: dict) -> tuple[int, int, Decimal, Decimal, Decimal]:
    """
    Return (gas_est, gas_price_wei, fee_bnb, price_usd, fee_usd)
    """
    tx_params = {"from": addr, "chainId": CHAIN_ID, "value": 0}
    gas_price_wei = int(w3.eth.gas_price)
    # try estimate_gas; if it fails, fall back to GAS_LIMIT
    try:
        gas_est = contract.functions.claim(
            params["index"], params["amount"], params["expireAt"], bytes.fromhex(params["signature"][2:])
        ).estimate_gas(tx_params)
    except Exception:
        gas_est = GAS_LIMIT

    fee_wei = gas_est * gas_price_wei
    fee_bnb = Decimal(fee_wei) / Decimal(10**18)
    price_usd = get_bnb_usd_price()
    fee_usd = fee_bnb * price_usd
    return gas_est, gas_price_wei, fee_bnb, price_usd, fee_usd


def do_claim(pk_hex: str) -> str:
    acct: LocalAccount = Account.from_key(bytes.fromhex(pk_hex))
    addr = acct.address

    # Get claim params from backend
    try:
        params = fetch_claim_params(addr)
    except Exception as e:
        return f"[{addr}] Failed to fetch claim params: {e}"

    ttl = params["expireAt"] - int(time.time())
    human_amt = Decimal(params["amount"]) / Decimal(10**18)
    print(f"[{addr}] index={params['index']} amount={human_amt} MTP TTL={ttl}s")

    if ttl < TTL_WARN:
        print(f"[{addr}] ⚠ Signature expiring soon (TTL={ttl}s). Sending immediately.")

    # quick simulation
    try:
        simulate_claim(addr, params)
    except Exception as e:
        return f"[{addr}] Pre-check failed: {e}"

    # Gas check in USD
    try:
        gas_est, gas_price_wei, fee_bnb, price_usd, fee_usd = estimate_fee_usd(addr, params)
        gwei = Decimal(gas_price_wei) / Decimal(10**9)
        print(f"[{addr}] gas_est≈{gas_est} | gas_price≈{gwei:.2f} gwei | est_fee≈{fee_bnb:.6f} BNB ≈ ${fee_usd:.4f} (BNB ${price_usd:.2f})")
        if fee_usd > MAX_TX_FEE_USD:
            return f"[{addr}] ❌ Estimated fee ${fee_usd:.4f} > limit ${MAX_TX_FEE_USD} — aborting"
    except Exception as e:
        return f"[{addr}] Gas check failed: {e}"

    # Build & send tx
    try:
        nonce = w3.eth.get_transaction_count(addr)
        gas_price = int(gas_price_wei)  # use the same as estimated
        tx = contract.functions.claim(
            params["index"], params["amount"], params["expireAt"], bytes.fromhex(params["signature"][2:])
        ).build_transaction({
            "from": addr,
            "chainId": CHAIN_ID,
            "nonce": nonce,
            "gas": max(gas_est, GAS_LIMIT),  # ensure enough gas
            "gasPrice": gas_price,
            "value": 0
        })
        signed = acct.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
        h = tx_hash.hex()
        print(f"[{addr}] Sent: {h}")
        rcpt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=WAIT_TIMEOUT)
        status = "SUCCESS" if rcpt.status == 1 else "FAILED"
        return f"[{addr}] {status} | gasUsed={rcpt.gasUsed} | tx={h}"
    except Exception as e:
        return f"[{addr}] Send failed: {e}"


def main():
    keys = load_keys(KEYS_FILE)
    print(f"Found {len(keys)} wallets")
    for i, pk in enumerate(keys, 1):
        print(f"\n=== [{i}/{len(keys)}] ===")
        result = do_claim(pk)
        print(result)


if __name__ == "__main__":
    main()
