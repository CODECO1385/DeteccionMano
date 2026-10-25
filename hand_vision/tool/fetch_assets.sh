#!/usr/bin/env bash
# Descarga MediaPipe y el modelo a web/mediapipe/ para ejecutar sin CDN.
# Después edita web/hand_vision.js y pon useLocal: true.
set -euo pipefail
VER=1.0.1
cd "$(dirname "$0")/.."
mkdir -p web/mediapipe/wasm
tmp=$(mktemp -d)
( cd "$tmp" && npm pack "@mediapipe/tasks-vision@$VER" >/dev/null && tar xzf ./*.tgz )
cp "$tmp/package/vision_bundle.mjs" web/mediapipe/
cp "$tmp/package/wasm/"* web/mediapipe/wasm/
curl -L -o web/mediapipe/hand_landmarker.task \
  https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task
echo "Listo. Pon useLocal: true en web/hand_vision.js"
