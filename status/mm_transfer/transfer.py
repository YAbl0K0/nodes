from web3 import Web3
from web3.middleware import geth_poa_middleware  # Убедись, что это импортируется правильно

# RPC-адреса для поддерживаемых сетей
RPC_URLS = {
    "mantle": "https://rpc.mantle.xyz",
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "optimism": "https://mainnet.optimism.io",
    "opbnb": "https://opbnb-mainnet-rpc.bnbchain.org"
}

def connect_to_network(network):
    """ Подключение к выбранной сети """
    if network not in RPC_URLS:
        print(f"❌ Ошибка: Сеть '{network}' не поддерживается!")
        return None

    w3 = Web3(Web3.HTTPProvider(RPC_URLS[network]))
    
    # Добавляем поддержку POA
    w3.middleware_onion.inject(geth_poa_middleware, layer=0)

    if w3.is_connected():
        print(f"✅ Подключено к сети {network.capitalize()} (Block: {w3.eth.block_number})")
        return w3
    else:
        print(f"❌ Ошибка подключения к сети {network.capitalize()}!")
        return None

if __name__ == "__main__":
    print("Выберите сеть: mantle, arbitrum, optimism, opbnb")
    network = input("Введите название сети: ").strip().lower()
    
    w3 = connect_to_network(network)
    
    if w3:
        print(f"🔗 Подключение к сети {network} успешно!")
