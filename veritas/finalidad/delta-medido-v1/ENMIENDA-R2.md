# Enmienda R2 — Δ medida con objetos del presupuesto de Q2 y medias de llegada (Q3)

Fecha de la enmienda: 2026-09-13. Decisión: Katana (TAREAS.md §3.1, preguntas Q1–Q5,
decididas 2026-09-13). Ejecutado por DeepSeek en la zona aislada
`deepseek/veritas/finalidad/delta-medido-v1/`; validado por Claude reejecutando (2026-09-13 y
2026-09-14); migrado a `veritas/finalidad/delta-medido-v1/` el 2026-09-14 (§7). Este documento
conserva la procedencia del cambio antes de que la zona temporal desaparezca.

## 1 · Qué se enmendó y por qué

Tres cosas, en el orden en que se hicieron:

1. **Procedencia de la r1 (sección 3 del encargo).** La reproducción de Claude (8 hilos,
   37,14 s, `fecha=2026-09-12T22:19:29Z`) había sobrescrito `resultados/barrido-principal/`.
   Se guardó una copia íntegra en `resultados/r1-reproduccion-claude-8hilos/` (con
   `LEEME.txt`) y se regeneraron `barrido-principal/` y `sensibilidad/` con 24 hilos y el
   código de la r1 **sin modificar**. Resultado: `resumen.csv` **idéntico byte a byte**
   entre 8 y 24 hilos en ambos modos; `corridas.csv` idéntico en todas las columnas salvo
   `segundos_pared`. El determinismo entre números de hilos se sostiene.
2. **Sesgo de modelo de la r1, declarado y recalificado.** El modelo de propagación reenvía
   el bloque completo a los 8 vecinos en serie (`src/rapido.jl:151-158`) y valida en 0 s,
   mientras el SPEC exige relé compacto (R-NET-01, SPEC.md:2509-2511) y validar antes de
   retransmitir (C-NET-12, SPEC.md:2496-2498; C-NET-06, SPEC.md:2162-2165). El INFORME pasa
   a revisión 2 y recalifica tres conclusiones como dependientes del modelo (no borradas).
3. **Modo nuevo `--r2`** (todo lo nuevo en código nuevo; la r1 no cambia su semántica ni sus
   valores por defecto): mide Δ con los objetos del presupuesto de Q2 a 100 y 59,67 Mbit/s,
   publica ρ y régimen, y guarda la media de llegada por bloque y por nodo para Q3, más la
   Δ̄ ponderada por producción bajo dos repartos de espacio (uniforme y la hipótesis de
   concentración H: «el 10 % de los nodos tiene el 50 % del espacio»).

## 2 · Derivaciones a mano (2026-09-13 22:59 CEST / 20:59Z, escritas ANTES de ejecutar)

Regla del encargo: cada valor esperado se deriva primero; la medición sólo lo confirma.

### D1 — Tamaños de objeto y utilización ρ (tabla 5.2 del encargo), recalculados

`cabecera = 556 + 32·padres + 128·slots`; `anuncio = 812 + 6·tx`; `bloque = 812 + 350·tx`;
`ρ = λ·d·t_tx = 1·8·(8·tam/banda)`.

| Objeto | Fórmula | Bytes | ρ @100 Mbit/s (derivado, 4 dec.) | ρ @59,67 (derivado, 4 dec.) |
|---|---|---:|---:|---:|
| cabecera 1 padre 1 slot | 556+32+128 | **716** | 8·8·716/1e8 = 4,5824·10⁻⁴ → **0,0005** | 45824/5,967e7 = 7,6796·10⁻⁴ → **0,0008** |
| cabecera 4 padres 1 slot | 556+128+128 | **812** | 5,1968·10⁻⁴ → **0,0005** | 8,7092·10⁻⁴ → **0,0009** |
| anuncio arranque (571 tx) | 812+6·571 | **4 238** | 2,71232·10⁻³ → **0,0027** | 4,5455·10⁻³ → **0,0045** |
| cabecera peor caso (16 p, 150 slot) | 556+512+19200 | **20 268** | 1,297152·10⁻² → **0,0130** | 2,1739·10⁻² → **0,0217** |
| anuncio techo (4464 tx) | 812+6·4464 | **27 596** | 1,766144·10⁻² → **0,0177** | 2,9599·10⁻² → **0,0296** |
| bloque techo (control) | 812+350·4464 | **1 563 212** | 1,00045568 → **1,0005** (saturado) | 1,6766 → **1,6766** (saturado) |

