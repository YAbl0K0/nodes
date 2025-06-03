import requests
import time
import csv
import os
import threading
from requests.exceptions import ConnectionError, JSONDecodeError

# Здесь указываем API ключи для каждой сети
API_KEYS = {
    'bsc': 'HFMB6Z9IGCGG1CGAHING89K89JJU5FAD2S',
    'arbitrum': 'UIUVBSRNQYYRQTMR4W6IGE3HI7VX7JEUIN',
    'mantle': 'Y5U5T5IERB24ZBSMCXR35CM8YMJQ8DK91H',
    'opbnb': 'KMCZ4MTSVURVUPMZNQ9A8CAUMN2PB4BK2C',
    'base': '1VPXAR3DZS7TU957HW9W2S14NXCJ1N6WV8'
}

# Эндпоинты для каждой сети
API_URLS = {
    'bsc': 'https://api.bscscan.com/api',
    'arbitrum': 'https://api.arbiscan.io/api',
    'mantle': 'https://explorer.mantle.xyz/api',  # Mantle пока заглушка
    'opbnb': 'https://opbnbscan.com/api',
    'base': 'https://api.basescan.org/api'
}

# Читаем кошельки
with open('1accaunts.txt', 'r') as f:
    wallets = [line.strip() for line in f if line.strip()]

os.makedirs('results', exist_ok=True)

def process_wallet(chain, api_url, api_key, wallet):
    csv_path = f'results/{chain}.csv'
    lock = threading.Lock()

    if chain == 'mantle':
        print(f"Mantle: API пока не поддерживается для парсинга историй транзакций.")
        return

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
                if tx['from'].lower() == wallet.lower():
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
                if tx['from'].lower() == wallet.lower():
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

threads = []

for chain in API_URLS:
    print(f"Processing {chain}...")
    api_url = API_URLS[chain]
    api_key = API_KEYS[chain]

    for wallet in wallets:
        t = threading.Thread(target=process_wallet, args=(chain, api_url, api_key, wallet))
        threads.append(t)
        t.start()
        time.sleep(0.05)

for t in threads:
    t.join()

print("\nСбор данных завершён. Результаты в папке 'results'.")
