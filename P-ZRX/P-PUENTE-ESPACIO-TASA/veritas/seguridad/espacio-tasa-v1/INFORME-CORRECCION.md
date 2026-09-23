# INFORME DE CORRECCIÓN — espacio-tasa-v1 (revisión 1 → revisión 2)

Este documento responde al encargo de corrección. Formato: **afirmación anterior → corrección →
fuente/test**. Al final: archivos cambiados, comandos y resultados reales, cifras que permanecen
válidas, y la respuesta explícita a la pregunta sobre el umbral.

**El instrumento no se ha movido de directorio** (sus dependencias Rust usan rutas relativas).
La desviación respecto de la ubicación pedida y qué habría que ajustar para trasladarlo están en
`INFORME.md` §11.

---

## 1 · Correcciones, una por una

### C1 · Fracciones de seguridad

**Afirmación anterior.** «`α_blue_work ≤ α_bytes` porque `blue_work` suma solo azules», y
`α_blue_work = (β_adv/β_hon)·α_bytes` presentado como cuota.

**Por qué es falsa.** `(β_a/β_h)·α_bytes` no es una cuota normalizada —no divide por el total de
trabajo azul— y no está acotada por `α_bytes`. Con `β_a = 1`, `β_h = 1/2` vale `2·α_bytes`, que
puede superar 1 como «cuota». La cuota correcta es `R_adv/(R_adv+R_hon)`.

**Corrección.** Se retira la afirmación de `INFORME.md`, `CONTRATO.md`, `HIPOTESIS.md` y los tests.
Se definen por separado, con `Rational{BigInt}`:

| Concepto | Implementación |
|---|---|
| fracción de **bytes nominales solicitados** | `RepartoBytes.bytes_solicitados` / `fracciones().bytes_nominales_solicitados` |
| fracción de **bytes de sectores completos** | `fracciones().bytes_nominales_completos` |
| fracción de **piezas efectivas** | `fracciones().piezas_efectivas` |
| fracción **esperada de candidatos** | `fraccion_candidatos_esperada_esc1` (identidad del modelo; se etiqueta como tal). La `fraccion_candidatos_esperada` inicial se **retiró** por mezclar escenarios —ver §6— |
| **tasas esperadas de trabajo azul** de atacante y honestos | `puente(...).trabajo_azul` con `π_validez`, `π_admision`, `β` explícitos |
| **cuota** `R_adv/(R_adv+R_hon)` | `cuota_azul`; **si el denominador es 0 devuelve `nothing`** (la cuota no está definida: si `β=0` en ambos o no hay candidatos, no hay trabajo azul que repartir) |

Los tres factores desconocidos quedan **separados**, cada uno como fila propia `pendiente` en
`resultados/CIFRAS.tsv`: `prob_PoAS_completa_valida_pi_validez`, `prob_admision_PoST_DAG_pi_admision`
y `fraccion_azul_beta`. `β` no absorbe a los otros dos.

**Test adversarial (el pedido).** `test/runtests.jl`, conjunto «cuota azul: la afirmación
«α_blue_work ≤ α_bytes» es FALSA»:

```julia
c = ET.cuota_azul_condicional(3//10, 1//1, 1//2)
@test c == 6//13                       # exacto en Rational{BigInt}
@test isapprox(Float64(c), 0.461538, atol=1e-6)
@test c > 3//10                        # SUPERA la fracción de piezas
@test ET.cuota_azul(big(0), big(0)) === nothing   # denominador cero
```

Resultado real: `cuota_azul_condicional_ejemplo = 6/13 = 0,46153846153846156` en
`resultados/CIFRAS.tsv`. **6/13 ≈ 0,461538 > 0,3.** ✔

### C2 · Significado de `α_bytes`

**Afirmación anterior.** `alfa_tasas` calculaba `n_adv/n_tot` **después de convertir bytes a
piezas** y lo llamaba `α_bytes`; el informe presentaba `α_candidatos = α_bytes` como validación
experimental.

**Corrección.** `alfa_tasas` **se retira** de `src/modelo.jl` (con un comentario que explica por qué).
Se sustituye por `RepartoBytes` / `fracciones`, que distinguen:

* **bytes nominales solicitados** — lo que el granjero declara;
* **bytes nominales de sectores completos** — `⌊solicitados/sector_size(1000)⌋·sector_size(1000)`;
* **sobrantes** — no son piezas;
* **piezas efectivas** — `sectores_completos · 1000`;
* **bytes realmente materializados** — `RepartoBytes.bytes_materializados`.

`f_candidatos = f_piezas_efectivas` se documenta como **identidad algebraica del modelo** (con el
mismo `SR`, `p` y `o` se cancelan), **no** como validación. El informe añade que **no** demuestra
almacenamiento físico, ni preexistencia, ni que se sostenga por slot, ni que valga con `SR`
distintos.

**Test del caso con sobrantes** (`test/runtests.jl`, «reparto de bytes: sobrantes que no completan
un sector»): con `2·ss + ss/2` bytes → 2 sectores, 2000 piezas, `ss/2` sobrantes; con **1 byte** → 0
sectores, 0 piezas; y `fracciones` da `f_bytes_solicitados ≠ f_piezas_efectivas`.

