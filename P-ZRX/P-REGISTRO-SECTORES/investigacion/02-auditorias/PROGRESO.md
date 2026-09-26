# PROGRESO — S02a

Zona `deepseek/S02a/`. Marcas de tiempo con `date -Is`.

## Estado

- Lectura íntegra de entradas: completa. `ENTRADA-S02a.sha256`: 4/4 al inicio.
- Zona preparada (clon `f8842d0`, caché cargo, prototipo copiado) y binario `s02a` compilado en
  `--release`.
- Corrección antes de medir: **0 discrepancias y 0 fallos** en p = 2, 3, 4, 16 (validación
  exhaustiva de regeneración + 100 aperturas por estrategia contra R2).
- `t_reg` por hilos: medido (1, 2, 4, 8, 16): 900,6 → 157,7 ms (speedup 5,71×; eficiencia 36 %).
- Series de medición: **completas** (1 080 aperturas, todas verifican). Ver `logs/series.log` y
  `resultados/resumen-mediciones.tsv`.
- **Veredicto: se confirma «encarece, no impide».** Regenerar cuesta 0,17–4,06 s por apertura frente
  a 0,2–0,3 µs de disco (8,8·10⁵ – 1,35·10⁷×), con cota inferior `t_reg` por registro regenerado.

## Pasos

1. **Lectura de entradas.** Orden, LINEO, ENCARGO-02, ANALISIS §§4–5, RFT-03/04/06, S01 completo
   (informe, especificación de bytes, revisión, método, prototipo) e histórico del `.trash`.
   Verificación de la entrada congelada: 4/4.
2. **Zona.** `prototipo/` copiado de S01; `autonomys-subspace` @ `f8842d019cdf…`; `.cargo-home`
   copiado; `CARGO_HOME`/`CARGO_TARGET_DIR` en la zona. Incidencia: un `source entorno.sh` inicial
   definía `CARGO_HOME=$PWD/.cargo-home` y creó un `.cargo-home` vacío dentro de `prototipo/`;
   detectado y corregido (ruta absoluta), sin efecto en resultados.
3. **Código.** `src/regeneracion.rs`, `src/estrategias.rs`, `src/bin/s02a.rs`; accesores en
   `sector.rs` y `merkle.rs`. Sin Python.
4. **Calibración.** `t_reg` a 1 hilo ≈ 0,90 s; a 16 hilos ≈ 0,158 s (mediana de 12).
5. **Validación.** p=2: 0/0; p=3: 0/0; p=4: 0/0; p=16: 0/0 (chunks discrepantes / fallos).
6. **Medición.** Malla completa a 16 hilos (p = 2, 3, 4, 16) y malla reducida de escalado
   (T = 1, 4, 8). Espera de carga registrada antes de cada serie.

## Faltas de definición (informadas antes de editar; resueltas por interpretación declarada)

1. **Nivel de E-árbol(L)**: se toma la letra «`2^(prof−L)·32 B`» = nodos del nivel `L`, con los
   ancestros recompuestos al abrir (coste dentro de la latencia). Se informa además el coste de
   conservar todos los niveles ≥ L (≈2×).
2. **Árbol Merkle en E-disco**: se cuenta como almacenamiento el fichero de sector y la caché del
   árbol se informa aparte en RAM; sin ella el camino costaría `O(n)`.
3. **Solución de la apertura A1**: S01 abría soluciones ganadoras; para muestrear posiciones
   uniformes se construye la `Solution<()>` con la prueba PoS real de la tabla y el chunk fuente, y
   se verifica con `verificar_apertura` de S01 (el verificador PoAS real no depende de la posición).
4. **`t_reg`**: tabla PoS + codificación erasure de un registro; la obtención local de la pieza queda
   fuera del cronómetro (gratuita y local por la orden).

## Pendiente

- Nada: entregables completos. Verificación final de la entrada congelada: 4/4 (`ENTORNO.txt`).
