# TAREAS — lo que falta para que el SPEC PoST + DAG pase a fase de código

Fecha: 2026-09-12; actualizado el 2026-09-14. Derivado de §17 de [SPEC.md](SPEC.md),
`ci/consenso-pendiente.txt`, los límites declarados de los instrumentos de `veritas/`,
[MIGRACION.md](MIGRACION.md), la auditoría externa de la comprobación decisiva v1
([AUDITORIA-EXTERNA.md](veritas/consenso/comprobacion-decisiva-v1/AUDITORIA-EXTERNA.md)) y las
decisiones de Katana sobre `Δ` del 2026-09-13 (§3.1).

No congela parámetros ni convierte pendientes en decisiones. Los niveles 1 y 2 separan «el SPEC
describe un protocolo» de «el SPEC especifica un protocolo». El nivel 3 separa «se puede
implementar» de «se puede lanzar».

---

## Nivel 1 — Forks latentes: el SPEC no es determinista aquí

Escribir código contra estos puntos produce nodos que discrepan. Son el único bloqueo duro.

### 1.2 · `rank` no define un orden total

§7.2 fija el desempate entre copias (P1: azul primero, luego `rank`, luego id de bloque), pero
`rank` es hoy una etiqueta abstracta suministrada — CONTRATO de DCM-v0.1: «Rank y color son
etiquetas globales suministradas, no recalculadas». Hay que atarlo al orden concreto del mergeset
(`blue_work`, `solution_distance`, hash) y **demostrar que es total**. Un empate hace el desempate
no determinista, y eso es un fork. Ya declarado como PENDIENTE en §7.2.

### 1.3 · GHOSTDAG no está derivado, y P1 depende de él

El color (azul / `rojo_k` / `rojo_U3`) lo suministra hoy el oráculo del fixture; DCM-v0.1 declara
que «no acredita la coloración ni el orden contextual de GHOSTDAG». Con P1 decidido, el desempate
de §7.2 **no es computable** hasta que la coloración sea determinista y acordada por todos los
nodos. La elegibilidad ya dependía del color por R-FIN-8′, así que P1 no añade una dependencia
nueva, pero la vuelve crítica para el pago.

**Dirección de los desempates — DECIDIDO POR KATANA (2026-09-14): opción C de GDR-v0.1 (D-1/D-2).**

- **Orden del mergeset**, el mismo para colorear (U3″) y para aplicar (R-FIN-8′(4)):
  `(blue_work, solution_distance, hash)` ascendente, con el hash comparado byte a byte.
- **Padre seleccionado** (y punta virtual): el de mayor `blue_work`. Si hay empate, el que va
  primero en ese orden: menor `solution_distance` y, después, menor hash.
- **`rank` para P1:** la misma tupla, en orden ascendente; gana el menor.
- **Motivo:** dos hermanos con los mismos padres tienen siempre el mismo `blue_work`, así que el
  desempate del padre es el caso común. Con C, el orden de aplicación entre hermanos y la copia
  superviviente de un billete son los mismos tanto si llegan como padres como si llegan dentro de
  un mergeset. Con la lectura `:spec`, entre hermanos va primero el de mayor `solution_distance`;
  la lectura `:python` reproduce el error de `r8c_gd.py`.
- **Coste:** se aparta del patrón de Kaspa (padre = máximo del mismo orden) y obliga a redactar
  dos reglas en vez de una.
- **Comprobado por Claude** (regla sustituida en memoria sobre GDR-v0.1, sin tocar el
  instrumento):
  - hermanos y copias, coherentes;
  - oráculo = kernel en 1 800 DAGs con k de 1 a 30;
  - 1 000 órdenes de llegada idénticos en dos familias;
  - todo padre tiene menor `rank` que su hijo.
- **Pendiente derivado:**
  - implementar el modo en GDR-v0.1 con sus tests (hoy solo existe la parte de
    `solution_distance`, `SP_PYTHON` + `MERGE_SPEC`; falta el hash menor);
  - corregir DERIVACIONES (horas inventadas) y las demostraciones de `rank`;
  - redactar §7.2 y §11 del SPEC;
  - el dominio y el desbordamiento de `blue_work` (D-5) siguen abiertos.

### 1.4 · La cabecera DAG no existe

