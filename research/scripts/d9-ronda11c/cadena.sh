#!/bin/bash
# Cadena de corridas de la ronda 11c, en segundo plano y EN SERIE (<= 12 procesos a la vez).
cd /home/katana/zeo/ZEROX
D=research/scripts/d9-ronda11c
while pgrep -f "r11c_a_control.py" > /dev/null; do sleep 10; done
python3 -u $D/r11c_c3_lema.py       > $D/salida_c3.txt      2>&1
python3 -u $D/r11c_d_censura.py     > $D/salida_d.txt       2>&1
python3 -u $D/r11c_c25_fabricar.py  > $D/salida_c25.txt     2>&1
python3 -u $D/r11c_c14_dosvistas.py > $D/salida_c14.txt     2>&1
python3 -u $D/r11c_b_hipotesis.py   > $D/salida_b.txt       2>&1
python3 -u $D/r11c_a2_laguna41.py   > $D/salida_a2.txt      2>&1
echo "CADENA TERMINADA"
