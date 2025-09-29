#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
1000 → 1 для 0G (native coin):
- Читает сид-фразы (MetaMask путь m/44'/60'/0'/0/i) из mnemonics.txt
- Для каждого U:
  1) баланс X (bash-чекером)
  2) баланс U (bash-чекером)
  3) отправка U→X (всё, минус газ и leave-native)
  4) баланс X повторно (bash-чекером) и сверка дельты
- При любом расхождении — жёсткая остановка с понятной ошибкой
- Если --recipient не задан, спросит адрес X интерактивно
"""

import argparse
import csv
import logging
import os
import subprocess
import sys
import tempfile
from decimal import Decimal, getcontext
from typing import Dict, List, Tuple

from web3 import Web3
from eth_account import Account
from bip_utils import (
    Bip39SeedGenerator, Bip39MnemonicValidator,
    Bip44, Bip44Coins, Bip44Changes
)

LOG_FMT = "%(asctime)s | %(levelname)s | %(message)s"
BAL_SH = "./og_balance.sh"   # путь к bash-чекеру балансов

# ----------------- ЛОГИ/СЕРВИС -----------------

def setup_logger(path: str):
    logging.basicConfig(level=logging.INFO, format=LOG_FMT)
    fh = logging.FileHandler(path, encoding="utf-8")
    fh.setFormatter(logging.Formatter(LOG_FMT))
    logging.getLogger().addHandler(fh)

def die(msg: str, code=1):
    logging.error(msg)
    sys.exit(code)

def prompt_recipient_interactive() -> str:
    """Интерактивный ввод адреса получателя X с валидацией."""
    while True:
        try:
            s = input("Введите адрес получателя (X): ").strip()
        except EOFError:
            s = ""
        if not s:
            print("Адрес пуст. Повторите.")
            continue
        if Web3.is_address(s):
            x = Web3.to_checksum_address(s)
            print(f"Приму X = {x}")
            return x
        print("Неверный EVM-адрес. Попробуйте снова.")

# ----------------- ДЕРИВАЦИЯ -----------------

def derive_eth_from_mnemonic(mnemonic: str, index: int = 0) -> Tuple[str, str]:
    """m/44'/60'/0'/0/index -> (priv_hex, checksum_addr)"""
    if not Bip39MnemonicValidator(mnemonic).Validate():
        raise ValueError("Невалидная сид-фраза")
    seed = Bip39SeedGenerator(mnemonic).Generate()
    ctx = Bip44.FromSeed(seed, Bip44Coins.ETHEREUM)
    node = ctx.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(index)
    priv_hex = node.PrivateKey().Raw().ToHex()                 # 32-байтовый приватник hex
    addr = Web3.to_checksum_address(node.PublicKey().ToAddress())
    return priv_hex, addr

# ----------------- ЧЕК БАЛАНСА (bash) -----------------

def _parse_og_csv(path: str) -> Dict[str, int]:
    """Парсит balances.csv формата Address;Balance_OG -> {checksum_addr: wei}"""
    out: Dict[str, int] = {}
    getcontext().prec = 80
    with open(path, "r", encoding="utf-8") as f:
        first = True
        for line in f:
            line = line.strip()
            if not line:
                continue
            if first:
                # заголовок Address;Balance_OG
                first = False
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) != 2:
                continue
            addr, bal_s = parts
            if bal_s.upper() == "ERROR":
                raise RuntimeError(f"og_balance.sh вернул ERROR для {addr}")
            # decimal OG -> wei
            og_dec = Decimal(bal_s)
            wei = int(og_dec * (Decimal(10) ** 18))
            out[Web3.to_checksum_address(addr)] = wei
    return out