Los 12 valores redondeados a 4 decimales coinciden con la tabla de TAREAS.md §3.1/Q2.
Ninguno de los 5 objetos estables llega a ρ=1: todos `estable`; el bloque completo del techo
es el único `saturado` (control).

### D2 — Medias a mano: camino de 4 nodos (fracciones binarias exactas)

Camino 1-2-3-4, latencia 1 s/arista, t_tx=0, t_proc=0, creador 1, t=0. Llegadas [0,1,2,3].

- media por bloque = (1+2+3)/3 = **2,0** (suma exacta: 6/3).
- media por nodo: nodo1 = NaN (no hay bloques ajenos); nodo2 = **1,0**; nodo3 = **2,0**; nodo4 = **3,0**.
- Δ̄ uniforme = **2,0**. Invariante: 1 ≤ 2,0 ≤ Δ_100 = 3,0.

### D3 — Medias a mano: estrella (centro 1, hojas 2-3-4), t_tx=0,5, lat=0

Creador hoja 2: llegadas en orden de nodo [0,5; 0; 1,5; 2,0].
media por bloque = (0,5+1,5+2,0)/3 = 4,0/3,0 = **Float64 más próximo a 4/3** (suma exacta
4,0; división redondeada; misma operación en la implementación → bit a bit).

Creador centro 1: llegadas [0; 0,5; 1,0; 1,5]. media por bloque = (0,5+1,0+1,5)/3 = 3,0/3 =
**1,0** (exacto). media por nodo: hoja2 = 0,5; hoja3 = 1,0; hoja4 = 1,5.

### D4 — Dos bloques en el camino: Δ̄ uniforme == media de medias

Camino, creadores [1, 4], t=[0,0]. Bloque1 (creador 1): [0,1,2,3]; bloque2 (creador 4):
[3,2,1,0]. medias por bloque = [2,0; 2,0]. Δ̄ uniforme = **2,0**. Media general sobre los 6
pares observador≠creador = (1+2+3+3+2+1)/6 = 12/6 = **2,0** — coinciden exactamente.
Invariante por bloque: 1 ≤ 2,0 ≤ 3,0 en ambos.

### D5 — Hipótesis de concentración: cuotas y muestreo

*(Nota: esta derivación se reescribió una vez antes de ejecutar — el primer borrador sumó
mal el total de cuotas; aquí queda la cuenta correcta y única.)*

Cuota entera: los k = n÷10 nodos «ricos» (nodos 1..k, reparto sintético sin datos reales)
reciben **9** unidades de espacio y los n−k restantes **1**. Con n=1000: k=100; total =
100·9 + 900·1 = **1 800**; fracción de espacio del top-10 % = 900/1800 = **0,5** exacto
(aritmética entera). Igual en n=100 (k=10, total 180) y n=10000 (k=1000, total 18 000).

- pesos = cuota/total; Σ pesos ≈ 1 (rtol 1e-12; 1/1800 no es representable en binario).
- Fracción esperada de creadores en el top-10 %: 0,5; con H=600 bloques la desviación típica
  binomial es √(0,5·0,5·600) ≈ 12,2 → 2,04 % de H. Tolerancia declarada en el test:
  |f−0,5| ≤ 0,05 (≈2,45σ; la semilla queda fija y el resultado congelado).

### D6 — Equivalencia referencia↔rápido con medias, bit a bit

Las mismas 9 configuraciones pequeñas × 3 semillas del test de equivalencia r1; se añade que
las medias por bloque y por nodo calculadas sobre ambas matrices coincidan bit a bit (función
común sobre matrices idénticas).

