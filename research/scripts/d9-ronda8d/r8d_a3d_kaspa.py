#!/usr/bin/env python3
"""
r8d_a3d_kaspa.py — ?es el dano de A3(2) real, o un artefacto de un `pick_virtual_parents`
INCOMPLETO?

El `_padres` de D9-c (r8c_sim.py) lleva el PRESUPUESTO pero NO la rama de SUSTITUCION:
cuando un candidato no cabe, Kaspa no lo descarta, lo **sustituye por un ancestro suyo**
(`MergesetIncreaseResult::Rejected { new_candidate }`,
 consensus/src/pipeline/virtual_processor/processor.rs:1099-1114), y retira de la cola a
todos los candidatos que estan en el futuro del nuevo. `mergeset_increase` esta en :1121-1148.

Aqui se implementa esa rama (`MundoKaspa`) y se repite la medida de delta_hon. Si el dano
desaparece, R-FIN-12 COMPLETA cierra el ataque de presupuesto; si no, no lo cierra.

NO IMPLEMENTADO, y se declara: el `shuffle` de :1070-1089 (aleatorio, no controlable por el
atacante) y `remove_bounded_merge_breaking_parents` (:1117).

Criterio alpha: alpha = 0 -> delta_hon = huerfanos honestos, igual en los dos algoritmos.
"""
from r8d_lib import Mundo, LAMBDA
from r8d_a1_menu import K, MP

T1, T2 = 80.0, 300.0


class MundoKaspa(Mundo):
    """Sobrescribe SOLO la seleccion de padres; el resto es el simulador de D9-c."""

    def _mergeset_increase(self, d, sps, cand, budget):
        queue = list(d.B[cand].parents)
        visited = set(queue)
        inc = 1
        while queue:
            cur = queue.pop(0)
            if any(d.is_ancestor(cur, sp) for sp in sps):
                continue
            inc += 1
            if inc > budget:
                return ("rejected", cur)
            for p in d.B[cur].parents:
                if p not in visited:
                    visited.add(p)
                    queue.append(p)
        return ("accepted", inc)

    def _padres(self, d, visibles):
        cands = sorted(d.tips(visibles), key=lambda h: -d.gd[h].blue_work)
        sp = cands[0]
        cola = list(cands[1:])
        padres = [sp]
        ms = 1
        while cola:
            if ms >= self.msl or len(padres) >= self.mp:
                break
            c = cola.pop(0)
            estado, val = self._mergeset_increase(d, padres, c, self.msl - ms)
            if estado == "accepted":
                ms += val
                padres.append(c)
            else:
                nuevo = val
                if any(d.is_ancestor(h, nuevo) for h in cola):
                    continue
                cola = [h for h in cola if not d.is_ancestor(nuevo, h)]
                cola.append(nuevo)
        return padres


def medida(cls, alpha, semilla, T, u3_mode, copias, pol):
    m = cls(alpha, T, semilla, k=K, mp=MP, u3_mode=u3_mode)
    est = {i: (0.0, pol) for i, (t, q, *_) in enumerate(m.ev) if q == "a"}
    d, tip = m.corre(est, copias=copias)
    az = d.blueset(tip)
    hon = [h for h in d.B if d.B[h].creator == "h" and T1 < d.B[h].t <= T2]
    ha = sum(1 for h in hon if h in az)
    nf = sum(1 for h in hon if h != tip and h not in d.anc[tip])
    return 1 - ha / ((1 - alpha) * LAMBDA * (T2 - T1)), nf


if __name__ == "__main__":
    print("=== A3(4) · pick_virtual_parents CON sustitucion frente a SIN sustitucion ===")
    print("ventana [80, 300] s, horizonte 400 s, 5 semillas, delta nominal 0,2105 / real 0,267\n")
    print(f"{'u3':>8} {'cop':>4} {'pol':>10} | {'alpha':>5} | "
          f"{'SIN sustitucion':>22} | {'CON sustitucion (Kaspa)':>26}")
    for u3, cop, pol in (("dynamic", 0, "tips"), ("dynamic", 14, ("retro", 1)),
                         ("dynamic", 14, ("retro", 8)), ("filter", 14, ("retro", 1))):
        for a in (0.0, 0.10, 0.25, 0.40):
            rs0 = [medida(Mundo, a, s, 400.0, u3, cop, pol) for s in range(1, 6)]
            rs1 = [medida(MundoKaspa, a, s, 400.0, u3, cop, pol) for s in range(1, 6)]
            d0 = sum(r[0] for r in rs0) / len(rs0); n0 = sum(r[1] for r in rs0) / len(rs0)
            d1 = sum(r[0] for r in rs1) / len(rs1); n1 = sum(r[1] for r in rs1) / len(rs1)
            print(f"{u3:>8} {cop:>4} {str(pol):>10} | {a:>5.2f} | "
                  f"d={d0:>7.4f}  no fus={n0:>5.1f} | d={d1:>7.4f}  no fus={n1:>5.1f}")
        print()
