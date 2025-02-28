import sys
import subprocess
import time
from web3 import Web3

# Настройки сети Dill
RPC_URL = "https://rpc-alps.dill.xyz"
CHAIN_ID = 102125
DEFAULT_GAS_LIMIT = 500000  # Базовый лимит газа (используется для оценки)

# Подключение к Web3
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "Ошибка: Не удалось подключиться к сети Dill!"

def get_gas_price():
    """Получает актуальную цену газа в пределах 2–10 Gwei"""
    try:
        gas_price = w3.eth.gas_price
        return min(max(gas_price, w3.to_wei(2, 'gwei')), w3.to_wei(10, 'gwei'))
    except Exception as e:
        print(f"❌ Ошибка получения цены газа: {e}")
        return w3.to_wei(5, 'gwei')  # Дефолтное значение 5 Gwei

def to_checksum(address):
    """Приводит адрес к checksum-формату или возвращает None при ошибке"""
    try:
        return Web3.to_checksum_address(address)
    except Exception:
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
    except Exception as e:
        print(f"❌ Ошибка получения баланса {address}: {e}")
        return 0.000

def send_dill(private_key, sender, recipient):
    """Отправляет весь доступный DILL (оставляя 0)"""
    eth_balance = get_dill_balance(sender)

    print(f"💰 Баланс {sender}: {eth_balance} DILL")

    if eth_balance <= 0:
        print(f"⚠️ Пропускаем {sender}: баланс 0 DILL")
        return  # Баланс 0, пропускаем

    gas_price = get_gas_price()

    # Оцениваем реальный лимит газа
    try:
        estimated_gas = w3.eth.estimate_gas({
            'from': sender,
            'to': recipient,
            'value': w3.to_wei(eth_balance, 'ether')
        })
    except:
        estimated_gas = DEFAULT_GAS_LIMIT  # Если не удалось оценить, берем дефолтный

    required_eth = float(w3.from_wei(estimated_gas * gas_price, 'ether'))  # Приводим к float

    print(f"🛠 Требуется {required_eth} DILL на газ | Баланс {eth_balance} DILL")

    if eth_balance <= required_eth:
        print(f"❌ Недостаточно DILL для газа, пропускаем {sender}")
        return  # Недостаточно DILL для газа, пропускаем

    # Оставляем небольшой запас (10 Gwei)
    safety_buffer = float(w3.from_wei(10, 'gwei'))  # 10 Gwei (~0.00000001 DILL)
    send_amount = eth_balance - required_eth - safety_buffer  # Теперь оставляем небольшой остаток

    if send_amount <= 0:
        print(f"⚠️ После учета газа нечего отправлять. Пропускаем {sender}")
        return  # Нечего отправлять после вычета газа

    nonce = w3.eth.get_transaction_count(sender, "pending")
    
    try:
        tx = {
            'to': recipient,
            'value': w3.to_wei(send_amount, 'ether'),
            'gas': estimated_gas,  # Используем точный лимит газа
            'gasPrice': gas_price,
            'nonce': nonce,
            'chainId': CHAIN_ID
        }
        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        print(f"✅ Отправлено {send_amount} DILL: {w3.to_hex(tx_hash)}")

        time.sleep(5)  # Задержка для избежания "nonce too low"
    except Exception as e:
        print(f"❌ Ошибка при отправке с {sender}: {str(e)}")


def main():
    """Главная функция"""
    try:
        with open("addresses.txt", "r") as file:
            lines = file.readlines()
        
        if not lines:
            print("⚠️ Файл addresses.txt пуст. Добавьте адреса и повторите.")
            return
        
        for line in lines:
            try:
                sender, private_key, recipient = line.strip().split(";")
                
                sender = to_checksum(sender)
                recipient = to_checksum(recipient)
                
                if not sender or not recipient:
                    print(f"⚠️ Некорректный адрес в строке: {line.strip()} Пропускаем.")
                    continue  # Пропускаем некорректные адреса
                
                send_dill(private_key, sender, recipient)  # Отправка DILL
                time.sleep(3)  # Задержка между транзакциями
            except Exception as e:
                print(f"❌ Ошибка обработки строки '{line.strip()}': {e}")
                continue  # Пропускаем строки с ошибками
    except FileNotFoundError:
        print("❌ Файл addresses.txt не найден! Создайте файл и добавьте адреса.")

if __name__ == "__main__":
    main()
