"""
frame_processor.frame_utils
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Gelen Base64 veya binary goruntu verisini OpenCV (cv2) formatinda
numpy dizisine ceviren yardimci fonksiyonlar.
"""

import base64
import logging

import cv2
import numpy as np

logger = logging.getLogger("frame_processor")


def decode_base64_frame(data: str) -> np.ndarray:
    """
    Base64 formatindaki goruntu verisini OpenCV formatinda BGR numpy
    dizisine cevirir.

    Parameters
    ----------
    data : str
        Base64-encoded goruntu verisi.
        Data URI prefix'i varsa (ornegin "data:image/jpeg;base64,...")
        otomatik olarak ayiklanir.

    Returns
    -------
    np.ndarray
        OpenCV BGR formatinda goruntu (H x W x 3).

    Raises
    ------
    ValueError
        Base64 decode veya goruntu decode basarisiz olursa.
    """
    # Data-URI prefix'ini temizle (eger varsa)
    if "," in data:
        data = data.split(",", 1)[1]

    try:
        raw_bytes = base64.b64decode(data)
    except Exception as exc:
        raise ValueError(f"Base64 decode hatasi: {exc}") from exc

    return _bytes_to_cv2(raw_bytes)


def decode_binary_frame(data: bytes) -> np.ndarray:
    """
    Ham binary (JPEG/PNG vb.) goruntu verisini OpenCV formatinda BGR
    numpy dizisine cevirir.

    Parameters
    ----------
    data : bytes
        Goruntu dosyasinin ham byte icerigi.

    Returns
    -------
    np.ndarray
        OpenCV BGR formatinda goruntu (H x W x 3).

    Raises
    ------
    ValueError
        Goruntu decode basarisiz olursa.
    """
    return _bytes_to_cv2(data)


def _bytes_to_cv2(raw_bytes: bytes) -> np.ndarray:
    """
    Byte dizisini cv2 goruntusune cevirir (ortak ic fonksiyon).
    """
    np_arr = np.frombuffer(raw_bytes, dtype=np.uint8)
    frame = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if frame is None:
        raise ValueError(
            "Goruntu decode edilemedi. "
            "Gecerli bir JPEG/PNG formatinda goruntu gonderin."
        )

    logger.debug("Frame decoded: %dx%d", frame.shape[1], frame.shape[0])
    return frame
