# `mediciones/` — qué hay en cada fichero

Salidas crudas del banco. **Ninguna cifra del informe se teclea**: el bin `exportar_modelo` parsea
estos ficheros y escribe `modelo-entrada.tsv`, y el modelo Julia se niega a arrancar si falta una
clave.

## Medidas del encargo

| Fichero | Qué contiene | Instrumento |
|---|---|---|
| `m1_tabla.txt` | `t_tabla` por tabla, 1 hilo y paralelo | Criterion, muestra 10 |
| `m1_escalado.txt` | tablas/s agregadas para 1, 2, 4, 8, 16 y 24 hilos, en las dos formas | `escalado`, mediana de 3 × 12 s |
| `m1_ram.txt` | RAM por tabla viva | `escalado --ram 8` |
| `m2_reto.txt` | coste por reto: aislado, `por_bucket` y lote, para `w ∈ {1,10,100,1000,10⁴}` | Criterion, muestra 20 |
| `m3_ganador.txt` | componentes del camino ganador | Criterion, muestra 10 |
| `m4_cono.txt` | responder un bucket desde el mapa compacto y desde las siete tablas | Criterion, muestra 10 |
| `m4_cono_tablas.txt` | `Tables::create` frente a `create_proofs`; cota de poda | `cono`, Instant, n = 3 |
| `distribucion.txt` | distribución espacial de las pruebas y `o` medido | `distribucion`, 32 semillas |
| `modelo-entrada.tsv` | **entrada del modelo Julia**, extraída de los anteriores | `exportar_modelo` |

## Control contra la evidencia histórica

| Fichero | Qué contiene |
|---|---|
| `clon_plotting.txt` | `plotting/in-memory` de 1.000 piezas — el control de los 83,6 s |
| `clon_proving.txt` | camino ganador extremo a extremo del prover honesto |
| `clon_auditing.txt` | coste de auditoría del clon |
| `clon_kzg.txt` | banco KZG del clon |
| `clon_pos.txt` | banco `pos` completo del clon |

## Fallos e incidencias

| Fichero | Qué contiene |
|---|---|
| `fallo-semilla.md` | SIGSEGV reproducible en `ab-proof-of-space` para ciertas semillas, con entrada mínima |
| `fallo-semilla-muestra2.txt` | segunda corrida de búsqueda de semillas malas |
| `gpu.txt` | sonda GPU (M5) y su resultado dentro del presupuesto de 1 h |

## Bitácoras de ejecución

`_suite.log`, `_m1m2.log`, `_escalado.log` y `_control.log` son la salida completa de cada fase tal
cual se ejecutó, incluidos los abortos.

## Etiquetas

Toda cifra publicada lleva su estado: `medido` (con banco, muestra, hilos y máquina), `derivado`,
`estimado` o `no determinado`. Ninguna cifra de `research/` se hereda: **aquello es evidencia
histórica**, y el control del §4 del informe existe precisamente para contrastarla.
