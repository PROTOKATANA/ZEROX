# PROGRESO — P-2.1 v3 · ancla-inyeccion-v2 (ANCLA-v0.2)

> **Nota de migración (Claude, 2026-09-20, `P-CIERRE`).** Bitácora del ejecutor, migrada desde
> `P-2.1/veritas/consenso/ancla-inyeccion-v2/` al validar y trasladar el trabajo a `veritas/consenso/ancla-inyeccion-v2/`. **Las rutas
> `P-2.1/veritas/consenso/ancla-inyeccion-v2/` que aparecen más abajo son históricas** y no se han reescrito: son el
> testimonio de dónde se ejecutó. El estado vigente está en `PROCEDENCIA.md` y, para reproducir,
> en `METODO.md`. El original queda intacto en su sitio.

Ejecutor: DeepSeek. Bitácora con salida de `date` (CEST), no horas estimadas.

---

## 2026-09-18 21:02 CEST — Registro de entrada (desde la raíz del repo)

```
vie 18 sep 2026 21:02:42 CEST
P-2.1/ENCARGO.md: OK
P-2.1/PROMPT.md: OK
exit=0
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

`git status --short` idéntico al registrado en `CONTEXTO.md` §6 (incluido `?? P-2.1/`).

## 2026-09-18 21:12 CEST — Lecturas previas completadas

Leídos íntegros: `veritas/LINEO.md`, `ENCARGO.md` §0-§10, `CONTEXTO.md`, fuentes obligatorias
(`ancla-de-orden.md` §2/§4/§5/§7, `inyeccion-auditoria.md`, `recursion-flujos.md`,
`candidatos-auditoria.md` §0/§1/l.520-545, `auditoria-8c.md`, `auditoria.md` l.337-360,
`SPEC.md` §7.1/§7.3/C-NET-31/32, GDR-v0.2 y DMS-v0.1, `TAREAS.md` §2.1/§3.3).
Inspeccionados (solo lectura, para portar): `d9-ronda9c/r9c_c4_wdec.py` + `r9c_lib.py`,
`d9-ronda11c/r11c_c14_dosvistas.py` + `salida_c14.txt`, `d8-ronda8/d8_lib.py` (MundoDosVistas).

## 2026-09-18 21:12 CEST — Objeciones/decisiones de interpretación ANTES de ejecutar (lo que pide PROMPT §final)

1. **Orden de evaluación §3.1**: implementable sin circularidad. Con `S_max < L` (condición de
   corrección de §4.D) todo candidato a ancla tiene slot ∈ [T_j, T_j+S_max], el punto fijo
   `t_j = slot(I_j)+L` se resuelve por iteración finita y el resultado es independiente del corte
   para cualquier corte > T_j+S_max. Implemento el punto fijo con detección de ciclo y reporto si
   aparece no-unicidad (MODELO.md §3). Añado vector de regresión que demuestra que la vista
   completa puede dar OTRA ancla que la restringida (el artefacto que el encargo prohíbe).
2. **Definición de W_obs**: la descompongo en dos componentes medidas por separado: (a) observador
   vs ancla definitiva (la que decide L), (b) parejas de observadores. Con Δ constante uniforme
   (escalones de estrés, la definición histórica «Δ=4 s constante») la componente (b) es 0 **por
   construcción** (vistas idénticas salvo creador): el encargo lo anticipa al llamar «cota
   inferior» al retraso simétrico. La componente (b) se mide en los casos heterogéneos (nominal
   DMS-v0.1 y A3). W_obs es un máximo sobre observadores: fijo N_obs = 12 (histórico) y declaro la
   dependencia; añado una celda de sensibilidad N_obs = 24 en red honesta.
3. **Ancla definitiva**: la calculo sobre el sub-DAG {slot < t_j*} (punto fijo), nunca sobre la
   vista completa del simulador (regla de la ronda 14 y prohibición explícita del encargo).
4. **Control positivo 2 (anomalía α=0)**: hipótesis a contrastar — en r11c el máximo se tomaba
   sobre una familia cuya cobertura varía con α; mi instrumento mide W_obs por época/réplica sin
   máximo sobre familia, así que debe resolver la anomalía; la reporto como discrepancia si
   persiste.
5. **4.C**: no objeciones a la formulación, pero registro desde ya mi lectura (se resuelve con
   argumento en §4.C): la cota de unión describe «S ramas independientes con asignación fija de
   victorias»; BDK ec. 39 describe ramificación adaptativa por nivel (objeto distinto). La
   ganancia v_gain ≈ √(2α·ln S/I) es la misma familia que `g_steer = c_m/√(αλI)` con m→S si se
   deriva bien; el «α en otro sitio» del v2 desaparece al incluir el denominador de ingreso.
6. **V3**: la construyo como V2 (cadena privada, P barrido) + A3 (entrega selectiva), buscando el
   máximo de W_obs sobre (P, d, observador). Declarada «la más fuerte que encontré, no demostrada
   óptima».
7. **Alcance de células adversarias**: V1 y A3 en α ∈ {0,10; 0,25; 0,33; 0,40; 0,45}, Δ=4 s;
   V2 en α ∈ {0,25; 0,40}; V3 en α = 0,40; honesta en Δ ∈ {nominal DMS, 4, 10, 16}.

## 2026-09-18 21:14 CEST — Zona creada, documentos escritos

`CONTRATO.md` (presupuesto declarado), `MODELO.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 2026-09-18 ~22:10 CEST — ADENDA-1 leída y registrada

