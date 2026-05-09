"""
WebSocket URL routing for frame_processor.

Frontend su adrese baglanir:
    ws://<host>:<port>/ws/frames/
"""

from django.urls import re_path

from . import consumers

websocket_urlpatterns = [
    re_path(r"^ws/frames/$", consumers.FrameConsumer.as_asgi()),
]
