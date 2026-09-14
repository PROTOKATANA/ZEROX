# GDR-v0.2 — GHOSTDAG y `rank` en Julia (CPU)

Fecha: 2026-09-14. Revisión del instrumento: **2** (Corrección 1 sobre GDR-v0.1). Estado:
**instrumento de estudio; la única regla de consenso que aplica es la decidida por Katana
(regla C, TAREAS.md §1.3) — el resto de lo que el SPEC no determina sigue como opción**.
Categoría dominante: consenso; secundaria: rendimiento (kernel optimizado con validación de
equivalencia y escalado por hilos). Vive en `veritas/consenso/ghostdag-rank-v1/`, sin
migrar ni validar por Katana; el destino final, si se acepta, es
`veritas/consenso/ghostdag-rank-v1/`.

## Presupuesto de esta sesión (declarado antes de ejecutar, LINEO §7)

Máquina: `znver5`, 32 hilos lógicos, 123,4 GB RAM (perfil verificado en `resultados/ENTORNO.txt`).
Tope de LINEO en esta máquina: 64 GiB de RAM y 24 hilos de cómputo. Esta corrección declara:

- **Tests, vectores de Kaspa, derivaciones D2′-D11, corpus 3.2(d):** 1 hilo, < 1 GiB de RAM, cada
  corrida < 15 s de pared. Ya ejecutados (`resultados/REGISTRO.log`).
- **Escalado por hilos (`bench/escalado.jl`):** hasta 24 hilos, sujeto a convivencia con
  `deepseek/MIDIENDO` (la sesión hermana mide tiempos en `deepseek/prototipos/`; si su candado
  está vivo, esta corrección espera y usa 1 hilo mientras tanto). < 1 GiB de RAM por corrida.
- **Disco temporal:** `tmp/` de este instrumento, < 50 MiB, borrado al terminar.
- Si algún paso agotara este presupuesto, el estado sería **inconcluso** con checkpoint en
  `BITACORA.md`; no ha ocurrido en esta corrección.

## Qué calcula

Dado un DAG de bloques con id de 32 bytes, lista de padres, `slot`, `solution_distance` (`sd`), un
rango de espacio `SR` (peso `w(B) = ⌊2^128/(SR+1)⌋`, exacto) y una identidad de billete opcional
`(public_key, sector_index, history_size, chunk, slot)` (R-FIN-11), el instrumento calcula, como
función pura del pasado de cada bloque `B` —nunca de información futura ni del orden de llegada—:

- el padre seleccionado `sp(B)` (regla C: mayor `blue_work`; empate → menor `sd`; empate → menor
  `id` — dirección mixta, `SP_ZEROX`, `Params()` por defecto);
- el mergeset de `B` sin `sp(B)`, ordenado `(bw, sd, id)` ascendente (`MERGE_SPEC`, sin cambios);
- la partición de ese mergeset en azules, `rojo_k` (excluido por el tope de anticono azul del
  k-cluster) y `rojo_U3` (excluido por unicidad de billete, R-FIN-11);
- `blue_score(B)` y `blue_work(B) = blue_work(sp(B)) + Σ w(x)` sobre `blues(B) = [sp(B)] ++`
  azules del mergeset;
- la cadena seleccionada desde una punta y el orden de aplicación de R-FIN-8′(4) (misma clave que
  el coloreo, regla C), saltando los `rojo_U3`;
- `rank(B) = (blue_work, sd, id)` ascendente — misma tupla que el mergeset — propuesto para P1
  (`PROPUESTA-SPEC.md` §7.2, con demostración escrita de totalidad y compatibilidad causal),
  **texto aún no trasladado a `SPEC.md`**.

Valida, además, la estructura de cada bloque contra los límites declarados: ≤ 15 padres,
mergeset ≤ 180 (k=30, R-FIN-12), `slot(sp(B)) ≤ slot(B)` (C-HDR-05, no estricto), y
`slot(B) − slot(sp(B)) ≤ S_max = 150`.

## Qué NO calcula (fuera de alcance, declarado)

Merge depth bound, pruning, finalidad y `pick_virtual_parents` (política de producción, no de
verificación) quedan explícitamente fuera. El instrumento no deriva PoAS/PoT, compromisos, firmas
ni estado UTXO; la identidad de billete y el resto de campos de cabecera se toman como entrada, no
se autentican. No implementa el controlador de retarget ni ninguna regla de recompensa. No es un
nodo ni un validador de red: es un oráculo/kernel de estudio sobre datos ya construidos.

## Los modos históricos (`:spec`, `:python`, `:kaspa`) siguen implementados, ya no son candidatos

Antes de que Katana decidiera la regla C, el instrumento parametrizaba tres lecturas posibles
(`SpMode`/`MergeMode`) para no elegir en silencio dónde el SPEC, Kaspa y el prototipo Python
discrepaban. Esa ambigüedad para los usos (a), (b), (c) y (d) del orden GHOSTDAG **ya está resuelta
por la regla C** (`DECISIONES-PENDIENTES.md` §0 y §2, D-1/D-2/D-3/D-6 marcados DECIDIDOS). Los tres
modos históricos se conservan en el código, probados con su propio oráculo independiente
(`seleccionar_sp_ref`/`orden_merge_ref`, Corrección 1) y contrastados con contraejemplos
(`DERIVACIONES.md`, D2/D3/D5/D6/D7 vs. D2′/D5′/D6′/D7′), porque documentan por qué ningún modo
anterior coincidía con C — no porque sigan siendo opciones abiertas.

## Dominio numérico de `blue_work`

Tipo propio `BW256` (`hi::UInt128, lo::UInt128`), dominio declarado `[0, 2^256−1]`. Suma y resta
comprueban desbordamiento y lanzan `OverflowError` en vez de envolver silenciosamente. Cota
DEMOSTRADA (Corrección 1, tarea 3.5; `PROPUESTA-SPEC.md` §11): `blue_work(B) < n·2^128` — **158
bits para n=10^9**, muy por debajo de 256. La política de desbordamiento en producción sigue
**PENDIENTE** en SPEC.md §11:1548-1551 (D-5); este instrumento demuestra y mide la cota, no
elige el dominio final de producción.

## Criterios y coste

Aceptación: oráculo (`referencia.jl`, con claves de dirección INDEPENDIENTES del kernel desde
Corrección 1 — ver `MODELO.md` §3) y kernel (`rapido.jl`, incremental, `blue_work` en `BW256`)
deben coincidir exactamente en cada DAG de prueba — cualquier diferencia es fallo, sin
tolerancias. Contra los seis vectores oficiales de rusty-kaspa (dag0–dag5, commit `c338d495`),
con `SP_KASPA`/`MERGE_KASPA` explícitos, el 100 % de los bloques coincide en `sp`, azules, rojos y
`blue_score`. El determinismo exige ≥ 1000 órdenes de entrega distintos por familia de DAG (al
menos una con ventana ≤ 6) con resultado bit a bit idéntico, bajo la regla C.

## Identificador

`GDR-v0.2`. Sin `HUELLAS.sha256`: ese archivo lo genera Claude solo al migrar este instrumento
fuera de `deepseek/`, no esta sesión.