### D7 — Modelo de coste de la r2 (LINEO §6), declarado ANTES de ejecutar

Eventos por corrida = H·(1+n·d) con H≈600 (los eventos no dependen del tamaño del objeto).
Referencia r1 medida: 72 corridas → 13,9 s de pared con 24 hilos (dominadas por las 24 de
n=10000, ≈4 s de CPU cada una a 1 hilo).

| Subtarea | Corridas | n | CPU estimada (hilo-s) |
|---|---|---:|---:|
| rejilla (5 obj × 2 BW × 2 topo × 3 N) | 60×12 = 720 | 240×{10000,1000,100} | 240·4 + 240·0,4 + 240·0,04 ≈ **1 066** |
| concentración | 4×12 = 48 | 1000 | 48·0,4 ≈ **19** |
| t_proc=0,1 s | 2×12 = 24 | 1000 | 24·0,4 ≈ **10** |
| saturación (T=300/600) | 2×12 = 24 | 1000 | 24·0,4 ≈ **10** |

Total ≈ **1 105 hilo-s** → ≈ 46 s de pared ideal con 24 hilos; presupuesto declarado: ≤ 5 min
de pared, RAM ≤ 24×150 MB ≪ 64 GiB. No hay recorte: el objeto de 716 B se queda (no se
aplica el recorte opcional por N=10000). Tamaño previsto de `resultados/`: ≈50 MB, dominado
por `medias_nodo-*.csv` (2,76 M filas, media en µs enteros).

### D8 — Expectativas cualitativas de las corridas (no son valores de test)

- Δ a 100 Mbit/s con objetos ≤ 4 238 B: dominada por latencia (t_tx·d ≤ 8·0,34 ms), esperada
  del orden de **0,2–0,5 s**, comparable a la r1 (que ya estaba dominada por latencia).
- Δ del anuncio de techo (27 596 B): t_tx = 2,2 ms → d·t_tx = 17,7 ms por salto; esperada
  del orden de **0,3–0,6 s**.
- Cabecera peor caso (20 268 B): d·t_tx = 13 ms por salto; esperada ≈ **0,3–0,6 s**.
- Control saturado (1 563 212 B, ρ=1,0005): cola que crece despacio (~0,3 s de trabajo
  extra acumulado en 600 s); Δ_100 debe crecer con T (300→600) sin divergir — es la
  evidencia de no estacionariedad, no una Δ publicable.

### Discrepancias con lo derivado (escrito al ejecutar)

1. **D2, test de medias del camino: el primer test `mn_r == mn` falló** (un assert rojo en
   la primera ejecución de la suite). Quién tenía razón: **IEEE 754** — `==` sobre vectores
   que contienen NaN es falso porque `NaN == NaN` es false; la derivación no previó que
   media_nodo contiene NaN cuando un nodo crea todos los bloques. El código no tenía error
   alguno: los dos vectores eran iguales valor a valor. Corregido el **test** a
   `isequal(mn_r, mn)` (isequal trata NaN==NaN como true), y la suite pasó a 25 593 asserts
   en verde. No se cambió ninguna derivación de valores: todas las medias D2–D6 coincidieron
   con lo derivado.

2. **D8, control de saturación: la medición NO cumplió la expectativa.** D8 esperaba una cola
   extra del orden de ~0,3 s (el exceso medio de trabajo (ρ−1)·T = 0,000456·600 ≈ 0,27 s).
   La medición dio Δ̄ = 9,27 s (T=300) y 18,10 s (T=600), con Δ_100 máxima 43,1 → 79,1 s:
   **unos 60× más que la expectativa** (9,27/0,15 ≈ 60 a T=300). **Quién tenía razón: la
   medición.** Por qué: la derivación sólo contó el exceso medio de trabajo y olvidó las
   fluctuaciones aleatorias de las llegadas (Poisson y de la propia inundación), que dominan
   cuando ρ ≈ 1: un nodo con ρ=1,0005 no puede absorber NINGUNA racha de llegadas sin que la
   cola crezca, y cada segundo de cola extra retrasa los reenvíos aguas abajo (realimentación
   positiva en la red entera). No se inventa ley de escalado: el factor ~60 es una lectura de
   lo medido, no una derivación; si se da un orden de magnitud del mecanismo hay que
   etiquetarlo **D** y derivarlo. La conclusión de la r2 no cambia: la cola no es estacionaria
   (crece con T) y sus cifras no son Δ.

