#!/usr/bin/env python3
"""
check_og_new.py

Reads addresses from a text file (one address per line or lines containing 0x...),
queries a single OG RPC for balances using a ThreadPoolExecutor, and writes a clean
CSV (semicolon-separated) with header to an output file.

Logs and status messages go to stderr so stdout (and the CSV file) remains clean.
"""

import argparse
import csv
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Optional

try:
    from web3 import Web3
except Exception:
    print("Please install web3: python3 -m pip install web3", file=sys.stderr)
    sys.exit(2)


RE_ADDR = re.compile(r'(0[xX][a-fA-F0-9]{40})')  # matches 0x... or 0X...
DECIMALS = 18


def parse_args():
    p = argparse.ArgumentParser(description="Check OG balances from wallet.txt with threads.")
    p.add_argument("--in", dest="infile", default="wallet.txt", help="Input text file with addresses (default: wallet.txt)")
    p.add_argument("--out", dest="outfile", default="balances.csv", help="Output CSV file (default: balances.csv)")
    p.add_argument("--rpc", dest="rpc", default="https://16601.rpc.thirdweb.com", help="RPC URL for OG (default provided)")
    p.add_argument("--workers", dest="workers", type=int, default=10, help="Number of threads (default 10)")
    p.add_argument("--delay", dest="delay", type=float, default=0.01, help="Delay between requests per thread in seconds (default 0.01)")
    p.add_argument("--timeout", dest="timeout", type=int, default=10, help="HTTP timeout for RPC requests in seconds (default 10)")
    p.add_argument("--retries", dest="retries", type=int, default=3, help="Retries per request on failure (default 3)")
    return p.parse_args()


def load_addresses(path: str):
    try:
        with open(path, "r", encoding="utf-8") as f:
            lines = [ln.strip() for ln in f if ln.strip()]
    except FileNotFoundError:
        print(f"Input file not found: {path}", file=sys.stderr)
        sys.exit(3)

    found = []
    for ln in lines:
        m = RE_ADDR.search(ln)
        if m:
            found.append(m.group(1))
    # dedupe preserving order
    seen = set()
    ordered = []
    for a in found:
        key = a.lower()
        if key not in seen:
            seen.add(key)
            ordered.append(a)
    return ordered


def make_w3(rpc: str, timeout: int) -> Web3:
    w3 = Web3(Web3.HTTPProvider(rpc, request_kwargs={"timeout": timeout}))
    if not w3.is_connected():
        raise ConnectionError(f"Cannot connect to RPC: {rpc}")
    return w3


def to_checksum_safe(w3: Web3, addr: str) -> Optional[str]:
    try:
        return Web3.toChecksumAddress(addr)
    except Exception:
        # try lowercase/uppercase fallback
        try:
            return Web3.toChecksumAddress(addr.lower())
        except Exception:
            return None


def fetch_balance(w3: Web3, address: str, retries: int = 3, delay: float = 0.01) -> str:
    """
    Return balance as decimal string with 6 decimal places, or 'ERR' on failure.
    """
    cs = to_checksum_safe(w3, address)
    if not cs:
        return "ERR_ADDR"

    attempt = 0
    while attempt <= retries:
        try:
            bal = w3.eth.get_balance(cs)
            # convert to ether float string with 6 decimal places
            ether = bal / (10 ** DECIMALS)
            return f"{ether:.6f}"
        except Exception as e:
            attempt += 1
            if attempt > retries:
                print(f"[ERROR] {cs} - final failure: {e}", file=sys.stderr)
                return "ERR"
            backoff = 0.5 * (2 ** (attempt - 1))
            print(f"[WARN] {cs} - attempt {attempt}/{retries} failed: {e}. backoff {backoff}s", file=sys.stderr)
            time.sleep(backoff)
        finally:
            # small throttle between attempts/requests
            if delay:
                time.sleep(delay)
    return "ERR"


def worker_task(w3: Web3, addr: str, retries: int, delay: float):
    # returns tuple for CSV: (checksum_address, balance_str)
    cs = to_checksum_safe(w3, addr)
    if not cs:
        return (addr, "ERR_ADDR")
    bal = fetch_balance(w3, addr, retries=retries, delay=delay)
    return (cs, bal)


def main():
    args = parse_args()

    print(f"[INFO] Loading addresses from: {args.infile}", file=sys.stderr)
    addrs = load_addresses(args.infile)
    if not addrs:
        print("[ERROR] No valid addresses found in input file.", file=sys.stderr)
        sys.exit(4)
    print(f"[INFO] {len(addrs)} unique addresses loaded.", file=sys.stderr)

    print(f"[INFO] Connecting to RPC: {args.rpc}", file=sys.stderr)
    try:
        w3 = make_w3(args.rpc, args.timeout)
        chain = None
        try:
            chain = w3.eth.chain_id
        except Exception:
            pass
        print(f"[OK] Connected to RPC (chainId={chain})", file=sys.stderr)
    except Exception as e:
        print(f"[ERROR] RPC connection failed: {e}", file=sys.stderr)
        sys.exit(5)

    # Open output CSV and write header
    try:
        out_f = open(args.outfile, "w", encoding="utf-8", newline="")
    except Exception as e:
        print(f"[ERROR] Cannot open output file: {args.outfile} -> {e}", file=sys.stderr)
        sys.exit(6)

    writer = csv.writer(out_f, delimiter=";")
    writer.writerow(["Address", "OG"])

    # Use ThreadPoolExecutor
    workers = max(1, args.workers)
    print(f"[INFO] Starting ThreadPoolExecutor with {workers} workers", file=sys.stderr)
    with ThreadPoolExecutor(max_workers=workers) as ex:
        future_to_addr = {
            ex.submit(worker_task, w3, addr, args.retries, args.delay): addr for addr in addrs
        }

        completed = 0
        for fut in as_completed(future_to_addr):
            addr = future_to_addr[fut]
            try:
                cs, bal = fut.result()
                writer.writerow([cs, bal])
            except Exception as e:
                print(f"[ERROR] Unexpected error for {addr}: {e}", file=sys.stderr)
                writer.writerow([addr, "ERR"])
            completed += 1
            if completed % 50 == 0 or completed == len(addrs):
                print(f"[INFO] progress: {completed}/{len(addrs)}", file=sys.stderr)

    out_f.close()
    print(f"[DONE] Results written to {args.outfile}", file=sys.stderr)


if __name__ == "__main__":
    main()
