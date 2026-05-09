import argparse
import sys
import time
import cv2

# Backend modullerini import edebilmek icin (Django ortamina baglanmadan)
# Sadece inference.py kullanilacak.
from frame_processor.inference import run_yolo_inference

def process_video(input_path: str, output_path: str = "output.mp4"):
    print(f"[*] Video isleniyor: {input_path}")
    
    cap = cv2.VideoCapture(input_path)
    if not cap.isOpened():
        print(f"[!] Hata: Video acilamadi -> {input_path}")
        sys.exit(1)

    # Video ozelliklerini al
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    if fps == 0 or fps != fps: # NaN check
        fps = 30.0

    print(f"[*] Cozunurluk: {width}x{height}, FPS: {fps:.2f}, Toplam Frame: {total_frames}")
    print(f"[*] Cikti dosyasi: {output_path} (Islem basladi...)")

    # Video kayit ayari (mp4 formati icin genelde mp4v kullanilir)
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))

    frame_count = 0
    start_time = time.time()

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_count += 1
        
        # YOLO Modelini calistir
        # model ilk calismada otomatik indirilecektir (yolov8n.pt)
        result = run_yolo_inference(frame)

        # Sonuclari frame uzerine ciz
        for det in result["detections"]:
            bbox = det["bbox"]
            label = det["label"]
            conf = det["confidence"]
            
            x1, y1, x2, y2 = bbox["x1"], bbox["y1"], bbox["x2"], bbox["y2"]
            
            # Kutuyu ciz (Yesil)
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            
            # Etiketi hazirla
            text = f"{label} {conf:.2f}"
            (text_w, text_h), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
            
            # Etiket arka plani
            cv2.rectangle(frame, (x1, y1 - 20), (x1 + text_w, y1), (0, 255, 0), -1)
            # Yazi (Siyah)
            cv2.putText(frame, text, (x1, y1 - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)

        # Gorseli cikti videosuna yaz
        out.write(frame)

        # Gidisi gostermek icin basit bir progress bar (her 10 framede bir yaz)
        if frame_count % 10 == 0 or frame_count == total_frames:
            percent = (frame_count / total_frames) * 100 if total_frames > 0 else 0
            print(f"\rIsleme Durumu: {frame_count}/{total_frames} frame ({percent:.1f}%)", end="")

    cap.release()
    out.release()
    
    elapsed = time.time() - start_time
    print(f"\n[+] Islem tamamlandi! Sure: {elapsed:.2f} saniye.")
    print(f"[+] Cikti dosyasi kaydedildi: {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Yerel video uzerinde YOLOv8 inference calistirir.")
    parser.add_argument("input_video", help="Islenecek girdi videonun yolu (orn: sample.mp4)")
    parser.add_argument("--output", default="output.mp4", help="Cikti video adi (varsayilan: output.mp4)")
    args = parser.parse_args()

    process_video(args.input_video, args.output)
