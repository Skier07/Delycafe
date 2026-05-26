import json
import urllib.parse
import urllib.request
import urllib.error
from datetime import datetime


def post_json(url, data):
    body = json.dumps(data).encode("utf-8")

    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))

def get_all_nomenclature(token, point_id, price_list_id):
    page = 0
    page_size = 100
    all_items = []

    while True:
        url = (
            "https://api.sbis.ru/retail/v2/nomenclature/list"
            f"?pointId={point_id}"
            f"&priceListId={price_list_id}"
            "&noStopList=true"
            "&withBalance=false"
            f"&page={page}"
            f"&pageSize={page_size}"
        )

        response = get_json(url, token)

        items = response.get("nomenclatures", [])
        all_items.extend(items)

        outcome = response.get("outcome", {})
        has_more = outcome.get("hasMore", False)

        print(f"Страница {page}: получено {len(items)} товаров")

        if not has_more:
            break

        page += 1

    return {
        "nomenclatures": all_items,
        "outcome": {
            "hasMore": False,
            "pagesLoaded": page + 1,
            "totalLoaded": len(all_items),
        },
    }

def get_json(url, token):
    request = urllib.request.Request(
        url,
        method="GET",
        headers={
            "Accept": "application/json",
            "X-SBISAccessToken": token,
        },
    )

    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def save_json(filename, data):
    with open(filename, "w", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, indent=2)

    print(f"Сохранено в файл: {filename}")


def main():
    print("=== Saby menu test ===")
    print("Ключи сюда в чат не отправляй. Вводи только у себя в терминале.\n")

    app_client_id = input("Введите app_client_id / ID подключения: ").strip()
    app_secret = input("Введите app_secret / Защищенный ключ: ").strip()
    secret_key = input("Введите secret_key / Сервисный ключ: ").strip()

    point_id = 187

    auth_url = "https://online.sbis.ru/oauth/service/"

    auth_body = {
        "app_client_id": app_client_id,
        "app_secret": app_secret,
        "secret_key": secret_key,
    }

    print("\nПолучаю токен...")

    try:
        auth_response = post_json(auth_url, auth_body)

        token = auth_response.get("token")

        if not token:
            print("\nТокен не получен. Ответ сервера:")
            print(json.dumps(auth_response, ensure_ascii=False, indent=2))
            return

        print("Токен получен успешно.")

        actual_date = datetime.now().strftime("%d.%m.%Y %H:%M:%S")
        encoded_actual_date = urllib.parse.quote(actual_date)

        price_list_url = (
            "https://api.sbis.ru/retail/nomenclature/price-list"
            f"?pointId={point_id}"
            f"&actualDate={encoded_actual_date}"
            "&page=0"
            "&pageSize=50"
        )

        print("\nПолучаю прайсы / меню...")
        price_list_response = get_json(price_list_url, token)

        print("\nОтвет по прайсам / меню:")
        print(json.dumps(price_list_response, ensure_ascii=False, indent=2))

        save_json("tools/saby_price_lists_response.json", price_list_response)

        print("\nТеперь пробую получить товары по default priceListId = 4...")

        price_list_id = 4

        nomenclature_response = get_all_nomenclature(
            token,
            point_id,
            price_list_id,
        )

        print("\nОтвет по товарам:")
        print(json.dumps(nomenclature_response, ensure_ascii=False, indent=2))

        save_json("tools/saby_nomenclature_response.json", nomenclature_response)

    except urllib.error.HTTPError as error:
        print("\nHTTP ошибка:")
        print("Код:", error.code)

        try:
            error_body = error.read().decode("utf-8")
            print(error_body)
        except Exception:
            pass

    except urllib.error.URLError as error:
        print("\nОшибка соединения:")
        print(error)

    except Exception as error:
        print("\nДругая ошибка:")
        print(error)


if __name__ == "__main__":
    main()