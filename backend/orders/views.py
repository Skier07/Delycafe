from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import OrderCreateSerializer, OrderSerializer


class OrderCreateAPIView(APIView):
    def post(self, request):
        serializer = OrderCreateSerializer(data=request.data)

        serializer.is_valid(raise_exception=True)

        order = serializer.save()

        response_serializer = OrderSerializer(
            order,
            context={
                'request': request,
            },
        )

        return Response(
            response_serializer.data,
            status=status.HTTP_201_CREATED,
        )