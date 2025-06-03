import requests
import time
import csv
import os
import threading
from requests.exceptions import ConnectionError, JSONDecodeError
from web3 import Web3

# Здесь указываем API ключи для API-сетей
API_KEYS = {
    'bsc': 'HFMB6Z9IGCGG1CGAHING89K89JJU5FAD2S',
    'arbitrum': 'UIUVBSRNQYYRQTMR4W6IGE3HI7VX7JEUIN',
    'base': '1VPXAR3DZS7TU957HW9W2S14NXCJ1N6WV8'
}

# Эндпоинты для API-сетей
API_URLS = {
    'bsc': 'https://api.bscscan.com/api',
    'arbitrum': 'https://api.arbiscan.io/api',
    'base': 'https://api.basescan.org/api'
}

# RPC-сети без API
RPC_URLS = {
    'mantle': 'https://rpc.mantle.xyz',
    'opbnb': 'https://opbnb-mainnet-rpc.bnbchain.org'
}

# Читаем кошельки
with open('1accaunts.txt', 'r') as f:
    wallets = [line.strip().lower() for line in f if line.strip()]

os.makedirs('results', exist_ok=True)

def process_api_wallet(chain, api_url, api_key, wallet):
    csv_path = f'results/{chain}.csv'
    lock = threading.Lock()
    try:
        url_normal = f"{api_url}?module=account&action=txlist&address={wallet}&startblock=0&endblock=99999999&sort=asc&apikey={api_key}"
        resp = requests.get(url_normal)
        if resp.status_code != 200:
            print(f"{chain} {wallet}: HTTP {resp.status_code} on normal txlist")
            return
        try:
            data = resp.json()
        except JSONDecodeError:
            print(f"{chain} {wallet}: JSONDecodeError on normal txlist")
            return

        rows = []
        if data.get('status') == '1':
            for tx in data['result']:
                if tx['from'].lower() == wallet:
                    rows.append([wallet, tx['hash'], tx['timeStamp'], tx['to'], 'Native', int(tx['value'])/10**18])

        url_token = f"{api_url}?module=account&action=tokentx&address={wallet}&startblock=0&endblock=99999999&sort=asc&apikey={api_key}"
        resp = requests.get(url_token)
        if resp.status_code != 200:
            print(f"{chain} {wallet}: HTTP {resp.status_code} on token txlist")
            return
        try:
            data = resp.json()
        except JSONDecodeError:
            print(f"{chain} {wallet}: JSONDecodeError on token txlist")
            return

        if data.get('status') == '1':
            for tx in data['result']:
                if tx['from'].lower() == wallet:
                    decimals = int(tx['tokenDecimal']) if tx['tokenDecimal'] else 18
                    value = int(tx['value']) / 10**decimals
                    rows.append([wallet, tx['hash'], tx['timeStamp'], tx['to'], tx['tokenSymbol'], value])

        with lock:
            file_exists = os.path.isfile(csv_path)
            with open(csv_path, 'a', newline='') as csvfile:
                writer = csv.writer(csvfile)
                if not file_exists:
                    writer.writerow(['wallet', 'hash', 'timestamp', 'to', 'tokenSymbol', 'value'])
                writer.writerows(rows)

    except ConnectionError as e:
        print(f"{chain} {wallet}: Connection error: {e}")
    except Exception as e:
        print(f"{chain} {wallet}: Unexpected error: {e}")

def process_rpc_wallet(chain, rpc_url, wallet):
    csv_path = f'results/{chain}.csv'
    lock = threading.Lock()
    try:
        web3 = Web3(Web3.HTTPProvider(rpc_url))
        latest_block = web3.eth.block_number
        rows = []
        
        for block_number in range(latest_block-5000, latest_block+1):  # ограничиваемся последними 5000 блоков для скорости
            block = web3.eth.get_block(block_number, full_transactions=True)
            for tx in block.transactions:
                if tx['from'].lower() == wallet:
                    rows.append([wallet, tx['hash'].hex(), block.timestamp, tx['to'], 'Native', web3.from_wei(tx['value'], 'ether')])
            time.sleep(0.01)
        
        with lock:
            file_exists = os.path.isfile(csv_path)
            with open(csv_path, 'a', newline='') as csvfile:
                writer = csv.writer(csvfile)
                if not file_exists:
                    writer.writerow(['wallet', 'hash', 'timestamp', 'to', 'tokenSymbol', 'value'])
                writer.writerows(rows)
    except Exception as e:
        print(f"{chain} {wallet}: RPC error: {e}")

threads = []

for chain in API_URLS:
    print(f"Processing {chain} (API)...")
    api_url = API_URLS[chain]
    api_key = API_KEYS[chain]

    for wallet in wallets:
        t = threading.Thread(target=process_api_wallet, args=(chain, api_url, api_key, wallet))
        threads.append(t)
        t.start()
        time.sleep(0.05)

for chain in RPC_URLS:
    print(f"Processing {chain} (RPC)...")
    rpc_url = RPC_URLS[chain]

    for wallet in wallets:
        t = threading.Thread(target=process_rpc_wallet, args=(chain, rpc_url, wallet))
        threads.append(t)
        t.start()
        time.sleep(0.05)

for t in threads:
    t.join()

print("\nСбор данных завершён. Результаты в папке 'results'.")
