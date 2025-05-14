from web3 import Web3
import time
import random
import sys

# === НАСТРОЙКИ ===
RPC_LIST = [
    "https://arb1.arbitrum.io/rpc",
    "https://1rpc.io/arb"
]

CHAIN_ID = 42161
AMOUNT_TO_SEND = 0.00001  # ETH
GAS_LIMIT = 35000
ADDRESSES_FILE = "address_arb.txt"
LOG_FILE = "transfer_log.txt"


def get_w3():
    for rpc in RPC_LIST:
        try:
            w3 = Web3(Web3.HTTPProvider(rpc))
            if w3.is_connected():
                print(f"✅ Подключено к RPC: {rpc}")
                return w3
        except Exception as e:
            print(f"❌ Ошибка подключения к RPC {rpc}: {e}")
    raise Exception("❌ Не удалось подключиться ни к одному RPC!")


def main():
    w3 = get_w3()

    private_key = input("Введите приватный ключ кошелька (он НЕ сохранится): ").strip()
    account = w3.eth.account.from_key(private_key)
    sender_address = account.address
    print(f"Отправитель: {sender_address}")

    with open(ADDRESSES_FILE, "r") as f:
        addresses = [line.strip() for line in f if line.strip()]

    print(f"Найдено {len(addresses)} адресов для отправки.\n")

    balance = w3.eth.get_balance(sender_address)
    required = w3.to_wei(AMOUNT_TO_SEND * len(addresses), 'ether') + GAS_LIMIT * w3.eth.gas_price * len(addresses)

    if balance < required:
        print("❌ Недостаточно средств для выполнения всех переводов.")
        sys.exit()

    nonce = w3.eth.get_transaction_count(sender_address)
    gas_price = w3.eth.gas_price

    with open(LOG_FILE, "a") as log:
        for address in addresses:
            try:
                tx = {
                    'to': w3.to_checksum_address(address),
                    'value': w3.to_wei(AMOUNT_TO_SEND, 'ether'),
                    'gas': GAS_LIMIT,
                    'gasPrice': gas_price,
                    'nonce': nonce,
                    'chainId': CHAIN_ID
                }

                signed_tx = w3.eth.account.sign_transaction(tx, private_key)
                tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction) 


                msg = f"✅ {AMOUNT_TO_SEND} ETH -> {address} | TX: {tx_hash.hex()}"
                print(msg)
                log.write(msg + "\n")
                nonce += 1

                time.sleep(random.uniform(1, 3))  # Небольшая задержка

            except Exception as e:
                error_msg = f"❌ Ошибка отправки на {address}: {e}"
                print(error_msg)
                log.write(error_msg + "\n")


if __name__ == "__main__":
    main()
