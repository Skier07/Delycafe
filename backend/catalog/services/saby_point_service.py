import requests

from catalog.services.saby_catalog_service import (
    SabyCatalogService,
)


class SabyPointService:
    URL = "https://api.sbis.ru/retail/point/list"

    def get_points(self):
        token = SabyCatalogService().get_token()

        response = requests.get(
            self.URL,
            headers={
                "X-SBISAccessToken": token,
            },
            params={
                "product": "delivery",
            },
            timeout=30,
        )

        response.raise_for_status()

        return response.json()
