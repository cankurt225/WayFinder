"""
WebSocket baglanti testi.

Kullanim:
    pip install websockets
    python test_ws_client.py

Bu script sunucuya baglanir, kucuk bir test goruntusu gonderir
ve donusu ekrana yazdirir.
"""

import asyncio
import base64
import json
import sys

import numpy as np

# opencv-python-headless goruntu olusturmak icin
import cv2

try:
    import websockets
except ImportError:
    print("[!] websockets kutuphanesi gerekli: pip install websockets")
    sys.exit(1)


WS_URL = "ws://10.16.179.80:8000/ws/frames/"


async def main():
    print(f"[*] {WS_URL} adresine baglaniliyor...")

    async with websockets.connect(WS_URL) as ws:
        # Baglanti onay mesajini oku
        greeting = await ws.recv()
        print(f"[+] Sunucu: {greeting}\n")

        # ----------------------------------------------------------
        # Test 1: Base64 formatinda frame gonder (JSON text mesaj)
        # ----------------------------------------------------------
        print("--- Test 1: Base64 JSON frame ---")
        # 640x480 siyah goruntu olustur
        dummy_frame = np.zeros((480, 640, 3), dtype=np.uint8)
        # Goruntuyu maviye boya (icerik farketmez, codec testi)
        dummy_frame[:] = (255, 128, 0)

        _, buffer = cv2.imencode(".jpg", dummy_frame)
        b64_str = base64.b64encode(buffer).decode("utf-8")

        payload = json.dumps({"frame": b64_str})
        await ws.send(payload)

        response = await ws.recv()
        result = json.loads(response)
        print(json.dumps(result, indent=2, ensure_ascii=False))

        # ----------------------------------------------------------
        # Test 2: Binary frame gonder (ham JPEG byte)
        # ----------------------------------------------------------
        print("\n--- Test 2: Binary JPEG frame ---")
        await ws.send(buffer.tobytes())

        response = await ws.recv()
        result = json.loads(response)
        print(json.dumps(result, indent=2, ensure_ascii=False))

        # ----------------------------------------------------------
        # Test 3: Hata durumu - gecersiz JSON
        # ----------------------------------------------------------
        print("\n--- Test 3: Gecersiz format (hata bekleniyor) ---")
        await ws.send(json.dumps({"wrong_key": "data"}))

        response = await ws.recv()
        result = json.loads(response)
        print(json.dumps(result, indent=2, ensure_ascii=False))

    print("\n[+] Tum testler tamamlandi.")


if __name__ == "__main__":
    asyncio.run(main())
