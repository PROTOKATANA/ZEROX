# LAGUNA 1 de D8: composicion de delta_parasita con la inflacion del retarget.
# El retarget sube lambda hasta que los AZULES observados vuelven a lambda_obj: lambda_real = 1/(1 - delta_total).
# Como k esta en bloques, la unica combinacion adimensional que cambia es Delta*lambda: se simula subiendo LAMBDA
# (eventos/s) con Delta = 4 s fijo. Control: LAMBDA = 1 debe reproducir salida_a1b.txt (0,2867 / 0,3065 con J = 31).
import sys, statistics
import os; H=os.path.dirname(os.path.abspath(__file__)); [sys.path.insert(0, os.path.join(H, d)) for d in ('d8-ronda8', 'd9-ronda8c', 'd9-ronda8f')]
import r8c_sim, d8_lib
from d8_lib import MundoL9, delta_hon
HOR = 1800.0; SEMS = list(range(1, 13))
for lam in (1.0, 1.25, 1.45):
    r8c_sim.LAMBDA = lam                      # el generador de eventos lee el global en tiempo de ejecucion
    for alpha in (0.33, 0.35):
        for J in (31, 48):
            ds = []
            for sem in SEMS:
                m = MundoL9(alpha, HOR, sem, k=30, mp=15)
                d, tip, llega = m.corre_l9(J=J, d_fork=1, giveup=None, modo="parasito")
                dl, n = delta_hon(d, tip, 60.0, HOR - 60.0)
                ds.append(dl)
            print(f"LAMBDA={lam:.2f} (Delta*lambda={4*lam:.0f})  alpha={alpha:.2f}  J={J:2d}  delta={statistics.mean(ds):.4f}  "
                  f"(min {min(ds):.3f} max {max(ds):.3f})  rafagas={m.n_rafagas}", flush=True)
