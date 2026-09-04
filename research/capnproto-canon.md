# Cap'n Proto — canonicalización: veredicto sobre la decisión de ZEROX · agente zx-uso-real, 2026-09-04

> **Conclusión directa: la decisión de ZEROX (no hashear Cap'n Proto, preimagen canónica hecha a
> mano) es CORRECTA — no excesivamente conservadora.** Es el mismo patrón que llegaron a adoptar,
> de forma independiente, Cosmos SDK (ADR-027) y la familia Diem/Aptos/Sui (BCS).

## Qué garantiza el modo canónico — y qué no

- El modo canónico existe (árbol en preorden, un segmento, sin packing, palabras finales en cero truncadas) pero **NO es el comportamiento por defecto** — hay que invocarlo explícitamente. Cita del propio creador (Kenton Varda, 2017): *"users must invoke them explicitly"*.
- ⚠️ **Incluso en modo canónico hay ambigüedad no resuelta**: la spec exige orden preorden para *punteros*, pero **no define orden para campos de datos no-puntero** (issue `go-capnp#581`, abierto ago-2024, **sigue abierto**). Dos serializadores "canónicos" pueden producir bytes distintos para el mismo valor lógico si copian segmentos completos en vez de reconstruir campo a campo.
- **Bug real confirmado**: `is_canonical()` del crate Rust devolvía `true` para mensajes con far pointers patológicos que NO eran canónicos (2018, corregido). Si se hubiera usado como gate de seguridad antes de verificar una firma, habría colado una codificación no-canónica.
- **Evolución de schema + defaults**: discusión de 2015 sin solución formal verificada en la spec actual — un campo nuevo con default no-cero puede romper la promesa de "los mensajes viejos se canonicalizan igual".
- Solo desde la v0.5 (regla "listas de structs siempre C=7") la canonicalización es siquiera posible sin conocer el schema — antes era imposible en general. Mensajes pre-0.5 pueden ser literalmente no-canonicalizables.

## Proyectos reales — ninguno hace lo que se necesitaría para consenso multi-implementación

| Proyecto | Usa canónico para firmar/hashear | Por qué es seguro (o no) |
|---|---|---|
| **Sandstorm** (kentonv) | NO — firma SHA-512 de los **bytes crudos no canonicalizados** | Frágil: el propio ecosistema (`docker-spk#6`, 2018, **abierto desde hace 8 años**) señaló que los bytes no son reproducibles entre versiones de la librería. Funciona solo porque productor y verificador son (en la práctica) el mismo binario |
| **Turborepo** (Vercel) | SÍ, `set_root_canonical` para claves de hash de **caché de build** | Bajo riesgo: un fallo de determinismo produce como mucho un *cache-miss*, no un fork de consenso. Aun así tropezaron con footguns reales (panics de `Allocator` por tamaño mal calculado, PR `capnproto-rust#424`, 2023) |
| **Veilid** (red P2P) | SÍ, firma bytes canónicos de `PeerInfo`/`NodeInfo` | Evita el problema de fondo porque **productor y verificador son siempre el mismo binario Rust** — nunca dos implementaciones independientes |

**Ninguno de los tres firma/hashea Cap'n Proto canónico entre dos implementaciones independientes con consecuencias de consenso.** Es exactamente el escenario de ZEROX (nodo Rust + minero C++).

## ⚠️ Riesgo directamente análogo al que ZEROX ya confirmó (H-001)

No existe ningún conjunto de vectores de prueba compartido entre implementaciones de Cap'n Proto (C++, Rust, Go, Haskell) para canonicalización — a diferencia de SHA-3 (860 vectores CAVP del NIST) o ZIP-244 (`zcash-test-vectors`), que ZEROX ya usa para otras partes de su stack. **Es el mismo patrón de riesgo que ya se materializó dentro del propio proyecto**: la ruta CPU (Rust, correcta) y GPU (C++/HIP) de ZEROX divergían silenciosamente (nonce `u128` vs `u64`) hasta que una auditoría dedicada las comparó bit a bit (H-001). Confiar en que "Cap'n Proto canónico" produce los mismos bytes en Rust y C++ sin vectores cruzados sería repetir exactamente ese error.

## El patrón que siguen todos los que sí necesitan esto para consenso

- **Cosmos SDK (ADR-027)**: documentó que Protobuf estándar tiene *"un número prácticamente ilimitado de representaciones binarias válidas para un mismo documento"* → definieron su propio subconjunto estricto de reglas.
- **Diem/Aptos/Sui → BCS** (Binary Canonical Serialization): construyeron su propio formato desde cero, precisamente para que *"firmar el valor lógico y firmar los bytes serializados sean equivalentes"*.
- **Zcash → ZIP-244**: mismo patrón (ver `zerox/research/zip244.md`).

**Patrón dominante y unánime en toda la muestra: NO confiar en el modo canónico nativo de un framework de serialización de propósito general para firma/consenso — definir una codificación propia, estricta, byte a byte, encima.** Es exactamente lo que hace ZEROX.

## Salud del crate `capnp` (Rust)

Sano y activo: release 0.27.0 (2026-08-02), cadencia mensual/bimensual desde 2024, commits del mantenedor (dwrensha) hasta la fecha. Tuvo una vulnerabilidad de memoria real (`RUSTSEC-2025-0143`, UB en `get_root_unchecked`, reportada dic-2025, parcheada en 0.24.0 ene-2026) gestionada con rapidez — señal de proyecto vivo. **La canonicalización específicamente es la parte menos pulida**: feature request sin resolver desde 2023 (`#431`, "canonicalizar al recibir"), y el propio mantenedor admitió incertidumbre sobre el cálculo de tamaño de `set_root_canonical` en 2023.

## Antipatrones a evitar (si alguna vez se reconsidera)

- Asumir que "canónico" = único bit a bit entre implementaciones distintas (no lo es, `go-capnp#581`).
- Confiar en `is_canonical()` como gate de seguridad sin validarlo (tuvo un bug real).
- Activar `set_root_canonical` sin dimensionar el `Allocator` (panics en producción, Turborepo).
- No prever el acoplamiento schema-evolution ↔ semántica de defaults.
- Firmar bytes wire crudos confiando en "siempre los escribe el mismo código" (Sandstorm — frágil ante upgrades de librería, sin arreglar en 8 años).

## Lagunas
- No verificado si la spec 2026 resolvió formalmente "defaults + upgrade" (2015).
- No se encontró un caso público de firma/hash falsificado explotando esto — pero la ausencia de evidencia no es evidencia de ausencia; el patrón "canónico para firmar entre implementaciones independientes" es raro en producción, así que la superficie reportada también es pequeña.
- No se compiló y comparó byte a byte `capnp` Rust 0.27.0 vs la librería C++ actual — solo se confirmó la ausencia de un test suite compartido que lo garantice.
