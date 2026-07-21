from rest_framework.permissions import BasePermission

from customers.authentication import (
    CustomerPrincipal,
    OrderAccessPrincipal,
    get_request_customer,
)


class IsAuthenticatedCustomer(BasePermission):
    def has_permission(self, request, view):
        return get_request_customer(request) is not None


class IsCustomerOrOrderAccess(BasePermission):
    def has_permission(self, request, view):
        user = getattr(request, 'user', None)
        return isinstance(user, (CustomerPrincipal, OrderAccessPrincipal))