Padres múltiples, compromisos, formato y límites de la justificación PoT, y tamaño final: todo
pendiente (§17). Persiste la discrepancia 92/556 con un test rojo conocido
(`el_spec_dice_el_tamano_real_de_la_cabecera`). Y **C-HDR-06 define `rango_esperado(padre)` como
«función pura de la cadena de cabeceras»** — lineal — cuando el destino es un DAG: esa regla hay
que reescribirla, no portarla.

**Ya tiene presupuesto de diseño** (Q2 de §3.1, decidido por Katana el 2026-09-13; presupuesto,
no formato):
- cabecera ≤ ~1 kB en el caso típico y ≤ ~20 kB en el peor, que son 16 padres y 150 slots de
  justificación PoT;
- anuncio compacto ≤ ~28 kB en el techo;
- relé compacto obligatorio en la ruta crítica.

La r2 de `DMS-v0.1` midió 1,14–1,39 padres típicos, es decir, una cabecera típica de ≈716–748 B.
El formato debe especificar además el caso degradado del relé compacto (§2.7).

---

## Nivel 2 — Reglas escritas que todavía no se pueden computar

### 2.1 · Verificación conjunta PoAS/PoT (§7.1)
Solución de espacio, testigos KZG, identidad de billete, reto, distancia de solución, sello y
justificación PoT. Pendiente además: formato y validación conjunta, retardo de autoría, puntos de
control, inyección de entropía y dependencias por flujo.

**La parte de red ya está decidida** (Q4 de §3.1, 2026-09-13):
- antes de reenviar se comprueban cabecera, prueba de espacio, 2 KZG, sello, justificación PoT
  (desde la caché) y compromiso Merkle;
- después, firmas, pruebas Halo2 y UTXO;
- el PoT se verifica una vez por slot y se cachea.

Eso fija el orden, no la verificación conjunta en sí, que sigue pendiente. Las reglas que faltan
por escribir están en §2.7.

### 2.2 · La identidad del billete está supuesta, no demostrada
Toda §7.2 —dedup, unicidad pagable, peso— se apoya en que el billete identifique de verdad la
oportunidad. En los instrumentos eso es una declaración del fixture. La propiedad real depende de
`veritas/consenso/contrato-billete-v1/` y de C-HDR-03/04 (dos firmas Ed25519 bajo la misma
`public_key`). Es el límite H7 del INFORME; es el cimiento de lo que §7.2 acaba de cerrar.

### 2.3 · Rango: lo que R-FIN-13′ no cierra
Arranque por red, ventana, límites y redondeos, fusiones fuera de ventana y validación de ramas
candidatas con pesos reales. Conservado a propósito en el «Pendiente» de §7.2.

### 2.4 · Orden de ejecución del DAG y conflictos
Cadena seleccionada, peso, `blue_work`, orden de aplicación del mergeset y resolución de
conflictos de transacciones (§17, «DAG»).

### 2.5 · Alturas y calendario derivados del orden DAG
Activaciones, madurez de coinbase, timelocks, expiración de tx y sectores, archivado. MIGRACION:
«El significado de altura, orden de aplicación y madurez en DAG aún debe cerrarse antes de
trasladar esas cuentas a una garantía temporal». No escalar constantes por 120 mecánicamente.

### 2.6 · Estado UTXO con datos de deshacer
`ci/consenso-pendiente.txt` documenta que `zx-consensus::bloque::validar_bloque` no lo alcanza
nadie porque la cadena no mantiene ese conjunto — hay un `TODO(sincronizador)` en
`crates/zx-node/src/cadena.rs`. Sin eso no hay validación completa de bloque.

### 2.7 · Reglas de transporte decididas y todavía sin escribir en el SPEC
Salen de las decisiones de Katana del 2026-09-13 (§3.1). No son consenso, pero sin ellas la Δ
medida es optimista, y el v2a las modela: conviene redactarlas antes. Cada ID nuevo debe citarse
en `crates/` o declararse en `ci/reglas-sin-codigo.txt`.

