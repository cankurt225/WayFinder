"""
frame_processor.consumers
~~~~~~~~~~~~~~~~~~~~~~~~~~
WebSocket consumer: Frontend'den gelen goruntu frame'lerini
anlik olarak dinler, OpenCV formatina cevirir, YOLO inference
calistirir ve sonuclari JSON olarak geri gonderir.

Protokol
--------
GELEN (Client -> Server):
  - Text mesaj:  JSON { "frame": "<base64_encoded_image>" }
  - Binary mesaj: ham JPEG/PNG byte'lari

GIDEN (Server -> Client):
  - Text mesaj:  JSON {
        "type": "detection_result",
        "detections": [...],
        "frame_shape": [H, W, C],
        "inference_time_ms": float,
        "frame_id": int,
    }
  - Hata durumunda: JSON {
        "type": "error",
        "message": str,
    }
"""

import json
import logging
import time

from channels.generic.websocket import AsyncWebsocketConsumer

from .frame_utils import decode_base64_frame, decode_binary_frame
from .inference import run_yolo_inference

logger = logging.getLogger("frame_processor")


class FrameConsumer(AsyncWebsocketConsumer):
    """
    Async WebSocket consumer: saniyede birden fazla goruntu
    frame'ini sifir HTTP overhead ile isler.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.frame_count: int = 0
        self.connect_time: float = 0.0

    # ------------------------------------------------------------------
    # Baglanti yasam dongusu
    # ------------------------------------------------------------------

    async def connect(self):
        """WebSocket baglantisi acildiginda cagrilir."""
        self.connect_time = time.time()
        self.frame_count = 0
        await self.accept()

        logger.info(
            "WebSocket baglantisi kabul edildi: %s",
            self.scope.get("client", "unknown"),
        )

        # Baglanti onay mesaji gonder
        await self.send(text_data=json.dumps({
            "type": "connection_established",
            "message": "Wayfinder frame stream baglantisi kuruldu.",
        }))

    async def disconnect(self, close_code):
        """WebSocket baglantisi kapandiginda cagrilir."""
        elapsed = time.time() - self.connect_time if self.connect_time else 0
        logger.info(
            "WebSocket baglantisi kapatildi (code=%s). "
            "Toplam frame: %d, Sure: %.1f sn",
            close_code,
            self.frame_count,
            elapsed,
        )

    # ------------------------------------------------------------------
    # Mesaj isleyiciler
    # ------------------------------------------------------------------

    async def receive(self, text_data=None, bytes_data=None):
        """
        Frontend'den gelen her mesaji isler.

        - text_data: Base64 formatinda JSON { "frame": "..." }
        - bytes_data: Ham binary goruntu verisi (JPEG/PNG)
        """
        self.frame_count += 1
        frame_id = self.frame_count

        try:
            if bytes_data is not None:
                # Binary frame (daha dusuk overhead)
                frame = decode_binary_frame(bytes_data)
            elif text_data is not None:
                payload = json.loads(text_data)
                base64_str = payload.get("frame")

                if not base64_str:
                    await self._send_error(
                        "Gecersiz format. 'frame' alani zorunludur.",
                        frame_id,
                    )
                    return

                frame = decode_base64_frame(base64_str)
            else:
                await self._send_error("Bos mesaj alindi.", frame_id)
                return

            # ----------------------------------------------------------
            # YOLO inference calistir
            # ----------------------------------------------------------
            result = run_yolo_inference(frame)

            # Sonuclari JSON olarak geri gonder
            await self.send(text_data=json.dumps({
                "type": "detection_result",
                "frame_id": frame_id,
                **result,
            }))

        except json.JSONDecodeError:
            await self._send_error(
                "Gecersiz JSON formati.", frame_id
            )
        except ValueError as exc:
            await self._send_error(str(exc), frame_id)
        except Exception as exc:
            logger.exception("Frame #%d islenirken beklenmedik hata", frame_id)
            await self._send_error(
                f"Sunucu hatasi: {type(exc).__name__}", frame_id
            )

    # ------------------------------------------------------------------
    # Yardimci metodlar
    # ------------------------------------------------------------------

    async def _send_error(self, message: str, frame_id: int | None = None):
        """Hata mesajini WebSocket uzerinden JSON olarak gonderir."""
        logger.warning("Frame #%s hatasi: %s", frame_id, message)
        await self.send(text_data=json.dumps({
            "type": "error",
            "message": message,
            "frame_id": frame_id,
        }))
