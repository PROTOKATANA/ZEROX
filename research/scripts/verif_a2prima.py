#!/usr/bin/env python3
"""
Variante (A''): lambda = 1/s, tau = 1 s (1 slot de PoT por bloque), R-FIN-1a NO estricta (<=).
D9-f B0 midio que la version ESTRICTA (<) invalida 24-29 % de las aristas de cadena a gran=1:
son EMPATES. Con <= los empates son validos. Aqui se cuenta, con el instrumento de D9-f,
12 semillas, adversario del paper: (a) violaciones de <=, (b) empates, (c) salto maximo de slot.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "d9-ronda8f"))
from r8f_lib import Mundo, slot_de
import r8f_b1_slot as b1
K, MP, HOR = b1.K, b1.MP, b1.HOR
def cadena(d, tip):
    if hasattr(d, "chain"):
        ch=list(d.chain(tip)); return ch if ch and ch[0]!=tip else list(reversed(ch))
    ch=[]; b=tip
    while b is not None:
        ch.append(b); g=d.gd[b]
        b=getattr(g,"selected_parent",None) if getattr(g,"selected_parent",None) is not None else getattr(g,"sp",None)
    return list(reversed(ch))
print(f"k={K} mp={MP} horizonte={HOR}s · 12 semillas · adversario del paper (sin retardo)\n")
print(f"{'gran':>5} {'alpha':>6} {'aristas':>8} {'viol <= (slot sp > slot B)':>27} {'empates (=)':>12} {'salto max (s)':>14}")
print("-"*80)
for gran in (1.0, 0.1):
    for alpha in (0.0, 0.25, 0.40):
        ar=viol=emp=0; smax=0.0
        for semilla in range(12):
            mundo=Mundo(alpha, HOR, semilla, k=K, mp=MP, u3_mode="dynamic")
            d, tip = mundo.corre({}, copias=0)
            ch=cadena(d, tip)
            for p,c in zip(ch, ch[1:]):
                sp_, sc = slot_de(d.B[p].t, gran), slot_de(d.B[c].t, gran)
                ar+=1
                if sp_ > sc: viol+=1
                elif sp_ == sc: emp+=1
                smax=max(smax, (d.B[c].t - d.B[p].t))
        print(f"{gran:5.1f} {alpha:6.2f} {ar:8d} {viol:27d} {emp:8d} ({emp/ar:5.1%}) {smax:14.1f}")
print("""
Lectura: con <= las violaciones son CERO por construccion (un hijo se crea despues de su padre,
luego floor(t_sp/gran) <= floor(t_hijo/gran)). Lo que D9-f B0 contaba como 'invalida 24-29 %'
son los EMPATES, que <= admite. La variante (A'') es factible en R-FIN-1a.""")