**Evidencia real** (`resultados/TABLA-PUENTE.md`): adversario que pide el **1 % de 1 TiB** →
`f_bytes_solicitados = 0,010000000000` pero `f_bytes_nominales_completos = f_piezas_efectivas =
0,009615384615`, con **426 155 637 B sobrantes**.

### C3 · Alcance del oráculo

**Afirmación anterior.** «Un sector real de 1000 piezas»; `pruebas_completas_validas = 1`.

**Corrección de rótulos.**
`resultados/bits-meta.tsv` y `INFORME.md` §0 declaran ahora, explícitamente:

* las **tablas PoS**, la **codificación de borrado** y los **hashes** son reales;
* los **bytes del registro fuente son SINTÉTICOS** (generados con `blake3` desde la semilla de
  evaluación, no historia archivada de ZEROX);
* los bytes materializados son **8 192 000 B** (`bitmaps.bin`); **no** se escribió un sector físico
  de ~1 GiB;
* la verificación hecha es la **prueba PoS** (`is_proof_valid`), que **no** equivale a
  `verify_solution` (compromiso, testigo KZG, firma, cabecera, PoT, admisión DAG).

La clave `pruebas_completas_validas` se renombra a **`pruebas_pos_validas`** en
`oraculo-rust/src/bin/puente.rs` y en `src/validacion.jl` (`eq_prueba_pos`), y el test comprueba que
la clave antigua **ya no existe**.

**Etapa pendiente con bloqueo reproducible.** Verificar una solución exige `verify_solution` con el
compromiso de registro y el testigo KZG de una pieza de **historia archivada real**; el clon no trae
historia y generarla excede el presupuesto (P-INTENTO: ~90 s por sector solo para plotear, más
`Kzg::create_witness` ≈ 19 ms por candidato). Además `zx-node` no ejecuta la ruta PoST + DAG, así que
no hay contexto contra el que verificar. Entrada mínima: `candidatos = 1`, `bucket = 26859` en
`resultados/prueba.tsv`. Se deja **`pendiente`**, no simulada.

### C4 · Inferencia estadística

**Afirmación anterior.** «`0,2634` observado frente a `0,2933` independiente: **−2,5 σ**», y el
cociente **2,0028×** presentado como medición.

**Por qué estaba mal.** Los 2 016 pares se forman con **64 retos únicos**; cada reto aparece en 63
pares. No son observaciones independientes, así que cualquier σ que lo presuponga es inválida.
Y 2,0028 era el cociente de **una sola** asignación asimétrica de las mitades.

**Corrección.**

1. El veredicto «−2,5 σ» **se retira** de informe e hipótesis.
2. La incertidumbre se recalcula con un **bootstrap de bloques sobre los 64 retos**
   (`ET.bootstrap_unidades`), que respeta la estructura de dependencia. Resultados reales
   (`resultados/FLUJOS.tsv`, `SR` calibrado):

   | Magnitud | Medido | IC95 bootstrap | Referencia de independencia |
   |---|---:|---|---:|
   | Piezas auditadas por ambos retos | 275,81 | [232,50 ; 322,01] | 276,49 |
   | `Pr(≥1 ganador)` | 0,26339 | [0,1238 ; 0,3953] | 0,29330 |

   Las referencias **caen dentro** de los intervalos: no hay discrepancia sostenible.
3. **La correlación poblacional es exactamente 0** por intercambiabilidad de los retos (dos retos
   son dos extracciones uniformes independientes); los `−0,011` son ruido de muestra.
4. **Identidad algebraica, con un caso degenerado.** Con `s = s_a + s_b`,
   `asignación1 = s_a[b_i]+s_b[b_j]`, `asignación2 = s_a[b_j]+s_b[b_i]`, se cumple
   **`promedio = compartido/2` para TODO par**, incluido el degenerado. El **cociente**
   `compartido/promedio` vale 2 cuando `compartido > 0` y está **INDEFINIDO** (`0/0`) cuando los dos
   buckets están vacíos: en los 64 retos publicados hay 5 con `leidos = 0`, así que **10 de los 2016
   pares** son degenerados. Decir «la razón es 2 para todo par» era **falso** y así lo refutó la
   revisión independiente. Implementado en `ET.reparto_exclusivo` (que devuelve `razon = nothing` en
   el caso `0/0`) y fijado en tests, incluido el caso vacío. Se publican
   `reparto_exclusivo_promedio_igual_mitad`, `reparto_exclusivo_razon_medias = 2.0000000000`,
   `reparto_exclusivo_pares_degenerados = 10` y `reparto_exclusivo_razon_una_asignacion = 2.002843`.
5. **Las dos varianzas, separadas** (`resultados/TABLA-VARIANZA.md`):

   | Población | n | Media | Varianza | Denominador | Cociente |
   |---|---:|---:|---:|---|---:|
   | Los 65 536 buckets del sector (población completa) | 65 536 | 500,000000 | 40 792,2309 | `M/4 = 250` | **163,1689** |
   | Los 512 retos (muestra) | 512 | 516,6602 | 34 108,2209 | `M/4 = 250` | **136,4329** |
   | Los 512 retos (muestra) | 512 | 516,6602 | 34 108,2209 | la **media** (índice de Poisson) | **66,0167** |

   Poblaciones y denominadores distintos: **no son intercambiables**. El `66×` de la revisión 1
   mezclaba el denominador de Poisson con el binomial.
