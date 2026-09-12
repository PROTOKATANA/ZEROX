# DAV-v0.1 — Resultado de dominio y composición contextual

Fecha: 2026-09-11. Categoría **consenso**: contrato de identidad y condiciones de entrada a
adjudicación; secundarios criptografía y almacenamiento. Se siguió LINEO con especialistas
Rust, matemáticas/Julia y C++/sistemas. Sin Python, simulación Julia nueva, GPU o benchmark.

## Resultado

**Quedan fijadas decisiones candidatas y un prototipo verificable, no el consenso de producción.**
El [contrato](CONTRATO.md) adopta para esta variante dominio económico fijo por red e igualdad
independiente de reto/raíz/rango. La compatibilidad del reloj compara prefijos históricos con N,
no etiquetas actuales de las puntas. La autorización transparente se compone realmente sobre
un snapshot inmutable; el almacén sólo recibe tokens del compositor y separa contextos.

En [prototipos/autorizacion-contextual](../../../prototipos/autorizacion-contextual/):

| Componente | Cambio efectivo frente a la etapa anterior | Límite |
|---|---|---|
| `dominio.rs` | Proyección económica exacta y comparador de prefijos declarados | No autentica calendario, no valida PoAS/PoT ni construye el pasado DAG. |
| `compromiso.rs` | Vector ordenado txid/auth_digest y composición contra un compromiso esperado | Compromiso esperado suministrado externamente; aún no está en una cabecera DAG firmada. |
| `lib.rs` | API que compone controles nativos y verificación real de firmas, no sólo helper de test P2K | Perfil transparente explícito; no bloque PoST plenamente válido. |
| `almacen.rs` | Tokens owned, consultas exactas, no degradación, límites y control de versión por instancia | Caché local en memoria, no ledger ni persistencia de producción. |

No se modificaron archivos anteriores, incluidos SPEC, crates de producción, IDV y CBE.
Las huellas antiguas se verificaron íntegramente. Las lagunas del nodo activo documentadas
en IDV **siguen pendientes de integrar**: añadir este prototipo no las corrige retroactivamente.

## 1. Qué se decide sobre el derecho económico

Clave candidata:

```text
(NetworkDomain, slot, public_key, sector_index, history_size, piece_offset)
```

NetworkDomain se mantiene entre forks, inyecciones y upgrades; no lo elige cada productor.
Cambiar contexto criptográfico no crea otro derecho. Es una elección económica explícita:
no afirma que servir archivos/retos diferentes requiera el mismo trabajo físico.

Se conserva ledger por historia y undo de CBE, no unión de estados de ramas. Por R-FIN-5,
pasado incompatible después de la divergencia no puede fusionarse como si fueran pagos
compatibles; pasado común anterior no se rechaza sólo porque después cambien los flujos.
El comparador nuevo refina el descriptor para incluir N efectivo: entropías y slots solos
no bastan si N puede diferir. Los valores y procedencia de calendario siguen pendientes.

**Coste honesto conservado:** un productor puede perder una adjudicación al abandonarse su
rama; dos trabajos sobre distintos contextos con igual coordenada/slot no tienen prometidos
dos pagos. No se mantiene la afirmación «sólo perjudica a quien equivoca».

La multiplicidad de ensayos PoS/retos demostrada o planteada en IDV no desaparece al limitar
cobros. No se recalibró alpha ni se supuso una tasa Poisson/independencia de ensayos.
Véase [DOMINIO.md](DOMINIO.md) para derivación, contraejemplos y obligaciones.

## 2. Qué se comprueba de verdad sobre cuerpo y autorización

El compromiso candidato conserva `(n, pares ordenados(txid, auth_digest))`, coinbase incluida.
No contiene hash de cabecera, PoS o sello; por eso no crea la autorreferencia que causaría
introducir `body_key` de caché dentro de esa cabecera. No se añadió un nuevo hash de consenso.

Se probaron dos autorizaciones MultiSig 1-de-2 distintas, ambas válidas, con la misma cabecera
actual y los mismos efectos. Tienen distinto compromiso candidato. Contra el compromiso
esperado de A, `autorizar_con_compromiso(B, ...)` rechaza la entrega B, aunque sus firmas sean
válidas. Contra A, compone las firmas y permite retener exactamente A. No selecciona por llegada.
También se comprueba que comprometer una firma mala no la convierte en válida.

