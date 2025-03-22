import requests

COVALENT_API_KEY = "CZp2sOzdTa1SZukXkVGpP0kpsyhJL5nL"
CHAIN_ID = 42161  # Arbitrum

def get_sqd_balance_covalent(address):
    try:
        url = f"https://api.covalenthq.com/v1/{CHAIN_ID}/address/{address}/balances_v2/"
        params = {"key": COVALENT_API_KEY}
        response = requests.get(url, params=params)
        data = response.json()

        for token in data["data"]["items"]:
            if token["contract_address"].lower() == "0x1337420ded5adb9980cfc35f82b2b054ea86f8ab":
                raw_balance = int(token["balance"])
                decimals = token["contract_decimals"]
                return round(raw_balance / (10 ** decimals), 3)
        return 0.0  # Якщо SQD не знайдено
    except Exception as e:
        print(f"[DEBUG] Помилка при запиті Covalent для {address}: {e}")
        return 0.0

def check_sqd_from_file():
    try:
        with open("wallet.txt", "r") as file:
            addresses = [line.strip() for line in file.readlines()]
    except FileNotFoundError:
        print("Файл wallet.txt не знайдено.")
        return

    print("Адрес;SQD")
    for address in addresses:
        balance = get_sqd_balance_covalent(address)
        print(f"{address};{balance}")

if __name__ == "__main__":
    check_sqd_from_file()
