# INFORME — ORDEN-S02a (Encargo 02, parte a: coste real de regenerar para auditar R2)

**Ejecutor:** DeepSeek Harness, modelo `deepseek-flash`, esfuerzo `high`. **Fecha:** 2026-09-26.
**Zona:** `/home/katana/zeo/ZEROX/deepseek/S02a/`. **Investigación aislada:** nada entra en el
workspace ni en el consenso.

**Veredicto.** Se confirma el resultado esperado por RFT-04: **encarece, no impide**. Sobre el
formato PoAS actual y el compromiso R2 de S01, un adversario que borra los chunks y contesta una
apertura regenerando paga, por apertura, **entre 8,8·10⁵ y 1,35·10⁷ veces** el tiempo de leerla del
disco en la memoria del proceso (0,2–0,3 µs frente a 0,17–4,06 s), con una **cota inferior de
`t_reg` por registro regenerado** (las tablas PoS). La condición de refutación —«tiempo
indistinguible del de leerlas de disco»— **no se cumple**. El almacenamiento que se ahorra es
pequeño hasta que se poda muy profundo, y la latencia se satura en `p · t_reg` (p = piezas del
sector): la curva «almacenamiento ↔ latencia» cae en un acantilado, no permite elegir un punto con
latencia de disco ahorrando almacenamiento.

---

## 1. Faltas de definición detectadas e interpretación declarada

Se informan antes de editar. Ninguna impidió cumplir la orden; se resolvieron como la propia orden
autoriza y se declaran.

1. **Nivel de E-árbol(L).** «Nodos del árbol por encima del nivel L (tamaño `2^{prof−L}×32 B`)». Se
   interpreta literalmente: se conservan los `2^(prof−L)` nodos del nivel `L` (nivel 0 = hojas) y la
   apertura **recompone los ancestros** desde ese nivel (coste `2^(prof−L)−1` hashes, incluido en la
   latencia medida). Conservar todos los niveles ≥ L costaría ≈2×; se declara.
2. **Árbol Merkle en E-disco.** La orden dice «guarda el sector completo». Se cuenta como
   almacenamiento el fichero de sector; la caché del árbol Merkle que E-disco necesita para
   recomponer el camino en `O(prof)` se informa aparte en RAM y **no** se imputa al almacenamiento.
   Sin ella, el camino costaría `O(n)` hashes.
3. **Apertura A1.** La orden la define como «hoja de R2 en una posición `chunk_location` uniforme +
   camino Merkle, exactamente como la de S01». S01 abría soluciones ganadoras reales; para poder
   muestrear posiciones uniformes se construye la `Solution<()>` con la **prueba de espacio real** de
   la tabla del registro y el chunk fuente, y se verifica con `verificar_apertura` de S01 (el
   verificador PoAS real de S01 no depende de la posición). Se muestrea **uniformemente entre las
   hojas con `codificado = 1`**, que son las que una solución ganadora puede abrir. En los cuatro
   tamaños medidos, `cod1 = n` (no aparecen chunks sin codificar).
4. **`t_reg`.** Tabla PoS del registro (`generate_parallel`) **más** codificación erasure del
   registro. La obtención de la pieza de la historia local queda fuera del cronómetro: la orden la
   supone gratuita y local, y el coste de red se declara no medido.
5. **Relleno de potencia de dos.** La fórmula `2^(prof−L)·32 B` cuenta los nodos de relleno cuando
   `n` no es potencia de dos (p = 3). Un adversario real guardaría solo `ceil(n/2^L)` nodos. La tabla
   principal usa la **fórmula de la orden**; se anota la corrección.

## 2. Qué se midió

Sector PoAS real ploteado con el plotter de Autonomys `f8842d0` (mismo camino que S01:
`plot_sector` + `CpuRecordsEncoder::<ChiaTable>`), historia archivada determinista del fixture dev.
Estrategias (todas contestan la apertura de la posición pedida):

