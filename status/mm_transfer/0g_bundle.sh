#!/usr/bin/env bash
set -euo pipefail

# ===== 0) Проверки окружения и зависимости (Ubuntu/Debian) =====
echo "[*] Проверка зависимостей..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip jq curl dos2unix

# ===== 1) Виртуальное окружение Python =====
echo "[*] Готовим виртуальное окружение .venv ..."
python3 -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
python3 -m pip install -U pip
python3 -m pip install -U "web3>=6,<7" "eth-account>=0.10,<0.11" "bip-utils>=2.8"

# ===== 2) Пишем balans_0g.sh (чистый POSIX-совместимый вариант) =====
cat > balans_0g.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

RPC="${RPC:-https://evmrpc.0g.ai}"
FILE="${1:-addresses.txt}"
OUT="${OUT:-balances.csv}"
ERRLOG="${ERRLOG:-errors.log}"
TIMEOUT="${TIMEOUT:-15}"
RETRIES="${RETRIES:-3}"

command -v curl >/dev/null || { echo "Нужен curl"; exit 1; }
command -v jq   >/dev/null || { echo "Нужен jq (sudo apt-get install -y jq)"; exit 1; }
command -v python3 >/dev/null || { echo "Нужен python3"; exit 1; }
[ -f "$FILE" ] || { echo "Файл с адресами не найден: $FILE"; exit 1; }

: > "$ERRLOG"
echo "Address;Balance_OG" > "$OUT"

while IFS= read -r addr || [ -n "$addr" ]; do
  addr="$(printf "%s" "$addr" | tr -d '[:space:]')"
  [ -z "$addr" ] && continue
  case "$addr" in \#*) continue;; esac
  case "$addr" in 0x*) ;; *)
    printf "%s;%s\n" "$addr" "ERROR" >>"$OUT"
    printf "[INVALID] %s\n" "$addr" >>"$ERRLOG"
    continue
  esac

  i=0
  hex=""
  while :; do
    i=$((i+1))
    hex="$(curl -sS --max-time "$TIMEOUT" "$RPC" \
      -H "content-type: application/json" \
      -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":["'"$addr"'","latest"]}' \
      | jq -r '.result // empty')" || true
    [ -n "$hex" ] && break
    [ "$i" -ge "$RETRIES" ] && {
      printf "%s;%s\n" "$addr" "ERROR" >>"$OUT"
      printf "[RPC_ERROR] %s\n" "$addr" >>"$ERRLOG"
      break
    }
    sleep 0.4
  done
  [ -z "$hex" ] && continue

  wei="$(python3 - "$hex" <<'PY'
import sys
x=sys.argv[1]
try: v=int(x,16) if x and x!="0x" else 0
except Exception: v=0
print(v)
PY
)"
  og="$(python3 - "$wei" <<'PY'
import sys
from decimal import Decimal, getcontext
getcontext().prec=80
w=int(sys.argv[1])
print((Decimal(w)/Decimal(10**18)).normalize())
PY
)"
  printf "%s;%s\n" "$addr" "$og" >>"$OUT"
done < "$FILE"

echo "Готово: $OUT"
[ -s "$ERRLOG" ] && echo "Есть ошибки, смотри: $ERRLOG" || echo "Ошибок нет"
SH
dos2unix balans_0g.sh 2>/dev/null || true
chmod +x balans_0g.sh

# ===== 3) Пишем transfer_0g.py (всё-в-одном: strict/final, ALL/ONE, force-any-words, dry-run) =====
cat > transfer_0g.py <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse, csv, logging, os, subprocess, sys, tempfile, hashlib, unicodedata, difflib
from decimal import Decimal
from typing import Dict, List, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed

from web3 import Web3
from eth_account import Account
from bip_utils import (Bip39SeedGenerator, Bip39MnemonicValidator, Bip39Languages,
                       Bip44, Bip44Coins, Bip44Changes)
import bip_utils  # только для подсказок слов EN

LOG_FMT = "%(asctime)s | %(levelname)s | %(message)s"
BAL_SH = "./balans_0g.sh"
ONE_OG_WEI = 10**18

def setup_logger(path: str):
    logging.basicConfig(level=logging.INFO, format=LOG_FMT)
    fh = logging.FileHandler(path, encoding="utf-8")
    fh.setFormatter(logging.Formatter(LOG_FMT))
    logging.getLogger().addHandler(fh)

