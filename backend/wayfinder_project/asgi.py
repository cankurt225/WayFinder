"""
ASGI config for wayfinder_project project.

Django Channels ile WebSocket destegi saglanir.
HTTP istekleri standart Django'ya, ws:// istekleri ise
frame_processor consumer'larina yonlendirilir.
"""

import os

from channels.auth import AuthMiddlewareStack
from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'wayfinder_project.settings')

# Django ORM ve diger modullerin yuklenmesi icin
# get_asgi_application() ONCE cagrilmalidir.
django_asgi_app = get_asgi_application()

# Import routing AFTER Django setup to avoid AppRegistryNotReady
from frame_processor.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter({
    # Standart HTTP istekleri
    "http": django_asgi_app,

    # WebSocket baglantilari
    "websocket": AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)
    ),
})
