#!/usr/bin/env bash
# Downloads Gabay's on-device AI models and extracts their label lists.
set -u
mkdir -p assets/models assets/labels
base=https://storage.googleapis.com/mediapipe-models

# Object detector: most accurate first, smaller fallbacks after.
for url in \
  "$base/object_detector/efficientdet_lite2/int8/latest/efficientdet_lite2.tflite" \
  "$base/object_detector/efficientdet_lite2/float16/latest/efficientdet_lite2.tflite" \
  "$base/object_detector/efficientdet_lite0/int8/latest/efficientdet_lite0.tflite"; do
  if curl -fsSL -o assets/models/detector.tflite "$url"; then echo "Detector: $url"; break; fi
done
# Label map is packed inside the model file (zip metadata).
unzip -l assets/models/detector.tflite 2>/dev/null | grep -i '\.txt' || true
f=$(unzip -l assets/models/detector.tflite 2>/dev/null | awk '/\.txt/{print $4; exit}')
if [ -n "${f:-}" ]; then unzip -p assets/models/detector.tflite "$f" > assets/labels/detector_labels.txt; echo "Detector labels: $f ($(wc -l < assets/labels/detector_labels.txt) lines)"; fi

# Sound classifier: YAMNet (521 sound classes).
curl -fsSL -o assets/models/yamnet.tflite "$base/audio_classifier/yamnet/float32/latest/yamnet.tflite" && echo "YAMNet downloaded"
f=$(unzip -l assets/models/yamnet.tflite 2>/dev/null | awk '/\.txt|\.csv/{print $4; exit}')
if [ -n "${f:-}" ]; then
  unzip -p assets/models/yamnet.tflite "$f" > assets/labels/yamnet_labels.txt
else
  curl -fsSL https://raw.githubusercontent.com/tensorflow/models/master/research/audioset/yamnet/yamnet_class_map.csv \
    | python3 -c "import csv,sys; r=csv.reader(sys.stdin); next(r); print('\n'.join(row[2] for row in r))" > assets/labels/yamnet_labels.txt
fi
echo "YAMNet labels: $(wc -l < assets/labels/yamnet_labels.txt) lines"; head -3 assets/labels/yamnet_labels.txt
ls -la assets/models assets/labels
