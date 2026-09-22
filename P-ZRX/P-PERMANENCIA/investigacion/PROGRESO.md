# PROGRESO — P-PERMANENCIA

Bitácora del encargo `P-ZRX/P-PERMANENCIA/PROMPT.md`. Zona de escritura: **solo**
`P-ZRX/P-PERMANENCIA/investigacion/`. `PROMPT.md`, `CANDIDATA.md` y `ENTRADA.sha256` son de solo
lectura y se comprobaron al empezar y al terminar.

Agente: agente de cálculo del repositorio ZEROX. Fecha de trabajo: 2026-09-21.

---

## 0 · Objeciones al encargo, ANTES de empezar (§8 del encargo)

Se presentan aquí, y no al final, porque el encargo lo exige. Ninguna se resuelve por deferencia:
cada una se comprueba o se cuantifica en el instrumento y en `INFORME.md`.

**O1 — La hipótesis del §0, leída literalmente, se reduce a E5.** «Exigir responder en cada slot
sobre la parcela entera» es exactamente lo que **ya exige farmear** en Autonomys: el granjero honesto
audita **un s-bucket por sector y slot** (`PDF/autonomys-subspace/crates/subspace-farmer-components/src/auditing.rs:126-186,198-234`)
y no puede saber si tiene un ganador sin recorrer la parcela. Un parcial es una solución con umbral
más fácil (`is_within_solution_range`, `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:148-159`),
es decir **el mismo objeto con otro umbral**. Por tanto E3 no añade una obligación nueva: hace
**observable** una obligación que E5 ya impone. Su valor es de *medición*, no de *coste*. Lo que
puede cambiarlo es la ventana `w`: si el atacante conoce `w` retos futuros, la respuesta por slot se
fabrica una vez por ventana (F2b). **RESULTADO: CONFIRMADA.** El coste de E3 es idéntico al de E5
(`N/(r·w)` CPU) y, a la ventana medida, **sí es vinculante** (5,84 CPU/TiB frente a ~1 TiB de disco);
de donde E3 no encarece, solo hace auditable.

**O2 — E3 mide tamaño respondido, no edad ni identidad.** La estadística de parciales estima
cuánta parcela **responde**, no cuántos bytes **existen** ni si son los bytes registrados. Quien
regenera dentro de la ventana responde por la parcela entera sin almacenarla, y la estadística no lo
distingue. Para la afirmación (i) «existía entera antes del reto» esto es estructuralmente
insuficiente: no hay nada en un parcial que fije un instante anterior al reto. **RESULTADO:
CONFIRMADA.** Spacemesh lo dice de su propio PoST: «the protocol does not allow a prover to prove
they _stored_ the data, since an adversary can instead store only the initial seed».

**O3 — El modelo de trampa con ventana del F2 es una cota superior, y hay que decirlo dos veces.**
`r = 25,03` tablas/s es el *mejor agregado medido del código de Autonomys tal cual*, no el mejor
kernel posible. Además, el tramposo no necesita regenerar el lote entero: le basta con pasar el
umbral estadístico. **RESULTADO: respetada como restricción**; el instrumento publica el coste como
cota superior y el escenario GPU va etiquetado como **documentación ajena nunca medida**.

**O4 — La Poisson es una hipótesis, no un hecho del protocolo.** El número de pruebas por pieza no
es uniforme por bucket (P-INTENTO §2, precisión 3). El instrumento calcula la **binomial exacta** y
la **Poisson con intervalo riguroso**; la discrepancia medida Poisson↔binomial es `1,52·10⁻³`,
dentro de la cota de Le Cam `2np²`. **RESULTADO: CONFIRMADA** la necesidad de la referencia exacta
en lotes pequeños.

**O5 — «Coste absoluto de hacer trampa» se da en hardware, nunca en dinero.** **RESULTADO:
respetada.** Ninguna cifra monetaria; ningún precio inventado; el `17×` de GPU marcado como
escenario.

---

## 1 · Comprobaciones de entrada (inicio)

Ejecutado desde la raíz `/home/katana/zeo/ZEROX` antes de escribir nada:

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-PERMANENCIA/ENTRADA.sha256
P-ZRX/P-PERMANENCIA/PROMPT.md: OK
P-ZRX/P-PERMANENCIA/CANDIDATA.md: OK
exit=0

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
lun 21 sep 2026 16:45:39 CEST

$ uptime
 16:45:39  up 13 days 13:15,  0 users,  carga promedio: 1,92, 1,50, 0,69
