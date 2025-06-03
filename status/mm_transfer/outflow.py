import requests
import time
import csv
import os
import threading
from requests.exceptions import ConnectionError, JSONDecodeError
from web3 import Web3
from tqdm import tqdm

# API-сети (через API)
API_KEYS = {
    'bsc': 'HFMB6Z9IGCGG1CGAHING89K89JJU5FAD2S',
    'arbitrum': 'UIUVBSRNQYYRQTMR4W6IGE3HI7VX7JEUIN',
    'base': '1VPXAR3DZS7TU957HW9W2S14NXCJ1N6WV8'
}

API_URLS = {
    'bsc': 'https://api.bscscan.com/api',
    'arbitrum': 'https://api.arbiscan.io/api',
    'base': 'https://api.basescan.org/api'
}

# RPC-сети (через прямой RPC)
RPC_URLS = {
    'mantle': 'https://rpc.mantle.xyz',
    'opbnb': 'https://opbnb-mainnet-rpc.bnbchain.org'
}

# Читаем кошельки
with open('1accaunts.txt', 'r') as f:
    wallets = [line.strip().lower() for line in f if line.strip()]

os.makedirs('results', exist_ok=True)
os.makedirs('logs', exist_ok=True)

def safe_request(url):
    for _ in range(5):
        try:
            resp = requests.get(url, timeout=30)
            if resp.status_code == 200:
                return resp.json()
            else:
                time.sleep(2)
        except Exception:
            time.sleep(2)
    return None

def process_api_wallet(chain, api_url, api_key, wallet):
    csv_path = f'results/{chain}.csv'
    lock = threading.Lock()
    try:
        rows = []
        url_normal = f"{api_url}?module=account&action=txlist&address={wallet}&startblock=0&endblock=99999999&sort=asc&apikey={api_key}"
        data = safe_request(url_normal)
        if data and data.get('status') == '1':
            for tx in data['result']:
                if tx['from'].lower() == wallet:
                    rows.append([wallet, tx['hash'], tx['timeStamp'], tx['to'], 'Native', int(tx['value'])/10**18])

        url_token = f"{api_url}?module=account&action=tokentx&address={wallet}&startblock=0&endblock=99999999&sort=asc&apikey={api_key}"
        data = safe_request(url_token)
        if data and data.get('status') == '1':
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

    except Exception as e:
        with open('logs/errors.log', 'a') as log:
            log.write(f"API {chain} {wallet}: {str(e)}\n")

def process_rpc_wallet(chain, rpc_url, wallet):
    csv_path = f'results/{chain}.csv'
    lock = threading.Lock()
    try:
        web3 = Web3(Web3.HTTPProvider(rpc_url, request_kwargs={'timeout': 60}))
        latest_block = web3.eth.block_number
        chunk = 10000
        rows = []
        
        for start in tqdm(range(0, latest_block, chunk), desc=f"{chain} {wallet}"):
            end = min(start+chunk-1, latest_block)
            
            # Native через блоки
            for block_number in range(start, end+1):
                block = web3.eth.get_block(block_number, full_transactions=True)
                for tx in block.transactions:
                    if tx['from'].lower() == wallet:
                        rows.append([wallet, tx['hash'].hex(), block.timestamp, tx['to'], 'Native', web3.from_wei(tx['value'], 'ether')])
                time.sleep(0.01)
            
            # ERC20 через getLogs
            transfer_topic = web3.keccak(text="Transfer(address,address,uint256)").hex()
            logs = web3.eth.get_logs({
                'fromBlock': start,
                'toBlock': end,
                'topics': [transfer_topic, Web3.to_hex(Web3.to_bytes(hexstr=wallet))]
            })
            for log in logs:
                if len(log['topics']) >= 3:
                    to_addr = '0x' + log['topics'][2].hex()[-40:]
                    value = int(log['data'], 16)
                    rows.append([wallet, log['transactionHash'].hex(), log['blockNumber'], to_addr, 'ERC20', value])
            
            time.sleep(0.05)

        with lock:
            file_exists = os.path.isfile(csv_path)
            with open(csv_path, 'a', newline='') as csvfile:
                writer = csv.writer(csvfile)
                if not file_exists:
                    writer.writerow(['wallet', 'hash', 'timestamp', 'to', 'tokenSymbol', 'value'])
                writer.writerows(rows)
    
    except Exception as e:
        with open('logs/errors.log', 'a') as log:
            log.write(f"RPC {chain} {wallet}: {str(e)}\n")

threads = []

for chain in API_URLS:
    print(f"Processing {chain} (API)...")
    api_url = API_URLS[chain]
    api_key = API_KEYS[chain]

    for wallet in wallets:
        t = threading.Thread(target=process_api_wallet, args=(chain, api_url, api_key, wallet))
        threads.append(t)
        t.start()
        time.sleep(0.1)

for chain in RPC_URLS:
    print(f"Processing {chain} (RPC)...")
    rpc_url = RPC_URLS[chain]

    for wallet in wallets:
        t = threading.Thread(target=process_rpc_wallet, args=(chain, rpc_url, wallet))
        threads.append(t)
        t.start()
        time.sleep(0.1)

for t in threads:
    t.join()

print("\nСбор данных полностью завершён. Результаты в папке 'results'.")