El compositor soporta PubKey, MultiSig y HTLC preimagen/timeout usando las primitivas nativas.
Comprueba todos los importes/Locks requeridos por el sighash, su orden, branch ID, madurez,
expiración y los controles nativos de cuerpo. Se añadieron precontroles necesarios de coinbase
y Locks manuales, que no quedan cubiertos sólo por llamar `validar_cuerpo`.

Perfil excluido expresamente: otros HashType distintos de ALL, lock_time no nulo, Orchard y
dependencias intra-cuerpo. NoSoportado no es invalidez de consenso. Las vistas declaradas de
UTXO distinguen omitido/desconocido, inexistente y gastado; el último no acredita autorización
ni se presenta como conflicto de ejecución ya validado. [AUTORIZACION.md](AUTORIZACION.md).

## 3. Qué protege el almacén experimental

- Mala→buena repara porque la entrega mala no produce token ni envenena el blockhash.
- Buena→mala no degrada: no puede insertarse evidencia para la entrega inválida.
- Buena→idéntica es idempotente; dos autorizaciones válidas pueden coexistir bajo claves exactas.
- Saturación local preserva evidencia retenida/visible y no convierte la variante válida en inválida.
- Evidencia en C1 no se relabela C2; puede conservarse y reutilizarse al volver al mismo snapshot.
- Publicación condicional rechaza vistas obsoletas, incluida A→B→A y referencias de otra caché.
- Mutar el candidato después de autorizarlo no altera el cuerpo owned que conserva el token.

**Hallazgo corregido durante esta ronda:** mi primera VistaVersionada sólo contenía contexto
y revisión. El especialista de sistemas detectó que dos instancias nuevas podían intercambiar
sus tickets si esos valores coincidían. Se añadió identidad de instancia local, asignación
atómica comprobada y regresión con firmas reales. El contador no recicla valores al agotarse.
La revisión independiente confirmó el cierre por lectura; el principal ejecutó la regresión.
No se atribuye protección a reinicios entre procesos: los tickets son volátiles y no serializables.

El patrón no demuestra disponibilidad global, recuperación tras corte, durabilidad RocksDB,
poda o transición atómica de ledger/UTXO/Orchard/emisión/recuento/undo. La retención DA0 puede
seguir impidiendo progreso. [ALMACENAMIENTO.md](ALMACENAMIENTO.md).

## 4. Validación ejecutada

| Grupo | Resultado |
|---|---|
| Autorización nativa | 12 tests aprobados. |
| Caché y versiones con firmas reales | 10 tests aprobados. |
| Compromiso y composición | 7 tests aprobados. |
| Dominio y prefijos declarados | 8 tests aprobados, semánticos; no PoT. |
| Fronteras de contadores/peso locales | 3 tests aprobados. |
| Privacidad/inmutabilidad del token | 2 doctests compile_fail aprobados. |
| Regresión Rust CBE anterior | 14 tests aprobados sin modificar el instrumento. |
| Clippy del prototipo, todos los targets | Código 0 con `-D warnings`. |
| Formato del prototipo y diff-check | Código 0. |
| Huellas IDV y CBE conservadas | Todas correctas. |

Total nuevo: **40 tests de ejecución y 2 de compilación negativa**. Las cifras son conteos de
tests, no cobertura exhaustiva ni probabilidad de seguridad. CBE sigue siendo un modelo abstracto;
volver a ejecutar sus tests no prueba que el nuevo token ya esté integrado con su ledger.

El doctest inicial intentaba construir un literal sin campos y no discriminaba privacidad:
se reemplazó por una construcción bien tipada con todos los campos, y se añadió la mutación
por getter. La primera compilación de fixtures tuvo errores de préstamo Rust, corregidos sin
cambiar los casos. Clippy final detectó un atributo must_use redundante tras cambiar el constructor
del almacén a Result; se retiró sólo ese atributo. No se omitieron tests ni se relajaron validadores.

Se conserva [salida final de tests](resultados/TESTS.txt), [controles](resultados/CONTROLES.txt)
y [entorno](resultados/ENTORNO.txt). Los inputs son fuentes de fixture deterministas, no blobs
regenerados al azar; están incluidos en [HUELLAS.sha256](HUELLAS.sha256).

## 5. Parámetros, procedencia y coste

No se escoge ningún nuevo parámetro de red. Datos de fixture:

- claves Ed25519 públicas reproducibles desde semillas `[7;32]` y `[8;32]`;
- altura 10, salida previa 100 brek, salida nueva 90 brek, coinbase con valor cero;
- mediana 100000 tomada de la zona libre nativa; madurez probada con la constante nativa;
- descriptores de reloj: origen de índice 0, eventos en 5/10, horizontes 20/30 e iteraciones
  1600/3200 elegidos para probar igualdad y bordes, **sin ejecutar PoT con ellos**;
