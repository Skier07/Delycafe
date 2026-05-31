from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.shortcuts import redirect
from django.urls import include, path


admin.site.site_header = 'DelyCafe'
admin.site.site_title = 'DelyCafe Admin'
admin.site.index_title = 'Панель управления'


def home_redirect(request):
    return redirect('/admin/')


urlpatterns = [
    path('', home_redirect),
    path('admin/', admin.site.urls),
    path('api/catalog/', include('catalog.urls')),
    path('api/orders/', include('orders.urls')),
]

if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,
        document_root=settings.MEDIA_ROOT,
    )