| Estrategia | Conserva | Al abrir |
|---|---|---|
| **E-disco** (base honesta) | fichero de sector completo | lee el chunk almacenado y recompona el camino desde la caché del árbol |
| **E-árbol(L)** | `2^(prof−L)` nodos del nivel L | regenera las `2^L` hojas del bloque alineado y recompone el camino |
| **E-nada** ≡ E-árbol(prof) | raíz (32 B) + metadatos públicos | regenera todas las hojas y el árbol completo |

**Regeneración real**, no simulada: se reproduce `record_encoding` (privado en el clon) con la API
pública — `ChiaTable::generator().generate_parallel(semilla)`, `ErasureCoding::extend` del registro
y enmascarado `chunk_almacenado = chunk_fuente XOR proof.hash()` (director:
`subspace-verification/src/lib.rs:248-249`). Se mide explícitamente el número de **tablas distintas**
por apertura (depende de los `piece_offset` distintos del bloque; no se supone `2^L`).

Tamaños: `pieces_in_sector` ∈ {2, 3, 4} (los de S01) y {16} (mayor, autorizado por §3.5). En todos,
`cod1 = n` y `profundidad` = 16, 17, 17 y 19.

## 3. Corrección antes de medir

1. **Validación exhaustiva de la regeneración** por tamaño: las `n` hojas regeneradas se cotejan
   byte a byte contra la región de chunks del fichero de sector y contra las hojas del árbol de R2.

   | piezas | n | chunks discrepantes | hojas discrepantes |
   |---:|---:|---:|---:|
   | 2 | 65 536 | 0 | 0 |
   | 3 | 98 304 | 0 | 0 |
   | 4 | 131 072 | 0 | 0 |
   | 16 | 524 288 | 0 | 0 |

2. **100 aperturas aleatorias por estrategia y tamaño** verificadas contra R2 con el verificador de
   S01: **0 fallos** en todas las combinaciones (6 estrategias por tamaño en p = 2/3/4; 7 en
   p = 16). Detalle crudo en `resultados/VALIDACION-RESUMEN.tsv`.
3. En las **1 080 aperturas medidas** (`modo medir`), todas verifican contra R2: 1 080/1 080.

Una estrategia que no verifica no se mide; ninguna se descartó.

## 4. `t_reg` y escalado con hilos

`t_reg` = tabla PoS + erasure coding de un registro, p = 4, 3 repeticiones por registro (12 medidas
por configuración), mediana:

| hilos | `t_reg` mediana (ms) | min–max (ms) | speedup | eficiencia |
|---:|---:|---:|---:|---:|
| 1 | 900,6 | 895,3–922,6 | 1,00 | 1,00 |
| 2 | 501,7 | 497,9–515,1 | 1,80 | 0,90 |
| 4 | 302,1 | 298,9–309,8 | 2,98 | 0,75 |
| 8 | 206,3 | 197,3–212,7 | 4,37 | 0,55 |
| 16 | 157,7 | 156,1–162,3 | 5,71 | 0,36 |

El generador de tablas (Chia, K = 20) **no escala** más allá de ~6× a 16 hilos: es un cuello de
memoria/ordenación, no de cómputo puro. Por eso la cota inferior `c · t_reg` tiene un suelo que no
baja al añadir núcleos.

## 5. Tabla final (malla principal a 16 hilos, N = 30 por punto)

Abreviaturas: **T** = hilos, **N** = aperturas medidas, **alm.** = almacenamiento conservado (B),
**tablas** = media de tablas PoS distintas regeneradas por apertura, **wall** = mediana del tiempo
de pared por apertura, **p99** = percentil 99, **núcleos** = tiempo de CPU / tiempo de pared
(núcleos efectivos), **verif** = aperturas que verifican.

### p = 2 (sector 2 113 856 B; n = m = 65 536; prof = 16)

