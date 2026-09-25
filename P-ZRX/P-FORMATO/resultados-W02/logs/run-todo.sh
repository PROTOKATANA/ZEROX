#!/usr/bin/env bash
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W02
bash "$Z/logs/run-verificacion.sh"
bash "$Z/logs/run-V5.sh"
bash "$Z/logs/run-V6.sh"
