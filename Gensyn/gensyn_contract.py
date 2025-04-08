from web3 import Web3

# Подключаемся к ноде (пример: Gensyn testnet RPC)
w3 = Web3(Web3.HTTPProvider("https://rpc.gensyn.network"))

# Адрес контракта
contract_address = Web3.to_checksum_address("0x84bC23FC1188ab882aB671A415cC2Cc79F09B417")

# ABI (только нужные фрагменты)
abi = [
    {
        "name": "getEoa",
        "type": "function",
        "stateMutability": "view",
        "inputs": [{"name": "peerIds", "type": "string[]"}],
        "outputs": [{"name": "", "type": "address[]"}]
    },
    {
        "name": "getTotalWins",
        "type": "function",
        "stateMutability": "view",
        "inputs": [{"name": "peerId", "type": "string"}],
        "outputs": [{"name": "", "type": "uint256"}]
    }
]

contract = w3.eth.contract(address=contract_address, abi=abi)

# Твой peerId
peer_id = "QmeqtpAPzR2wGeDfD1YJVjBzqEfB6fcvp7tkszrp4LFoi"

# Получаем адрес
eoa = contract.functions.getEoa([peer_id]).call()[0]
print(f"EOA address: {eoa}")

# Получаем количество побед
wins = contract.functions.getTotalWins(peer_id).call()
print(f"Total wins: {wins}")
