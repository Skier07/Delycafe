import json
import urllib.request
import urllib.error


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


def main():
    print("=== Saby API test ===")
    print("Ключи сюда в чат не отправляй. Вводи только у себя в терминале.\n")

    app_client_id = input("Введите app_client_id / ID подключения: ").strip()
    app_secret = input("Введите app_secret / Защищенный ключ: ").strip()
    secret_key = input("Введите secret_key / Сервисный ключ: ").strip()

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

        point_url = (
            "https://api.sbis.ru/retail/point/list"
            "?product=delivery"
            "&withPrices=true"
            "&withPhones=true"
            "&withSchedule=true"
            "&page=0"
            "&pageSize=50"
        )

        print("\nПроверяю точки продаж...")

        points_response = get_json(point_url, token)

        print("\nОтвет по точкам продаж:")
        print(json.dumps(points_response, ensure_ascii=False, indent=2))

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