def die(msg: str, code=1):
    logging.error(msg); sys.exit(code)

def prompt_recipient_interactive() -> str:
    while True:
        try: s = input("Введите адрес получателя (X): ").strip()
        except EOFError: s = ""
        if not s: print("Адрес пуст. Повторите."); continue
        if Web3.is_address(s):
            x = Web3.to_checksum_address(s); print(f"Приму X = {x}"); return x
        print("Неверный EVM-адрес. Попробуйте снова.")

def prompt_mode_interactive() -> str:
    print("Режим перевода:\n  [1] ALL — весь баланс (минус газ и --leave-native)\n  [2] ONE — ровно 1.0 0G")
    while True:
        try: s = input("Выберите 1 или 2 (по умолчанию 1): ").strip()
        except EOFError: s = ""
        if s in ("", "1"): print("Режим: ALL (sweep)"); return "all"
        if s == "2":      print("Режим: ONE (1.0 0G)");  return "one"
        print("Неверный выбор. Введите 1 или 2.")

# --- сиды: нормализация/валидатор/фоллбек ---
_HOMO = {ord('а'):'a',ord('е'):'e',ord('о'):'o',ord('р'):'p',ord('с'):'c',ord('у'):'y',ord('х'):'x',ord('к'):'k',
         ord('і'):'i',ord('ї'):'i',ord('А'):'A',ord('Е'):'E',ord('О'):'O',ord('Р'):'P',ord('С'):'C',ord('У'):'Y',
         ord('Х'):'X',ord('К'):'K',ord('І'):'I'}

def _normalize_mnemonic(s: str) -> str:
    s = s.replace("\u00a0"," ").replace("\t"," ").replace("\r"," ").translate(_HOMO)
    s = " ".join(s.strip().lower().split())
    return unicodedata.normalize("NFKD", s)

_BIP39_LANGS = [getattr(Bip39Languages, n) for n in
    ("ENGLISH","SPANISH","FRENCH","ITALIAN","JAPANESE","KOREAN",
     "CHINESE_SIMPLIFIED","CHINESE_TRADITIONAL","CZECH","PORTUGUESE")
    if hasattr(Bip39Languages, n)]

def _detect_lang_and_validate(m: str):
    for lang in _BIP39_LANGS:
        try:
            ok = bool(Bip39MnemonicValidator(lang).Validate(m))
        except Exception:
            ok = False
        if ok: return (lang, True)
    try:
        ok = bool(Bip39MnemonicValidator(m).Validate())
    except Exception:
        ok = False
    return (None, ok)

def _bip39_seed_from_any_words(m: str, passphrase: str) -> bytes:
    m = unicodedata.normalize("NFKD", m)
    salt = unicodedata.normalize("NFKD", "mnemonic" + (passphrase or ""))
    return hashlib.pbkdf2_hmac("sha512", m.encode("utf-8"), salt.encode("utf-8"), 2048, dklen=64)

def _load_en_words():
    wl_path = os.path.join(os.path.dirname(bip_utils.__file__), "data","wordlist","bip39_english.txt")
    try: 
        return [w.strip() for w in open(wl_path, encoding="utf-8") if w.strip()]
    except Exception:
        return []
_EN_WORDS = _load_en_words()

def explain_bad_word(m: str) -> str:
    if not _EN_WORDS: return "Фраза не соответствует словарям BIP-39."
    for w in m.split():
        if w not in _EN_WORDS:
            import difflib
            sug = difflib.get_close_matches(w, _EN_WORDS, n=8, cutoff=0.7)
            return f"Слово вне EN BIP-39: '{w}'. Ближайшие: {', '.join(sug) if sug else 'нет'}"
    return "Фраза не соответствует словарям BIP-39."

def derive_eth_from_mnemonic(mnemonic: str, index: int = 0,
                             passphrase: str = "", allow_any: bool = False) -> Tuple[str, str]:
    m = _normalize_mnemonic(mnemonic)
    if allow_any:
        seed = _bip39_seed_from_any_words(m, passphrase)
    else:
        _lang, ok = _detect_lang_and_validate(m)
        if not ok:
            words = len(m.split())
            raise ValueError(f"Невалидная сид-фраза (слов: {words}; ждём BIP-39 12/15/18/21/24). {explain_bad_word(m)}")
        try:
            seed = Bip39SeedGenerator(m).Generate(passphrase)
        except TypeError:
            seed = Bip39SeedGenerator(m).Generate(passphrase)
    ctx  = Bip44.FromSeed(seed, Bip44Coins.ETHEREUM)
    node = ctx.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(index)
    priv_hex = node.PrivateKey().Raw().ToHex()
    addr = Web3.to_checksum_address(node.PublicKey().ToAddress())
    return priv_hex, addr