---
*(el resto de secciones se completa tras ejecutar; ver abajo)*

## 3 · Cifras de la validación

Medidas por DeepSeek ejecutando (Claude las validará reejecutando), 2026-09-13:

| Comprobación | Resultado |
|---|---|
| Suite `test/runtests.jl` con `--check-bounds=yes` | **25 598 asserts, 0 fallos** (25 040 de la r1 + 558 de la r2; antes de la corrección §6 eran 25 593) → `resultados/TESTS.txt` |
| Procedencia r1 reparada: barrido 24 hilos vs copia de la reproducción de Claude (8 hilos) | `resumen.csv` **idéntico byte a byte**; `corridas.csv` idéntico salvo `segundos_pared`; pared 13,78 s (INFORME citaba 13,9 s) |
| `--sensibilidad` re-ejecutado | `resumen.csv` byte a byte; `corridas.csv` idéntico salvo `segundos_pared` |
| r1 al final de la enmienda (tras todo el código r2) | barrido y sensibilidad `resumen.csv` **byte a byte** con el paso 3; `corridas.csv` sólo difiere en `segundos_pared` |
| r2 reproducible (criterio 4) | dos ejecuciones completas de las 4 subtareas (816 corridas) idénticas salvo `segundos_pared`, `ENTORNO.txt`, `RUN.txt` |
| Rejilla r2 (720 corridas, 24 hilos) | 132,1 s de pared (presupuesto declarado ≤5 min, cumplido); 60/60 combos `estable` |
| Muestreo concentrado | fracción de creadores top-10 % en [0,467; 0,553] sobre 48 corridas (esperado 0,50; dentro de la tolerancia ±0,05 declarada en D5) |
| Control de saturación | ρ=1,0005; Δ̄ 9,27 s (T=300) → 18,10 s (T=600); Δ_100 máx 43,1 → 79,1 s: **crece con el horizonte** (evidencia de no estacionariedad). **Corregido tras la validación de Claude:** la frase «la expectativa D8 de "sin divergir" se confirmó en el sentido de crecimiento lento y sostenido» era incorrecta — D8 esperaba ~0,3 s de cola y la medición dio ~60× más (discrepancia 2 de §2). La conclusión de la fila (cola no estacionaria, cifras que no son Δ) sigue siendo correcta |
| Tamaño de `resultados/` | **47 MB** (< ~50 MB declarado) |
| git | `git -C /home/katana/zeo/ZEROX status --short` = ` M TAREAS.md` (igual que al empezar); nada escrito fuera de `deepseek/` |

Cifras principales publicadas en INFORME.md §11: Δ_99 p99 0,26–0,60 s en toda la rejilla;
base r2 (812 B @ 100 Mbit/s) 0,26–0,45 s; Δ̄ uniforme 0,138–0,387 s; Δ̄ espacio (regla i,
corregido en §6) 0,2146–0,2566 s, ≈ Δ̄ uniforme por simetría del grafo; padres típicos ≈
1,14–1,39; máx Δ_100 estable conjunto (r1+r2) 8,63 s < 15 s; t_proc=0,1 s añade ≈0,55–0,61 s
a Δ_99 p99 (0,90/1,01 s).

## 4 · Límites que siguen en pie