`P-2.1/ADENDA-1.md` (solo lectura) **prevalece** sobre el encargo en lo que dice. Aplicado:
- **Primera pasada = 4.0 completa + 4.A «de forma»** (cola medida hasta ~10⁻³ con IC por
  clúster; decisión = ¿exponencial y con qué tasa?, por α/Δ/vía, contrastada con r calibrado).
  Después: PARAR, INFORME parcial, avisar. 4.B/C/D y la cola honda, después.
- Mejoras algorítmicas adoptadas (validar cada una contra referencia): (1) varios umbrales por
  réplica (T cada 200 slots, unidad estadística = réplica); (2) evaluación incremental del ancla
  (punta + saltos binarios, O(log n) por cambio, sin vector nuevo); (3) parada temprana por
  umbral con comprobación final del ancla definitiva y re-evaluación completa (replay) si
  difiere; declarado `d_calma = 40`; **desactivada en A3** (entrega incompleta ⇒ la garantía
  de la parada no vale; declarado).
- **Prohibido copiar el patrón del v1:** bucle interno sin asignaciones; escalado medido con
  JIT fuera del cronómetro; antes del lote publicar core-s por réplica a 1 y 24 hilos, recuento
  de celdas y presupuesto por celda.
- No se propone GPU (GDR es irregular; LINEO §5.7 la descartaría).

## 2026-09-18 ~22:15 CEST — Decisión de ejecución

Lanzados 2 agentes explore en paralelo (solo lectura) para pre-localizar las fuentes de
4.B/4.C/4.D (resúmenes con citas línea) mientras el principal compila y valida el motor 4.A.
El cómputo no se reparte: LINEO topa 24 hilos y el lote ya los usa.
**Resultado:** recibidos; discrepancias de cita anotadas (ver INFORME): la fórmula de φ_c está
en `dag-poas-auditoria.md:249` + `verif_constantes.py`; `α*=(1−δ)/(φ_c+1−δ)` en
`dag-poas-delta-real.md:40`; la condición de corrección de la fuente es «X < L»
(`inyeccion-auditoria.md:110`); el archivo de fork-choice real es `research/fork-choice-poas.md`;
la frase «cambia de naturaleza» no existe literalmente en `research/`.

## 2026-09-18 ~22:50 CEST — Motor validado; mediciones de rendimiento ANTES del lote (adenda §3)

Suite: **2763/2763 tests en verde** con `--check-bounds=yes` (equivalencia kernel↔referencia por
corte en mundos pequeños honestos y V1/A3; vector de regresión vista-completa≠restringida;
invariantes R-FIN-1a y cierre bajo ancestros; punto fijo; criterio-α: G(0)=15,2 < G(0,45)=60,4).