| Regla | De dónde sale | Estado actual del SPEC |
|---|---|---|
| Cola prioritaria para bloques y PoT sobre transacciones; presupuesto de reenvío de transacciones por debajo de la subida; reenvío de transacciones por anuncio y petición | Q1 | No existe en §16 ni en `crates/zx-p2p/src/behaviour.rs` |
| Relé compacto obligatorio en la ruta crítica | Q2 | R-NET-01 lo negocia conexión a conexión (`SPEC.md:2509`) |
| Caso degradado del relé compacto con presupuestos de recursos (C-NET-04), sin penalizar a quien reenvía (C-NET-05, C-NET-08) | Q2 | No especificado; se concreta en 1.4 |
| Tema de gossip del PoT, verificación una vez por slot con caché, y verificación bajo demanda con tres salvaguardas | Q4 | Solo existen los temas `blocks` y `txs` (`SPEC.md:2122`) |
| C-NET-06 reescrita: consenso antes de reenviar, transacciones después | Q4 | Hoy solo exime la comprobación de UTXO (`SPEC.md:2162-2165`) |

**Pregunta abierta:** relajar C-NET-06 para anunciar antes de reconstruir el bloque. Se decide
cuando el v2a mida con qué frecuencia faltan transacciones en las mempools.

---

## Nivel 3 — Parámetros sin cerrar (no impiden escribir, impiden lanzar)

| # | Punto | Estado |
|---|---|---|
| 3.1 | **`Δ` natural medida solo en simulación** | Instrumento `veritas/finalidad/delta-medido-v1/` (MS; revisión 2 validada y migrada el 2026-09-14); cinco decisiones tomadas; pendientes el banco en hardware y el v2, ver abajo |
| 3.2 | `F` = 2 h **provisional** | Con obligación declarada de bajarla en producción |
| 3.3 | `I`, `L`, `ρ_max` | Sin cerrar; `ρ_max` entre 3× sin segundo VDF y revelación retardada |
| 3.4 | **P-038** | Abierta |
| 3.5 | Génesis | Parámetros y hashes distintos por red; bootstrap explícito |

### 3.1 · `Δ`: medición, decisiones y lo que falta

**Medición (MS, no MR).** `veritas/finalidad/delta-medido-v1/` (ID `DMS-v0.1`). Revisión 1
reproducida por Claude el 2026-09-13; revisión 2 y su corrección, reproducidas fuera del repo
con 16 hilos el 2026-09-14: 25 598 asserts en verde, `resumen.csv` de r1 y r2 y 140 trazas
idénticos byte a byte a los de 24 hilos. Migrado el 2026-09-14 sin las trazas de medias (47 MB,
decisión de Katana): su huella está en `TRAZAS.sha256`. Procedencia en `ENMIENDA-R2.md`,
bitácora del ejecutor en `BITACORA.md`. La incidencia de procedencia (la reproducción de Claude
con 8 hilos había sobrescrito `resultados/barrido-principal/`) quedó reparada en la r2.

**Resultados de la r2 con la base decidida** (100 Mbit/s, objetos de Q2, validación a 0 s como
cota inferior):
- Δ_99 p99 de 0,26 a 0,45 s con la cabecera de 812 B; de 0,32 a 0,54 s con el anuncio compacto del
  techo; 0,60 s como máximo en toda la rejilla. 60 de 60 combinaciones en régimen estable.
- Con 0,1 s de validación por salto, 0,90–1,01 s.
- El bloque completo del techo satura (ρ = 1,0005): la cola crece con el horizonte y sus cifras no
  son Δ.
- Padres típicos 1,14–1,39.
- Comprobación de cordura: máximo estable 8,63 s < S_max/10.

**Enmienda del INFORME — CERRADA (2026-09-14).**
- Declarado el sesgo del modelo: bloque completo a los 8 vecinos (`src/rapido.jl:151-158`) y
  validación a 0 s, frente al relé compacto (R-NET-01) y la validación antes de retransmitir
  (C-NET-12) del SPEC.
- Recalificadas como dependientes del modelo, sin borrarlas, tres conclusiones de la r1: «128 kB
  corresponde a la banda de 4–8 s», «1 MB satura» y el procesado a 0 s.
- Añadidas las medias de llegada por bloque y por nodo, y medidas las celdas de Q2.
- Corregido un error de método encontrado al validar: la media ponderada por espacio contaba la
  cuota dos veces (efecto ≤ 0,24 %).
- Queda una observación sin corregir: el test de ese estimador no cubre la ruta en línea de
  `run.jl` (`ENMIENDA-R2.md` §7).