6. **Extrapolación a varios sectores**: la tabla de escala queda marcada `derivado` **bajo la
   hipótesis de independencia entre sectores, que NO se ha medido**; solo `S = 1` es `medido`.
7. El factor 2 **no** se presenta como pérdida de seguridad de ZEROX: mide **oportunidad**, no
   legalidad ni umbral.

### C5 · Errores verificables del informe

**C5.a · Fila de 1 EiB.** La revisión 1 publicaba `sectores = 1 090 889`, `piezas_adv = 109 088 910`,
`SR = 5 638 863`. El valor real de `PUENTE.tsv` era `sectores = 1 090 889 116`,
`piezas_adv (α=0,1) = 109 088 911 600`, `SR = 5 636 608` — errores de transcripción manual de hasta
un factor 10³. **Corrección:** la tabla se **genera** desde los datos (`resultados/TABLA-PUENTE.md`)
y el informe la cita; no se teclea. Además, con la corrección de C5.b los valores cambian otra vez:
`1 EiB → 1 090 856 086 sectores`, `109 085 608 000 piezas del adversario`, `SR = 5 636 779`.

**C5.b · Diferencia nominal.** La revisión 1 decía «8 224 B por sector más que `piezas·Piece::SIZE`»
y usaba `sector_size(1000) = 1 056 864 064`. Con **sus propias cifras publicadas**
(1 056 864 064 − 1 048 672 000) la diferencia es **8 192 064**, luego el «8 224» ya estaba mal.
Pero además el `sector_size` publicado estaba mal: `RecordMetadata::encoded_size()` es
**48 + 48 + 32 = 128** (`sector.rs:139-152`, incluye `piece_checksum`), no 96. Valores correctos:

```
sector_size(1000)        = 1 056 896 064 B
1000 · Piece::SIZE       = 1 048 672 000 B
diferencia               =     8 224 064 B  = 1000·32 + 1000·8192 + 64
```

**Qué metadatos entran y cuáles no.** Dentro de `sector_size()`: chunks de s-bucket, `commitment` +
`witness` + `piece_checksum` por registro, mapa de contenidos (1000·8192 + 32) y checksum de sector
(32). **Fuera**: `SectorMetadataChecksummed::encoded_size()` = **131 116 B** por sector
(`sector_index` 2 + `pieces_in_sector` 2 + `s_bucket_sizes` 65 536·u16 = 131 072 + `history_size` 8 +
checksum 32), que el granjero guarda aparte.

**Fuente:** `oraculo-rust ... constantes`, que **lee los tamaños de la API del clon**
(`sector_size`, `sector_record_metadata_size`, `SectorContentsMap::encoded_size`,
`SectorMetadataChecksummed::encoded_size`) en vez de recomponerlos a mano →
`resultados/constantes.tsv`. Test en `runtests.jl` que contrasta el modelo con ese fichero.

**C5.c · Cota de cola invertida.** La revisión 1 etiquetaba `1−0,05^{1/512} = 5,83·10⁻³` como «cota
superior exacta de `P(0 candidatos)`». Es una cota superior de **`P(≥1 candidato por slot)`**; de
ella se sigue `P(0 candidatos) ≥ 1 − 5,83·10⁻³ = 0,99417`. Corregido el rótulo en el informe y
añadida la columna `cota_sup_P_al_menos_uno_candidato` en `resultados/CANDIDATOS.tsv`.

### C6 · Comprobación de integridad

**Afirmación anterior.** `HUELLAS.sha256` permitía verificar el instrumento.

**Defecto.** El manifiesto se generaba con un `find` que incluía `*.sha256`, de modo que contenía
**su propia huella**; `sha256sum -c HUELLAS.sha256` fallaba siempre en `./HUELLAS.sha256` y salía 1.

**Corrección.** El manifiesto **excluye su propio fichero**; `verificar-huellas.sh` comprueba
explícitamente que no haya una línea de huella apuntando a él, verifica los dos manifiestos
(`ENTRADA.sha256` desde la raíz de ZEROX, `HUELLAS.sha256` desde el instrumento), comprueba el
commit y la limpieza del clon, y **termina con código de salida 0**.

**Demostración real** (`resultados/VERIFICACION-HUELLAS.txt`):

```
$ bash verificar-huellas.sh ; echo "EXIT=$?"
...
== 2. Huellas del INSTRUMENTO (desde el propio directorio) ==
   (sin autorreferencia: ninguna línea de huella apunta a HUELLAS.sha256)
   61 huellas verificadas
== 3. Fuente fijada de Autonomys ==
   commit OK: f8842d019cdf0f7163421b9644db5a9ff82b2a73
   árbol limpio
   huellas de las fuentes usadas OK
== 4. Árbol de ZEROX fuera del instrumento ==
   ningún fichero VERSIONADO cambió (20 entradas M/D/R/A idénticas)
RESULTADO: TODO VERIFICADO
EXIT=0
```