| estrategia | L | alm. (B) | tablas | wall (ms) | p99 (ms) | CPU (ms) | núcleos | verif |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| E-disco | — | 2 113 856 | 0,0 | 0,0002 | 0,0006 | ~0 | — | 30/30 |
| E-árbol | 0 | 2 097 152 | 1,0 | **176,5** | 206,8 | 1 062,8 | 6,0 | 30/30 |
| E-árbol | 1 | 1 048 576 | 1,7 | 308,1 | 351,6 | 1 928,8 | 6,3 | 30/30 |
| E-árbol | 2 | 524 288 | 2,0 | 326,0 | 341,6 | 2 019,3 | 6,2 | 30/30 |
| E-árbol | 4 | 131 072 | 2,0 | 312,7 | 830,6 | 2 020,5 | 6,5 | 30/30 |
| E-árbol | 8 | 8 192 | 2,0 | 322,0 | 892,0 | 2 047,8 | 6,4 | 30/30 |
| E-nada | 16 | 32 | 2,0 | **443,2** | 459,4 | 2 016,9 | 4,6 | 30/30 |

### p = 3 (sector 3 170 752 B; n = 98 304; m = 131 072; prof = 17)

| estrategia | L | alm. (B) | tablas | wall (ms) | p99 (ms) | CPU (ms) | núcleos | verif |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| E-disco | — | 3 170 752 | 0,0 | 0,0003 | 0,0006 | ~0 | — | 30/30 |
| E-árbol | 0 | 4 194 304¹ | 1,0 | 174,7 | 178,3 | 984,9 | 5,6 | 30/30 |
| E-árbol | 1 | 2 097 152 | 2,0 | 308,6 | 313,5 | 1 897,4 | 6,1 | 30/30 |
| E-árbol | 2 | 1 048 576 | 2,7 | 445,9 | 451,6 | 2 778,2 | 6,2 | 30/30 |
| E-árbol | 4 | 262 144 | 3,0 | 440,4 | 474,6 | 2 790,5 | 6,3 | 30/30 |
| E-árbol | 8 | 16 384 | 3,0 | 440,4 | 453,2 | 2 756,2 | 6,3 | 30/30 |
| E-nada | 17 | 32 | 3,0 | **672,4** | 690,2 | 2 994,2 | 4,5 | 30/30 |

¹ `n` no es potencia de dos: la fórmula de la orden cuenta el relleno `m·32 = 4 MiB`, **más** que el
propio sector (3,17 MiB). Guardar solo las `n` hojas reales serían 3,15 MiB. La conclusión no cambia.

### p = 4 (sector 4 227 648 B; n = m = 131 072; prof = 17)

| estrategia | L | alm. (B) | tablas | wall (ms) | p99 (ms) | CPU (ms) | núcleos | verif |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| E-disco | — | 4 227 648 | 0,0 | 0,0003 | 0,0006 | ~0 | — | 30/30 |
| E-árbol | 0 | 4 194 304 | 1,0 | 189,7 | 218,2 | 1 125,3 | 5,9 | 30/30 |
| E-árbol | 1 | 2 097 152 | 2,0 | 321,6 | 443,0 | 1 977,0 | 6,1 | 30/30 |
| E-árbol | 2 | 1 048 576 | 3,1 | 450,2 | 598,4 | 2 837,2 | 6,3 | 30/30 |
| E-árbol | 4 | 262 144 | 4,0 | 585,9 | 594,1 | 3 682,7 | 6,3 | 30/30 |
| E-árbol | 8 | 16 384 | 4,0 | 586,3 | 595,5 | 3 720,0 | 6,3 | 30/30 |
| E-nada | 17 | 32 | 4,0 | **882,6** | 893,2 | 4 014,5 | 4,5 | 30/30 |

### p = 16 (sector 16 910 400 B; n = m = 524 288; prof = 19)

