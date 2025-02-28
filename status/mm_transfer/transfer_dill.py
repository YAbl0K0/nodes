import sys
import subprocess
import time
from web3 import Web3

# Настройки сети Dill
RPC_URL = "https://rpc-alps.dill.xyz"
CHAIN_ID = 102125
GAS_LIMIT = 500000  # Базовый лимит газа
GAS_PRICE = lambda: min(max(w3.eth.gas_price, w3.to_wei(2, 'gwei')), w3.to_wei(10, 'gwei'))  # От 2 до 10 Gwei

# Подключение к Web3
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети Dill!"

def to_checksum(address):
    """Приводит адрес к checksum-формату или возвращает None при ошибке"""
    try:
        return Web3.to_checksum_address(address)
    except:
        return None

def get_dill_balance(address):
    """Получает баланс нативного токена DILL"""
    checksum_address = to_checksum(address)
    if not checksum_address:
        return 0.000  # Если адрес некорректен, возвращаем 0
    
    try:
        balance_wei = w3.eth.get_balance(checksum_address)
        balance_dill = float(w3.from_wei(balance_wei, 'ether'))
        return round(balance_dill, 6)  # Округляем до 6 знаков
    except Exception:
        return 0.000

def send_dill(private_key, sender, recipient):
    """Отправляет весь доступный DILL (минус газ)"""
    eth_balance = get_dill_balance(sender)

    if eth_balance <= 0:
        return  # Баланс 0, пропускаем

    gas_price = GAS_PRICE()
    estimated_gas_cost = GAS_LIMIT * gas_price
    required_eth = w3.from_wei(estimated_gas_cost, 'ether')

    if eth_balance <= required_eth:
        return  # Недостаточно DILL для газа, пропускаем

    send_amount = eth_balance - required_eth  # Вычитаем стоимость газа

    if send_amount <= 0:
        return  # Нечего отправлять после вычета газа

    nonce = w3.eth.get_transaction_count(sender)
    
    try:
        tx = {
            'to': recipient,
            'value': w3.to_wei(send_amount, 'ether'),
            'gas': GAS_LIMIT,
            'gasPrice': gas_price,
            'nonce': nonce,
            'chainId': CHAIN_ID
        }
        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        print(f"✅ Отправлено {send_amount} DILL: {w3.to_hex(tx_hash)}")
    except Exception as e:
        print(f"❌ Ошибка при отправке с {sender}: {str(e)}")

def main():
    """Главная функция"""
    with open("addresses.txt", "r") as file:
        lines = file.readlines()
    
    for line in lines:
        try:
            sender, private_key, recipient = line.strip().split(";")
            
            sender = to_checksum(sender)
            recipient = to_checksum(recipient)
            
            if not sender or not recipient:
                continue  # Пропускаем некорректные адреса
            
            send_dill(private_key, sender, recipient)  # Отправка DILL
            time.sleep(3)  # Задержка между транзакциями
        except Exception:
            continue  # Пропускаем строки с ошибками

if __name__ == "__main__":
    main()