# --- balans_0g.sh обёртки ---
def _parse_balances_csv(path: str) -> Dict[str, int]:
    out: Dict[str, int] = {}
    with open(path, "r", encoding="utf-8") as f:
        first = True
        for line in f:
            line = line.strip()
            if not line: continue
            if first: first = False; continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) != 2: continue
            addr, bal_s = parts
            if bal_s.upper() == "ERROR":
                raise RuntimeError(f"balans_0g.sh вернул ERROR для {addr}")
            wei = int(Decimal(bal_s) * (Decimal(10) ** 18))
            out[Web3.to_checksum_address(addr)] = wei
    return out

def sh_get_balances(rpc: str, addresses: List[str], tempdir: str) -> Dict[str, int]:
    infile  = os.path.join(tempdir, "addresses.txt")
    outfile = os.path.join(tempdir, "balances.csv")
    errfile = os.path.join(tempdir, "errors.log")
    with open(infile, "w", encoding="utf-8") as f:
        for a in addresses: f.write(a + "\n")
    env = os.environ.copy()
    env.update({"RPC": rpc, "OUT": outfile, "ERRLOG": errfile, "TIMEOUT":"15","RETRIES":"3"})
    # ГАРАНТИРОВАННО через bash:
    try:
        subprocess.run(["bash", BAL_SH, infile], check=True, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Ошибка запуска balans_0g.sh: {e.stderr or e.stdout or e}")
    if os.path.exists(errfile) and os.path.getsize(errfile) > 0:
        with open(errfile, "r", encoding="utf-8") as ef:
            for ln in ef: logging.warning(f"[BAL_CHECKER] {ln.strip()}")
    if not os.path.exists(outfile):
        raise RuntimeError("balans_0g.sh не создал balances.csv")
    return _parse_balances_csv(outfile)

def sh_get_balance_single(rpc: str, address: str, tempdir: str) -> int:
    return sh_get_balances(rpc, [address], tempdir)[Web3.to_checksum_address(address)]

# --- отправка ---
def eip1559_fees(w3: Web3, priority_gwei: float, base_mult: float):
    latest = w3.eth.get_block("latest")
    base = latest.get("baseFeePerGas")
    if base is None: return {"gasPrice": w3.eth.gas_price}
    try: prio = w3.eth.max_priority_fee
    except Exception: prio = w3.to_wei(priority_gwei, "gwei")
    max_fee = int(base * base_mult) + int(prio)
    return {"type": 2, "maxFeePerGas": max_fee, "maxPriorityFeePerGas": int(prio)}

def send_native_all(w3: Web3, priv_hex: str, to_addr: str, leave_native_wei: int,
                    priority_gwei: float, base_mult: float) -> Tuple[str, str, int]:
    acct = w3.eth.account.from_key(bytes.fromhex(priv_hex)); sender = acct.address
    bal = w3.eth.get_balance(sender)
    fees = eip1559_fees(w3, priority_gwei, base_mult); gas_limit = 21000
    gas_cost = gas_limit * int(fees.get("gasPrice", fees.get("maxFeePerGas")))
    amount = bal - gas_cost - leave_native_wei
    if amount <= 0: raise RuntimeError("Недостаточно нативного 0G для перевода (учти газ/--leave-native)")
    tx = {"chainId": w3.eth.chain_id, "nonce": w3.eth.get_transaction_count(sender, "pending"),
          "to": Web3.to_checksum_address(to_addr), "value": int(amount), "gas": gas_limit}
    tx.update(fees)
    signed = w3.eth.account.sign_transaction(tx, acct.key)
    txh = w3.eth.send_raw_transaction(signed.rawTransaction).hex()
    return sender, txh, int(amount)

def send_native_fixed(w3: Web3, priv_hex: str, to_addr: str, amount_wei: int,
                      leave_native_wei: int, priority_gwei: float, base_mult: float) -> Tuple[str, str, int]:
    acct = w3.eth.account.from_key(bytes.fromhex(priv_hex)); sender = acct.address
    bal = w3.eth.get_balance(sender)
    fees = eip1559_fees(w3, priority_gwei, base_mult); gas_limit = 21000
    gas_cost = gas_limit * int(fees.get("gasPrice", fees.get("maxFeePerGas")))
    need = amount_wei + gas_cost + leave_native_wei
    if bal < need: raise RuntimeError(f"Недостаточно средств: баланс {bal}, требуется ≥ {need}")
    tx = {"chainId": w3.eth.chain_id, "nonce": w3.eth.get_transaction_count(sender, "pending"),
          "to": Web3.to_checksum_address(to_addr), "value": int(amount_wei), "gas": gas_limit}
    tx.update(fees)
    signed = w3.eth.account.sign_transaction(tx, acct.key)
    txh = w3.eth.send_raw_transaction(signed.rawTransaction).hex()
    return sender, txh, int(amount_wei)

def sweep_once_strict(w3: Web3, rpc: str, recipient: str, priv_hex: str,
                      mode: str, leave_native_wei: int,
                      priority_gwei: float, base_mult: float,
                      wait_timeout: int, tempdir: str) -> Tuple[str, str, int]:
    acct = w3.eth.account.from_key(bytes.fromhex(priv_hex)); sender = acct.address
    recip = Web3.to_checksum_address(recipient)
    x_before = sh_get_balance_single(rpc, recip,  tempdir); logging.info(f"[1] Баланс Х ДО: {x_before} wei | X={recip}")
    y_before = sh_get_balance_single(rpc, sender, tempdir); logging.info(f"[2] Баланс У ДО: {y_before} wei | U={sender}")
    if y_before == 0: raise RuntimeError("Баланс У нулевой")

    if mode == "all": sender_addr, txh, sent = send_native_all(w3, priv_hex, recip, leave_native_wei, priority_gwei, base_mult)
    else:             sender_addr, txh, sent = send_native_fixed(w3, priv_hex, recip, ONE_OG_WEI, leave_native_wei, priority_gwei, base_mult)
    logging.info(f"[3] TX U→X: {sender_addr} amount_wei={sent} tx={txh}")

    rcpt = w3.eth.wait_for_transaction_receipt(txh, timeout=wait_timeout, poll_latency=2)
    if rcpt.status != 1: raise RuntimeError(f"Транзакция неуспешна (status={rcpt.status}), tx={txh}")

    x_after = sh_get_balance_single(rpc, recip, tempdir); delta = x_after - x_before
    expected = sent if mode == "all" else ONE_OG_WEI
    logging.info(f"[4] Баланс Х ПОСЛЕ: {x_after} wei (дельта={delta}), ожидалось ≥ {expected}")
    if delta < expected: raise RuntimeError(f"Дельта на Х меньше ожидаемой: delta={delta}, expected≥{expected}, tx={txh}")
    return sender_addr, txh, sent

def send_job_final(w3: Web3, recipient: str, mnemonic: str, index: int,
                   mode: str, leave_native_wei: int, priority_gwei: float,
                   base_mult: float, wait_timeout: int, passphrase: str, allow_any: bool) -> Tuple[int,int,str,str,int,str]:
    priv_hex, _addr = derive_eth_from_mnemonic(mnemonic, index, passphrase, allow_any)
    recip = Web3.to_checksum_address(recipient)
    if mode == "all": sender_addr, txh, sent = send_native_all(w3, priv_hex, recip, leave_native_wei, priority_gwei, base_mult)
    else:             sender_addr, txh, sent = send_native_fixed(w3, priv_hex, recip, ONE_OG_WEI, leave_native_wei, priority_gwei, base_mult)
    rcpt = w3.eth.wait_for_transaction_receipt(txh, timeout=wait_timeout, poll_latency=2)
    if rcpt.status != 1: raise RuntimeError(f"Транзакция неуспешна (status={rcpt.status}), tx={txh}")
    return (index, index, sender_addr, mode, sent, txh)

def main():
    ap = argparse.ArgumentParser(description="U→X для 0G (native). Балансы через balans_0g.sh, strict/final.")
    ap.add_argument("--recipient", help="Адрес X (получатель). Если не указан — спросим интерактивно.")
    ap.add_argument("--mode", choices=["all", "one"], help="Режим: all (всё) или one (1.0 0G). Если не указан — спросим.")
    ap.add_argument("--verify-mode", choices=["strict", "final"], default="strict", help="strict=последовательно. final=до/после (можно --workers).")
    ap.add_argument("--workers", type=int, default=1, help="Потоков для final.")
    ap.add_argument("--mnemonics", default="mnemonics.txt", help="Сид-фразы (по одной в строке).")
    ap.add_argument("--passphrase", default="", help="BIP-39 passphrase (если используется).")
    ap.add_argument("--force-any-words", action="store_true", help="Разрешить не-BIP39 слова (seed=PBKDF2). Используй, если кошелёк принимает такую фразу.")
    ap.add_argument("--dry-run", action="store_true", help="Только вывести адреса (ничего не отправлять).")
    ap.add_argument("--from-index", type=int, default=0, help="Начальный BIP44 индекс (m/44'/60'/0'/0/i).")
    ap.add_argument("--to-index",   type=int, default=0, help="Конечный индекс (включительно).")
    ap.add_argument("--rpc", default="https://evmrpc.0g.ai", help="RPC 0G Mainnet.")
    ap.add_argument("--priority-gwei", type=float, default=1.0)
    ap.add_argument("--basefee-mult",  type=float, default=2.0)
    ap.add_argument("--leave-native",  type=Decimal, default=Decimal('0'))
    ap.add_argument("--wait-timeout",  type=int, default=180)
    ap.add_argument("--log", default="og_transfer.log")
    ap.add_argument("--out-csv", default="og_transfer.csv")
    args = ap.parse_args()

    if not os.path.exists(BAL_SH):
        die(f"Не найден {BAL_SH}. chmod +x balans_0g.sh и положи рядом с этим скриптом.")
    setup_logger(args.log)

    w3 = Web3(Web3.HTTPProvider(args.rpc, request_kwargs={"timeout": 30}))
    if not w3.is_connected(): die(f"Не удалось подключиться к RPC: {args.rpc}")
    try:
        if w3.eth.chain_id != 16661:
            logging.warning(f"chainId={w3.eth.chain_id}, ожидали 16661 (0G Mainnet) — проверь RPC")
    except Exception:
        pass

    if args.recipient:
        if not Web3.is_address(args.recipient):
            die(f"Неверный адрес: {args.recipient}. Ожидается 0x + 40 hex.")
        recipient = Web3.to_checksum_address(args.recipient)
    else:
        recipient = prompt_recipient_interactive()

    mode = args.mode if args.mode else prompt_mode_interactive()
    leave_native_wei = int(args.leave_native * (10 ** 18))

    try:
        with open(args.mnemonics, "r", encoding="utf-8") as fh:
            mnems = [ln.strip() for ln in fh if ln.strip() and not ln.strip().startswith("#")]
    except FileNotFoundError:
        die(f"Файл не найден: {args.mnemonics}")

    # DRY RUN
    if args.dry_run:
        print("=== DRY RUN: адреса без отправки ===")
        idx = 0
        for m in mnems:
            idx += 1
            for i in range(args.from_index, args.to_index + 1):
                try:
                    _, addr = derive_eth_from_mnemonic(m, i, args.passphrase, args.force_any_words)
                    print(f"{idx};{i};{addr}")
                except Exception as e:
                    print(f"{idx};{i};ERROR: {e}")
        return

    with open(args.out_csv, "w", newline="", encoding="utf-8") as fcsv:
        w = csv.writer(fcsv, delimiter=";")
        w.writerow(["mnemonic_idx", "bip44_index", "sender", "mode", "amount_wei", "tx", "status"])

    if args.verify_mode == "strict":
        if args.workers != 1:
            logging.warning("strict-режим игнорирует --workers.")
        with tempfile.TemporaryDirectory(prefix="og_bal_") as tmpdir:
            m_idx = 0
            for m in mnems:
                m_idx += 1
                for i in range(args.from_index, args.to_index + 1):
                    try:
                        priv_hex, addr = derive_eth_from_mnemonic(m, i, args.passphrase, args.force_any_words)
                        sender, txh, sent = sweep_once_strict(
                            w3, args.rpc, recipient, priv_hex,
                            mode, leave_native_wei,
                            args.priority_gwei, args.basefee_mult,
                            args.wait_timeout, tmpdir
                        )
                        status = "OK"
                    except Exception as e:
                        status = f"FAIL: {e}"
                        with open(args.out_csv, "a", newline="", encoding="utf-8") as fcsv:
                            w = csv.writer(fcsv, delimiter=";")
                            w.writerow([m_idx, i, addr if 'addr' in locals() else "-", mode, 0, "", status])
                        die(f"Остановка: {status}")
                    with open(args.out_csv, "a", newline="", encoding="utf-8") as fcsv:
                        w = csv.writer(fcsv, delimiter=";")
                        w.writerow([m_idx, i, sender, mode, sent, txh, status])
        logging.info("Все переводы выполнены успешно.")
        print(f"OK. Логи: {args.log} | CSV: {args.out_csv}")
        return

    # final (параллельно)
    with tempfile.TemporaryDirectory(prefix="og_bal_") as tmpdir:
        # до/после по Х и сверка суммы
        x_before = sh_get_balance_single(args.rpc, recipient, tmpdir)
        logging.info(f"[FINAL] Баланс Х ДО: {x_before} wei | X={recipient}")

        jobs = [(idx, m, i) for idx, m in enumerate(mnems, start=1)
                            for i in range(args.from_index, args.to_index + 1)]
        results: List[Tuple[int,int,str,str,int,str,str]] = []

        def worker(m_idx:int, mnem:str, i:int):
            try:
                idx, _, sender_addr, mode_used, sent, txh = send_job_final(
                    w3, recipient, mnem, i, mode, leave_native_wei,
                    args.priority_gwei, args.basefee_mult, args.wait_timeout,
                    args.passphrase, args.force_any_words
                )
                return (m_idx, i, sender_addr, mode_used, sent, txh, "OK")
            except Exception as e:
                return (m_idx, i, "-", mode, 0, "", f"FAIL: {e}")

        with ThreadPoolExecutor(max_workers=max(1, int(args.workers))) as ex:
            futs = [ex.submit(worker, m_idx, m, i) for (m_idx, m, i) in jobs]
            for fut in as_completed(futs):
                m_idx, i, sender, mode_used, sent, txh, status = fut.result()
                with open(args.out_csv, "a", newline="", encoding="utf-8") as fcsv:
                    w = csv.writer(fcsv, delimiter=";")
                    w.writerow([m_idx, i, sender, mode_used, sent, txh, status])
                if status.startswith("FAIL"): die(f"Остановка: {status}")
                results.append((m_idx, i, sender, mode_used, sent, txh, status))

        x_after = sh_get_balance_single(args.rpc, recipient, tmpdir)
        delta   = x_after - x_before
        sum_sent = sum(r[4] for r in results)
        logging.info(f"[FINAL] Баланс Х ПОСЛЕ: {x_after} wei | ΔХ={delta}, сумма отправленного={sum_sent}")
        if delta != sum_sent:
            die(f"Несовпадение итоговой дельты: ΔХ={delta} != сумме отправленного={sum_sent}")


    logging.info("Все переводы выполнены успешно (final check).")
    print(f"OK. Логи: {args.log} | CSV: {args.out_csv}")

if __name__ == "__main__":
    main()
PY
chmod +x transfer_0g.py

# ===== 4) Заготовка mnemonics.txt (пример) =====
if [ ! -f mnemonics.txt ]; then
  cat > mnemonics.txt <<'TXT'
# по одной сид-фразе на строку (12/15/18/21/24 слов), либо "как есть" — с флагом --force-any-words
# пример (заглушка — ЗАМЕНИ!):
word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12
TXT
fi

echo
echo "✓ Готово. Файлы созданы:"
ls -lah transfer_0g.py balans_0g.sh mnemonics.txt
echo
echo "== Быстрый dry-run (показать адреса, без отправок) =="
echo ". .venv/bin/activate && python3 transfer_0g.py --mnemonics mnemonics.txt --rpc https://evmrpc.0g.ai --from-index 0 --to-index 0 --force-any-words --dry-run"
echo
echo "== Отправить по 1.0 0G (строгая проверка после каждой TX) =="
echo ". .venv/bin/activate && python3 transfer_0g.py --recipient 0xВАШ_АДРЕС_X --mode one --verify-mode strict --mnemonics mnemonics.txt --rpc https://evmrpc.0g.ai --force-any-words"
echo
echo "== Перевести весь баланс (оставив 0.01 0G на адресе-источнике) =="
echo ". .venv/bin/activate && python3 transfer_0g.py --recipient 0xВАШ_АДРЕС_X --mode all --leave-native 0.01 --mnemonics mnemonics.txt --rpc https://evmrpc.0g.ai --force-any-words"
