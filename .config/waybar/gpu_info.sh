#!/bin/bash
INFO=$(nvidia-smi --query-gpu=utilization.gpu,utilization.memory,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits)

IFS=', ' read -r GPU_UTIL MEM_UTIL TEMP MEM_USED MEM_TOTAL <<< "$INFO"

printf '{"text": "󰢮  %s%% %s°C", "tooltip": "󰢮 Usage: %s%%\\n󰍛 Vram: %sMB / %sMB\\n Temp: %s°C\\n󰈐 FanSpeed: %s%%"}\n' \
    "$GPU_UTIL" "$TEMP" "$GPU_UTIL" "$MEM_USED" "$MEM_TOTAL" "$TEMP"