| # | Pregunta abierta del v1 | Estado |
|---|---|---|
| Q1 | Ancho de banda de referencia | **Decidido por Katana, 2026-09-13** (abajo) |
| Q2 | Presupuesto de tamaño de cabecera y bloque DAG (condiciona 1.4) | **Decidido por Katana, 2026-09-13** (abajo) |
| Q3 | Qué estadístico de Δ gobierna cada parámetro | **Decidido por Katana, 2026-09-13** (abajo) |
| Q4 | Cuánto cuesta la validación por salto (C-NET-12 ya obliga a validar) | **Decidido por Katana, 2026-09-13** (abajo) |
| Q5 | Adversario de red: cuándo y cómo modelarlo | **Decidido por Katana, 2026-09-13** (abajo) |

**Q1 · Referencia de diseño de red: 100 Mbit/s de SUBIDA — DECIDIDO POR KATANA (2026-09-13).**

- **Techo:** ≈1,56 MB/s de datos que cada nodo puede reenviar, con la cuenta pesimista del repo
  (8 pares, sin overhead). Con transacciones de 350 B (Modelo B350, hipotético) son **4 464 tx/s**;
  con transacciones Orchard de 2 acciones (9 163 B) serían ≈170 tx/s. Por eso el techo se declara
  en bytes y no en tx/s. Equivale a 7,8 veces el límite de bloque de arranque.
- **Qué es y qué no:** se calcula por nodo, pero en un libro replicado cada nodo procesa todas
  las transacciones, así que es también el techo de planificación de la red entera: añadir
  nodos no lo sube. No es el límite actual del protocolo (el límite de bloque de arranque da
  ≈571 tx/s) ni la única cota: sostenido, ese techo son 49,3 TB/año de disco sin poda (4 TB en
  unos 30 días), frente al presupuesto de 72 tx/s del Modelo B350 (`ZEROX-EN-NUMEROS.md:160`).
  La CPU de validación no está medida.
- **Motivo:** política de marketplace. Se prioriza a quien produce bloques con conexión fija de
  calidad, aunque centralice algo y perjudique a los nodos mal conectados.
- **Alcance:** es una referencia de planificación, no un requisito. Ninguna regla la comprueba ni
  expulsa a nadie. No cambia Δ: con objetos pequeños, pasar de 10 a 50 Mbit/s mejora Δ_100 de
  0,337 a 0,325 s (v1 §6).
- **Fuente:** Speedtest Global Index, julio 2026, subida mediana de banda ancha fija, copiada por
  Katana. Mundial 63,72; EE. UU. 59,67; Canadá 96,30; México 94,09; Argentina 84,57; Brasil 133,90;
  Colombia 105,71; China 47,92; India 58,80; Japón 133,27; Taiwán 188,01; Singapur 352,74;
  Alemania 37,43; Francia 262,68; España 211,64. Faltan datos del Norte de Europa.
- **Consecuencia declarada:** la línea típica de EE. UU., Canadá, México, Argentina, China, India y
  Alemania queda por debajo. Con carga sostenida entre ≈2 139 y 4 464 tx/s (transacciones de 350 B)
  esas líneas no pueden reenviar toda la carga: siguen recibiendo y validando, pero el reenvío se
  concentra en los nodos mejor conectados.
- **Condición:** una regla de transporte que hoy no existe ni en SPEC §16 ni en
  `crates/zx-p2p/src/behaviour.rs`. Tres partes: cola prioritaria para bloques y PoT sobre
  transacciones; presupuesto de reenvío de transacciones por debajo de la subida disponible; y
  reenvío de transacciones por anuncio y petición. Sin ella, los nodos por debajo de la referencia
  se saturan en lugar de recortar. Pendiente de redactar como regla C-NET y de declarar en
  `ci/reglas-sin-codigo.txt` hasta que haya código.
- **Revisión:** cuando se mida el relé real, o si la carga sostenida se acerca a ~2 000 tx/s.

**Q2 · Presupuesto compacto para la ruta crítica — DECIDIDO POR KATANA (2026-09-13).**