| estrategia | L | alm. (B) | tablas | wall (ms) | p99 (ms) | CPU (ms) | núcleos | verif |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| E-disco | — | 16 910 400 | 0,0 | 0,0003 | 0,0006 | ~0 | — | 30/30 |
| E-árbol | 0 | 16 777 216 | 1,0 | 290,3 | 299,3 | 1 235,8 | 4,3 | 30/30 |
| E-árbol | 1 | 8 388 608 | 2,0 | 365,2 | 432,2 | 2 037,5 | 5,6 | 30/30 |
| E-árbol | 2 | 4 194 304 | 4,0 | 652,2 | 677,5 | 4 003,9 | 6,1 | 30/30 |
| E-árbol | 4 | 1 048 576 | 12,2 | 1 856,0 | 2 609,3 | 11 986,0 | 6,5 | 30/30 |
| E-árbol | 8 | 65 536 | 15,9 | 2 721,0 | 3 416,5 | 16 915,5 | 6,2 | 30/30 |
| E-nada | 19 | 32 | 16,0 | **4 059,4** | 6 363,0 | 17 994,8 | 4,4 | 30/30 |

La tabla completa por hilos (malla de escalado T = 1, 4, 8 sobre p = 2 y p = 4) está en
`resultados/resumen-mediciones.tsv`. La columna **tablas** confirma la decisión §3.3 de la orden: el
número de tablas es el de `piece_offset` distintos del bloque, **≤ p**, no `2^L`.

## 6. Curva «almacenamiento conservado ↔ latencia por apertura» (16 hilos)

Puntos (almacenamiento B, latencia mediana ms); «sector» = E-disco:

| p | sector (B, ms) | L=0 | L=1 | L=2 | L=4 | L=8 | E-nada |
|---:|---|---|---|---|---|---|---|
| 2 | 2 113 856 / 0,0002 | 2 097 152 / 176,5 | 1 048 576 / 308,1 | 524 288 / 326,0 | 131 072 / 312,7 | 8 192 / 322,0 | 32 / 443,2 |
| 3 | 3 170 752 / 0,0003 | 4 194 304 / 174,7 | 2 097 152 / 308,6 | 1 048 576 / 445,9 | 262 144 / 440,4 | 16 384 / 440,4 | 32 / 672,4 |
| 4 | 4 227 648 / 0,0003 | 4 194 304 / 189,7 | 2 097 152 / 321,6 | 1 048 576 / 450,2 | 262 144 / 585,9 | 16 384 / 586,3 | 32 / 882,6 |
| 16 | 16 910 400 / 0,0003 | 16 777 216 / 290,3 | 8 388 608 / 365,2 | 4 194 304 / 652,2 | 1 048 576 / 1 856,0 | 65 536 / 2 721,0 | 32 / 4 059,4 |

Lectura:

- **E-árbol(0)** ya paga **≥ `t_reg`** (1 tabla) y solo ahorra mapa+metadatos+checksum: **0,79 %** del
  sector en p = 2/4/16 (y en p = 3, con la fórmula de la orden, **gasta más** que el sector). Es decir:
  el primer byte que se deja de guardar cuesta ~10⁶ veces más latencia.
- Para ahorrar almacenamiento de verdad hay que podar profundo (L grande), pero la latencia **se
  satura** en `p · t_reg` porque el número de tablas está acotado por `p`. En p = 16, pasar de L = 4
  a L = 8 ahorra 1 MiB y cuesta +0,87 s (más tablas medias); E-nada es el más lento porque además
  reconstruye las `n` hojas y el árbol entero (coste `O(n)`).
- La curva no ofrece ningún punto con latencia cercana a la de disco ahorrando almacenamiento: es un
  acantilado de ~6 órdenes de magnitud en tiempo por una fracción pequeña de bytes, y solo se
  «suaviza» renunciando a casi todo el sector y aun así pagando `p · t_reg`.

## 7. Escalado de la apertura con hilos (p = 4, E-árbol con 4 tablas)

