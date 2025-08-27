#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import time
import random
from decimal import Decimal, getcontext
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests
from dotenv import load_dotenv
from web3 import Web3
from eth_account import Account
from eth_account.signers.local import LocalAccount
from web3.exceptions import ContractLogicError

getcontext().prec = 40
load_dotenv()

# ========= Settings =========
BSC_RPC = os.getenv("BSC_RPC", "https://bsc-dataseed.binance.org")
CHAIN_ID = int(os.getenv("CHAIN_ID", "56"))
CLAIM_API_URL = os.getenv("CLAIM_API_URL", "https://multipass.multiple.cc/api/reward/airdrop/signature")
KEYS_FILE = os.getenv("KEYS_FILE", "keys.txt")
MAX_WORKERS = int(os.getenv("MAX_WORKERS", "5"))

# Limits
GAS_LIMIT = int(os.getenv("GAS_LIMIT", "260000"))
MAX_TX_FEE_USD = Decimal(os.getenv("MAX_TX_FEE_USD", "0.05"))
TTL_WARN = int(os.getenv("TTL_WARN", "45"))
WAIT_TIMEOUT = int(os.getenv("WAIT_TIMEOUT", "180"))

# BNB/USD Chainlink oracle
BNB_USD_ORACLE = Web3.to_checksum_address("0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE")

# Contract ABI
CLAIM_CONTRACT = Web3.to_checksum_address("0x507d8ea248224e332CD8292Fadf527Df852f3632")
CLAIM_ABI = [{
    "name": "claim",
    "type": "function",
    "stateMutability": "nonpayable",
    "inputs": [
        {"name": "index", "type": "uint256"},
        {"name": "amount", "type": "uint256"},
        {"name": "expireAt", "type": "uint256"},
        {"name": "signature", "type": "bytes"}
    ],
    "outputs": []
}]

# Web3
w3 = Web3(Web3.HTTPProvider(BSC_RPC))
if not w3.is_connected():
    raise SystemExit("❌ RPC not reachable")

contract = w3.eth.contract(address=CLAIM_CONTRACT, abi=CLAIM_ABI)
session = requests.Session()

# Chainlink oracle ABI
AGG_ABI = [
    {"name":"latestRoundData","outputs":[
        {"type":"uint80","name":"roundId"},
        {"type":"int256","name":"answer"},
        {"type":"uint256","name":"startedAt"},
        {"type":"uint256","name":"updatedAt"},
        {"type":"uint80","name":"answeredInRound"}],
     "inputs":[],"stateMutability":"view","type":"function"},
    {"name":"decimals","outputs":[{"type":"uint8","name":""}],
     "inputs":[],"stateMutability":"view","type":"function"}
]

def get_bnb_usd_price() -> Decimal:
    oracle = w3.eth.contract(address=BNB_USD_ORACLE, abi=AGG_ABI)
    dec = oracle.functions.decimals().call()
    _, ans, _, _, _ = oracle.functions.latestRoundData().call()
    return Decimal(ans) / (10 ** dec)

def load_keys(path="keys.txt"):
    out = []
    with open(path, "r") as f:
        for line in f:
            k = line.strip()
            if not k: continue
            if k.startswith("0x"): k = k[2:]
            out.append(k)
    return list(dict.fromkeys(out))

def fetch_claim(addr: str):
    r = session.get(CLAIM_API_URL, params={"user_address": addr}, timeout=20)
    r.raise_for_status()
    d = r.json()["data"]
    return {
        "index": int(d["round"]),
        "amount": int(d["reward_amount"]),
        "expireAt": int(d["expiration_time"]),
        "signature": d["signature"]
    }

def estimate_fee(params, addr):
    gas_price = w3.eth.gas_price
    try:
        gas_est = contract.functions.claim(
            params["index"], params["amount"], params["expireAt"],
            bytes.fromhex(params["signature"][2:])
        ).estimate_gas({"from": addr})
    except Exception:
        gas_est = GAS_LIMIT
    fee_bnb = Decimal(gas_est * gas_price) / Decimal(10**18)
    fee_usd = fee_bnb * get_bnb_usd_price()
    return gas_est, gas_price, fee_bnb, fee_usd

def do_claim(pk: str):
    acct: LocalAccount = Account.from_key(bytes.fromhex(pk))
    addr = acct.address
    try:
        params = fetch_claim(addr)
    except Exception as e:
        return f"[{addr}] ❌ Fetch fail: {e}"

    ttl = params["expireAt"] - int(time.time())
    amt = Decimal(params["amount"]) / Decimal(10**18)
    if ttl < TTL_WARN:
        print(f"[{addr}] ⚠ TTL low: {ttl}s")

    # gas & balance check
    try:
        gas_est, gas_price, fee_bnb, fee_usd = estimate_fee(params, addr)
    except Exception as e:
        return f"[{addr}] ❌ Gas check fail: {e}"

    balance = Decimal(w3.eth.get_balance(addr)) / Decimal(10**18)
    if balance < fee_bnb:
        return f"[{addr}] ⚠ Недостаточно BNB для газа. Баланс={balance}, нужно≈{fee_bnb:.6f}"

    if fee_usd > MAX_TX_FEE_USD:
        return f"[{addr}] ❌ Fee ${fee_usd:.4f} > limit ${MAX_TX_FEE_USD}"

    # send tx
    try:
        tx = contract.functions.claim(
            params["index"], params["amount"], params["expireAt"],
            bytes.fromhex(params["signature"][2:])
        ).build_transaction({
            "from": addr,
            "chainId": CHAIN_ID,
            "nonce": w3.eth.get_transaction_count(addr),
            "gas": gas_est,
            "gasPrice": gas_price
        })
        signed = acct.sign_transaction(tx)
        txh = w3.eth.send_raw_transaction(signed.rawTransaction)
        rcpt = w3.eth.wait_for_transaction_receipt(txh, timeout=WAIT_TIMEOUT)
        return f"[{addr}] ✅ {amt} MTP | tx={txh.hex()} | gasUsed={rcpt.gasUsed}"
    except Exception as e:
        return f"[{addr}] ❌ Send failed: {e}"

def main():
    keys = load_keys(KEYS_FILE)
    results = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futs = {ex.submit(do_claim, pk): pk for pk in keys}
        for fut in as_completed(futs):
            results.append(fut.result())
            print(results[-1])

    # save log
    with open("results.log", "w") as f:
        for r in results:
            f.write(r + "\n")

    print("\n=== SUMMARY ===")
    for r in results:
        print(r)

if __name__ == "__main__":
    main()
