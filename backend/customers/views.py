from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import BonusTransaction, Customer, CustomerAddress
from .serializers import (
    BonusTransactionSerializer,
    CustomerAddressSerializer,
    CustomerAuthAccountSerializer,
    CustomerProfileSerializer,
)
from .services.saby_customer_service import (
    SabyCustomerService,
    upsert_customer_from_saby,
)


def normalize_phone(value):
    raw_phone = str(value or '').strip()
    digits = ''.join(char for char in raw_phone if char.isdigit())

    if len(digits) == 11 and digits.startswith('8'):
        digits = '7' + digits[1:]

    if len(digits) == 10:
        digits = '7' + digits

    if len(digits) == 11 and digits.startswith('7'):
        return digits

    return digits or raw_phone


def get_or_create_customer_by_phone(phone):
    normalized_phone = normalize_phone(phone)

    if not normalized_phone:
        return None, Response(
            {'detail': 'Не передан телефон.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    customer, _ = Customer.objects.get_or_create(
        phone=normalized_phone,
        defaults={
            'first_order_discount_available': True,
            'first_order_discount_used': False,
        },
    )

    return customer, None


def sync_customer_default_address(customer, address_obj=None):
    if address_obj is None:
        address_obj = customer.addresses.filter(is_default=True).first()

    if address_obj is None:
        customer.default_address = ''
    else:
        customer.default_address = address_obj.full_address

    customer.save(update_fields=['default_address', 'updated_at'])


def sync_customer_from_saby(phone: str):
    service = SabyCustomerService()
    saby_data = service.find_by_phone(phone)

    if saby_data is None:
        return None

    return upsert_customer_from_saby(saby_data)


class CustomerSabyLookupAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        phone = request.query_params.get('phone')
        normalized_phone = normalize_phone(phone)

        if not normalized_phone:
            return Response(
                {'detail': 'Не передан телефон.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            customer = sync_customer_from_saby(normalized_phone)
        except Exception as exc:
            return Response(
                {'detail': f'Ошибка Saby: {exc}'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        if customer is None:
            return Response(
                {
                    'found': False,
                    'phone': SabyCustomerService().format_phone_for_app(
                        normalized_phone,
                    ),
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(
            {
                'found': True,
                'customer': CustomerAuthAccountSerializer(customer).data,
            },
        )


class CustomerAuthMatchAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        raw_phones = request.data.get('phones')

        if not isinstance(raw_phones, list) or not raw_phones:
            return Response(
                {'detail': 'Передайте список phones.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        normalized_phones = []

        for raw_phone in raw_phones:
            normalized_phone = normalize_phone(raw_phone)

            if normalized_phone:
                normalized_phones.append(normalized_phone)

        normalized_phones = list(dict.fromkeys(normalized_phones))

        if not normalized_phones:
            return Response({'accounts': []})

        matched_accounts = []

        for phone in normalized_phones:
            customer = Customer.objects.filter(phone=phone).first()

            if customer is None:
                try:
                    customer = sync_customer_from_saby(phone)
                except Exception:
                    customer = None

            if customer is None:
                continue

            matched_accounts.append(
                CustomerAuthAccountSerializer(customer).data,
            )

        return Response(
            {
                'accounts': matched_accounts,
            },
        )


class CustomerProfileAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        phone = request.query_params.get('phone')
        customer, error_response = get_or_create_customer_by_phone(phone)

        if error_response:
            return error_response

        if request.query_params.get('sync_saby') == '1':
            try:
                synced_customer = sync_customer_from_saby(customer.phone)

                if synced_customer is not None:
                    customer = synced_customer
            except Exception:
                pass

        return Response(CustomerProfileSerializer(customer).data)

    def post(self, request):
        return self._update_profile(request)

    def patch(self, request):
        return self._update_profile(request)

    def _update_profile(self, request):
        phone = request.data.get('phone')
        customer, error_response = get_or_create_customer_by_phone(phone)

        if error_response:
            return error_response

        name = request.data.get('name')

        if name is not None:
            customer.name = str(name).strip()

        default_address = request.data.get('default_address')

        if default_address is not None:
            customer.default_address = str(default_address).strip()

            if customer.default_address:
                address_obj = customer.addresses.filter(is_default=True).first()

                if address_obj is None:
                    customer.addresses.update(is_default=False)

                    CustomerAddress.objects.create(
                        customer=customer,
                        title='Основной',
                        address=customer.default_address,
                        is_default=True,
                    )
                else:
                    address_obj.address = customer.default_address
                    address_obj.save(update_fields=['address', 'updated_at'])

        customer.save(
            update_fields=[
                'name',
                'default_address',
                'updated_at',
            ]
        )

        return Response(CustomerProfileSerializer(customer).data)


class CustomerBonusesAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        phone = request.query_params.get('phone')
        customer, error_response = get_or_create_customer_by_phone(phone)

        if error_response:
            return error_response

        transactions = customer.bonus_transactions.all()[:50]

        return Response(
            {
                'bonus_balance': customer.bonus_balance,
                'first_order_discount_available': customer.first_order_discount_available,
                'first_order_discount_used': customer.first_order_discount_used,
                'transactions': BonusTransactionSerializer(
                    transactions,
                    many=True,
                ).data,
            }
        )


class CustomerAddressesAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        phone = request.query_params.get('phone')
        customer, error_response = get_or_create_customer_by_phone(phone)

        if error_response:
            return error_response

        addresses = customer.addresses.all()

        return Response(CustomerAddressSerializer(addresses, many=True).data)

    def post(self, request):
        phone = request.data.get('phone')
        customer, error_response = get_or_create_customer_by_phone(phone)

        if error_response:
            return error_response

        serializer = CustomerAddressSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        is_first_address = not customer.addresses.exists()
        should_be_default = bool(
            request.data.get('is_default', False)
        ) or is_first_address

        if should_be_default:
            customer.addresses.update(is_default=False)

        address_obj = serializer.save(
            customer=customer,
            is_default=should_be_default,
        )

        if address_obj.is_default:
            sync_customer_default_address(customer, address_obj)

        return Response(
            CustomerAddressSerializer(address_obj).data,
            status=status.HTTP_201_CREATED,
        )


class CustomerAddressDetailAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def patch(self, request, address_id):
        return self._update_address(request, address_id)

    def put(self, request, address_id):
        return self._update_address(request, address_id)

    def delete(self, request, address_id):
        address_obj = CustomerAddress.objects.filter(id=address_id).first()

        if address_obj is None:
            return Response(
                {'detail': 'Адрес не найден.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        customer = address_obj.customer
        was_default = address_obj.is_default

        address_obj.delete()

        if was_default:
            next_address = customer.addresses.first()

            if next_address:
                next_address.is_default = True
                next_address.save(update_fields=['is_default', 'updated_at'])
                sync_customer_default_address(customer, next_address)
            else:
                sync_customer_default_address(customer, None)

        return Response(status=status.HTTP_204_NO_CONTENT)

    def _update_address(self, request, address_id):
        address_obj = CustomerAddress.objects.filter(id=address_id).first()

        if address_obj is None:
            return Response(
                {'detail': 'Адрес не найден.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        customer = address_obj.customer

        serializer = CustomerAddressSerializer(
            address_obj,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)

        should_be_default = request.data.get('is_default')

        if should_be_default is True:
            customer.addresses.exclude(id=address_obj.id).update(
                is_default=False,
            )

        address_obj = serializer.save()

        if address_obj.is_default:
            sync_customer_default_address(customer, address_obj)

        return Response(CustomerAddressSerializer(address_obj).data)


class SetDefaultAddressAPIView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request, address_id):
        address_obj = CustomerAddress.objects.filter(id=address_id).first()

        if address_obj is None:
            return Response(
                {'detail': 'Адрес не найден.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        customer = address_obj.customer

        customer.addresses.exclude(id=address_obj.id).update(
            is_default=False,
        )

        address_obj.is_default = True
        address_obj.save(update_fields=['is_default', 'updated_at'])

        sync_customer_default_address(customer, address_obj)

        return Response(CustomerAddressSerializer(address_obj).data)
