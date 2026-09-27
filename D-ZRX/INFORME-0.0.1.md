# Informe final de 0.0.1 del ZEROX híbrido — para Katana

**Estado: BORRADOR** (redactado 2026-09-27 desde ≈ 11:00; mediciones de W07b incorporadas a las 23:46). Falta el
veredicto, que espera a W06d10-B y a la E-0 del candidato final. **Firma:** Claude (director, `AUTO-ZRX.md` §8). Todo en commits locales de
la rama `rediseno/v1-spec-first`; nunca push. **Commit candidato:** se fija tras W06d10-B (antes `27dcfeb`, `26312ff` y `3d21b1f`; W06d8 y W06d9 corrigieron dos caídas del productor y W06d10 la falta de penalización del par, todas halladas al medir). R1 y R2 se midieron con `26312ff`; R3 y R4, con `3d21b1f`; E-7 con penalización, con W06d10.

---

## 1. Veredicto

*Pendiente W07b.* Criterio de `AUTO-ZRX.md` §8: 0.0.1 está lista para mediciones reales si su ruta de consenso está
integrada y varios nodos independientes producen, validan, propagan, sincronizan, reinician y revierten con reglas
idénticas; si el corte PoW → PoAS + PoT + DAG se prueba con garantía y espacio elegibles; y si los verificadores de
los mecanismos **activados** aceptan lo válido y rechazan lo inválido; con receta reproducible, registros y
medidas de latencia, recursos, errores y conducta ante ataques y fallos especificados.

**Lo que ya está demostrado antes de W07b** (procesos reales en `127.0.0.1`, órdenes y revisiones citadas):
tres nodos cruzan el corte y convergen (W06d4, W06d6); un nodo que llega tras ≥ 500 bloques PoST alcanza a la red
y termina con el mismo estado (W06d6); una partición PoST con el mismo terminal y una con terminales distintos
convergen al terminal que dicta FC-3 (W06d7); el productor honesto sobrevive a 10 `SIGKILL` sin ninguna evidencia
contra él y a la pérdida de su registro con abstención exacta (SL-4b2); una doble firma real se detecta, se incluye
y se castiga en los tres nodos (SL-4b2, 3/3); las entradas inválidas de `zx-adversario` se rechazan con su motivo
(W06d6). Suite de la raíz: 82 binarios de test, 0 fallos (SL-4b3). Diferenciales Rust ↔ oráculos Julia: T01 v0.5
(3 179 casos) y T04 v0.6 (2 108), **0 discrepancias**.

## 2. Qué es 0.0.1 (ruta vertical)

Génesis dev → PoW SHA3-256 de desarrollo (sin premine) → coinbases maduras → depósitos de garantía por clave →
terminal `T` por CUT-HWΦ → primer bloque PoST hijo de `T` → producción PoAS (Autonomys `f8842d0`) + PoT AES (un
flujo, `N_dev`) con sello Ed25519 **a través del firmante seguro** → GHOSTDAG (`k = 10`, hasta 15 padres) con
estado por fusión (UTXO + garantía + emisión) → FC-3 entre terminales → evidencia de doble firma (`EvidenceTx` v4)
con congelación y confiscación (`f = 1`, `suelo(C·2/8)` al incluidor, resto quemado) → red libp2p con validación
diferida, sincronización por páginas del registro de admisión y límites C-NET → almacén RocksDB con reinicio por
repetición. Detalle regla a regla: `D-ZRX/SPEC-0.0.1.md`.

## 3. Problema → evidencia → decisión → siguiente puerta