La enmienda declara el sesgo, no lo corrige: el modelo sigue reenviando el objeto completo a
los 8 vecinos en serie (`src/rapido.jl:151-158`), validando en 0 s en el caso base, sin
canal de transacciones ni mempool. No hay relé compacto, reenvío de transacciones, cola
prioritaria, adversario ni GHOSTDAG: todo eso es v2a/v2b (TAREAS Q5). La Δ del anuncio del
techo es optimista salvo la regla de transporte de Q1. El coste real de validación por salto
sigue pendiente del banco en hardware (Q4). El reparto de espacio concentrado es una
hipótesis sintética por ID de nodo, no el reparto real (pendiente para δ₀). Nada es MR ni
parámetro de producción.

## 5 · Decisiones de ejecución que el prompt no cubría

1. **Precisión de las trazas de medias:** `medias_bloque` con %.9f s; `medias_nodo` en µs
   enteros (redondeo ≤0,5 µs, cuatro órdenes por debajo del ruido de muestreo de ~1 ms), para
   caber en el tope orientativo de ~50 MB (medido final: 47 MB). Declarado en METODO.md.
2. **La subtarea `sensibilidad/` de la r1 no la había sobrescrito la reproducción de Claude**
   (su ENTORNO conservaba 24 hilos): aun así se copió a `r1-reproduccion-claude-8hilos/` y
   se re-ejecutó, porque el encargo lo pedía y la comparación salió byte a byte.
3. **El recorte opcional (N=10000 en el objeto de 716 B) NO se aplicó**: el coste medido
   (132 s de pared) quedó dentro del presupuesto declarado de ≤5 min, así que la rejilla va
   completa. Justificación con números en BITACORA.md.
4. **`corridas.csv` de la r2 guarda la fracción de creadores top-10 % y la Δ̄ por corrida**;
   el `resumen.csv` de concentración guarda Δ̄ uniforme y de espacio a nivel de pool. Es
   trazabilidad adicional, no cambia nada de la r1.
5. **Un fallo de test propio, corregido y documentado**: la primera suite tuvo 1 assert rojo
   porque `==` sobre vectores con NaN es falso (IEEE 754); el código estaba bien y se corrigió
   el test a `isequal`. Queda escrito en §2 de este documento, no corregido en silencio.
6. **`git status --short` mostró exactamente ` M TAREAS.md` al empezar** (lo editó Claude,
   esperado) y sigue igual al terminar; no se tocó nada fuera de `deepseek/`.

## 6 · Correcciones tras la validación de Claude (2026-09-13)

Claude validó la r2 y encontró un error de método y tres cosas de documentación. Los cinco
puntos, con lo hecho en cada uno:

1. **Δ̄ de concentración contaba la cuota dos veces (error de método).** Con el sorteo de
   creadores ∝ cuota, volver a pesar cada bloque por la cuota de su creador da peso ∝ cuota²
   (81:1 en vez de 9:1). Regla correcta: (i) sorteo ∝ cuota → Δ̄ = media simple de las medias
   por bloque ponderadas por observador; (ii) sorteo uniforme → peso por creador. Se
   sustituyó `delta_barra_espacio` por `delta_barra_sorteo_por_cuota` (i) y
   `delta_barra_peso_por_creador` (ii, documentada como válida SOLO con sorteo uniforme);
   `run.jl` acumula `num += mb; den += 1`. Derivación del test que las distingue, con hora
   (escrita ANTES de ejecutar):

   ### Derivación T1 — 2026-09-13 23:43 CEST (21:43Z)

   Dos nodos: rico con cuota 3, pobre con cuota 1 → pesos 3/4 y 1/4. Medias por bloque ya
   ponderadas por observador: 1,0 para bloques del rico, 2,0 para los del pobre.
   - Muestra con sorteo ∝ cuota, creadores [rico, rico, rico, pobre]:
     `delta_barra_sorteo_por_cuota` = (1+1+1+2)/4 = **5/4 = 1,25** (exacto en binario).
   - Muestra con sorteo uniforme, creadores [rico, pobre]:
     `delta_barra_peso_por_creador` = (3/4·1 + 1/4·2)/(3/4+1/4) = 0,75+0,5 = **1,25** (exacto).
   - La regla doble aplicada a la muestra ∝ cuota: (3·1+3·1+3·1+1·2)/(3+3+3+1) = 11/10 =
     **1,1** ≠ 1,25. El test comprueba que el estimador de concentración da **1,25 y NO 1,1**.

