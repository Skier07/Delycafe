import logging
from datetime import timedelta

import requests
from django.conf import settings
from django.utils import timezone

from catalog.services.saby_catalog_service import SabyCatalogService
from orders.models import Order

logger = logging.getLogger(__name__)


SABY_STATUS_TO_ORDER_STATUS = {
    'новый': Order.Status.NEW,
    'new': Order.Status.NEW,
    'принят': Order.Status.ACCEPTED,
    'accepted': Order.Status.ACCEPTED,
    'готовится': Order.Status.COOKING,
    'готов': Order.Status.COOKING,
    'cooking': Order.Status.COOKING,
    'передан курьеру': Order.Status.DELIVERY,
    'в доставке': Order.Status.DELIVERY,
    'delivery': Order.Status.DELIVERY,
    'завершён': Order.Status.DONE,
    'завершен': Order.Status.DONE,
    'выполнен': Order.Status.DONE,
    'done': Order.Status.DONE,
    'completed': Order.Status.DONE,
    'отменён': Order.Status.CANCELED,
    'отменен': Order.Status.CANCELED,
    'canceled': Order.Status.CANCELED,
    'cancelled': Order.Status.CANCELED,
}


class SabyOrderStatusService:
    """
    Синхронизация статусов через GET retail/order/list.
    Документация: https://saby.ru/help/integration/api/app_sale/get_sale_data
    """

    ORDER_LIST_URL = 'https://api.sbis.ru/retail/order/list'
    DEFAULT_LIST_DAYS_BACK = 7
    PAGE_SIZE = 100
    MAX_PAGES = 10

    def sync_order_status(self, order: Order) -> bool:
        if not order.saby_sale_id and not order.saby_order_number:
            return False

        from_dt = self._order_list_from_datetime(order)
        to_dt = timezone.now() + timedelta(hours=1)
        sales = self._fetch_sales_list(from_dt, to_dt)

        if sales is None:
            return False

        sale_data = self._match_sale(order, sales)
        if sale_data is None:
            logger.info(
                'Saby sale not found in list for order #%s (sale_id=%s)',
                order.id,
                order.saby_sale_id,
            )
            return False

        return self._apply_sale_state(order, sale_data)

    def sync_active_orders(self, limit: int = 100) -> int:
        active_statuses = [
            Order.Status.NEW,
            Order.Status.ACCEPTED,
            Order.Status.COOKING,
            Order.Status.DELIVERY,
        ]

        orders = list(
            Order.objects.filter(
                saby_sale_id__gt='',
                status__in=active_statuses,
            ).order_by('-created_at')[:limit]
        )

        if not orders:
            return 0

        oldest_order = min(orders, key=lambda item: item.created_at)
        from_dt = self._order_list_from_datetime(oldest_order)
        to_dt = timezone.now() + timedelta(hours=1)
        sales = self._fetch_sales_list(from_dt, to_dt)

        if sales is None:
            return 0

        updated = 0

        for order in orders:
            try:
                sale_data = self._match_sale(order, sales)
                if sale_data is None:
                    continue

                if self._apply_sale_state(order, sale_data):
                    updated += 1
            except Exception:
                logger.exception(
                    'Failed to sync Saby status for order #%s',
                    order.id,
                )

        return updated

    def _order_list_from_datetime(self, order: Order):
        start = order.created_at - timedelta(days=self.DEFAULT_LIST_DAYS_BACK)
        if timezone.is_naive(start):
            start = timezone.make_aware(start, timezone.get_current_timezone())
        return start

    def _fetch_sales_list(self, from_dt, to_dt) -> list[dict] | None:
        token = SabyCatalogService().get_token()

        from_text = timezone.localtime(from_dt).strftime('%Y-%m-%d %H:%M:%S')
        to_text = timezone.localtime(to_dt).strftime('%Y-%m-%d %H:%M:%S')

        collected: list[dict] = []

        for page in range(self.MAX_PAGES):
            params = {
                'pointId': settings.SABY_POINT_ID,
                'fromDateTime': from_text,
                'toDateTime': to_text,
                'page': page,
                'pageSize': self.PAGE_SIZE,
            }

            try:
                response = requests.get(
                    self.ORDER_LIST_URL,
                    headers={
                        'X-SBISAccessToken': token,
                        'Content-Type': 'application/json',
                    },
                    params=params,
                    timeout=30,
                )
            except requests.RequestException:
                logger.exception('Saby order list request failed')
                return None

            logger.info(
                'Saby order list page=%s status=%s body=%s',
                page,
                response.status_code,
                response.text[:500],
            )

            if response.status_code >= 400:
                return None

            try:
                payload = response.json()
            except ValueError:
                return None

            page_sales = self._extract_sales_from_payload(payload)
            collected.extend(page_sales)

            if len(page_sales) < self.PAGE_SIZE:
                break

        return collected

    def _extract_sales_from_payload(self, payload: dict) -> list[dict]:
        orders = payload.get('orders')

        if isinstance(orders, list):
            return [item for item in orders if isinstance(item, dict)]

        if isinstance(payload.get('result'), list):
            return [
                item for item in payload['result']
                if isinstance(item, dict)
            ]

        return []

    def _match_sale(self, order: Order, sales: list[dict]) -> dict | None:
        sale_id = self._parse_sale_id(order.saby_sale_id)
        order_number = (order.saby_order_number or '').strip()
        external_id = (order.saby_external_id or '').strip()

        for sale in sales:
            if sale_id is not None and sale.get('Sale') == sale_id:
                return sale

            if order_number and str(sale.get('Number', '')).strip() == order_number:
                return sale

            if external_id:
                key = str(sale.get('Key', '')).strip()
                if key and key == external_id:
                    return sale

        return None

    def _apply_sale_state(self, order: Order, sale: dict) -> bool:
        if self._is_sale_canceled(sale):
            return self._mark_canceled(order)

        if sale.get('Return') is True:
            return self._mark_canceled(order)

        closed_at = sale.get('ClosedWTZ')
        if closed_at and not self._is_sale_canceled(sale):
            if order.status != Order.Status.DONE:
                order.status = Order.Status.DONE
                order.save(update_fields=['status', 'updated_at'])
                logger.info(
                    'Order #%s marked done from Saby ClosedWTZ=%s',
                    order.id,
                    closed_at,
                )
            return True

        status_name = self._extract_status(sale)
        if status_name:
            mapped_status = self._map_status(status_name)
            if mapped_status is None:
                logger.info(
                    'Unknown Saby status "%s" for order #%s',
                    status_name,
                    order.id,
                )
                return True

            if mapped_status == Order.Status.CANCELED:
                return self._mark_canceled(order)

            if order.status != mapped_status:
                order.status = mapped_status
                order.save(update_fields=['status', 'updated_at'])
                logger.info(
                    'Order #%s status updated to %s from Saby "%s"',
                    order.id,
                    mapped_status,
                    status_name,
                )

        return True

    def _is_sale_canceled(self, sale: dict) -> bool:
        if sale.get('Deleted') is True:
            return True

        if sale.get('Refused') is True:
            return True

        return False

    def _mark_canceled(self, order: Order) -> bool:
        if order.status != Order.Status.CANCELED:
            order.status = Order.Status.CANCELED
            order.save(update_fields=['status', 'updated_at'])
            logger.info('Order #%s marked canceled from Saby', order.id)

        from orders.services import rollback_order

        rollback_order(order)
        return True

    def _parse_sale_id(self, value: str | None) -> int | None:
        if not value:
            return None

        try:
            return int(str(value).strip())
        except (TypeError, ValueError):
            return None

    def _extract_status(self, sale: dict) -> str:
        candidates = [
            sale.get('statusName'),
            sale.get('StatusName'),
            sale.get('status'),
            sale.get('Status'),
            sale.get('stateName'),
            sale.get('StateName'),
            sale.get('SaleName'),
        ]

        for candidate in candidates:
            if candidate:
                return str(candidate).strip()

        return ''

    def _map_status(self, saby_status: str) -> str | None:
        normalized = saby_status.strip().lower()
        return SABY_STATUS_TO_ORDER_STATUS.get(normalized)