| Medida (JIT fuera del cronómetro) | 1 hilo | 24 hilos | asignado/réplica |
|---|---|---|---|
| honesta Δ=4 (9 umbrales, H=2700, 12 obs) | 0,42 core-s | 0,30 core-s (×25) | 1,26 GiB |
| V1 α=0,33 (1 umbral, 41 escenarios) | 5,6 core-s | 4,2 core-s (×24) | — |

Sin degradación por asignador al subir hilos (el defecto del v1: ×6,6 de 1→24 — aquí NO aparece).

**Celdas y presupuesto por celda** (medido, 24 hilos): honestas (2000 réplicas ×9 umbrales):
~0,5 min/celda (dms ~1 min) ×4; V1 (1000 réplicas ×~41 escenarios): ~3 min ×5; A3 (~13
escenarios): ~1 min ×5; V2 (~26): ~2 min ×2; V3 (~109, 500 réplicas): ~4 min ×1; ctrl9c
(12 semillas ×5 α ×2 S_max): ~2 min; ctrl11c (12 semillas ×3 α): ~2 min. **Total ≈ 30-40 min.**

## 2026-09-19 04:05 CEST — PRIMERA PASADA TERMINADA (4.0 + 4.A «de forma»)

- Suite: 2763/2763 verde (con `--check-bounds=yes`).
- Celdas 4.A completas: hon-dms, hon-4, hon-10/16 (ventana 600) + hon-10L/hon-16L (ventana
  2000, sustituyen a las primeras — censuraba 14 %/53 %), v1 ×5, a3 ×5, v2 ×2, v3 ×1, ctrl9c ×5,
  ctrl11c ×3. Todas en `resultados/4a/*` y `resultados/ctrl*`.
- Hallazgos: puerta → la partición se sostiene sola (deriva 0 con R-FIN-13′, sin absorción);
  cola exponencial en todas las celdas; A3 = vía más fuerte (L_mín(10⁻³)=177 a α=0,45); el
  honesto a Δ=10/16 manda (L_mín(10⁻³)=1198/1682 slots); criterio-α satisfecho; anomalía 11c
  REPRODUCIDA (no era artefacto); control 9c en orden con diferencias declaradas.
- INFORME.md parcial escrito. PARADA según ADENDA-1 §3. Quedan: 4.B, 4.C, 4.D, cola honda,
  PROPUESTA.md, METODO.md, HUELLAS.sha256.

## 2026-09-19 04:01 CEST — Registro de salida (desde la raíz del repo)

```
P-2.1/ENCARGO.md: OK
P-2.1/PROMPT.md: OK
exit=0
 M SPEC.md   M TAREAS.md   M ci/reglas-sin-cablear.txt   M ci/reglas-sin-codigo.txt
?? P-2.1/   ?? P-POT/   ?? P-PUERTA/   ?? problemas/
?? veritas/consenso/poda-post-v1/   ?? veritas/consenso/prueba-recursiva-v1/   ?? veritas/seguridad/
```

AVISO: `git status` ya NO es idéntico al de entrada: aparecieron `?? P-POT/` y `?? P-PUERTA/`
(creados 2026-09-18 22:55 por Katana, fuera de esta zona; este ejecutor no los tocó). Los
archivos congelados de la entrada siguen OK y `?? P-2.1/` no cambió.

## 2026-09-19 04:10 CEST — ADENDA-2 leída y registrada (solo lectura, del validador)

- **4.0 retirada** (constantes literales `deriva_retarget = 0.0`/`t_abs = Inf` = hipótesis que
  codifica la conclusión; y la hipótesis es la equivocada para ZEROX: la selección es por
  blue_work con w = ⌊2^128/(SR+1)⌋, el SR se cancela y el peso crece ∝ espacio; el
  «contrafactual» era el modelo correcto). La puerta pasa a ser el c de equilibrio →
  **PCO-v0.1 (P-PUERTA/)**. Se marca en INFORME.md como «retirada, sustituida por PCO-v0.1».
- **4.A:** a declarar en MODELO.md e INFORME.md: (1) tope de 8 candidatos V1 por muestreo
  uniforme = cota inferior del poder del atacante (la misma laguna que el tope 10 de 9c);
  (2) ventana [T, T+45] de la familia base hereda el «45 s» histórico — justificarla o barrerla.
- Reejecución del validador pendiente. NO se lanza la segunda pasada.
