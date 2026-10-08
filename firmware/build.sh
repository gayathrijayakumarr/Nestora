#!/usr/bin/env bash
# Compile-check NESTORA V1 firmware (no device required).
set -e
cd "$(dirname "$0")/nestora_v1"
arduino-cli compile \
  --fqbn esp32:esp32:esp32s3 \
  --build-property "build.extra_flags=-DARDUINO_USB_CDC_ON_BOOT=1 -DESP32" \
  .