- caché de prueba: 0/1/2 entradas y presupuestos de peso 0/1000000, límites locales elegidos;
  u64::MAX sólo para fronteras aritméticas exactas, no parámetro de operación.

Firmador de pruebas ed25519-zebra=4.2.0, dependencia exacta ya presente; verificación por la
ruta nativa ZIP-215. `Cargo.lock` propio y paths a crates locales, sin actualizaciones upstream.
HEAD de referencia ZEROX `7b783d469fbae5722a0ae014b5e212ed6999eb2b` con worktree previo preservado.
Ese HEAD no contiene por sí solo el prototipo nuevo: las huellas fijan los archivos utilizados.

Entorno: rustc 1.97.0-nightly (20de910db 2026-05-02), Cargo 1.97.0-nightly
(4f9b52075 2026-05-01), toolchain existente; no se afirma validación con compilador estable.
AMD Ryzen 9 9950X3D, 16 núcleos/32 hilos lógicos, RAM observada 132497408000 bytes.
2 jobs por comando Cargo; tests con un hilo. Sin BLAS ni GPU.

Presupuesto declarado de pruebas por instrumento: 10 minutos, 4 GiB RAM, 2 GiB de disco nuevo
y 2 jobs, timeout 120 s por comando. El prototipo final comparte ese target aislado, que ocupó
178 MiB después de test/Clippy. No hubo agotamiento ni cambio de veredicto por timeout; no se
instaló un cgroup. El consumo reportado es del proceso, no de toda la máquina.

En el pase conjunto final instrumentado, GNU time informó 0,54 s de pared, 0,62 s CPU usuario,
0,22 s sistema y RSS máximo 208744 KiB; la compilación incremental informó 0,32 s.
La salida exacta queda en TESTS.txt.
Son datos operativos del test, **no benchmarks, coste estable de nodo ni mejora de latencia**.
La compilación inicial del agente informó 5,31 s y RSS máximo 438832 KiB; AUTORIZACION.md registra
su alcance. No se comparan estos tiempos como optimizaciones.

Coste conceptual: snapshot O(U log U) para ordenar y O(U) para codificar/hashear, lectura por
outpoint O(log U), copia owned del cuerpo y hashes lineales en sus bytes. Persisten costes
cuadráticos nativos de detección de doble gasto y recorridos de sighash por entrada. El mapa
de evidencia usa BTreeMap O(log E); los descriptores ordenan eventos y comparan prefijos exactos.
La construcción/copias de snapshots puede dominar memoria: no hay optimización medida aquí.

## 6. Reproducción y siguiente paso

Desde la raíz ZEROX:

```sh
/usr/bin/time -v timeout 120s cargo test --offline --locked -j 2 --manifest-path prototipos/autorizacion-contextual/Cargo.toml -- --test-threads=1
timeout 120s cargo clippy --offline --locked -j 2 --manifest-path prototipos/autorizacion-contextual/Cargo.toml --all-targets -- -D warnings
cargo fmt --manifest-path prototipos/autorizacion-contextual/Cargo.toml -- --check
timeout 60s cargo test --offline --locked -j 2 -p zx-consensus --test contrato_billete_modelo -- --test-threads=1
sha256sum -c veritas/consenso/dominio-autorizacion-v1/HUELLAS.sha256
sha256sum -c veritas/consenso/identidad-disponibilidad-v1/HUELLAS.sha256
sha256sum -c veritas/consenso/contrato-billete-v1/HUELLAS.sha256
git diff --check
```

No se reejecutaron Julia ni la suite completa del nodo. No se usa el conocido fallo 92/556 de
cabecera para desactivar tests, ni un pase de esta suite aislada para afirmar migración terminada.

**Siguiente trabajo sobre este candidato:** especificar ventana/admisión tardía y controlador
causal alimentado por las mismas adjudicaciones. Debe conservar explícitos multiplicidad de
ensayos, producción admitida frente a producción total, retención y periodos sin progreso.
Puede estudiarse como modelo condicionado; antes de certificar pagos en producción siguen
faltando contexto causal autenticado, cabecera DAG con compromiso firmado, PoAS/PoT integrados,
Orchard, aplicación económica conjunta y disponibilidad adversarial. No se añaden segundos
de finalidad ni una nueva tabla de riesgo a Cortex.
