"""
frame_processor.inference
~~~~~~~~~~~~~~~~~~~~~~~~~~
YOLO obje tanima modeli placeholder'i.

Bu dosyadaki `run_yolo_inference` fonksiyonunu kendi YOLO
implementasyonunuzla degistirin. Mevcut hali temsili (dummy)
sonuclar uretir.
"""

import logging
import time
from typing import Any

import numpy as np

logger = logging.getLogger("frame_processor")


def run_yolo_inference(frame: np.ndarray) -> dict[str, Any]:
    """
    YOLO modeli ile goruntude obje tanima islemi yapar.

    BU FONKSIYON PLACEHOLDER'DIR -- gercek YOLO agirliklarini
    yukleyip inference yapan implementasyonla degistirilecektir.

    Parameters
    ----------
    frame : np.ndarray
        OpenCV BGR formatinda goruntu (H x W x 3).

    Returns
    -------
    dict
        Asagidaki yapida bir sonuc sozlugu:
        {
            "detections": [
                {
                    "label": str,        # Sinif adi (ornegin "person")
                    "confidence": float,  # 0.0 - 1.0 arasi guven skoru
                    "bbox": {
                        "x1": int,        # Sol ust kose X
                        "y1": int,        # Sol ust kose Y
                        "x2": int,        # Sag alt kose X
                        "y2": int,        # Sag alt kose Y
                    }
                },
                ...
            ],
            "frame_shape": [H, W, C],
            "inference_time_ms": float,
        }
    """
    start = time.perf_counter()

    h, w = frame.shape[:2]

    # -------------------------------------------------------
    # TODO: Gercek YOLO inference kodunu buraya ekle.
    #
    # Ornek kullanim (Ultralytics YOLOv8):
    #
    #   from ultralytics import YOLO
    #   model = YOLO("yolov8n.pt")          # Modeli bir kez yukle
    #   results = model(frame, verbose=False)
    #   detections = []
    #   for box in results[0].boxes:
    #       detections.append({
    #           "label": model.names[int(box.cls)],
    #           "confidence": round(float(box.conf), 4),
    #           "bbox": {
    #               "x1": int(box.xyxy[0][0]),
    #               "y1": int(box.xyxy[0][1]),
    #               "x2": int(box.xyxy[0][2]),
    #               "y2": int(box.xyxy[0][3]),
    #           }
    #       })
    # -------------------------------------------------------

    # Placeholder: temsili dummy sonuc
    detections = [
        {
            "label": "person",
            "confidence": 0.92,
            "bbox": {
                "x1": int(w * 0.1),
                "y1": int(h * 0.2),
                "x2": int(w * 0.4),
                "y2": int(h * 0.9),
            },
        },
        {
            "label": "car",
            "confidence": 0.87,
            "bbox": {
                "x1": int(w * 0.5),
                "y1": int(h * 0.4),
                "x2": int(w * 0.9),
                "y2": int(h * 0.8),
            },
        },
    ]

    elapsed_ms = (time.perf_counter() - start) * 1000

    result = {
        "detections": detections,
        "frame_shape": list(frame.shape),
        "inference_time_ms": round(elapsed_ms, 2),
    }

    logger.info(
        "Inference tamamlandi: %d tespit, %.1f ms",
        len(detections),
        elapsed_ms,
    )

    return result
