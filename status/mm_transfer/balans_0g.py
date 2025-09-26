#!/usr/bin/env python3
import json
import time
from web3 import Web3

# Список RPC для сети OG (пробуем по порядку)
OG_RPCS = [
    "https://16601.rpc.thirdweb.com",      # публичный (может требовать ключ)
    "https://evmrpc-testnet.0g.ai",        # публичный вариант
    # Добавь сюда свой RPC, если есть (например QuickNode / Ankr / Alchemy)
    # "https://your-rpc.example"
]

# Минимальный ERC-20 ABI (balanceOf, decimals, symbol)
ERC20_ABI = json.loads("""[
    {"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},
    {"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},
    {"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"}
]""")

# При необходимости укажи адреса контрактов токенов на OG (или оставь пустым)
TOKEN_CONTRACTS = {
    "OG": [
        # "0xTokenAddress1",
        # "0xTokenAddress2"
    ]
}

# Путь к файлу со списком адресов (по одному адресу на строку)
WALLET_FILE = "wallet.txt"

def pick_working_provider(rpc_list, timeout=5):
    """Попробовать по порядку RPC и вернуть первый рабочий Web3 провайдер."""
    for rpc in rpc_list:
        try:
            w3 = Web3(Web3.HTTPProvider(rpc, request_kwargs={"timeout": timeout}))
            if w3.is_connected():
                # проверим chainId (опционально)
                try:
                    cid = w3.eth.chain_id
                except Exception:
                    cid = None
                return w3, rpc, cid
        except Exception:
            continue
    return None, None, None

def to_checksum(addr):
    try:
        return Web3.toChecksumAddress(addr)
    except Exception:
        return None

def get_native_balance(w3, addr):
    try:
        bal = w3.eth.get_balance(addr)
        # Web3.fromWei is module-level; можно использовать Web3.fromWei
        return Web3.fromWei(bal, 'ether')
    except Exception as e:
        print(f"  ❌ Ошибка получения нативного баланса: {e}")
        return None

def get_token_balance(w3, token_addr, user_addr):
    try:
        token_addr_cs = to_checksum(token_addr)
        if not token_addr_cs:
            return None, None
        contract = w3.eth.contract(address=token_addr_cs, abi=ERC20_ABI)
        raw = contract.functions.balanceOf(user_addr).call()
        # Попробуем получить decimals и symbol (могут провалиться)
        try:
            decimals = contract.functions.decimals().call()
        except Exception:
            decimals = 18
        try:
            symbol = contract.functions.symbol().call()
        except Exception:
            symbol = "ERC20"
        human = raw / (10 ** decimals) if decimals is not None else raw
        return human, symbol
    except Exception as e:
        # не падаем — просто возвращаем None
        return None, None

def load_addresses(path):
    with open(path, "r", encoding="utf-8") as f:
        lines = [l.strip() for l in f if l.strip()]
    return lines

def main():
    print("🔎 Ищем рабочий RPC для OG...")
    w3, rpc_used, chain_id = pick_working_provider(OG_RPCS, timeout=6)
    if not w3:
        print("❌ Не удалось подключиться ни к одному из RPC. Добавь рабочий RPC в OG_RPCS.")
        return

    print(f"✅ Подключено к RPC: {rpc_used} (chainId={chain_id})\n")

    try:
        addresses = load_addresses(WALLET_FILE)
    except FileNotFoundError:
        print(f"❌ Файл {WALLET_FILE} не найден. Создай файл с адресами (по одному на строку).")
        return

    if not addresses:
        print("❌ Список адресов пуст.")
        return

    # Заголовок вывода
    print("Адрес; Нативный (OG); Токены (если есть)")
    for a in addresses:
        cs = to_checksum(a)
        if not cs:
            print(f"{a}; ERROR_CHECKSUM; -")
            continue

        native = get_native_balance(w3, cs)
        if native is None:
            native_str = "ERR"
        else:
            # native может быть Decimal/float; форматируем красиво
            native_str = f"{float(native):.18f}".rstrip('0').rstrip('.')  # убираем лишние нули

        tokens_out = []
        for tok in TOKEN_CONTRACTS.get("OG", []):
            bal, sym = get_token_balance(w3, tok, cs)
            if bal is None:
                continue
            # фильтр нулей (порог > 0)
            if bal and float(bal) > 0:
                tokens_out.append(f"{bal} {sym}")

        tokens_txt = ", ".join(tokens_out) if tokens_out else "Нет токенов"
        print(f"{cs}; {native_str}; {tokens_txt}")

if __name__ == "__main__":
    main()
