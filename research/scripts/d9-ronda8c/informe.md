# D9-c · Ronda 8c — refutación del ancla en la cadena seleccionada

**Fecha:** 2026-09-08 · **Agente:** D9-c (Opus 5), fresco, sin deferencia al principal.
**Objetivo:** `dag-poas-solucion-ancla.md` + `dag-poas-ancla-de-orden.md` §2 (R-FIN-1..12).
**Directorio:** `research/scripts/d9-ronda8c/` (duradero, en el repo).

## 0 · Instrumento

`r8c_gd.py` — GHOSTDAG mínimo con correspondencia línea a línea al clon `rusty-kaspa @ c338d495`.
Validado por `r8c_test_gd.py` (6 pruebas, todas pasan):

```
t1 cadena pura OK
t2 tope k+1 en mergeset_blues OK (k=2,3,5,25)
t3 blue_work estrictamente creciente sobre el past: 0 violaciones en 121 bloques
t4 orden topologico, 66 bloques, cadena de 20: el bloque va tras su mergeset OK
t5 cadena seleccionada subset de azules OK
t6 R-FIN-12: 13 padres -> TooManyParents OK
```

**VERIFICADO (código+paper) · La fórmula del orden del principal es correcta.**
Algoritmo 1 del paper (`phantom-ghostdag.txt` L361-375):
`order(G) = order(past(Bmax)) ++ [Bmax] ++ anticone(Bmax)`. Desenrollando una vez,
`order(past(Bmax)) = order(past(sp)) ++ [sp] ++ mergeset(Bmax)`, luego
`… , C_{i-1}, mergeset(C_i), C_i, …`. Kaspa hace lo mismo:
`consensus_ordered_mergeset = once(selected_parent).chain(ascending mergeset)`
(`model/stores/ghostdag.rs:86-91`), concatenado a lo largo de la cadena. **El bloque va después de
su mergeset.** Mi `total_order()` lo reproduce y `t4` lo comprueba.

**LEMA propio, DEMOSTRADO y comprobado (t3): `B ∈ past(C) ⇒ blue_work(B) < blue_work(C)`.**
Prueba: `blue_work(C) = blue_work(sp(C)) + Σ_{mergeset_blues(C)} w`, y `mergeset_blues` **siempre
contiene a `sp(C)`** (`ghostdag.rs:115-120`, `new_with_selected_parent` empuja el sp), luego
`bw(C) > bw(sp(C)) ≥ bw(p)` para todo padre `p` (`find_selected_parent` es el máximo). Inducción
sobre el past. Lo uso varias veces abajo.
