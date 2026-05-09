"""
frame_processor.inference
~~~~~~~~~~~~~~~~~~~~~~~~~~
YOLO obje tanima modeli entegrasyonu.
"""

import logging
import time
from typing import Any
import numpy as np

try:
    from ultralytics import YOLO
except ImportError:
    YOLO = None

logger = logging.getLogger("frame_processor")

# -------------------------------------------------------------------------
# MODEL YUKLEME ALANI
# -------------------------------------------------------------------------
# GECICI MODEL: Su anda YOLOv8 Nano kullaniliyor.
# ILERIDE DEGISIKLIK: "yolov8n.pt" yerine "yolov26n.pt" veya kendi ozel
# egitilmis modelinizin yolunu buraya yazacaksiniz.
MODEL_PATH = "yolov8n.pt" 

global_model = None

def get_model():
    """Modeli sadece ilk cagrildiginda bellege yukler (Singleton)."""
    global global_model
    if global_model is None:
        if YOLO is None:
            raise ImportError("ultralytics paketi yuklu degil. Lutfen 'pip install ultralytics' calistirin.")
        logger.info(f"YOLO modeli yukleniyor: {MODEL_PATH}")
        global_model = YOLO(MODEL_PATH)
    return global_model


def run_yolo_inference(frame: np.ndarray) -> dict[str, Any]:
    """
    YOLO modeli ile goruntude obje tanima islemi yapar.

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
                        "x1": int,
                        "y1": int,
                        "x2": int,
                        "y2": int,
                    }
                },
                ...
            ],
            "frame_shape": [H, W, C],
            "inference_time_ms": float,
        }
    """
    start = time.perf_counter()
    model = get_model()

    # Inference islemi (verbose=False ile log kirliligini onluyoruz)
    results = model(frame, verbose=False)
    
    detections = []
    # results genelde tek bir goruntu icin tek bir eleman iceren liste doner
    for box in results[0].boxes:
        # box.xyxy formatinda: [x1, y1, x2, y2]
        x1, y1, x2, y2 = box.xyxy[0].tolist()
        
        # Sınıf adı ve güven skoru
        cls_id = int(box.cls[0].item())
        conf = float(box.conf[0].item())
        label = model.names[cls_id]

        detections.append({
            "label": label,
            "confidence": round(conf, 4),
            "bbox": {
                "x1": int(x1),
                "y1": int(y1),
                "x2": int(x2),
                "y2": int(y2),
            }
        })

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
