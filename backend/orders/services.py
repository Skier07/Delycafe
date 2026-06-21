from customers.models import BonusTransaction
from orders.models import Order

from datetime import timedelta

from django.utils import timezone

def rollback_order(order: Order):
    """
    Возвращает бонусы и при необходимости
    восстанавливает скидку первого заказа.
    """

    if order.bonus_compensated:
        return

    customer = order.customer
    if customer is None:
        return

    #
    # Возврат начисленных бонусов
    #
    if order.bonus_earned > 0:
        customer.bonus_balance -= order.bonus_earned

        BonusTransaction.objects.create(
            customer=customer,
            transaction_type=BonusTransaction.TransactionType.REFUND,
            amount=-order.bonus_earned,
            order_id=order.id,
            comment=(
                f'Отмена заказа №{order.id}. '
                f'Отмена начисления бонусов.'
            ),
        )

    #
    # Возврат списанных бонусов
    #
    if order.bonus_spent > 0:
        customer.bonus_balance += order.bonus_spent

        BonusTransaction.objects.create(
            customer=customer,
            transaction_type=BonusTransaction.TransactionType.REFUND,
            amount=order.bonus_spent,
            order_id=order.id,
            comment=(
                f'Отмена заказа №{order.id}. '
                f'Возврат списанных бонусов.'
            ),
        )

    #
    # Возврат скидки первого заказа
    #
    if order.first_order_discount_applied:

        completed_discount_orders = (
            Order.objects
            .filter(
                customer=customer,
                first_order_discount_applied=True,
                status=Order.Status.DONE,
            )
            .exclude(id=order.id)
            .exists()
        )

        if not completed_discount_orders:
            customer.first_order_discount_available = True
            customer.first_order_discount_used = False

    customer.save()

    order.bonus_compensated = True
    order.save(update_fields=['bonus_compensated'])

import requests

from django.conf import settings

from catalog.services.saby_catalog_service import (
    SabyCatalogService,
)


class SabyOrderService:
    ORDER_URL = (
        "https://api.sbis.ru/retail/order/create"
    )

    def create_order(self, order):
        token = SabyCatalogService().get_token()

        delivery_time = timezone.localtime() + timedelta(
            hours=2
        )


        nomenclatures = []

        for item in order.items.all():
            if not item.saby_id:
                continue

            nomenclatures.append(
                {
                    "id": item.saby_id,
                    "priceListId": settings.SABY_PRICE_LIST_ID,
                    "count": item.quantity,
                    "name": item.product_title,
                }
            )

        payload = {
            "product": "delivery",
            "pointId": settings.SABY_POINT_ID,
            "comment": order.comment or "",
            "customer": {
                "name": order.customer_name or "Клиент",
                "phone": order.phone,
            },


            "datetime": delivery_time.strftime(
                "%Y-%m-%d %H:%M:%S"
            ),
            "nomenclatures": nomenclatures,
            "delivery": {
                 "addressJSON": {
                    "Address": "Самовывоз",
                    "isPickup": True,
                }
            },
            "isPickup": True,
            "paymentType": "online",
        }

        from pprint import pprint

        print("===== SABY PAYLOAD =====")
        pprint(payload)
        print("========================")

        response = requests.post(
            self.ORDER_URL,
            headers={
                "X-SBISAccessToken": token,
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=60,
        )

        print("SABY STATUS:", response.status_code)
        print("SABY RESPONSE:", response.text)

        saby_response = response.json()

        if saby_response.get("resultCode") == 0:
            order.saby_order_number = (
                saby_response.get("orderNumber", "")
            )

            order.saby_sale_id = str(
                saby_response.get("sale_id", "")
            )

            order.saby_external_id = (
                saby_response.get("externalId", "")
            )

            order.save(
                update_fields=[
                    "saby_order_number",
                    "saby_sale_id",
                    "saby_external_id",
                ]
            )

        return saby_response
