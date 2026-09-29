from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import FoodPhrase


class FoodPhraseView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        phrases = FoodPhrase.objects.filter(is_active=True).values_list('text', flat=True)
        return Response(list(phrases), headers={'Cache-Control': 'no-cache'})
