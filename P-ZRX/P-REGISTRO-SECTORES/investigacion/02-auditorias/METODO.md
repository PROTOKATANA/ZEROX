# METODO — S02a

**Objetivo.** Ejecutar `ORDEN-S02a.md` (primera parte de `ENCARGO-02-AUDITORIAS.md`) en la zona
aislada `deepseek/S02a/`: medir **cuánto** encarece contestar una auditoría R2 sin conservar el
sector, con regeneración real (no simulada) sobre el formato PoAS actual.

**Pregunta falsable.** Para el formato PoAS con compromiso R2 (S01), el coste de contestar una
apertura sin guardar el sector crece con los datos omitidos y tiene una cota inferior de latencia de
`t_reg` por registro regenerado. Se refuta si una estrategia sin chunks contesta en un tiempo
indistinguible del de leerlos de disco.

## 1. Entradas leídas íntegras antes de escribir código

`ORDEN-S02a.md`; `V-ZRX/LINEO.md`; `ENCARGO-02-AUDITORIAS.md`; `ANALISIS.md` §§4–5;
`D-ZRX/RFT-ZRX.md` (RFT-03, RFT-04, RFT-06); S01 en
`P-ZRX/P-REGISTRO-SECTORES/investigacion/01-formato-alta/` (`INFORME.md`, `ESPECIFICACION-BYTES.md`,
`REVISION.md`, `METODO.md`, `prototipo/`); histórico en `/home/katana/zeo/.trash/zerox/`
(`P-ZRX/P-INTENTO/investigacion/INFORME.md`, `research/coste-ploteo-medido.md`). Entrada congelada
`ENTRADA-S02a.sha256` verificada al empezar y al cerrar: 4/4.

## 2. Base y aislamiento

- Copia del `prototipo/` de S01 en `prototipo/` (no se modifica el de `P-ZRX`); clon de Autonomys
  `f8842d0` y caché de cargo copiados de `deepseek/S01/`.
- `CARGO_HOME` y `CARGO_TARGET_DIR` dentro de la zona; perfil `--release`; sin Python; sin commit ni
  push; nada fuera de `deepseek/S02a/`.
- Módulos nuevos: `src/regeneracion.rs` (tabla PoS + erasure coding + enmascarado),
  `src/estrategias.rs` (estrategias y aperturas), `src/bin/s02a.rs` (driver de medición). Accesores
  mínimos añadidos a `sector.rs` y `merkle.rs`.

## 3. Definiciones y decisiones declaradas

1. **E-árbol(L)**: se conservan exactamente los `2^(profundidad−L)` nodos del nivel `L` (nivel 0 =
   hojas); la apertura regenera el bloque alineado de `2^L` hojas y recompone los niveles superiores
   desde el nivel `L` (coste `2^(profundidad−L)−1` hashes, **incluido** en la latencia medida).
2. **E-disco**: conserva el fichero de sector y una caché del árbol Merkle; la apertura lee el chunk
   almacenado y recompona el camino en `O(profundidad)` hashes. El tamaño de la caché del árbol se
   informa aparte; el «almacenamiento conservado» cuenta el fichero de sector.
3. **E-nada** ≡ `E-árbol(profundidad)`: conserva la raíz (32 B) más metadatos públicos y regenera
   todas las hojas y el árbol completo.
4. **Apertura A1**: posición `chunk_location` uniforme entre las hojas con `codificado = 1` (las que
   una solución ganadora puede abrir), más el camino Merkle, como en S01. La `Solution<()>` se
   construye con la prueba de espacio **real** de la tabla del registro y el chunk fuente; se
   verifica con `verificar_apertura` de S01. (S01 validó el verificador PoAS real en su encargo; aquí
   la auditoría de S02a es sobre R2 y no depende de la solución ganadora concreta.)
5. **`t_reg`**: generación de la tabla PoS del registro (`generate_parallel`) **más** la codificación
   erasure del registro. La pieza se obtiene de la historia local una sola vez por registro, fuera
   del camino cronometrado (la orden la supone gratuita y local).

## 4. Modelo de coste

Con `p = pieces_in_sector`, `n = p·NUM_CHUNKS` hojas y `m = next_pow2(n)`, `profundidad = log2(m)`:

- **Tablas por apertura** = número de `piece_offset` **distintos** entre las hojas regeneradas. No
  se supone `2^L`: se mide. Cota superior `p`.
- **E-disco**: coste `O(profundidad)` hashes; 0 tablas.
- **E-árbol(L)**: `c` tablas + `2^L` hojas + `2^(profundidad−L)−1` hashes internos; almacenamiento
  `2^(profundidad−L)·32 B`.
- **E-nada**: `p` tablas + `n` hojas + árbol completo; almacenamiento 32 B.
- La cota inferior de latencia por apertura es `c · t_reg`; la curva completa
  «almacenamiento conservado ↔ latencia por apertura» se mide, no se estima.

## 5. Corrección antes de medir

1. **Validación exhaustiva de la regeneración** por tamaño: se regeneran las `n` hojas con tablas
   reales y se cotejan byte a byte contra la región de chunks del fichero de sector y contra las
   hojas del árbol de R2. Se exige `0` discrepancias.
2. **100 aperturas aleatorias por estrategia y tamaño** verificadas contra R2 con
   `verificar_apertura` de S01. Se exige `0` fallos.
3. En cada apertura **medida** viva (modo `medir`) se verifica también contra R2; una apertura que no
   verifica se cuenta como fallo y se declara.

## 6. Protocolo de medición

- Semilla por CLI (constante declarada `0x5a5a…`); posiciones muestreadas con splitmix64 y la **misma**
  secuencia para todas las estrategias (comparación aparcada).
- Calentamiento de 2 aperturas por estrategia antes de la serie; `N ≥ 30` aperturas por punto en la
  malla principal.
- Tiempo de pared (`Instant`) y de CPU (suma de `runtime_ns` de `/proc/self/task/*/schedstat`).
- RAM máxima por `VmHWM` de `/proc/self/status`.
- Hilos controlados con `RAYON_NUM_THREADS` (1, 2, 4, 8, 16); `t_reg` medido con 3 repeticiones por
  registro. La malla completa se mide a 16 hilos y el escalado con malla reducida.
- Antes de **cada** serie se registra `uptime`; si la carga de 1 minuto supera 4 se espera (tope
  20 min por serie). Todo queda en `logs/series.log` y `logs/esperas.log`.
- Presupuesto: 2 h de reloj, 16 hilos, 32 GiB, 40 GiB. Si se agota, **inconcluso** con lo medido.

## 7. Qué NO se mide (declarado)

GPU y ASIC; coste de descargar piezas y latencia de red (la historia se supone local); adversario que
conserva una fracción aleatoria de hojas (modelo, para S02b); plazos, ventanas y tasa de fallos
honestos (S02b); corrección del ploteo (R3). El `t_reg` incluye la tabla que la propia solución PoAS
necesita, así que parte del coste regenerador podría ser común con la producción honesta de la
prueba; se declara.

## 8. Reproducción

```bash
cd /home/katana/zeo/ZEROX/deepseek/S02a
source entorno.sh
(cd prototipo && cargo build --offline --release --bin s02a)
RAYON_NUM_THREADS=16 ./target/release/s02a validar 4 100 0,1,2,4
RAYON_NUM_THREADS=16 ./target/release/s02a medir   4 40  0,1,2,4,8
RAYON_NUM_THREADS=1  ./target/release/s02a treg    4 3
bash resumir.sh
```