| Problema | Evidencia | Decisión | Siguiente puerta |
|---|---|---|---|
| Transición PoW → PoST (A-01) | Oráculo T01 (29,5 M historias); diferencial 0 discrepancias; tres nodos reales | CONTRATO-v0 v0.1 | — (cerrado para dev) |
| Selección a través del corte (A-05, FC-3) | T01/T02 (RFT-13); en el nodo, **incumplía** FC-3 hasta W06d7 (congelaba el terminal); I-3 por propiedades; W07b: E-6 (mismo terminal, aislamiento verificado) y E-6b 3/3 | FC-3 con un DAG por terminal y `C-FIN-01` | Oráculo multiterminal T04-E |
| Semilla del corte (A-07) | Derivación S1/S2/S3 sin instrumento | Marcador S1 `blake3(T)`, **no se reivindica** | Modelo de sesgo T03 |
| Fallo de activación y censura de depósitos (A-08) | T02-A E4: con `h = 0,9` la censura domina | Prolongar PoW | Regla de fallo con coste del ataque |
| Sincronización y nodo tardío (A-09, B-08) | W06d6 (registro de admisión); W06d7 | Sincronización por páginas con cursor por par | Coste lineal por reconexión (E-10) |
| PoW de arranque (A-10, A-12) | CPU 73,8 MH/s; GTX 1070 561 MH/s = 7,6×; 1,94·10⁻⁷ J/hash (A10-M1) | SHA3-256 dev tras interfaz (Katana) | Algoritmo de producción y precios de alquiler |
| Parámetros PoT (B-02) | Slot real 1,66 s (W06d1) y 1,28 s (W07b) con el mismo `N_dev` en la misma máquina | `N_dev` fijo, `D = 0` | `ρ_max` por hardware; segundo VDF (RFT-12) |
| Doble farmeo en rama privada (B-04) | RFT-01, RFT-14 | **No evitable** en la familia; mitigación adoptada en principio: finalidad por votos (X-04) | FV-2…FV-4 (FV-D08: peso provisional solo en dev) |
| `Δ` y `F_slots` (B-05) | W07b en localhost: propagación p50 ≈ 170 ms, p95 ≈ 0,4 s, máx. ≈ 1,2 s (`Δ_p99` sin calcular) | `F_SLOTS = 600` dev | `Δ_p99` medida |
| Coste de admisión GHOSTDAG (B-12) | RI-1b: 90 µs → 1,66 ms de 2 000 a 16 000 bloques; W07b en red real: p50 0,09 → 0,44 ms de 0–499 a 1 500–1 999 bloques | Aceptado en dev | Índice de alcanzabilidad acotado |
| Garantía: forma y cuantía (C-02) | SL-2: por identidad es regresiva (RFT-23) | `q = 10` ZZK por clave, dev | Garantía por unidad de espacio |
| Evidencia y castigo (C-04, C-09, C-11) | SL-1…SL-4c; RI-3b; procesos reales (SL-4b2) | **Activo en dev**; `EvidenceTx` mal formada invalida el bloque | — |
| Retención de recompensas (C-12) | Sin regla con la forma del modelo; la coinbase PoST va entera a la garantía (D-T08) y es confiscable hasta retirarla y liberarla (EV-17, RAT-3) | Sin disuasión reivindicada en 0.0.1 | SL-2c: ¿basta para la región de SL-2b? |
| Registro de sectores, PoRep, auditorías (D-01…D-05) | S01 (G1); DS-4: regenerar cuesta ≈ 7,1 GPU y 677 W por TiB (GTX 1070) | **No activo** (`SEC-0`) | Encargos 02–05 en plantilla §6 |
| Finalidad por votos (X-04) | FV-1, AV-1; RFT-17…RFT-21 | Adoptada en principio (FV-D02); `b = 2`; FV-D08 | FV-2, FV-3, FV-4 tras 0.0.1 |

## 4. Mediciones reales de 0.0.1

Fuente: W07b (`P-ZRX/P-MEDICION/REVISION-W07b.md`, `resultados-W07b/`) y W06d10 (`P-ZRX/P-NODO/REVISION-W06d10.md`).
Procesos reales en `127.0.0.1`, una máquina de 32 hilos, `N_dev` real, una clave por nodo (salvo E-6b y E-9: 3 claves
por lado), `SR_dev = 13043817825332783104` (calibrado en E-2a: 0,99 bloques por slot). Veredicto de «mismo estado»:
reabrir cada nodo aislado sobre una **copia** de sus datos y comparar `resumen_estado` y `compendio_bloques` (W07d).

| Escenario | Commit | Resultado (3 repeticiones salvo indicación) |
|---|---|---|
| E-0 receta desde clon limpio | `27dcfeb`, `26312ff`, `3d21b1f` | superada en los tres; en `3d21b1f`: 877/0/6, fmt, clippy, guardianes. *Pendiente: candidato final* |
| E-1…E-4 cruce del corte, 30 min de régimen, `SIGKILL` y reinicio | `26312ff` | superadas; ≈ 1 500 bloques PoST por repetición, 0 rechazos; reinicio y puesta al día ≈ 104–118 s |
| E-5 nodo tardío (tras ≥ 500 bloques) | `26312ff` | superada; puesta al día ≈ 60–64 s; mismo estado en los cuatro |
| E-6 partición en PoST, aislamiento verificado (0 contactos) | `3d21b1f` | superada; reunión en ≈ 12 s |
| E-6b terminales distintos | `3d21b1f` | superada; FC-3 predijo el lado ganador y los tres convergieron |
| E-7 entradas inválidas | `3d21b1f`; penalización con W06d10 | rechazo con motivo y sin cambio de estado 3/3; **penalización del par 0/3 con `3d21b1f`** (defecto) → **4/4 por repetición tras W06d10**, 0 falsos positivos |
| E-8 doble firma con castigo | `3d21b1f` | superada; confiscación total en los tres nodos (comprobada en el estado por el director); en rep1 el propio infractor incluyó la prueba (autodenuncia, DS-L03) |
| E-9 retención del terminal | `3d21b1f` | descriptivo; en rep1 el terminal retenido **ganó** la reunión (reorganización de 30 en B y C) |

