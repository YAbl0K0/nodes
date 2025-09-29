#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
0G native (chainId=16661): массовый перевод U → X с проверкой балансов.
- Балансы X/U считаем через твой og_balance.sh (в strict-режиме per-tx; в final — до и после всего батча).
- Режим перевода: ALL (всё) или ONE (ровно 1 0G).
- Верификация:
    * strict (по умолчанию): строго последовательно, после каждой TX сверяем дельту Х.
    * final: параллельно (--workers N). В конце сверяем, что ΔХ >= сумме отправленного.
"""

import argparse, csv, logging, os, subprocess, sys, tempfile
from decimal import Decimal
from typing import Dict, List, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed

from web3 import Web3
from eth_account import Account
from bip_utils import Bip39SeedGenerator, Bip39MnemonicValidator, Bip44, Bip44Coins, Bip44Changes

LOG_FMT = "%(asctime)s | %(levelname)s | %(message)s"
BAL_SH = "./og_balance.sh"

# ---------------- утилиты / лог ----------------

def setup_logger(path: str):
    logging.basicConfig(level=logging.INFO, format=LOG_FMT)
    fh = logging.FileHandler(path, encoding="utf-8")
    fh.setFormatter(logging.Formatter(LOG_FMT))
    logging.getLogger().addHandler(fh)

def die(msg: str, code=1):
    logging.error(msg)
    sys.exit(code)

def prompt_recipient_interactive() -> str:
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

def prompt_mode_interactive() -> str:
    print("Режим перевода:")
    print("  [1] ALL — перевести весь доступный баланс (минус газ и --leave-native)")
    print("  [2] ONE — перевести ровно 1.0 0G")
    while True:
        try:
            s = input("Выберите 1 или 2 (по умолчанию 1): ").strip()
        except EOFError:
            s = ""
        if s in ("", "1"):
            print("Режим: ALL (sweep)")
            return "all"
        if s == "2":
            print("Режим: ONE (ровно 1 0G)")
            return "one"
        print("Неверный выбор. Введите 1 или 2.")

# ---------------- деривация ----------------

def derive_eth_from_mnemonic(mnemonic: str, index: int = 0) -> Tuple[str, str]:
    if not Bip39MnemonicValidator(mnemonic).Validate():
        raise ValueError("Невалидная сид-фраза")
    seed = Bip39SeedGenerator(mnemonic).Generate()
    ctx = Bip44.FromSeed(seed, Bip44Coins.ETHEREUM)
    node = ctx.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(index)
    priv_hex = node.PrivateKey().Raw().ToHex()
    addr = Web3.to_checksum_address(node.PublicKey().ToAddress())
    return priv_hex, addr

# --------------- обёртки над bash-чекером ---------------

def _parse_balances_csv(path: str) -> Dict[str, int]:
    out: Dict[str, int] = {}
    with open(path, "r", encoding="utf-8") as f:
        first = True
        for line in f:
            line = line.strip()
            if not line:
                continue
            if first:
                first = False  # заголовок Address;Balance_OG
                continue
            addr, bal_s = [p.strip() for p in line.split(";")]
            if bal_s.upper() == "ERROR":
                raise RuntimeError(f"og_balance.sh вернул ERROR для {addr}")
            # Decimal OG -> wei (int)
            wei = int(Decimal(bal_s) * (Decimal(10) ** 18))
            out[Web3.to_checksum_address(addr)] = wei
    return out

def sh_get_balances(rpc: str, addresses: List[str], tempdir: str) -> Dict[str, int]:
    infile = os.path.join(tempdir, "addresses.txt")
    outfile = os.path.join(tempdir, "balances.csv")
    errfile = os.path.join(tempdir, "errors.log")

    with open(infile, "w", encoding="utf-8") as f:
        for a in addresses:
            f.write(a + "\n")

    env = os.environ.copy()
    env.update({
        "RPC": rpc, "OUT": outfile, "ERRLOG": errfile,
        "CONCURRENCY": "10", "TIMEOUT": "15", "RETRIES": "3", "PROGRESS": "0",
    })
    try:
        subprocess.run([BAL_SH, infile], check=True, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Ошибка запуска og_balance.sh: {e.stderr or e.stdout or e}")

    if os.path.exists(errfile) and os.path.getsize(errfile) > 0:
        with open(errfile, "r", encoding="utf-8") as ef:
            for ln in ef:
                logging.warning(f"[BAL_CHECKER] {ln.strip()}")

    if not os.path.exists(outfile):
        raise RuntimeError("og_balance.sh не создал balances.csv")
    return _parse_balances_csv(outfile)

def sh_get_balance_single(rpc: str, address: str, tempdir: str) -> int:
    return sh_get_balances(rpc, [address], tempdir)[Web3.to_checksum_address(address)]

# --------------- отправка ----------------

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

def send_native_fixed(w3: Web3, priv_hex: str, to_addr: str, amount_wei: int,
                      leave_native_wei: int, priority_gwei: float, base_mult: float) -> Tuple[str, str, int]:
    acct = w3.eth.account.from_key(bytes.fromhex(priv_hex))
    sender = acct.address
    bal = w3.eth.get_balance(sender)
    fees = eip1559_fees(w3, priority_gwei, base_mult)
    gas_limit = 21000
    gas_cost = gas_limit * int(fees.get("gasPrice", fees.get("maxFeePerGas")))
    need = amount_wei + gas_cost + leave_native_wei
    if bal < need:
        raise RuntimeError(f"Недостаточно средств: баланс {bal}, требуется ≥ {need} (с учётом газа и --leave-native)")
    tx = {
        "chainId": w3.eth.chain_id,
        "nonce": w3.eth.get_transaction_count(sender, "pending"),
        "to": Web3.to_checksum_address(to_addr),
        "value": int(amount_wei),
        "gas": gas_limit,
    }
    tx.update(fees)
    signed = w3.eth.account.sign_transaction(tx, acct.key)
    txh = w3.eth.send_raw_transaction(signed.rawTransaction).hex()
    return sender, txh, int(amount_wei)

# --------------- один прогон (strict) ----------------

def sweep_once_strict(w3: Web3, rpc: str, recipient: str, priv_hex: str,
                      mode: str, leave_native_wei: int,
                      priority_gwei: float, base_mult: float,
                      wait_timeout: int, tempdir: str) -> Tuple[str, str, int]:
    acct = w3.eth.account.from_key(bytes.fromhex(priv_hex))
    sender = acct.address
    recip = Web3.to_checksum_address(recipient)

    # 1) X до
    x_before = sh_get_balance_single(rpc, recip, tempdir)
    logging.info(f"[1] Баланс Х ДО: {x_before} wei | X={recip}")

    # 2) U до
    y_before = sh_get_balance_single(rpc, sender, tempdir)
    logging.info(f"[2] Баланс У ДО: {y_before} wei | U={sender}")
    if y_before == 0:
        raise RuntimeError("Баланс У нулевой")

    # 3) send
    if mode == "all":
        sender_addr, txh, sent = send_native_all(w3, priv_hex, recip, leave_native_wei, priority_gwei, base_mult)
    else:
        one_og_wei = 10**18
        sender_addr, txh, sent = send_native_fixed(w3, priv_hex, recip, one_og_wei, leave_native_wei, priority_gwei, base_mult)
    logging.info(f"[3] TX U→X: {sender_addr} amount_wei={sent} tx={txh}")

    rcpt = w3.eth.wait_for_transaction_receipt(txh, timeout=wait_timeout, poll_latency=2)
    if rcpt.status != 1:
        raise RuntimeError(f"Транзакция неуспешна (status={rcpt.status}), tx={txh}")

    # 4) X после
    x_after = sh_get_balance_single(rpc, recip, tempdir)
    delta = x_after - x_before
    expected = sent if mode == "all" else 10**18
    logging.info(f"[4] Баланс Х ПОСЛЕ: {x_after} wei (дельта={delta}), ожидалось ≥ {expected}")
    if delta < expected:
        raise RuntimeError(f"Дельта на Х меньше ожидаемой: delta={delta}, expected≥{expected}, tx={txh}")

    return sender_addr, txh, sent

# --------------- отправка задач (final, параллельно) ----------------

def send_job_final(w3: Web3, recipient: str, mnemonic: str, index: int,
                   mode: str, leave_native_wei: int,
                   priority_gwei: float, base_mult: float, wait_timeout: int) -> Tuple[int, int, str, str, int, str]:
    """
    Возвращает: (mnemonic_idx-placeholder, index, sender, mode, sent_wei, txh)
    Примечание: mnemonic_idx заполним снаружи, тут вернём 0 — просто форма.
    """
    priv_hex, addr = derive_eth_from_mnemonic(mnemonic, index)
    recip = Web3.to_checksum_address(recipient)
    if mode == "all":
        sender_addr, txh, sent = send_native_all(w3, priv_hex, recip, leave_native_wei, priority_gwei, base_mult)
    else:
        one_og_wei = 10**18
        sender_addr, txh, sent = send_native_fixed(w3, priv_hex, recip, one_og_wei, leave_native_wei, priority_gwei, base_mult)

    rcpt = w3.eth.wait_for_transaction_receipt(txh, timeout=wait_timeout, poll_latency=2)
    if rcpt.status != 1:
        raise RuntimeError(f"Транзакция неуспешна (status={rcpt.status}), tx={txh}")

    return (0, index, sender_addr, mode, sent, txh)

# --------------- main ----------------

def main():
    ap = argparse.ArgumentParser(
        description="U→X для 0G (native). Балансы через og_balance.sh, «строгая» или «финальная» верификация."
    )
    ap.add_argument("--recipient", help="Адрес X (получатель). Если не указан — спросим интерактивно.")
    ap.add_argument("--mode", choices=["all", "one"], help="Режим перевода: all (всё) или one (ровно 1 0G). Если не указан — спросим.")
    ap.add_argument("--verify-mode", choices=["strict", "final"], default="strict",
                    help="strict=пер-тx сверка Х (последовательно). final=агрегатная сверка (до/после, можно --workers>1).")
    ap.add_argument("--workers", type=int, default=1, help="Число параллельных отправителей (только для --verify-mode final).")
    ap.add_argument("--mnemonics", default="mnemonics.txt", help="Сид-фразы U (по одной в строке)")
    ap.add_argument("--from-index", type=int, default=0, help="Начальный индекс BIP44 (m/44'/60'/0'/0/i)")
    ap.add_argument("--to-index", type=int, default=0, help="Конечный индекс (включительно)")
    ap.add_argument("--rpc", default="https://evmrpc.0g.ai", help="RPC 0G Mainnet (и для чекера, и для отправок)")
    ap.add_argument("--priority-gwei", type=float, default=1.0)
    ap.add_argument("--basefee-mult", type=float, default=2.0)
    ap.add_argument("--leave-native", type=Decimal, default=Decimal('0'))
    ap.add_argument("--wait-timeout", type=int, default=180)
    ap.add_argument("--log", default="og_transfer.log")
    ap.add_argument("--out-csv", default="og_transfer.csv")
    args = ap.parse_args()

    if not os.path.exists(BAL_SH):
        die(f"Не найден {BAL_SH}. Положи рядом и сделай исполняемым: chmod +x og_balance.sh")

    setup_logger(args.log)

    # RPC
    w3 = Web3(Web3.HTTPProvider(args.rpc, request_kwargs={"timeout": 30}))
    if not w3.is_connected():
        die(f"Не удалось подключиться к RPC: {args.rpc}")
    try:
        cid = w3.eth.chain_id
        if cid != 16661:
            logging.warning(f"chainId={cid}, ожидали 16661 (0G Mainnet) — проверь RPC")
    except Exception:
        pass

    # Получатель и режим
    recipient = Web3.to_checksum_address(args.recipient) if args.recipient else prompt_recipient_interactive()
    mode = args.mode if args.mode else prompt_mode_interactive()
    leave_native_wei = int(args.leave_native * (10 ** 18))

    # Сиды (стримингом, чтобы не кушать память на больших объёмах)
    try:
        mfile = open(args.mnemonics, "r", encoding="utf-8")
    except FileNotFoundError:
        die(f"Файл не найден: {args.mnemonics}")
    mnems_iter = (ln.strip() for ln in mfile)
    mnems = [l for l in mnems_iter if l and not l.startswith("#")]
    mfile.close()

    # CSV заголовок
    with open(args.out_csv, "w", newline="", encoding="utf-8") as fcsv:
        w = csv.writer(fcsv, delimiter=";")
        w.writerow(["mnemonic_idx", "bip44_index", "sender", "mode", "amount_wei", "tx", "status"])

    # strict: последовательный прогон с per-tx проверкой Х
    if args.verify_mode == "strict":
        if args.workers != 1:
            logging.warning("strict-режим игнорирует --workers и выполняется последовательно.")
        with tempfile.TemporaryDirectory(prefix="og_bal_") as tmpdir:
            m_idx = 0
            for m in mnems:
                m_idx += 1
                for i in range(args.from_index, args.to_index + 1):
                    try:
                        sender, txh, sent = sweep_once_strict(
                            w3, args.rpc, recipient, derive_eth_from_mnemonic(m, i)[0],
                            mode, leave_native_wei, args.priority_gwei, args.basefee_mult,
                            args.wait_timeout, tmpdir
                        )
                        status = "OK"
                        logging.info(f"OK: sender={sender} sent_wei={sent} tx={txh}")
                    except Exception as e:
                        status = f"FAIL: {e}"
                        logging.error(status)
                        with open(args.out_csv, "a", newline="", encoding="utf-8") as fcsv:
                            w = csv.writer(fcsv, delimiter=";")
                            w.writerow([m_idx, i, "-", mode, 0, "", status])
                        die(f"Остановка: {status}")
                    with open(args.out_csv, "a", newline="", encoding="utf-8") as fcsv:
                        w = csv.writer(fcsv, delimiter=";")
                        w.writerow([m_idx, i, sender, mode, sent, txh, status])
        logging.info("Все переводы выполнены успешно.")
        print(f"OK. Логи: {args.log} | CSV: {args.out_csv}")
        return

    # final: параллельная отправка + агрегатная сверка ΔХ
    with tempfile.TemporaryDirectory(prefix="og_bal_") as tmpdir:
        # баланс Х до
        x_before = sh_get_balance_single(args.rpc, recipient, tmpdir)
        logging.info(f"[FINAL] Баланс Х ДО: {x_before} wei | X={recipient}")

        jobs = []
        # формируем задания
        for m_idx, m in enumerate(mnems, start=1):
            for i in range(args.from_index, args.to_index + 1):
                jobs.append((m_idx, m, i))

        results: List[Tuple[int,int,str,str,int,str,str]] = []  # (m_idx, i, sender, mode, sent, txh, status)

        def worker(m_idx:int, mnem:str, i:int):
            try:
                priv_hex, _addr = derive_eth_from_mnemonic(mnem, i)
                sender_addr, txh, sent = send_job_final(
                    w3, recipient, mnem, i, mode, leave_native_wei,
                    args.priority_gwei, args.basefee_mult, args.wait_timeout
                )
                return (m_idx, i, sender_addr, mode, sent, txh, "OK")
            except Exception as e:
                return (m_idx, i, "-", mode, 0, "", f"FAIL: {e}")

        # пул
        workers = max(1, int(args.workers))
        with ThreadPoolExecutor(max_workers=workers) as ex:
            futs = [ex.submit(worker, m_idx, m, i) for (m_idx, m, i) in jobs]
            for fut in as_completed(futs):
                m_idx, i, sender, mode_used, sent, txh, status = fut.result()
                if status.startswith("FAIL"):
                    # Запишем и остановим обработку (остальные могли уже уйти — это особенность параллели)
                    with open(args.out_csv, "a", newline="", encoding="utf-8") as fcsv:
                        w = csv.writer(fcsv, delimiter=";")
                        w.writerow([m_idx, i, sender, mode_used, sent, txh, status])
                    die(f"Остановка: {status}")
                # успех
                with open(args.out_csv, "a", newline="", encoding="utf-8") as fcsv:
                    w = csv.writer(fcsv, delimiter=";")
                    w.writerow([m_idx, i, sender, mode_used, sent, txh, status])
                results.append((m_idx, i, sender, mode_used, sent, txh, status))

        # баланс Х после
        x_after = sh_get_balance_single(args.rpc, recipient, tmpdir)
        delta = x_after - x_before
        sum_sent = sum(r[4] for r in results)
        logging.info(f"[FINAL] Баланс Х ПОСЛЕ: {x_after} wei | ΔХ={delta}, сумма отправленного={sum_sent}")

        if delta < sum_sent:
            die(f"Несовпадение итоговой дельты: ΔХ={delta} < сумме отправленного={sum_sent}")

    logging.info("Все переводы выполнены успешно (final check).")
    print(f"OK. Логи: {args.log} | CSV: {args.out_csv}")

if __name__ == "__main__":
    main()
