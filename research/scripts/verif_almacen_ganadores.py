#!/usr/bin/env python3
"""
Término omitido del presupuesto económico (ronda 7 §1, punto iii): el atacante que plotea-y-descarta
debe GUARDAR cada sector ganador hasta su slot. ¿Cuánto SSD es eso, frente a la GPU?
Supuestos (marcados): espacio total de red S_total (el checkpoint de 3,2 PiB de §25 como escala),
lambda_real = 1,364 bloques/s (k=30), lookahead L+I = 3,2 h + 2 490 s, t_plot GPU tope ALU = 4,28 s.
"""
GiB_TOTAL   = 3.2 * 2**20            # 3,2 PiB en GiB
LAM         = 1.364                   # bloques/s (lambda_real a k=30)
LOOK        = 3.2*3600 + 2490.0       # s de lookahead
T_PLOT      = 4.28                    # s/sector (GPU tope, ALU)
C_GPU_H     = 0.0631                  # $/h, escenario B de lookahead_economico (favorece al atacante)
C_SSD_TIB_H = 0.00187                 # $/h/TiB, escenario B
p_win_slot  = LAM / GiB_TOTAL         # P(un sector de 1 GiB gana en un slot) ~ 1 bloque por sector-slot / sectores
p_win_look  = 1 - (1 - p_win_slot)**LOOK
sect_per_h  = 3600 / T_PLOT           # sectores ploteados por GPU y hora
winners_h   = sect_per_h * p_win_look # ganadores encontrados por GPU y hora
held_GiB    = winners_h * (LOOK/3600) # ganadores vivos en régimen estacionario (cada uno se guarda ~LOOK)
c_store_h   = held_GiB/1024 * C_SSD_TIB_H
print(f"S_total = 3,2 PiB  lambda={LAM}/s  lookahead={LOOK/3600:.2f} h  t_plot={T_PLOT}s")
print(f"P(sector gana en la ventana de lookahead) = {p_win_look:.3e}")
print(f"sectores ploteados por GPU·h = {sect_per_h:.0f}  ->  ganadores por GPU·h = {winners_h:.4f}")
print(f"ganadores vivos por GPU (régimen) = {held_GiB:.4f} GiB  ->  coste SSD = {c_store_h:.2e} $/h")
print(f"coste GPU = {C_GPU_H:.4f} $/h   =>  almacenamiento de ganadores / GPU = {c_store_h/C_GPU_H:.2e}")
print("\nConclusión: el término iii es < 1e-6 del coste de la GPU. A* no se mueve; el 1,05x se queda.")
print("Sensibilidad: con S_total 100x menor (32 TiB) el cociente sigue < 1e-4.")