```

Las cinco entradas de `git status` **no son de este encargo**: son las mismas que ya declaró
`P-ZRX/P-REVELACION/investigacion/INFORME.md`.

---

## 2 · Presupuesto declarado antes de ejecutar (§8.11 del bloque LINEO)

- **Hilos:** máximo **4** (el encargo lo baja del tope LINEO de 24 porque hay otros encargos).
- **RAM:** 8 GiB. **Disco temporal:** 256 MiB. **Tiempo:** 4 h de pared.
- **No se agotó.** Ningún resultado es **inconcluso** por presupuesto.

---

## 3 · Bitácora

- `16:43` — Comprobación de entrada y lectura de `PROMPT.md`, `CANDIDATA.md`, `AGENTS.md`,
  `veritas/LINEO.md` (entero) y de los informes de P-SEMBRADOR, P-INTENTO y P-REVELACION.
- `16:45` — Objeciones O1–O5 escritas **antes** de calcular. Directorio del instrumento creado.
- `16:47` — Código fijado leído: `auditing.rs`, `proving.rs`, `verification/src/lib.rs`,
  `solutions.rs`, `sectors.rs`, `pieces.rs`, `plotting.rs`, `chiapos.rs` y `chiapos/constants.rs`.
- `16:49` — Fuentes externas abiertas con red: `post.md` de Filecoin, `post.md` y `nipost.md` de
  Spacemesh y protocolo de pools de Chia. Ninguna cita externa se hereda sin abrir.
- `16:50-16:56` — Instrumento `permanencia-v1` construido con `veritas/nueva-auditoria.sh` como
  referencia de estructura: `modelo.jl`, `referencia.jl` (exacta + intervalo con redondeo dirigido),
  `rapido.jl`, `validacion.jl`, `run.jl`, `test/`, `bench/`, `mediciones/hardware.tsv`.
- `16:53` — **51 comprobaciones en verde.** Dos defectos propios detectados y corregidos, no
  escondidos: (a) `binomial_cdf_exacta` desbordaba `Int64` en `(b-a)^n`; (b) la «potencia» estaba
  invertida (el test rechaza si `X ≤ K`, así que la potencia es la cola **inferior**). Además, la
  inestabilidad de tipos que JET marcaba venía de capturar variables mutables en un `do`; se
  corrigió con funciones de redondeo propias.
- `16:56` — Barridos publicados (`./correr-modelo.sh`, 4 hilos), `JET`, `BENCH` y `VALIDACION`
  escritos en `resultados/`.
- `16:58` — `INFORME.md`, `DECISIONES-PENDIENTES.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` e
  `INFORME.md` del instrumento escritos.
- `16:58` — Comprobaciones de salida (abajo).

**Incidencias de método.** El kernel rápido `Float64` de Poisson daba umbrales absurdos porque
`exp(-λ)` **subdesborda** a cero para `λ≳745`: se reescribió sumando en escala logarítmica relativa
a la moda. Se documenta porque es el antipatrón «una optimización cambió un veredicto» de LINEO §9,
detectado por la validación contra la referencia (que habría dado `max_dK = 1798`).

---

## 4 · Comprobaciones de salida

Ejecutado desde la raíz `/home/katana/zeo/ZEROX` al terminar:

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-PERMANENCIA/ENTRADA.sha256
P-ZRX/P-PERMANENCIA/PROMPT.md: OK
P-ZRX/P-PERMANENCIA/CANDIDATA.md: OK
exit=0

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
lun 21 sep 2026 16:58:49 CEST

$ uptime
 16:58:49  up 13 days 13:28,  0 users,  carga promedio: 1,67, 1,95, 1,51
```

**Las cinco entradas de `git status` son idénticas al inicio y ninguna es de este encargo.** No se
editó ni movió nada de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`,
`veritas/` ni del resto de `P-ZRX/`. La única escritura está bajo
`P-ZRX/P-PERMANENCIA/investigacion/`.

---

## 5 · Entregables

- `investigacion/INFORME.md` — respuesta en la primera línea, fichas E1–E5, F1–F5, tabla comparativa.
- `investigacion/DECISIONES-PENDIENTES.md` — D1–D9.
- `investigacion/PROGRESO.md` — este fichero.
- `investigacion/veritas/almacenamiento/permanencia-v1/` — instrumento completo, con
  `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`, `INFORME.md`, `Project.toml`, `Manifest.toml`,
  `test/`, `bench/`, `resultados/` y `correr-modelo.sh`.