2. **INFORME §11.4 reescrito:** en grafos aleatorios (regular y Erdős–Rényi) los nodos son
   intercambiables, así que concentrar el espacio por número de nodo —sin relación con la
   posición en la red— deja Δ̄ igual POR CONSTRUCCIÓN; la subtarea comprueba el estimador, no
   el efecto de concentrar el espacio. La hipótesis relevante (espacio correlacionado con la
   centralidad) queda como entrada del **v2b** y NO se implementa aquí. MODELO.md y
   CONTRATO.md dicen ahora la regla (i).

3. **Expectativa D8 frente a medición:** discrepancia 2 de §2 (la medición tenía razón; la
   derivación olvidó las fluctuaciones Poisson que dominan en ρ ≈ 1). La fila de §3 quedó
   marcada como corregida, no borrada.

4. **INFORME §10:** el recuento de asserts pasa de «25040» al número real de la suite
   corregida (ver abajo).

5. **INFORME §11.3:** el texto truncado del encargo decía «objetos de 812, 4 238 y 27 596 B»;
   se añadió la línea del objeto de 4 238 B a 100 Mbit/s (sacada del `resumen.csv` ya
   existente, sin re-ejecutar nada para esto).

**Cifras antes y después de la corrección:**

| Valor | Antes (doble conteo) | Después (regla i) |
|---|---|---|
| Δ̄ espacio 1101 (4 238 B regular) | 0,21977 | **0,21937** (control de Claude; coincide ≥5 decimales) |
| Δ̄ espacio 1102 (4 238 B ER) | 0,21458 | **0,21457** |
| Δ̄ espacio 1103 (27 596 B regular) | 0,25733 | **0,25767** |
| Δ̄ espacio 1104 (27 596 B ER) | 0,25720 | **0,25657** |
| Asserts de la suite | 25 593 | **25 598** (5 asserts nuevos del test T1) |

Los valores «antes» son los de la revisión entregada; los «después» los medidos en la
re-ejecución de esta corrección (comandos en BITACORA.md).

## 7 · Notas de la migración (Claude, 2026-09-14)

- **Validación.** Claude reprodujo la r2 y su corrección fuera del repositorio, con 16 hilos.
  Tests 25 598/25 598 con `--check-bounds=yes`; los `resumen.csv` de r1 y r2 y las 140 trazas,
  idénticos a los de DeepSeek (24 hilos); los cuatro valores corregidos de Δ̄ espacio coinciden
  con el recálculo independiente hecho sobre las trazas.
- **Trazas no versionadas (decisión de Katana, 2026-09-14).** Las 140 trazas de medias (47 MB)
  no se migran. Su huella queda en `TRAZAS.sha256` y el modo de regenerarlas y comprobarlas, en
  `METODO.md`.
- **Bitácora.** `deepseek/PROGRESO.md` se migra como `BITACORA.md`, con el precedente de
  `comprobacion-decisiva-v1`. Sus rutas `deepseek/` son históricas.
- **Correcciones editoriales al migrar, sin tocar código ni resultados:** recuento de asserts en
  `METODO.md` (25 593 → 25 598) e INFORME §7; comandos de INFORME §10 con rutas finales;
  referencias a `PROGRESO.md` → `BITACORA.md`; cabecera de procedencia de este documento.
- **Observación que queda sin corregir:** el test T1 comprueba `delta_barra_sorteo_por_cuota` y
  `delta_barra_peso_por_creador`, pero `run.jl` aplica la regla (i) en línea, sin llamarlas. Una
  regresión en esa ruta no la detectaría T1; esta vez la detectaron los valores de control.
  Conviene arreglarlo la próxima vez que se toque el instrumento.
- **Huellas.** `HUELLAS.sha256` se generó desde la raíz del repositorio, con rutas finales y
  después de actualizar `TAREAS.md`. `FUENTES-R2.sha256` queda como registro histórico.