**Autorreferencia de segundo orden, encontrada al verificar la corrección.** El **informe de la
propia verificación** (`resultados/VERIFICACION-HUELLAS.txt`) también estaba en el manifiesto, y el
script lo reescribe al terminar: la huella quedaba obsoleta en la misma ejecución, así que la
verificación seguía saliendo 1. Es el mismo defecto de clase que (a) —un fichero que *informa
sobre* el manifiesto no puede formar parte de él—. Se excluye también, y el script comprueba
**ambas** exclusiones de forma explícita. Resultado: **EXIT=0**, e idempotente (dos pasadas
seguidas dan 0).

**No se alteró ningún dato para cuadrar huellas.** Prueba de que el mecanismo funciona: al editar
`verificar-huellas.sh` *después* de generar el manifiesto, la verificación detectó el cambio
(`./verificar-huellas.sh: La suma no coincide`) y solo volvió a 0 al **regenerar** el manifiesto; y
al escribir el informe de verificación después de comprobar, la segunda pasada también da 0 sin
tocar ningún dato.

### C7 · Defecto de la ruta serial: alcance del enunciado

**Afirmación anterior.** «Es el **mismo defecto** que P-INTENTO §13 documentó como SIGSEGV
reproducible para ciertas semillas.»

**Corrección del enunciado.** Se mantiene como **defecto reproducido** —`create_proofs` serial aborta
con `malloc(): corrupted top size` a partir de ~64 piezas— pero **no se afirma que tenga la misma
causa raíz** que el SIGSEGV de P-INTENTO: son síntomas distintos (corrupción de montón frente a
violación de segmento), en binarios y perfiles distintos, y P-INTENTO declaró la causa raíz
**«no determinada»** (sin `gdb` ni sanitizers). La coincidencia relevante y **sí** comprobada es la
**mitigación**: la ruta paralela, que es la del plotter honesto, no falla y produce bitmaps **byte a
byte idénticos** (`sha256 66fcaf890a80…`) en el rango donde la serial no falla.

---

## 2 · Archivos cambiados

**Modificados**

| Archivo | Cambio |
|---|---|
| `src/modelo.jl` | `alfa_tasas` retirada; `puente` con `π_validez`/`π_admision`/`β` explícitos; nuevos `rendimiento_limite_adversario`, `RepartoBytes`, `reparto_bytes`, `fracciones`, `cuota_azul`, `cuota_azul_condicional`, `bootstrap_unidades`, `percentiles`, `reparto_exclusivo` |
| `src/referencia.jl` | `PIEZA_CHECKSUM_SIZE`; `sector_size` corregido a 128 B por registro; `metadata_fuera_del_sector` |
| `src/validacion.jl` | `eq_prueba_completa` → `eq_prueba_pos`, con alcance declarado |
| `src/datos.jl` | `leer_constantes` |
| `test/runtests.jl` | tests de bytes corregidos; nuevos: sobrantes, cuota azul adversarial, identidad exacta 2, constantes contra la API; `−2,5 σ` eliminado |
| `run.jl` | `paso_puente` con las cinco fracciones; `paso_flujos` con bootstrap por retos y razón exacta; `paso_varianza`; `paso_candidatos` con la cota bien etiquetada; tablas markdown generadas |
| `oraculo-rust/src/bin/puente.rs` | subcomando `constantes`; claves `pruebas_pos_validas`/`pruebas_pos_corruptas_aceptadas`; docstring de alcance |
| `oraculo-rust/Cargo.toml` | dependencia `subspace-farmer-components` (para leer los tamaños de la API) |
| `INFORME.md` | **reescrito** (revisión 2) |
| `CONTRATO.md` | afirmaciones retiradas; nuevas filas de límites |
| `HIPOTESIS.md` | H6/H8/H9 corregidas; nuevas H12–H14 |
| `METODO.md` | comando `constantes`; §5 de integridad; defectos D-c1…D-c12 |
| `HUELLAS.sha256` | regenerado sin autorreferencia |

**Nuevos**

`INFORME-CORRECCION.md` (este documento), `verificar-huellas.sh`,
`resultados/constantes.tsv`, `resultados/TABLA-PUENTE.md`, `resultados/TABLA-CANDIDATOS.md`,
`resultados/TABLA-VARIANZA.md`, `resultados/VERIFICACION-HUELLAS.txt`.

**No modificados:** `SPEC.md`, `TAREAS.md`, `crates/`, `PDF/`, el resto de `P-ZRX/`, otros
instrumentos de `veritas/`, y el clon de Autonomys (que quedó limpio).

---

## 3 · Comandos y resultados reales

```bash
cd P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1
export JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia"
J=/home/katana/zeo/ZEROX/veritas/julia.sh

# Rust: recompilar con el subcomando nuevo
(cd oraculo-rust && CARGO_TARGET_DIR="$PWD/target" CARGO_NET_OFFLINE=true cargo build --release)
./oraculo-rust/target/release/puente constantes --out resultados
./oraculo-rust/target/release/puente prueba     --out resultados

# Julia
JULIA_NUM_THREADS=1 $J --check-bounds=yes --project=. test/runtests.jl
JULIA_NUM_THREADS=1 $J --project=. run.jl --piezas 1000 --retos 512

# Integridad
bash verificar-huellas.sh ; echo "EXIT=$?"
```