def sh_get_balances(rpc: str, addresses: List[str], tempdir: str) -> Dict[str, int]:
    """Запускает og_balance.sh по списку адресов и возвращает {addr: wei}."""
    infile = os.path.join(tempdir, "addresses.txt")
    with open(infile, "w", encoding="utf-8") as f:
        for a in addresses:
            f.write(a + "\n")

    outfile = os.path.join(tempdir, "balances.csv")
    errfile = os.path.join(tempdir, "errors.log")

    env = os.environ.copy()
    env.update({
        "RPC": rpc,
        "OUT": outfile,
        "ERRLOG": errfile,
        "CONCURRENCY": "10",
        "TIMEOUT": "15",
        "RETRIES": "3",
        "PROGRESS": "0",    # без прогресса, чтобы не шуметь
    })

    try:
        res = subprocess.run(
            [BAL_SH, infile],
            check=True,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Ошибка запуска og_balance.sh: {e.stderr or e.stdout or e}")

    # Отобразим предупреждения чекера, если были
    if os.path.exists(errfile) and os.path.getsize(errfile) > 0:
        with open(errfile, "r", encoding="utf-8") as ef:
            for ln in ef:
                logging.warning(f"[BAL_CHECKER] {ln.strip()}")

    if not os.path.exists(outfile):
        raise RuntimeError("og_balance.sh не создал balances.csv")
    return _parse_og_csv(outfile)

def sh_get_balance_single(rpc: str, address: str, tempdir: str) -> int:
    """Баланс одного адреса (wei) через bash-чекер."""
    return sh_get_balances(rpc, [address], tempdir)[Web3.to_checksum_address(address)]

# ----------------- ОТПРАВКА -----------------

def eip1559_fees(w3: Web3, priority_gwei: float, base_mult: float):
    latest = w3.eth.get_block("latest")
    base = latest.get("baseFeePerGas")
    if base is None:
        return {"gasPrice": w3.eth.gas_price}
    try:
        prio = w3.eth.max_priority_fee
    except Exception:
        prio = w3.to_wei(priority_gwei, "gwei")
    max_fee = int(base * base_mult) + int(prio)
    return {"type": 2, "maxFeePerGas": max_fee, "maxPriorityFeePerGas": int(prio)}

def send_native_all(w3: Web3, priv_hex: str, to_addr: str, leave_native_wei: int,
                    priority_gwei: float, base_mult: float) -> Tuple[str, str, int]:
    acct = w3.eth.account.from_key(bytes.fromhex(priv_hex))
    sender = acct.address
    bal = w3.eth.get_balance(sender)
    fees = eip1559_fees(w3, priority_gwei, base_mult)
    gas_limit = 21000
    gas_cost = gas_limit * int(fees.get("gasPrice", fees.get("maxFeePerGas")))
    amount = bal - gas_cost - leave_native_wei
    if amount <= 0:
        raise RuntimeError("Недостаточно нативного 0G для перевода (учти газ/--leave-native)")
    tx = {
        "chainId": w3.eth.chain_id,
        "nonce": w3.eth.get_transaction_count(sender, "pending"),
        "to": Web3.to_checksum_address(to_addr),
        "value": int(amount),
        "gas": gas_limit,
    }
    tx.update(fees)
    signed = w3.eth.account.sign_transaction(tx, acct.key)
    txh = w3.eth.send_raw_transaction(signed.rawTransaction).hex()
    return sender, txh, int(amount)

# ----------------- ОДИН ПРОГОН (U → X) -----------------

def sweep_once(w3: Web3, rpc: str, recipient: str, priv_hex: str,
               leave_native_wei: int, priority_gwei: float, base_mult: float,
               wait_timeout: int, tempdir: str) -> Tuple[str, str, int]:
    acct = w3.eth.account.from_key(bytes.fromhex(priv_hex))
    sender = acct.address
    recip = Web3.to_checksum_address(recipient)

    # 1) баланс X до
    x_before = sh_get_balance_single(rpc, recip, tempdir)
    logging.info(f"[1] Баланс Х ДО: {x_before} wei | X={recip}")

    # 2) баланс U до
    y_before = sh_get_balance_single(rpc, sender, tempdir)
    logging.info(f"[2] Баланс У ДО: {y_before} wei | U={sender}")
    if y_before == 0:
        raise RuntimeError("Баланс У нулевой")

    # 3) отправка
    sender_addr, txh, sent = send_native_all(w3, priv_hex, recip, leave_native_wei, priority_gwei, base_mult)
    logging.info(f"[3] Отправка U→X: sender={sender_addr} amount_wei={sent} tx={txh}")

    # wait receipt
    rcpt = w3.eth.wait_for_transaction_receipt(txh, timeout=wait_timeout, poll_latency=2)
    if rcpt.status != 1:
        raise RuntimeError(f"Транзакция неуспешна (status={rcpt.status}), tx={txh}")

    # 4) баланс X после
    x_after = sh_get_balance_single(rpc, recip, tempdir)
    delta = x_after - x_before
    logging.info(f"[4] Баланс Х ПОСЛЕ: {x_after} wei (дельта={delta}), ожидалось ≥ {sent}")

    if delta < sent:
        raise RuntimeError(f"Дельта на Х меньше отправленного: delta={delta}, sent={sent}, tx={txh}")

    return sender_addr, txh, sent

# ----------------- MAIN -----------------

def main():
    ap = argparse.ArgumentParser(
        description="1000→1: U→X для 0G (native). Балансы через og_balance.sh, стоп при расхождении."
    )
    ap.add_argument("--recipient", help="Адрес X (получатель). Если не указан — спросим интерактивно.")
    ap.add_argument("--mnemonics", default="mnemonics.txt", help="Сид-фразы U (по одной в строке)")
    ap.add_argument("--from-index", type=int, default=0, help="Начальный индекс BIP44 (m/44'/60'/0'/0/i)")
    ap.add_argument("--to-index", type=int, default=0, help="Конечный индекс (включительно)")
    ap.add_argument("--rpc", default="https://evmrpc.0g.ai", help="Единый RPC для чекера и отправки (0G Mainnet)")
    ap.add_argument("--priority-gwei", type=float, default=1.0)
    ap.add_argument("--basefee-mult", type=float, default=2.0)
    ap.add_argument("--leave-native", type=Decimal, default=Decimal('0'))
    ap.add_argument("--wait-timeout", type=int, default=180)
    ap.add_argument("--log", default="og_transfer.log")
    ap.add_argument("--out-csv", default="og_transfer.csv")
    args = ap.parse_args()

    if not os.path.exists(BAL_SH):
        die(f"Не найден {BAL_SH}. Сохрани твой bash-скрипт сюда и сделай исполняемым: chmod +x og_balance.sh")

    setup_logger(args.log)

    # RPC / подключение
    w3 = Web3(Web3.HTTPProvider(args.rpc, request_kwargs={"timeout": 30}))
    if not w3.is_connected():
        die(f"Не удалось подключиться к RPC: {args.rpc}")
    try:
        cid = w3.eth.chain_id
        if cid != 16661:
            logging.warning(f"chainId={cid}, ожидали 16661 (0G Mainnet) — проверь RPC")
    except Exception:
        pass

    # Адрес получателя X
    if args.recipient:
        recipient_global = Web3.to_checksum_address(args.recipient)
    else:
        print("⚠️  Адрес получателя не задан флагом --recipient.")
        recipient_global = prompt_recipient_interactive()

    leave_native_wei = int(args.leave_native * (10 ** 18))

    # Сиды
    try:
        mnems = [l.strip() for l in open(args.mnemonics, "r", encoding="utf-8").read().splitlines()
                 if l.strip() and not l.strip().startswith("#")]
    except FileNotFoundError:
        die(f"Файл не найден: {args.mnemonics}")

    # CSV заголовок
    with open(args.out_csv, "w", newline="", encoding="utf-8") as fcsv:
        w = csv.writer(fcsv, delimiter=";")
        w.writerow(["mnemonic_idx", "bip44_index", "sender", "amount_wei", "tx", "status"])

    # Временная папка для вызовов bash-чекера
    with tempfile.TemporaryDirectory(prefix="og_bal_") as tmpdir:
        for m_idx, m in enumerate(mnems, start=1):
            for i in range(args.from_index, args.to_index + 1):
                try:
                    priv_hex, addr = derive_eth_from_mnemonic(m, i)
                    logging.info(f"=== U {addr} → X {recipient_global} (mnemonic#{m_idx}, index {i}) ===")
                    sender, txh, sent = sweep_once(
                        w3, args.rpc, recipient_global, priv_hex,
                        leave_native_wei, args.priority_gwei, args.basefee_mult,
                        args.wait_timeout, tmpdir
                    )
                    status = "OK"
                    logging.info(f"Готово: sender={sender} sent_wei={sent} tx={txh}")
                except Exception as e:
                    status = f"FAIL: {e}"
                    logging.error(status)
                    with open(args.out_csv, "a", newline="", encoding="utf-8") as fcsv:
                        w = csv.writer(fcsv, delimiter=";")
                        w.writerow([m_idx, i, addr if 'addr' in locals() else "-", 0, "", status])
                    die(f"Остановка: {status}")

                with open(args.out_csv, "a", newline="", encoding="utf-8") as fcsv:
                    w = csv.writer(fcsv, delimiter=";")
                    w.writerow([m_idx, i, sender, sent, txh, status])

    logging.info("Все переводы выполнены успешно.")
    print(f"OK. Логи: {args.log} | CSV: {args.out_csv}")

if __name__ == "__main__":
    main()
