from web3 import Web3
import time

# Список RPC для Arbitrum
RPC_LIST = [
    "https://arb1.arbitrum.io/rpc",
    "https://1rpc.io/arb"
]

CHAIN_ID = 42161
GAS_LIMIT = 120000
TOKEN_DECIMALS = 18
MIN_SEND_AMOUNT = int(0.0001 * 10 ** TOKEN_DECIMALS)  # 0.0001 токенов в wei
ERC20_CONTRACT_ADDRESS = "0x1337420dED5ADb9980CFc35f8f2B054ea86f8aB1"

def get_w3():
    for rpc in RPC_LIST:
        try:
            w3 = Web3(Web3.HTTPProvider(rpc))
            if w3.is_connected():
                return w3
        except:
            continue
    raise Exception("❌ Не удалось подключиться ни к одному RPC!")

w3 = get_w3()

def GAS_PRICE():
    return min(max(w3.eth.gas_price, w3.to_wei(0.01, 'gwei')), w3.to_wei(3, 'gwei'))

def get_eth_balance(address):
    return w3.eth.get_balance(address)

def get_token_balance_raw(address):
    contract = w3.eth.contract(address=ERC20_CONTRACT_ADDRESS, abi=[
        {"constant": True, "inputs": [{"name": "", "type": "address"}], "name": "balanceOf",
         "outputs": [{"name": "", "type": "uint256"}], "type": "function"}
    ])
    return contract.functions.balanceOf(address).call()  # raw balance in wei

def send_tokens(private_key, sender, recipient):
    token_balance = get_token_balance_raw(sender)
    eth_balance = get_eth_balance(sender)
    eth_balance_ether = w3.from_wei(eth_balance, 'ether')

    if token_balance < MIN_SEND_AMOUNT:
        print(f"⚠️ Пропущен {sender}: {token_balance / 10 ** TOKEN_DECIMALS:.8f} SQD (< 0.0001)")
        return

    gas_price = GAS_PRICE()
    est_gas_cost = GAS_LIMIT * gas_price

    if eth_balance < est_gas_cost:
        print(f"❌ Недостаточно ETH на газ: {eth_balance_ether} ETH у {sender}")
        return

    contract = w3.eth.contract(address=ERC20_CONTRACT_ADDRESS, abi=[
        {"constant": False, "inputs": [{"name": "_to", "type": "address"}, {"name": "_value", "type": "uint256"}],
         "name": "transfer", "outputs": [{"name": "", "type": "bool"}], "type": "function"}
    ])

    nonce = w3.eth.get_transaction_count(sender)
    amount = token_balance  # отправляем весь доступный остаток

    try:
        est_gas = contract.functions.transfer(recipient, amount).estimate_gas({'from': sender})
        tx = contract.functions.transfer(recipient, amount).build_transaction({
            'from': sender,
            'nonce': nonce,
            'gas': est_gas,
            'gasPrice': gas_price,
            'chainId': CHAIN_ID
        })
        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        print(f"✅ Отправлено {amount / 10 ** TOKEN_DECIMALS:.8f} SQD: {w3.to_hex(tx_hash)}")
    except Exception as e:
        print(f"❌ Ошибка при отправке с {sender}: {e}")

def main():
    with open("addresses_sqd.txt", "r") as file:
        lines = file.readlines()

    for line in lines:
        try:
            sender, private_key, recipient = line.strip().split(";")
            sender = w3.to_checksum_address(sender)
            recipient = w3.to_checksum_address(recipient)
            balance = get_token_balance_raw(sender)
            print(f"💰 {sender}: {balance / 10 ** TOKEN_DECIMALS:.8f} SQD")
            send_tokens(private_key, sender, recipient)
            time.sleep(2)
        except Exception as e:
            print(f"⚠️ Пропущено {line.strip()}: {e}")

if __name__ == "__main__":
    main()
