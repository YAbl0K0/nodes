
import requests

def get_my_ip():
    # Получаем внешний IP текущей машины
    response = requests.get('https://api.ipify.org?format=json')
    return response.json()['ip']

def main():
    user_input = input("Введите IP для поиска или нажмите Enter для определения вашего IP: ").strip()

    if user_input == "":
        ip = get_my_ip()
        print(f"Ваш внешний IP: {ip}")
    else:
        ip = user_input

    response = requests.get(f"http://ip-api.com/json/{ip}")
    data = response.json()

    if data['status'] == 'success':
        print(f"IP: {data['query']}")
        print(f"Страна: {data['country']}")
    else:
        print(f"❌ Ошибка: {data['message']}")

if __name__ == "__main__":
    main()