| hilos | wall mediana (ms) | speedup | CPU (ms) | núcleos efectivos |
|---:|---:|---:|---:|---:|
| 1 | 3 366,4 | 1,00 | 3 366,6 | 1,0 |
| 4 | 1 116,1 | 3,02 | 3 373,7 | 3,0 |
| 8 | 788,7 | 4,27 | 3 649,0 | 4,6 |
| 16 | 585,9 | 5,75 | 3 682,7 | 6,3 |

La apertura regeneradora escala **igual de mal que `t_reg`** (≈5,7× de 1 a 16 hilos, eficiencia 36 %):
más núcleos no acercan la latencia a la del disco.

## 8. Qué encarece y cuánto

| Estrategia | Almacenamiento | Latencia por apertura (16 h) | Coste frente a E-disco | Núcleos por apertura |
|---|---:|---:|---:|---:|
| E-disco | sector completo | 0,2–0,3 µs | 1× | ≪1 |
| E-árbol(0) | ≈sector (ahorra 0,8 %) | 0,17–0,29 s | **6·10⁵ – 1,3·10⁶×** | 4,3–6,0 |
| E-árbol(L ≥ log₂p) | 2^(prof−L)·32 B | p · t_reg (0,31–2,7 s) | **1,5·10⁶ – 9·10⁶×** | 6,2–6,5 |
| E-nada | 32 B | 0,44–4,06 s | **2,2·10⁶ – 1,35·10⁷×** | 4,4–4,6 |

**Cota inferior confirmada.** La latencia por apertura sigue `c · t_reg` (`c` = tablas distintas,
medido) dentro de ~10 %, y **nunca baja de `t_reg`** mientras se regenere al menos un registro. En
consecuencia:

- La pregunta falsable **no se refuta**: regenerar es medible y muy superior a leer de disco.
- Crece con los datos omitidos **hasta el tope de `p` registros**; más allá de ahí el coste por
  tabla se satura y solo E-nada añade el `O(n)` del árbol completo.
- El techo del ataque no es «imposible»: con CPUs o GPUs abundantes y una ventana amplia, un
  adversario **puede** contestar regenerando (RFT-04 ya lo decía). Lo que la auditoría consigue es
  **encarecer** cada apertura en ~10⁶ veces y hacer que el coste agregado crezca con el número de
  aperturas y con `p`.

## 9. Qué NO se mide (declarado)

- **GPU y ASIC.** No se miden. Existe `ab-proof-of-space-gpu` en el clon; su coste queda abierto. El
  histórico de otra máquina/otra carga (§10) midió una GTX 1070 solo **1,21×** más rápida que 32
  hilos de CPU para plotear, pero **no se usa como cifra propia**.
- **Coste de descargar piezas y latencia de red.** La historia se supone pública y local; el coste de
  obtener la pieza se excluye del cronómetro.
- **Adversario que conserva una fracción aleatoria de hojas**, comprime o comparte bytes: modelo,
  para S02b.
- **Plazos, ventanas de reto, número de aperturas y tasa de fallos honestos**: S02b.
- Preexistencia, permanencia y doble uso entre ramas (RFT-03/04/06) siguen fuera de alcance.
- `t_reg` incluye la tabla que la propia solución PoAS necesita, así que parte del coste regenerador
  podría ser común con la producción honesta de la prueba; se declara.
- Los sectores son de **fixture** (2–16 MiB), no de producción; las cifras **no** son un benchmark de
  red (LINEO §7).

## 10. Gastos, incidencias y trazabilidad

- **Presupuesto:** 2 h de reloj, 16 hilos, 32 GiB, 40 GiB de disco. Consumo: disco de la zona
  ≈1,1 GiB (`target` 343 MiB, `.cargo-home` 697 MiB, clon 81 MiB); RAM pico de proceso
  ≈646 MiB (p = 16); hilos ≤16. Presupuesto no agotado.
- **Carga de cada serie** (`uptime` antes/después en `logs/series.log`; la espera global de 20 min
  por carga >4 está en `logs/esperas.log`):