- **Qué se fija:** un **presupuesto de diseño que 1.4 debe respetar, no un formato congelado**.
  - Cabecera DAG (base PoAS + padres + justificación PoT): ≤ ~1 kB en el caso típico y ≤ ~20 kB
    en el peor caso. El peor caso son 16 padres y 150 slots de justificación (S_max): 20 268 B, de
    los que 19,2 kB son PoT.
  - **Dos niveles.**
    - **Lo que se reenvía y se valida en cada salto:** la cabecera sin justificación (base 556 B +
      32 B por padre; 1 068 B con 16 padres) y los IDs cortos.
    - **Lo que viaja pero no cuesta CPU por salto:** la justificación PoT (≤ 19,2 kB). Acompaña al
      bloque (C-HDR-07) y se valida contra la caché de slots (Q4); su coste son bytes, 1,6 ms por
      par a 100 Mbit/s con 20 kB.
  - Anuncio compacto (cabecera + 6 B por transacción, C-NET-07): ≤ ~28 kB en el techo de Q1
    (≈4 464 transacciones de 350 B por bloque; 27 596 B).
  - Relé compacto **obligatorio en la ruta crítica**. Hoy R-NET-01 lo negocia conexión a
    conexión.
- **Motivo:** en el techo de Q1, con el modelo pesimista del v1 (8 pares en serie, ≈5,6 saltos),
  el anuncio compacto ocupa el 1,8 % de la subida de un nodo de 100 Mbit/s (utilización ρ = 0,018)
  y añade ≈0,1 s de Δ (≈0,17 s por líneas típicas de EE. UU.). El bloque completo **satura el
  enlace**: ρ = 1,0 con 100 Mbit/s y 1,68 por líneas típicas de EE. UU. No hay Δ estable, porque
  la cola crece con el tiempo. *Corregido el 2026-09-13: una versión anterior daba ≈5,6 s y ≈9,4 s
  para el bloque completo, pero eran solo tiempo de transmisión, sin la cola.*
- **Dependencia de Q1:** en el techo, el reenvío de transacciones ocupa toda la subida del nodo de
  referencia (ρ = 1,0 en la cuenta pesimista). El anuncio compacto solo sale a tiempo gracias a la
  regla de prioridad de bloques de Q1.
- **Riesgo declarado de esta opción:** con un bloque por segundo, lo que tardan las transacciones en
  llegar a todas las mempools es del orden del intervalo entre bloques. Si quien produce el bloque
  incluye transacciones hasta el último instante, puede faltar una parte grande en los receptores,
  y el caso degradado sería el normal. Es una hipótesis derivada, no medida; se mide en el v2a (Q5).
- **Pendiente derivado:**
  - Redactar la obligatoriedad del relé compacto en SPEC §16.
  - Especificar en 1.4 el **caso degradado** (el receptor pide las transacciones que le faltan) como
    mecanismo con presupuestos de recursos (C-NET-04), **sin penalizar a quien reenvía**: la falta
    suele venir de mempools desincronizadas, no de mala fe (C-NET-05, C-NET-08).
  - **Pregunta abierta: relajar C-NET-06.** Hoy exige tener todas las transacciones antes de emitir
    el anuncio, así que la petición de las que faltan está en la ruta crítica. Anunciar antes de
    reconstruir la sacaría de ahí, a cambio de reenviar anuncios cuyo cuerpo podría no coincidir.
    Se decide después de que el v2a mida con qué frecuencia faltan transacciones.

**Q3 · Ningún estadístico único: cada regla usa lo que consume — DECIDIDO POR KATANA (2026-09-13).**

- **Para `k`, la fracción de honestos rojos y la frontera:** la **distribución completa** de Δ
  (por bloque y por nodo, **ponderada por cuota de espacio**, no por número de nodos) entra en la
  medición de δ₀ (ronda 11a) en lugar de una Δ constante.
- **Para las reglas temporales duras** (S_max = 150 s, R-FIN-7 con F): no consumen un estadístico
  de Δ. S_max se dimensionó por tolerancia a particiones y por la cota de F
  (`research/dag-poas-ancla-de-orden.md:163`), y F por finalidad. Basta una **comprobación de
  cordura en régimen estable** (la red da abasto con la carga): Δ máxima muy por debajo de S_max
  (por ejemplo, menos de S_max/10 = 15 s) y de F. El v1 la pasa: máximo de 2,41 s con cabecera de
  683 B y 8,63 s con bloque completo de 100 kB a 10 Mbit/s. El caso saturado de 1 MB dio 3 428,7 s,
  por encima de S_max; por eso la comprobación exige régimen estable.
- **Para la aceptación de pagos:** no se usa Δ.
- **Valor provisional hasta tener esa medición:** Δ_99 en su p99. Recalculado en la r2 con la
  base decidida: **0,26–0,45 s** con la cabecera de 812 B a 100 Mbit/s, y 0,26–0,60 s en toda la
  rejilla (INFORME §11.3; en el v1 daba 0,28–0,48 s). **Etiqueta
  obligatoria:** representa «casi toda la red, casi siempre» y sirve para las herramientas
  históricas que exigen una Δ constante. No es el argumento de seguridad: ese es δ₀ medido, y
  bajo adversario en el v2b.
