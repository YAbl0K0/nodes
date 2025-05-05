import sys
import time
import random
from web3 import Web3
from decimal import Decimal, getcontext
import concurrent.futures
import json

getcontext().prec = 30

# RPC для SHM
RPC_URL = "https://api.shardeum.org/"
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "❌ Не удалось подключиться к RPC Shardeum!"

CHAIN_ID = 8081  # или 1, если это mainnet SHM
GAS_LIMIT = 60000

# Адрес контракта SHM и ABI (частичный, только для transfer)
TOKEN_ADDRESS = w3.to_checksum_address("0x...")  # адрес токена SHM, если это ERC20
with open("erc20_abi.json") as f:
    ERC20_ABI = json.load(f)

token_contract = w3.eth.contract(address=TOKEN_ADDRESS, abi=ERC20_ABI)

def get_token_balance(address):
    try:
        balance = token_contract.functions.balanceOf(address).call()
        return w3.from_wei(balance, 'ether')
    except Exception as e:
        print(f"❌ Ошибка при получении баланса токена: {e}")
        return 0.0

def send_token(private_key, sender, recipient):
    balance_wei = token_contract.functions.balanceOf(sender).call()
    token_balance = w3.from_wei(balance_wei, 'ether')
    print(f"💰 Баланс SHM у {sender}: {token_balance}")

    if balance_wei == 0:
        print(f"⚠️ Пропускаем {sender}, токенов нет")
        return

    nonce = w3.eth.get_transaction_count(sender, "pending")
    gas_price = w3.eth.gas_price

    try:
        tx = token_contract.functions.transfer(recipient, balance_wei).build_transaction({
            'chainId': CHAIN_ID,
            'gas': GAS_LIMIT,
            'gasPrice': gas_price,
            'nonce': nonce,
        })

        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        print(f"✅ Отправлено {token_balance} SHM → {recipient} | TX: {w3.to_hex(tx_hash)}")

        with open("tx_hashes.log", "a") as log_file:
            log_file.write(f"{sender} -> {recipient}: {token_balance} SHM | TX: {w3.to_hex(tx_hash)}\n")

        time.sleep(5)

    except Exception as e:
        print(f"❌ Ошибка при отправке токенов от {sender}: {e}")
        with open("errors.log", "a") as f:
            f.write(f"{sender}: {e}\n")

def main():
    try:
        with open("addresses.txt", "r") as file:
            lines = [line.strip() for line in file if line.strip()]
        
        def process_line(line):
            try:
                sender, private_key, recipient = line.split(";")
                sender = w3.to_checksum_address(sender)
                recipient = w3.to_checksum_address(recipient)

                send_token(private_key, sender, recipient)

                delay = random.uniform(2, 5)
                print(f"⏳ Задержка {delay:.2f} сек")
                time.sleep(delay)

            except Exception as e:
                print(f"⚠️ Ошибка строки '{line}': {e}")

        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            executor.map(process_line, lines)

    except FileNotFoundError:
        print("❌ Файл addresses.txt не найден!")

if __name__ == "__main__":
    main()

