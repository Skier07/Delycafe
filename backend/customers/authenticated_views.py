from rest_framework.views import APIView

from customers.authentication import CustomerTokenAuthentication
from customers.permissions import IsAuthenticatedCustomer


class AuthenticatedCustomerAPIView(APIView):
    authentication_classes = [CustomerTokenAuthentication]
    permission_classes = [IsAuthenticatedCustomer]