- **Media de llegada ponderada por producción:** se publica como estadístico **descriptivo de
  tamaño** (padres típicos ≈ 1 + λΔ̄, tamaño del mergeset), no de seguridad. Alimenta la cabecera
  típica de Q2: los «~4 padres» del ancla se estimaron con Δ = 4 s.
- **Ajuste del 2026-09-13, aprobado por Katana tras revisar un análisis externo.** Se rechazó usar
  esa media como provisional de seguridad en lugar de Δ_99 p99. Un bloque queda rojo cuando su
  anticono azul supera `k`, así que la fracción roja es un suceso de cola, no una función de la
  media. La ronda 11a lo muestra con `k=30`: 0,0000 / 0,0020 / 0,0828 / 0,2858 a Δ = 4 / 8 / 12 /
  16 s. Sustituir la distribución por su media quita la cola y subestima los rojos, que es la
  dirección insegura.
- **Motivo:** la pregunta del percentil existe solo porque las simulaciones antiguas usaban Δ
  constante. Hoy no cambia nada: todo estadístico del v1 queda por debajo de 4 s, donde `k=30` no
  deja bloques honestos rojos (ronda 11a). Importa para el método del v2.
- **Dependencia:** portar el instrumento δ₀ (Python) a Julia exige un GHOSTDAG en Julia, que es
  TAREAS 1.3. El trabajo sirve para las dos cosas. Ponderar por espacio requiere una hipótesis
  declarada sobre su reparto.

**Q4 · Consenso antes de reenviar, transacciones después; PoT por slot con caché y verificación
bajo demanda — DECIDIDO POR KATANA (2026-09-13).**

- **Antes de reenviar** (C-NET-12, C-NET-06): cabecera, prueba de espacio, 2 KZG, sello,
  justificación PoT (desde la caché) y compromiso Merkle. **Después**, antes de adoptar el estado:
  firmas, pruebas Halo2 y UTXO. Hay que reescribir C-NET-06 para decirlo explícitamente; hoy solo
  exime la comprobación de UTXO.
- **PoT:** se verifica una vez por slot en un tema de gossip propio y se guarda en caché. Es el
  patrón de Autonomys (`/home/katana/zeo/fuentes/subspace` @ `f8842d0`:
  `crates/sc-proof-of-time/src/source/gossip.rs` y `verifier.rs:25-29`). Es compatible con
  C-CHK-05: cada slot se verifica entero, una sola vez.
- **Verificación bajo demanda:** si un bloque cita slots aún no verificados, se verifican en ese
  momento con la justificación que trae el propio bloque (C-HDR-07), una vez por nodo y slot. Es el
  respaldo para nodos que se ponen al día; el camino normal sigue siendo el tema de gossip. Tres
  salvaguardas:
  1. comparar primero con la caché; si la salida no coincide, el bloque es inválido sin gastar CPU;
  2. los slots por delante del reloj PoT del nodo se retienen, no se verifican
     (`research/dag-poas-ancla-de-orden.md:342`);
  3. presupuesto de CPU para verificaciones bajo demanda, por par y por intervalo (espíritu de
     C-NET-04).
- **Motivo:** el coste por salto queda acotado por construcción. No depende del salto de slots
  (hasta 150 × 96,1 ms ≈ 14,4 s si el PoT se verificara por bloque) ni del número de transacciones
  (coste Halo2 sin medir). Es el mismo compromiso que BIP 152. Un bloque con cabecera válida y
  transacciones inválidas se propaga antes de detectarse, pero fabricarlo exige un billete ganador
  real.
- **Pendiente derivado:**
  - Tema de gossip del PoT en el SPEC (hoy solo hay `blocks` y `txs`, `SPEC.md:2122`).
  - Reescribir C-NET-06.
  - Nota de implementación: verificar varios slots en paralelo entre núcleos para ponerse al día
    (≈1,8 s para 150 slots en 8 núcleos; derivado, sin medir). Dentro de un slot no hay ganancia:
    la ruta AVX-512/VAES ya verifica los 8 tramos a la vez, con 16 carriles AES
    (`crates/subspace-proof-of-time/src/aes/x86_64.rs:248-269`).
  - Nota de implementación: banco en hardware del coste por salto (prueba de espacio, 2 KZG, sello
    y Merkle) y del PoT en las rutas sin AVX-512 (AVX2+VAES, AES-NI+SSE4.1). Los 96,1 ms son el
    mejor caso.