| Métrica (R1, régimen) | Valor | Nota |
|---|---|---|
| Slot real con `N_dev` | **1,28 s** (W07b, 3 nodos) | W06d1 midió 1,66 s en la misma máquina; causa no investigada |
| Verificación de cabecera (PoST + PoT) | p50 66–68 ms, p95 133–192 ms | domina el coste por bloque |
| Admisión GHOSTDAG | p50 0,09 ms (0–499 bloques) → 0,44 ms (1 500–1 999) | **crece con la profundidad** (B-12) |
| Persistencia | p50 0,84 ms, p95 4,0 ms | |
| Propagación productor → admisión | p50 ≈ 170 ms, p95 ≈ 0,35–0,42 s, máx. ≈ 1,2 s | en localhost, con verificación; `Δ_p99` no calculado |
| Bloques por slot | media 0,92–0,96 | padres por bloque: p50 1, máx. 3 |
| Tiempo con puntas distintas | 12–22 % | todas reconvergen |
| RSS por nodo | 0,79 GiB (p50) – 1,48 GiB (máx.) | |


## 5. Malas noticias (completas)

1. **El doble farmeo en rama privada sigue sin cerrarse** (RFT-01, RFT-14): ningún mecanismo de PoStake ni de
   Filecoin lo encarece de forma exigible frente al atacante con espacio propio suficiente; la finalidad por votos
   lo arrincona, no lo cierra, y aún no existe en código.
2. **La disuasión del castigo está sin comprobar**: el modelo (SL-2b) supone una retención de recompensas que
   ninguna regla implementa; el código retiene de otra forma (la coinbase PoST va entera a la garantía y es
   confiscable hasta retirarla y liberarla). Si eso basta lo dirá SL-2c (C-12). En 0.0.1 el castigo es el
   **mecanismo** (detectar, incluir, confiscar), con parámetros dev.
3. **Dos afirmaciones excesivas mías en `SPEC-0.0.1`**, corregidas al descubrirlas: TRN-09 «validada con procesos
   reales» (el nodo congelaba el terminal: no era FC-3) y parámetros de retención y `q = 20` como si estuvieran en
   el código.
4. **Un fallo crítico lo introdujo una corrección dirigida por mí** (RI-2b → persistir antes de admitir sin deshacer:
   el nodo no podía reiniciar tras un bloque verificable pero inadmisible). Lo encontró la revisión independiente
   RI-3c; corregido en W06d6.
5. **Sin oráculo independiente del caso multiterminal** en DAG: su evidencia es I-3 por propiedades, el desempate
   reutilizado del motor y procesos reales.
6. **El PoW de arranque es SHA3-256 de desarrollo**: una GPU de consumo rinde 7,6× una CPU de 16 núcleos; el
   algoritmo de producción (A-12) está abierto.
7. **La semilla del corte es un marcador** (A-07): quien mina el terminal puede sesgar los primeros retos.
8. **Varias órdenes necesitaron segunda ronda por errores míos de redacción** (alcances sin fijar, criterios mal
   elegidos, horas escritas a ojo) y dos ejecutores incumplieron reglas (Python para editar texto; eventos retirados
   sin pedirlo), declarados por ellos y registrados.
9. **El productor honesto no puede gastar sus recompensas mientras produce** con la misma clave: la coinbase PoST va
   a la garantía (D-T08) y RAT-3 impide liberar hasta 360 slots después de su último bloque (más `R_SLOTS`). No es un
   fallo de seguridad, pero sí un coste real para el granjero doméstico; lo cuantifica SL-2c y pide una decisión de
   diseño (IPA C-13). Derivado al cerrar, no medido.
10. **Tras el corte, la red de 0.0.1 está cerrada a nuevos productores**: sin relevo de transacciones, quien llega al corte
   sin garantía no puede depositarla nunca (sus depósitos solo irían en sus propios bloques, que no puede producir).
   Con varias claves por nodo, un solo operador puede cumplir `K_min` y dejar fuera a los demás (visto en W07b E-2a).
   IPA A-14; el remedio es el relevo de transacciones, fuera de 0.0.1.
11. **Midiendo apareció un pánico del nodo** (el cambio de terminal en caliente desincronizaba el protocolo entre el
   productor y el bucle: SL-4b2, paso 0). Lo corrigió W06d8 (protocolo numerado, parada ordenada); el candidato pasó
   de `27dcfeb` a `26312ff` y E-0 se repite sobre él.
