import requests
import time
import csv
import os

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
    'mantle': 'https://explorer.mantle.xyz/api',  # Mantle на данный момент не имеет публичного API полностью аналогичного etherscan
    'opbnb': 'https://api.opbnbscan.com/api',
    'base': 'https://api.basescan.org/api'
}

# Читаем кошельки
with open('1accaunts.txt', 'r') as f:
    wallets = [line.strip() for line in f if line.strip()]

# Собираем данные
for chain in API_URLS:
    print(f"Processing {chain}...")
    api_url = API_URLS[chain]
    api_key = API_KEYS[chain]

    os.makedirs('results', exist_ok=True)
    with open(f'results/{chain}.csv', 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['wallet', 'hash', 'timestamp', 'to', 'tokenSymbol', 'value'])

        for wallet in wallets:
            # ETH (native coin) outgoing tx (если поддерживается API)
            if chain in ['bsc', 'arbitrum', 'base', 'opbnb']:
                url_normal = f"{api_url}?module=account&action=txlist&address={wallet}&startblock=0&endblock=99999999&sort=asc&apikey={api_key}"
                resp = requests.get(url_normal)
                data = resp.json()
                if data['status'] == '1':
                    for tx in data['result']:
                        if tx['from'].lower() == wallet.lower():
                            writer.writerow([wallet, tx['hash'], tx['timeStamp'], tx['to'], 'Native', int(tx['value'])/10**18])
                time.sleep(0.2)

                # ERC20 outgoing tx
                url_token = f"{api_url}?module=account&action=tokentx&address={wallet}&startblock=0&endblock=99999999&sort=asc&apikey={api_key}"
                resp = requests.get(url_token)
                data = resp.json()
                if data['status'] == '1':
                    for tx in data['result']:
                        if tx['from'].lower() == wallet.lower():
                            decimals = int(tx['tokenDecimal']) if tx['tokenDecimal'] else 18
                            value = int(tx['value']) / 10**decimals
                            writer.writerow([wallet, tx['hash'], tx['timeStamp'], tx['to'], tx['tokenSymbol'], value])
                time.sleep(0.2)
            
            elif chain == 'mantle':
                # Mantle пока будем пропускать (нет нормального совместимого API)
                print(f"Mantle: API пока не поддерживается для парсинга историй транзакций.")

print("\nСбор данных завершён. Результаты в папке 'results'.")