**Q5 · Adversario de red en un v2 partido en dos — DECIDIDO POR KATANA (2026-09-13).**

- **Punto de partida:** el v1 se enmienda y se migra primero, como medición de la Δ natural.
- **v2a · Δ bajo ataque, solo red.** Tres vectores:
  - nodos que no reenvían, o aislar a un nodo rodeándolo de pares propios;
  - mempools desincronizadas: el relé compacto se degrada porque el receptor tiene que pedir las
    transacciones que faltan antes de comprobar el compromiso Merkle (C-NET-06). Se modela con el
    **retardo de propagación de transacciones** (la «segunda Δ») como parámetro explícito, y con la
    **política de inclusión** de quien produce el bloque (hasta el último instante, o solo
    transacciones con cierta antigüedad) como variable. Resultado que se busca: con qué frecuencia
    faltan transacciones, para decidir si se relaja C-NET-06 (Q2);
  - inundación de transacciones contra la subida honesta, con y sin la regla de prioridad de Q1.

  Se modela con relé compacto y con el coste por salto medido. No necesita GHOSTDAG.
- **v2b · Efecto en la seguridad.** La distribución de Δ de v2a, ponderada por espacio, entra en
  δ₀ y en la frontera (Q3). Añade dos vectores de Q4: agotar el presupuesto de verificación bajo
  demanda, y bloques con cabecera válida y transacciones inválidas. Requiere el GHOSTDAG en Julia
  de 1.3.
- **Motivo:** los vectores ya están identificados y cada parte depende de algo distinto (banco en
  hardware, GHOSTDAG en Julia). Partirlo evita que la parte de red espere a la de consenso.
- **Orden:**
  1. enmienda del INFORME v1 y migración — **hecho, 2026-09-14**;
  2. banco en hardware del coste por salto (Q4);
  3. v2a;
  4. GHOSTDAG en Julia (1.3 + 1.2);
  5. v2b.

---

## Nivel 4 — Decisiones de política que nadie ha tomado

### 4.1 · Recompensa del bloque honesto tardío
Abierta el 2026-09-12 y escrita en §7.2. Medido: un bloque honesto con billete único que nadie
disputa, fusionado tras el cierre de su ventana, **no cobra nunca**. ¿Pérdida definitiva, o
reinclusión como la que modela la cola de RCE-v0.1? La Δ natural ya está medida en simulación
(0,26–0,60 s, §3.1). Que eso vuelva raro el caso depende de dos cosas que siguen abiertas: el
margen `G` de cierre de la ventana, que en RCE-v0.1 es escenario pendiente, y las particiones y la
retención adversaria, que el v2 todavía no mide.

### 4.2 · IDs de regla para §7.2
Hoy es prosa, como el resto de §7.2. Darle IDs `C-XXX-NN` obliga a declararlos en
`ci/reglas-sin-codigo.txt` como trabajo futuro, porque `ci/citas-spec.sh` exige que toda regla esté
citada en `crates/` o declarada. Es una decisión de convención del SPEC.

---

## Nivel 5 — Deuda de evidencia (debilita afirmaciones, no bloquea)

- **H2** — la convergencia de dos nodos está probada para **un** par de órdenes de entrega, sin
  barrido de permutaciones.
- **H4** — los «dos nodos» comparten el mismo `EconModel`, incluido el oráculo `context_truth`:
  convergen en parte por construcción.
- **H5** — la capa económica no comprueba `Σsalidas ≤ Σentradas`; en el fixture principal se
  consumen 5500 y se pagan 3000 sin que nadie lo note.
- **H6** — `catch ArgumentError → Invalid` enmascara roturas de invariante interno como veredicto
  de consenso.
- `comprobacion-decisiva-v1`, el instrumento promovido, no lleva `CONTRATO.md` ni `MODELO.md`
  como sus hermanos de `veritas/consenso/`.