12. **Segunda caída del nodo hallada midiendo** (W07b R3): el productor moría por un hueco de portadores PoT que dejaban
   los bloques de red con salto de slots. Corregido en W06d9 (origen + red de seguridad); candidato `3d21b1f`.
13. **Una prueba que di por superada no lo era:** la partición con el mismo terminal de W06d7 no aisló al nodo (se
   reconectaba). Corregido en `SPEC-0.0.1`; W07b la mide ahora con aislamiento verificable.
14. **El timestamp de la cabecera PoST no se valida** (ni monotonía ni FTL; el PoW sí). En 0.0.1 no lo consume ninguna
   regla (`N` y `SR` constantes), pero es el requisito previo de un `N` dinámico (IPA B-13, `ENCARGO-ND1`, 0.0.2).
15. **W07b, E-7:** los bloques inválidos difundidos por gossip se rechazaban sin penalizar al par (sin puntuación de
   gossipsub; `par_penalizado` solo en la ruta de sincronización). Corrección: W06d10 (*en curso*).

## 6. Coste absoluto de los ataques relevantes (lo medido o derivado; nada inventado)

| Ataque | Estado en 0.0.1 | Coste o umbral conocido | Fuente |
|---|---|---|---|
| Reescribir el prefijo PoW | Encarece (PoW dev) | Hashrate medido; faltan precios de alquiler | A10-M1 |
| Doble farmeo en rama privada | **No afecta** (no se impide) | Espacio propio; ningún mecanismo exigible | RFT-01, RFT-14 |
| Doble firma publicada | **Detecta y castiga** | Pierde la garantía entera (`f = 1`) menos `suelo(C·2/8)` si se autodenuncia | SL-4b2, RAT-2′ |
| Sembrador (regenerar en vez de guardar) | Encarece (sin auditorías activas) | ≈ 7,1 GTX 1070 y 677 W por TiB para farmear regenerando | DS-4 |
| Terminal retenido / partición en el corte | Converge por FC-3 | Ventana previa al primer PoST = carrera PoW (RFT-13) | W06d7, T02 |
| Inundación de red | Acotada | Límites C-NET; tres DoS corregidos (RI-3a) | W06d6 |
| Pausar / sellar la futura capa de votos | No existe en 0.0.1 | 20 % / 50 % del peso con censura y `b = 2` | RFT-17 |

## 7. Artefactos, decisiones y pruebas

- **SPEC de lo implementado:** `D-ZRX/SPEC-0.0.1.md`. **Problemas abiertos:** `D-ZRX/IPA-ZRX.md`. **Refutaciones:**
  `D-ZRX/RFT-ZRX.md`. **Instrumentos y vectores validados:** `V-ZRX/REGISTRO.md`. **Bitácora:** `R-ZRX/BITACORA.md`.
- **Órdenes de esta etapa** (cada una con su orden, entrada congelada, revisión y resultados en `P-ZRX/`): RI-3a/b/c,
  SL-4b1, SL-4b2, SL-4b3, SL-4c-O (+B, +C), SL-4c (+R), W06d6, W06d7, W07a (+R), W07b, W07c.
- **Decisiones de Katana de esta etapa:** PK-01 → FV-D08 (garantía como peso de voto solo en dev, tras una interfaz
  por sector); PK-02 (archivos solo en la papelera, copiados a `R-ZRX/LEGADO/solo-trash/`).
- **Decisiones del director de esta etapa** (con su motivo en las revisiones): firmante en `zx-post`; `R_SLOTS = 600`;
  `EvidenceTx` mal formada es forma (invalida el bloque); sincronización por registro de admisión; admitir → persistir
  → difundir; un DAG por terminal (FC-3); criterio del coste de registro reformulado.

## 7 bis. Siguiente versión

**Hoja de ruta (Katana, 2026-09-27; `P-ZRX/HOJA-DE-RUTA.md`):** 0.0.2 = (1) medición del doble farmeo + FV-2/FV-3 + `ρ_max`, segundo VDF y `N` dinámico + eclipse
(investigación), (2) relevo de transacciones y prevención del eclipse, (3) PoStake pendiente, (4) coste de admisión GHOSTDAG,
(5) Filecoin; 0.0.3 = finalidad por votos en el nodo y recuperación del eclipse con los votos;
0.0.4 = minero SHA3 para CPU (Rust) y GPU AMD (HIP).

## 8. Lo que 0.0.1 no mide ni afirma

Red pública adversarial, latencia WAN, más de ~5 nodos, adversario con más espacio o hash que los honestos (solo
simulado), relevo de transacciones, sectores Filecoin, disuasión económica, finalidad por votos, seguridad de
producción de ningún parámetro. Una medición en `localhost` no es una red real (`AUTO-ZRX.md` §7).
