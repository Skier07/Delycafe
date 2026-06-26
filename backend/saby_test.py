import requests
from django.conf import settings


def get_saby_token():
    response = requests.post(
        'https://online.sbis.ru/oauth/service/',
        json={
            'app_client_id': settings.SABY_APP_CLIENT_ID,
            'app_secret': settings.SABY_APP_SECRET,
            'secret_key': settings.SABY_SECRET_KEY,
        },
        timeout=30,
    )

    print('STATUS:', response.status_code)
    print(response.text)