- **Huellas de SPEC.md desalineadas:** `disponibilidad-causal-multivista-v1`,
  `dominio-autorizacion-v1`, `identidad-disponibilidad-v1` y `ventana-retarget-causal-v1` firman un
  `SPEC.md` que ya no existe con ese contenido. Cada uno firmó el SPEC del día en que se cerró, y
  el SPEC se reescribió después. Declarado en el commit f1a10a8 y comprobado de nuevo el
  2026-09-14; pendiente de decisión.
- **`DMS-v0.1`:** el test del estimador ponderado por espacio (T1) comprueba las funciones, pero
  `run.jl` aplica la regla en línea, sin llamarlas. Una regresión en esa ruta no la detectaría el
  test (`veritas/finalidad/delta-medido-v1/ENMIENDA-R2.md` §7).

---

## Orden recomendado

1. **`Δ` (3.1)** desde ya — es medición, no diseño, y desbloquea el nivel 3 entero. Δ natural
   medida en simulación y migrada (2026-09-14). Siguiente paso: banco en hardware del coste por
   salto y v2a (Q5), con las reglas de §2.7 redactadas antes, porque el v2a las modela.
2. **GHOSTDAG + `rank` total (1.3 + 1.2)** juntos — son el mismo problema por dos lados, y
   desbloquean §7.2 completa. El GHOSTDAG en Julia también alimenta δ₀ con la distribución de Δ
   (Q3) y el v2b (Q5). **No depende de Δ:** puede arrancar en paralelo al banco y al v2a, y es el
   camino crítico para escribir código, porque el nivel 1 es el único bloqueo duro.
3. **Cabecera DAG (1.4)** — hasta que exista, ningún crate de serialización, red o almacenamiento
   puede cerrarse. Ya tiene presupuesto de diseño (Q2).
4. El resto por área, siguiendo §17 del SPEC.

---

## Cerrado recientemente (para no reabrirlo)

- **Δ natural medida en simulación (3.1, primer tramo)**, 2026-09-14. Instrumento `DMS-v0.1` en
  `veritas/finalidad/delta-medido-v1/`, revisión 2. Con la base decidida por Katana (100 Mbit/s
  de subida y relé compacto), Δ_99 p99 queda entre 0,26 y 0,60 s, frente a los 4 s que `k=30`
  tolera sin bloques honestos rojos. El bloque completo en el techo satura el enlace. Sigue
  siendo MS: sin validación medida, sin mempool y sin adversario (banco en hardware y v2).
  Evidencia: 25 598 asserts; resultados de r1 y r2 reproducidos byte a byte por Claude con 16
  hilos frente a 24; `ENMIENDA-R2.md`, `HUELLAS.sha256`, `TRAZAS.sha256`.

- **Z0 / semántica de ventana vacía (antiguo 1.1)**, 2026-09-12. `HeldZero` pasa a no-op
  explícito: `causal_step` devuelve `(StepHeldZero, current, 0, false)` sin slot de activación,
  así que los seis puntos de llamada no pueden agendarla. CONTRATO de RCE-v0.1 y ARM-v0.1 suben a
  revisión 2; el vector `delay=2` (rango 100→200 revertido a 100 antes de la enmienda) queda como
  regresión permanente en el fixture. Convergencia Julia–Rust medida: `range_at(40) = 200` en
  ambos lenguajes.
  Verificado tras migrar: `cargo test --workspace` 485/486 (el único rojo es el preexistente de
  1.4, `el_spec_dice_el_tamano_real_de_la_cabecera`), `cargo fmt --check` y `cargo clippy -D
  warnings` en verde, Julia RCE 12856 + ARM 687 + comprobación decisiva 451 asserts en verde,
  `sha256sum -c HUELLAS.sha256` 35/35.
  Evidencia: commit `08b3681` en `rediseno/v1-spec-first`;
  `veritas/consenso/retarget-causal-endogeno-v1/ENMIENDA-Z0.md`.

- **Unicidad pagable (§7.2)**, 2026-09-12. Identidad pagable = el billete; contexto persistente
  con liberación en reorg; copia en fusión posterior o fuera de ventana = inerte por dos reglas;
  desempate **P1 azul primero**, decidido por Katana, separado por escrito del orden de aplicación
  de R-FIN-8′(4); y declarado que **refina R-FIN-8′(1)**, que al pie de la letra pagaría a dos
  copias `RedK` del mismo billete.
  Evidencia: `veritas/consenso/comprobacion-decisiva-v1/`, 449/449 asserts, reproducida de forma
  independiente por el auditor.
