#!/usr/bin/env python3
"""
Detector de tautologías en scripts de auditoría. Reescrito tras el reinicio del 2026-09-08
(el original en /tmp se perdió). Marca sospechas; cada marca hay que leerla.

  T1  Una función recibe un parámetro del atacante ('alpha', 'a', 'att', ...) y NO lo usa en el
      cuerpo. Es el defecto que invalidó r7b_q1, r7_q1 y r7_q7 en la ronda 7: «20 000 trials, 0
      éxitos» con un adversario que no existía.
  T2  Un resultado asignado a un literal numérico/booleano DESPUÉS de haberse calculado en la misma
      función (payoffs cableados: r7_q2 `payoffs[2] = 0.5`).
  T3  Comparación de una expresión consigo misma (`x != x`), o dos variables distintas asignadas
      con la MISMA expresión larga y luego comparadas (d8b_b3: `Ij_A`, `Ij_B` = misma variable).

Uso:  python3 AUDITA_SCRIPTS.py [dir ...]     (por defecto, el directorio del propio script)
Criterio complementario, no automatizable: toda simulación adversarial debe cambiar de resultado
al cambiar alpha. Si con alpha=0 y alpha=0,49 sale lo mismo, no es una simulación.
"""
import ast, sys, pathlib, collections

ADV = {"alpha", "a", "alfa", "att", "attacker", "adv", "q_att", "alpha_a", "beta"}

def revisa(path):
    try:
        tree = ast.parse(path.read_text())
    except SyntaxError:
        return [("PARSE", 0, "no parsea")]
    except Exception as e:
        return [("IO", 0, str(e))]
    out = []
    for fn in [n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)]:
        # T1 · parámetro del atacante muerto
        adv = {a.arg for a in fn.args.args} & ADV
        if adv:
            usados = {n.id for n in ast.walk(fn) if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)}
            for m in sorted(adv - usados):
                out.append(("T1", fn.lineno, f"{fn.name}() recibe '{m}' y NO lo usa"))
        # T2 · literal que sobrescribe un valor calculado
        asignadas = {}
        for n in ast.walk(fn):
            if isinstance(n, ast.Assign) and len(n.targets) == 1:
                clave = ast.dump(n.targets[0])
                es_lit = isinstance(n.value, ast.Constant) and isinstance(n.value.value, (int, float, bool))
                if es_lit and clave in asignadas and not asignadas[clave][1]:
                    out.append(("T2", n.lineno, f"'{ast.unparse(n.targets[0])}' calculado en L{asignadas[clave][0]} y SOBRESCRITO con {n.value.value!r}"))
                asignadas[clave] = (n.lineno, es_lit)
        # T3b · dos variables con el mismo RHS largo
        rhs = collections.defaultdict(list)
        for n in ast.walk(fn):
            if isinstance(n, ast.Assign) and len(n.targets) == 1 and isinstance(n.targets[0], ast.Name):
                src = ast.unparse(n.value)
                if len(src) > 12:
                    rhs[src].append((n.targets[0].id, n.lineno))
        for src, ts in rhs.items():
            nombres = {t[0] for t in ts}
            if len(nombres) > 1 and not any(tok in src for tok in ("random", "rng", "np.")):
                out.append(("T3b", ts[0][1], f"{sorted(nombres)} = MISMA expresión: {src[:70]}"))
    # T3 · comparación consigo mismo
    for n in ast.walk(tree):
        if isinstance(n, ast.Compare) and len(n.comparators) == 1 and ast.unparse(n.left) == ast.unparse(n.comparators[0]):
            out.append(("T3", n.lineno, f"compara consigo mismo: {ast.unparse(n)}"))
    return out

if __name__ == "__main__":
    dirs = [pathlib.Path(p) for p in sys.argv[1:]] or [pathlib.Path(__file__).resolve().parent]
    files = sorted({p for d in dirs if d.exists() for p in d.rglob("*.py") if p.name != pathlib.Path(__file__).name})
    print(f"Scripts analizados: {len(files)}")
    total = 0
    for p in files:
        h = revisa(p)
        if h:
            total += len(h)
            print(f"\n{p}")
            for tipo, ln, msg in h:
                print(f"   [{tipo}] L{ln}: {msg}")
    print(f"\n{'=' * 70}\nSospechas totales: {total}")