**Resultados reales**

| Comando | Resultado |
|---|---|
| `puente constantes` | `sector_size(1000)=1056896064  1000*Piece::SIZE=1048672000  diferencia=8224064`; `sector_record_metadata_size_1000=128000`; `sector_metadata_checksummed_size=131116` |
| `puente prueba` | `1 candidatos en 1 pieza (SR=u64::MAX), 1 pruebas validas, 0 corruptas aceptadas` |
| `test/runtests.jl` | **41 816 / 41 816, 0 fallos** en los dos perfiles (`--check-bounds=yes` 1 hilo; sin límites 4 hilos) |
| `run.jl` (ronda 4) | esc. 1: `1 TiB a=1//100 esc1: 10+1029=1039 sectores cuota=10//1039`; esc. 2: `1040 sectores (resto 1)`; y N=1041 → `sectores esc1=0 sin_sector=1041` |
| `run.jl` | fracciones separadas; `razon EXACTA compartir/repartir=2.0000000000`; `comunes=275.81 IC95=[232.50,322.01]`; `P(>=1)=0.26339 IC95=[0.1238,0.3953]` |
| `verificar-huellas.sh` | `RESULTADO: TODO VERIFICADO`, **EXIT=0** |
| `git status --short` (inicio vs fin) | **NO idénticos**: aparecieron `?? P-ZRX/P-RIVAL/` y `?? P-ZRX/P-SELLO/` (ajenos, no atribuidos). Invariante comprobado: **ningún fichero versionado cambió** |
| clon Autonomys | commit `f8842d0…`, **árbol limpio** |

---

## 4 · Cifras que permanecen válidas

Confirmadas por la revisión y conservadas:

| Cifra | Valor | Estado |
|---|---|---|
| Ocupación observada del conjunto de 1000 piezas ensayado | media **500,000000** chunks/bucket; var **40 792,2309**; 5 942 buckets vacíos (9,0668 %); mín 0, mediana 584, máx 658 | `medido` |
| Media derivada de chunks auditados por bucket | `piezas/2 = 500` **exacta** | `derivado` |
| Pruebas por pieza | **32 768** en las 1000 piezas (mín = máx) | `medido` |
| Chunks auditados/slot con los 512 retos | media 516,660; mín 0; máx 629; 38/512 con cero | `medido` |
| Coincidencia Julia ↔ Rust | **512/512** retos | `medido` |
| Conteos de candidatos por `SR` | `p = 1/3000 → 0,154297`; `1/128 → 4,033203`; `1/8 → 64,826172`; `1/2 → 258,267578`; `1 → 516,660156` | `medido` |
| `E[candidatos] = P·A(SR)/2^64` | ratios 0,8959 … 1,0038 | `medido` |
| Cardinalidad y predicado | `A(SR)=2⌊SR/2⌋+1`, `d ≤ ⌊SR/2⌋`, LE, verificado | `derivado` |
| Cancelación del `SR` con residuo de paridad | exacta en `BigInt` | `derivado` |
| Ocupación desigual por bucket | **163,1689×** sobre los 65 536 buckets (población completa) | `medido` |
| `sector_size(1000)` y desglose | 1 056 896 064 B; +8 224 064 vs `1000·Piece::SIZE`; 131 116 B de metadata fuera | `derivado`, contrastado con la API |
| Rendimiento del kernel | 22,81× sobre el oráculo lento, 0 asignaciones; escalado 1→24 medido | `medido` |
| Reparto esc. 1 (1 TiB, `α = 1/100`) | `10 + 1029 = 1039` sectores; cuota **10/1039**; `SR` sobre `Σ piezas = 1 039 000` | `derivado` (test exacto) |
| Propiedad de agregación | `Σ⌊bytes_i/s⌋ ≤ ⌊(Σbytes_i)/s⌋`; con `N = 1041` el espacio efectivo es **0** | `derivado` (test + `TABLA-IDENTIDADES.md`) |
| Metadata externa al plot | 131 116 B por sector, **fuera** de `sector_size()` | `derivado`, contrastado con la API |

**Retiradas o degradadas:** `α_blue_work ≤ α_bytes` (falsa), `α_candidatos = α_bytes` como
validación (identidad del modelo), el «−2,5 σ» (diseño inválido), 2,0028× como medición (artefacto;
lo correcto es la identidad 2), `sector_size = 1 056 864 064` (faltaba el `piece_checksum`), la
fórmula `(β_adv/β_hon)·α_bytes` como cuota, y el rótulo «pruebas completas válidas».

---

## 5 · Revisión independiente y su efecto

Se encargó una **revisión independiente** (agente separado, solo lectura, sin acceso a este
razonamiento) sobre 8 afirmaciones concretas, con instrucción de refutarlas. Resultado y efecto:

