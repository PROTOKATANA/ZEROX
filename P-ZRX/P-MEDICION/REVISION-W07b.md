# REVISIÓN W07b — mediciones reales de 0.0.1 (E-0…E-9)

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 21:45). **Ejecutor:** subagente Sonnet, 10:45–21:37 (≈ 10 h
52 min de 8 h: presupuesto superado y declarado). Evidencia: `resultados-W07b/` (informe, receta, bitácora, guiones,
18 análisis del instrumento W07c-B y los `EJECUCION.txt`/`RESULTADO*.txt`/`W07D-VERIFICACION.txt` de cada
repetición); registros crudos (6,1 GiB) y copias de verificación en `deepseek/W07b/`, con `HUELLAS.sha256`.

**Veredicto: SUPERADO, salvo E-7 (penalización del par), que destapa un defecto del producto → ORDEN-W06d10.**

## Lo que el director comprobó por su cuenta

| Qué | Cómo | Resultado |
|---|---|---|
| E-0 sobre `3d21b1f` desde un clon limpio | `run/e0-3d21b1f-ci.log`: códigos de salida y suma de las líneas `test result` | fmt, clippy, build, test, tres guardianes y release a 0; **877/0/6** en 83 binarios; 0 `FAILED`/`panicked` |
| Binarios medidos = binarios de la E-0 | `sha256` de `zx-node` en cada `EJECUCION.txt` de R3/R4 frente a `RECETA.md` §8 | `e7ef7f19…` en todos |
| Huellas | `sha256sum -c HUELLAS.sha256` | 0 fallos |
| Aislamiento real en E-6 | `EJECUCION.txt` de `R3-E6-3d21b1f-rep1`: A en puerto nuevo sin pares | `contactos_A_con_BC=0`, `contactos_B_con_A=0`, `contactos_C_con_A=0` durante 60 slots |
| **Confiscación de E-8 aplicada en el estado** (el ejecutor solo comprobó inclusión) | `garantia_clave_tras_evidencia` (escrito por **cada** nodo al admitir el bloque que aplica la evidencia) en `e8-evidencia.txt` de las tres repeticiones | `activo = 0` en A, B y C en las tres: **confiscación total** (`f = 1`). Rep2 y rep3: `congelado = 0` (nada queda). Rep1: el incluidor fue **A, el propio infractor** (la clave usada por el adversario es la de A): remanente `congelado = 93`, que es la **autodenuncia** de DS-L03 (el incluidor cobra `suelo(C·2/8)`; el infractor pierde ≥ 6/8·C). El importe exacto no se mide aquí (no hay lectura de la garantía antes de la falta); lo cubren T01 v0.5 y SL-4a V5 |
| Causa de E-7 | Lectura del código (`crates/zx-node/src/nodo.rs` ≈ 1528–1546; `crates/zx-p2p/src/servicio.rs` ≈ 666–690, 760–780) | `par_penalizado` y la desconexión por `ViolacionDeConsenso` solo existen en la ruta de **sincronización**; en gossip, `Rechazar` solo llega a `report_message_validation_result(Reject)` y no hay puntuación de pares de gossipsub configurada: **el par no paga nada**. Además el /24 de `127.0.0.1` es común a toda la red dev: vetar el prefijo del adversario vetaría a los honestos. Defecto real → `P-ZRX/P-NODO/ORDEN-W06d10.md` |

## Resultados (repetición por repetición en `resultados-W07b/INFORME.md` §3)

- **E-1…E-4** (R1, `26312ff`, 3 nodos, 30 min de régimen, `SIGKILL` y reinicio): 3/3; ≈ 1 500 bloques PoST por
  repetición, 0 rechazos; mismo `resumen_estado` y `compendio_bloques` con el método W07d.
- **E-5** (R2, nodo tardío tras ≥ 500 bloques): 3/3; puesta al día ≈ 60–64 s; mismo estado en los cuatro.
- **E-6** (partición en PoST, aislamiento verificado): 3/3, reunión en ≈ 12 s. **Esto cierra la V6(b) de W06d7** que
  no se había demostrado.
- **E-6b** (terminales distintos, 3 claves por lado): 3/3; FC-3 predijo el lado ganador por `blue_score` y los tres
  convergieron.
- **E-8** (doble firma, castigo activo): 3/3 (arriba).
- **E-9** (retención del terminal, descriptivo): en rep1 el terminal retenido **ganó** la reunión (reorganización de
  profundidad 30 en B y C). Es el dato de A-07 (semilla del corte): el que retiene puede ganar.
- **E-7**: rechazo con motivo y sin cambio de estado 3/3; **penalización del par 0/3** (defecto, W06d10).

**Cifras (localhost, una máquina de 32 hilos, `N_dev` real, `SR_dev = 13043817825332783104`, ≈ 0,95 bloques por
slot, slot medido 1,28 s):**

| Métrica | R1 (régimen, 3 repeticiones) | Nota |
|---|---|---|
| Verificación de cabecera (PoST + PoT) | p50 66–68 ms, p95 133–192 ms | domina el coste por bloque |
| Admisión GHOSTDAG | p50 0,09 ms (0–499 bloques) → 0,44 ms (1 500–1 999); máx. 1,5–4,0 ms | **crece con la profundidad** (B-12); coherente con RI-1b |
| Persistencia | p50 0,84 ms, p95 4,0 ms | |
| Propagación productor → admisión | p50 ≈ 170 ms, p95 ≈ 0,35–0,42 s, máx. ≈ 1,2 s entre nodos vivos | incluye la verificación; `Δ_p99` no se calculó (el instrumento da p50/p95/máx.) |
| Bloques por slot / padres por bloque | media 0,92–0,96; p50 1, máx. 3 | |
| Fracción del tiempo con puntas distintas | 0,12–0,22 | todas reconvergen salvo 1 episodio abierto al cortar el registro |
| RSS por nodo | 0,79 GiB (p50) – 1,48 GiB (máx.) | |

Tras particiones, la fracción de rojos sube (0,8 en E-6 rep1): es lo esperado en GHOSTDAG con `k = 10` cuando un lado
produce más de `k` bloques fuera de la vista del otro, no un fallo.

## Observaciones del revisor

1. **Dos defectos del producto hallados midiendo** (pánico del productor, W06d8; hueco de portadores PoT, W06d9) y uno
   más ahora (E-7, W06d10): la medición con procesos reales es lo que los sacó; los tests unitarios no.
2. **Contradicción `ESCENARIOS-0.0.1.md` §3 ↔ `ORDEN-W07b.md`** sobre `C-EVP` en E-8: es del director. `ESCENARIOS`
   se escribió antes de que SL-4 activara el castigo; rige la orden. Se corrige `ESCENARIOS` con una nota.
3. **Presupuestos:** reloj 10 h 52 min de 8 h (motivos reales: dos candidatos nuevos a mitad, K_min por lado);
   disco 83 GiB de 50 detectado **al final** (no en tiempo real), corregido a 21 GiB borrando solo `target/debug` de
   los clones, con los hashes de release comprobados antes y después. Aceptado, anotado.
4. **Límites que se mantienen:** localhost y un reloj; máximo 4 nodos; ningún adversario con más espacio o hash;
   `Δ_p99` sin calcular; `estado_final_igual` del instrumento es descriptivo (el veredicto es el de W07d).
5. **Pendiente para cerrar 0.0.1:** W06d10 (E-7 con penalización y 0 falsos positivos) y la E-0 del nuevo candidato.