| serie | N | carga 1 min antes | carga 1 min después | real (s) |
|---|---:|---:|---:|---:|
| P2·T16 | 30 | 3,92 | 11,95 | 72,0 |
| P3·T16 | 30 | 3,16 | 5,07 | 82,4 |
| P4·T16 | 30 | 3,36 | 6,12 | 102,4 |
| P2·T1 | 10 | 3,71 | 2,01 | 96,0 |
| P4·T1 | 10 | 2,01 | 2,42 | 158,9 |
| P4·T4 | 10 | 2,42 | 3,02 | 58,2 |
| P4·T8 | 10 | 3,02 | 6,89 | 43,3 |
| P16·T16 | 30 | 3,76 | 11,86 | 342,0 |

  Las series a 16 hilos empezaron con carga ≤4, pero **su propia ejecución** (más la otra orden que
  compilaba en paralelo, nota del director) elevó la carga de 1 min a 5–14 durante la corrida; los
  `p99` de las series más cortas muestran esa contención (hasta 0,89 s frente a 0,31 s de mediana).
  Las **medianas** son estables y coherentes con el modelo `c·t_reg`; los `p99` deben leerse con esa
  cautela. Las series a T = 1/4/8 corrieron con carga ≤3,0.
- **Incidencia:** `entorno.sh` definía `CARGO_HOME=$PWD/.cargo-home`; al hacer `source` desde
  `prototipo/` creó un `.cargo-home` vacío allí y la primera compilación falló por resolución
  offline. Se corrigió con ruta absoluta y se borró el directorio espurio. Sin efecto en resultados.
- **Integridad:** `ENTRADA-S02a.sha256` verifica **4/4** al empezar y al cerrar. Clon de Autonomys
  intacto (`git status` vacío, HEAD `f8842d019cdf…`). `Cargo.lock` propio
  (`0dd126…`, 174 paquetes), toolchain `nightly-2026-05-03`. Binario `s02a` `5cd490a4…`.
- **Prohibiciones respetadas:** sin Python; nada escrito fuera de `deepseek/S02a/`; sin `git commit`
  ni `push`; sin secretos; ningún `Ok` ficticio.

## 11. Reproducción

```bash
cd /home/katana/zeo/ZEROX/deepseek/S02a
source entorno.sh
(cd prototipo && cargo build --offline --release --bin s02a)

RAYON_NUM_THREADS=16 ./target/release/s02a validar 4 100 0,1,2,4
RAYON_NUM_THREADS=16 ./target/release/s02a medir   4 30  0,1,2,4,8
RAYON_NUM_THREADS=1  ./target/release/s02a treg    4 3
bash resumir.sh
```

Crudos en `resultados/`: `medir-P*-T*.tsv` (1 080 aperturas), `validar-P*-T16.tsv`,
`treg-T*.tsv`, `TREG-RESUMEN.tsv`, `VALIDACION-RESUMEN.tsv`, `resumen-mediciones.tsv`. Logs y cargas
en `logs/`. Método en `METODO.md`; tiempos en `HORAS.log`; entorno en `ENTORNO.txt`.

## 12. Cierre

**Se confirma «encarece, no impide» y se mide cuánto.** Contestar una apertura R2 regenerando cuesta,
por apertura y a 16 hilos, de **0,17 s** (omitir los chunks guardando las hojas) a **4,06 s** (no
guardar nada), frente a **0,2–0,3 µs** de leerla del disco: **6·10⁵ a 1,35·10⁷ veces** más, con una
cota inferior de **`t_reg` por registro regenerado** y mal escalado en hilos. El ahorro de
almacenamiento es del **0,8 %** en el primer punto y solo crece podando profundo, donde la latencia
ya está saturada en `p · t_reg`. La auditoría sobre el formato PoAS actual **no distingue** guardado
de regenerado (RFT-04), pero para un adversario declarado **sí hace materialmente más caro** no
conservar el sector. GPU, red y modelos de retención parcial quedan abiertos para S02b.