| # | Afirmación sometida | Veredicto del revisor | Efecto en el instrumento |
|---|---|---|---|
| A1 | cuota azul condicional `6/13 > 0,3` | **VERIFICADA** | ninguna |
| A2 | `promedio = compartido/2` y «cociente = 2 para todo par» | **PARCIAL**: la identidad sí; «=2 para todo par» **REFUTADA** | **Corregido.** `reparto_exclusivo` devolvía `Inf` en el caso `0/0` y el docstring afirmaba universalidad. Ahora `razon` es `nothing` si el denominador es 0, el docstring enuncia la identidad correcta (`promedio = compartido/2` para todo par; cociente 2 solo si `compartido > 0`), y se publica `compartir_vs_repartir_pares_degenerados = 10` de 2016. Tests nuevos para el caso degenerado. |
| A3 | contabilidad de bytes | **VERIFICADA**, con **errata** | **Corregido.** La nota de `constantes.tsv` sumaba `1000·8192 + 32 + 32 = 8 192 064` y omitía el término `1000·32`; ahora dice el desglose completo. Cita del mapa corregida a `sector.rs:362-364`. |
| A4 | fracciones separadas | **VERIFICADA**, con matiz | **Corregido.** `f_bytes_solicitados` es `0,009999999999` (truncamiento a bytes enteros), no `0,01`; el informe ya no redondea. |
| A5 | identidad del modelo | **VERIFICADA** | ninguna |
| A6 | diseño estadístico | **VERIFICADA**, con matiz | **Corregido.** `audita-pares.tsv` tenía **2 016 líneas en blanco** intercaladas (un `
` de más por par). Eliminadas; el fichero pasa de 10 081 a 8 065 líneas (1 cabecera + 8 064 datos). |
| A7 | varianzas con poblaciones distintas | **VERIFICADA**, con matiz | **Corregido.** La tabla usaba la varianza **muestral** `/(n−1)` etiquetándola «población completa». Ahora publica **las dos** convenciones (163,1689 y 163,1664) y el número de buckets distintos que cubre la muestra (510 de 512 retos). |
| A8 | cota con cero observado | **VERIFICADA**, con matices | **Corregido.** Se distingue la cota **unilateral** (5,83·10⁻³) de la **bilateral** (7,18·10⁻³), y se precisa que `P(0 por slot) ≥ 0,99417` es **por slot**, no la conjunta de los 512 slots (esa sería `≥ 0,05`). |

**Dato relevante del proceso:** la única afirmación sustantiva que cayó (A2) la detectó el revisor
con el mismo dato que el instrumento ya publicaba —los 10 pares con ambos buckets vacíos estaban en
`audita-pares.tsv`—. Refuerza el criterio del `CONTRATO.md` §3: una afirmación universal («para todo
par») exige un test que recorra **todos** los casos, incluidos los degenerados, no una muestra.

## 6 · Ronda 4 — separación de los dos escenarios de reparto

**Afirmación anterior.** `paso_puente` calculaba `⌊bytes_adv/s⌋` y lo comparaba con los sectores del
**total** ya truncado (`⌊bytes_totales/s⌋ = 1040`), y presentaba el porcentaje de bytes solicitado
como presupuesto físico del actor. Eso mezcla dos situaciones que no son la misma: da a cada actor el
beneficio de los sobrantes del conjunto.

**Corrección.** Se separan, con nombre, dos escenarios:

| | Escenario 1 (principal) | Escenario 2 |
|---|---|---|
| Qué es | presupuestos **independientes** | sectores ya ploteados y **repartidos** |
| Truncamiento | `sectores_i = ⌊bytes_i/s⌋`, **por actor** | `S = ⌊bytes_totales/s⌋`, **una vez** |
| Denominador | `Σ piezas_i = (Σ sectores_i)·1000` | `S·1000` |
| Sobrantes | de cada actor y **se pierden** | el resto no asignado **no se regala** |
| ¿La cuota de bytes es presupuesto físico? | **sí** | **no** (se etiqueta `condicionado`) |

**Test exacto pedido (1 TiB, adversario al 1 %).** Con `s = sector_size(1000) = 1 056 896 064`:

```
⌊10 995 116 277 / 1 056 896 064⌋ = 10
⌊ 1 088 516 511 499 / 1 056 896 064⌋ = 1029
10 + 1029 = 1039 sectores      cuota esperada = 10/1039
```

Está en `test/runtests.jl` («escenario 1: presupuestos independientes (1 TiB y 1 %)») y se comprueba
además que **no** es `10/1040`. El `SR` experimental se recalibra sobre `Σ piezas = 1 039 000`:
`5 918 108 461 247`, frente a `5 912 417 972 342` con 1 040 000.

**Propiedad general.** `Σ⌊bytes_i/s⌋ ≤ ⌊(Σbytes_i)/s⌋`, con test aleatorio de 200 casos y dos casos
límite exactos (múltiplos de `s` → pérdida 0; trozos diminutos → pérdida = total agregado).

**Efecto al aumentar el número de identidades** (`resultados/TABLA-IDENTIDADES.md`). El reparto
**conserva todos los bytes** (`reparto_igual_exacto` reparte también `T mod N`, luego `Σbytes_i = T`) y
el escenario agregado se calcula **directamente desde `T`**, nunca desde `N·⌊T/N⌋`.

