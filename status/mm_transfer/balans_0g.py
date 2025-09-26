#!/usr/bin/env python3
import sys
import re
import time
from web3 import Web3
from concurrent.futures import ThreadPoolExecutor, as_completed

# --- Жёстко только OG (вставьте свой RPC) ---
RPC_URLS = {
    "OG": "https://16601.rpc.thirdweb.com"
}

# Параметры
WALLET_FILE = "wallet.txt"
MAX_WORKERS = 10
REQUEST_DELAY = 0.01

# Подключаемся к RPC (создаём Web3 объект для OG)
w3_networks = {}
for name, url in RPC_URLS.items():
    w3 = Web3(Web3.HTTPProvider(url, request_kwargs={"timeout": 10}))
    if w3.is_connected():
        chain = None
        try:
            chain = w3.eth.chain_id
        except Exception:
            pass
        print(f"[OK] {name} -> {url} (chainId={chain})", file=sys.stderr)
        w3_networks[name] = w3
    else:
        print(f"[WARN] Не удалось подключиться к {name} -> {url}", file=sys.stderr)

if not w3_networks:
    print("❌ Нет доступных RPC. Проверь RPC_URLS.", file=sys.stderr)
    sys.exit(1)

# Вспомогательные функции
def normalize_address(line: str):
    m = re.search(r'(0x[a-fA-F0-9]{40})', line)
    return m.group(1) if m else None

def to_checksum(address: str):
    try:
        return Web3.toChecksumAddress(address)
    except Exception:
        return None

def get_eth_balance(w3: Web3, address: str):
    try:
        bal = w3.eth.get_balance(address)
        return float(w3.fromWei(bal, "ether"))
    except Exception as e:
        return None

def check_address_balances(raw_address: str, networks):
    addr = normalize_address(raw_address.strip())
    if not addr:
        return None
    cs = to_checksum(addr)
    if not cs:
        return None
    out = [cs]
    for net in networks:
        w3 = w3_networks.get(net)
        if not w3:
            out.append("ERR_RPC")
            continue
        bal = get_eth_balance(w3, cs)
        if bal is None:
            out.append("ERR")
        else:
            out.append(f"{bal:.6f}")
        if REQUEST_DELAY:
            time.sleep(REQUEST_DELAY)
    return ";".join(out)

def check_balances():
    # читаем и фильтруем адреса
    try:
        with open(WALLET_FILE, "r", encoding="utf-8") as f:
            lines = [ln for ln in f.readlines() if ln.strip()]
    except FileNotFoundError:
        print(f"❌ {WALLET_FILE} не найден", file=sys.stderr)
        return

    # проверим, есть ли хоть один валидный адрес в файле
    valid_count = 0
    for ln in lines:
        if normalize_address(ln):
            valid_count += 1
    if valid_count == 0:
        print("❌ В wallet.txt не найдено валидных 0x-адресов.", file=sys.stderr)
        return

    selected_networks = ["OG"]

    # печатаем только CSV в stdout (чтобы можно было редиректить чисто в файл)
    print("Address;" + ";".join(selected_networks))

    # параллельная обработка
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [executor.submit(check_address_balances, ln, selected_networks) for ln in lines]
        for fut in as_completed(futures):
            res = fut.result()
            if res:
                print(res)

if __name__ == "__main__":
    check_balances()