**La pérdida NO es monótona en `N`**: con 1 TiB, `N = 7` pierde 4 sectores y `N = 10` pierde **0**. Lo
único afirmable es `Σ⌊bytes_i/s⌋ ≤ ⌊T/s⌋` y la cota `perdidos ≤ N`.

**La conclusión general «1041 identidades ⇒ cero espacio efectivo» queda RETIRADA.** Las columnas
«hip. 1000» suponen `piezas_por_sector = 1000`, que es el **máximo** `MAX_PIECES_IN_SECTOR`, no una
exigencia del formato: `SectorMetadata.pieces_in_sector` es un campo `u16` y un sector puede tener
**menos** piezas. El contraejemplo lo cierra: con `N = 1041` el presupuesto por identidad es
1 056 207 136 B, que no admite un sector de 1000 piezas pero **sí** uno de 999
(`sector_size(999) = 1 055 839 168 B`), incluso sumando los 131 116 B de metadata externa
(`1 055 970 284 ≤ 1 056 207 136`). Con `N = 2000` cabe un sector de 520 piezas.

| `N` | Bytes por identidad | `Σbytes_i = T` | Sectores esc. 1 (hip. 1000) | Sectores esc. 2 (desde `T`) | Perdidos | `perdidos ≤ N` | Sin sector (hip. 1000) | `piezas_max_que_caben` | ¿Cabe algún sector? |
|---:|---:|:---:|---:|---:|---:|:---:|---:|---:|:---:|
| 1 | 1 099 511 627 776 | sí | 1040 | 1040 | 0 | sí | 0 | 1000 | sí |
| 7 | 157 073 089 683 | sí | 1036 | 1040 | 4 | sí | 0 | 1000 | sí |
| 10 | 109 951 162 778 | sí | 1040 | 1040 | **0** | sí | 0 | 1000 | sí |
| 100 | 10 995 116 278 | sí | 1000 | 1040 | 40 | sí | 0 | 1000 | sí |
| 1040 | 1 057 222 720 | sí | 1040 | 1040 | 0 | sí | 0 | 1000 | sí |
| 1041 | 1 056 207 136 | sí | 0 | 1040 | 1040 | sí | 1041 | **999** | **sí** |
| 2000 | 549 755 814 | sí | 0 | 1040 | 1040 | sí | 2000 | **520** | **sí** |

**Test pedido.** Con `T = sector_size(1000)` y `N = 5`: `Σbytes_i = T` exacto (el reparto naïve
`N·⌊T/N⌋` perdería 4 B) y el **agregado contiene 1 sector**, calculado desde `T`; las cinco partes
por separado, bajo la hipótesis de 1000 piezas, dan 0.

**Función heredada retirada.** `fraccion_candidatos_esperada(ra, rt; SR)` mezclaba un presupuesto
independiente (el del adversario, truncado por su cuenta) con los sectores **agregados** del total, y
derivaba el lado honesto por **resta**. Para el mismo `α` daba `10/1040` donde el escenario 1 da
`10/1039`. Se **retira** —no se delimita, porque su firma invita al error— y se sustituye por
`cuota_piezas_escenario1` y `fraccion_candidatos_esperada_esc1`, que usan **solo** presupuestos
independientes. Un test comprueba que ya no existe.

**Bytes físicos: plot frente a metadata externa.** `sector_size(1000) = 1 056 896 064 B` es el
tamaño del **fichero de la parcela**. La metadata `SectorMetadataChecksummed::encoded_size()` =
**131 116 B** (`sector_index` 2 + `pieces_in_sector` 2 + `s_bucket_sizes` 65 536·u16 = 131 072 +
`history_size` 8 + checksum 32) es **fija, externa y no está en el plot**. Al hablar de bytes físicos
hay que decir cuál se cuenta; hay un test que fija que son magnitudes distintas.

**Contradicciones limpiadas en esta ronda:**

| Ubicación | Antes | Ahora |
|---|---|---|
| `PROCEDENCIA.md:52` | `piezas·96`, cita `sector.rs:367-380` | `piezas·128` (con `piece_checksum`), citas `:139-152` y `:362-364` |
| `METODO.md` D1 | «Es el mismo defecto que P-INTENTO §13 documentó como SIGSEGV» | defecto **reproducido**; causa raíz **no demostrada**; solo se comprueba que la **mitigación** coincide |
| `INFORME-CORRECCION.md` A2 | «la razón es 2 exactamente, par a par» | identidad `promedio = compartido/2` para todo par; cociente 2 si `compartido > 0`, **indefinido** en los 10 pares degenerados |
| `INFORME.md` integridad | «`GIT-ENTRADA.txt` y `GIT-SALIDA.txt` son **idénticos**» | **no** lo son: aparecieron `?? P-ZRX/P-RIVAL/` y `?? P-ZRX/P-SELLO/`. Son ajenos y **no se atribuyen** sin evidencia. Lo que se comprueba automáticamente es que **ningún fichero versionado** cambió |

## 7 · Ronda 5 — tabla de identidades: hipótesis, conservación de bytes y alcance

Solo se toca la tabla de identidades y su interpretación. **No se repite la auditoría PoS** (los
artefactos `bitmaps.bin`, `audita-*.tsv`, `vectores*.tsv` y `retos.tsv` no se regeneran) y no se toca
el SPEC.

**Qué resultados cambiaron:**

| Resultado | Antes (ronda 4) | Ahora (ronda 5) | Motivo |
|---|---|---|---|
| Hipótesis de truncamiento | implícita | **etiquetada** en código, `IDENTIDADES.tsv`, `TABLA-IDENTIDADES.md` e informe: `piezas_por_sector = 1000` es el **máximo**, no una exigencia del formato | `SectorMetadata.pieces_in_sector` es un `u16` |
| «`N = 1041` ⇒ cero espacio efectivo» | conclusión **general** | **retirada**; queda como enunciado **condicionado** a la hipótesis de 1000 piezas | contraejemplo `sector_size(999) = 1 055 839 168 B` cabe en 1 056 207 136 B |
| Conservación de bytes al repartir `T` | `N·⌊T/N⌋ < T`: se perdían `T mod N` bytes antes de calcular el agregado | `Σbytes_i = T` **exacto** (`reparto_igual_exacto`) | defecto propio detectado por el test pedido |
| Agregado del escenario 2 | se calculaba sobre las partes truncadas | **directamente desde `T`** | idem |
| `T = sector_size(1000)`, `N = 5` | agregado 0 sectores | agregado **1 sector** | `⌊T/s⌋ = 1`; antes las 5 partes truncadas daban 0 y el total se perdía |
| «La pérdida crece con `N`» | afirmado | **retirado**: no es monótona (`N=7` → 4, `N=10` → 0); se publica la cota `perdidos ≤ N` | contraejemplo en la propia tabla |
| `bytes_por_identidad` con `N = 1041` | 1 056 207 135 | **1 056 207 136** | ahora se reparte el resto (241 identidades reciben +1 B) |
| `fraccion_candidatos_esperada` | presente, mezclaba escenarios | **retirada**; sustituida por `cuota_piezas_escenario1` y `fraccion_candidatos_esperada_esc1` | evitaba que se repitiera el error de mezclar |
| Nº de comprobaciones | 41 750 | **41 816** | tests nuevos de conservación, hipótesis, contraejemplo, no-monotonía y cota |

**Lo que NO cambió:** el escenario 1 con 1 TiB y `α = 1/100` sigue dando `10 + 1029 = 1039` sectores
y cuota `10/1039`; el `SR` calibrado sigue siendo `5 918 108 461 247` sobre `Σ piezas = 1 039 000`; y
el escenario 2 sigue dando 1040 sectores del total. La sección §6 recoge ahora la redacción
corregida de la tabla.

**Veredicto, sin cambios:** el puente está **medido hasta candidatos PoS** bajo el escenario
ensayado; **no hay cifra validada de `blue_work`** (faltan `π_validez`, `π_admision` y `β`) **ni de la
caída del umbral por doble farmeo**.

## 8 · ¿Podemos ya cuantificar la caída del umbral de seguridad de ZEROX por doble farmeo?

# No.

Faltan, como mínimo, cinco piezas y **ninguna** está medida:

1. **Verificación completa** (`π_validez`). `verify_solution` — compromiso de registro, testigo KZG,
   firma, cabecera — **no la ejecuta ninguna ruta de ZEROX** y aquí solo se verificó la **prueba
   PoS** de **un** candidato. Sin ella no se sabe cuántos candidatos llegan a ser soluciones.
2. **Admisión PoST + DAG** (`π_admision`). No implementada. `AlmacGhostdag::admitir` es una puerta
   **parcial** de rango, no validación PoST completa, y `zx-node` sigue con cabecera lineal.
3. **Comportamiento del DAG y tasas azules** (`β`). `blue_work` suma **solo azules** (`SPEC.md`
   C-GD-08); `β` depende de GHOSTDAG y del retarget. Sin `β` no hay tasa de trabajo azul, y sin tasa
   de trabajo azul no hay umbral que comparar.
4. **Controlador de rango y reglas de flujo** (`C-HDR-06`, `C-FLU-13`, `C-FLU-14`). Sin ellas no se
   sabe si dos retos sobre la misma parcela son siquiera **admisibles**: el instrumento mide
   **oportunidad**, no legalidad, y tampoco mide el coste del adversario que regenera piezas tras
   conocer el reto.
5. **Una magnitud de comparación con datos.** Lo que el instrumento aporta es `R_i ∝ β_i·W_i` y la
   fórmula de la cuota `R_adv/(R_adv+R_hon)` con los factores `π_validez`, `π_admision` y `β`
   **`pendiente`**. La cuota, por tanto, **no se puede evaluar**.

Lo que sí puede decirse, y está corregido y comprobado: la cuota azul del adversario **no está
acotada por su fracción de bytes** (con `f = 0,3`, `β_a = 1`, `β_h = 1/2` es **6/13 ≈ 0,4615**), y
el puente bytes → candidatos **sí** está medido, con sus medias exactas y su dispersión. Eso
**acota** el problema y **elimina una cota falsa**; no lo cuantifica.

**No se traslada ninguna conclusión al SPEC.**
