# INFORME — ORDEN-W06d1 (relanzamiento): `zx-node` sin red

**Ejecutor:** Sonnet (único; sin subagentes, sin forks, en cumplimiento de «Relanzamiento» punto 1).
**Fecha:** 2026-09-26. **Zona:** `deepseek/W06d1/` (`ws.orig/`, `ws/`, `cambios.patch`,
`MIGRACION.sha256`, `logs/`, `PROGRESO.md`, `HORAS.log`).

## Veredicto

**SUPERADO.** Un proceso `zx-node` con 3 claves dev, desde el génesis, alcanza el terminal PoW,
produce bloques PoST en régimen que su propia tubería de admisión verifica íntegros, y tras
`SIGKILL` en puntos arbitrarios (fase PoW y fase PoST) reabre con el mismo estado persistido y sigue
produciendo. Un testigo PoW corrupto en disco (el límite declarado por `REVISION-W06b.md`) hace que
el nodo se niegue a arrancar con error explícito al repetir el registro.

Con reservas explícitas, documentadas abajo y en `PROGRESO.md`: la identidad GHOSTDAG de producción
usa un compromiso no inyectivo (punto 3), el tope real de padres por bloque es 3 y no 15 (punto 8), y
V8 (10 min con `SR_dev` calibrado a ≈ 1 bloque/slot) no se completó en su forma exacta por presupuesto
de tiempo; sí se corrió una medición real con `N_dev` real (60 slots, ver su fila).

## Tabla V1–V9

| Paso | Resultado |
|---|---|
| V1 (`fmt`) | **OK.** `cargo fmt --all -- --check` limpio en todo el workspace. |
| V2 (`clippy -D warnings`) | **OK.** Con `--all-features` y sin `--features rocksdb`, ambas limpias. |
| V3 (`cargo test --workspace --all-features --locked`) | **OK**, ver tabla de tests abajo. |
| V4 (integración: 3 claves, génesis → ≥ 30 PoST) | **OK.** `tests/integracion.rs`: terminal fijado a la altura 30 (dificultad inicial real de la red dev); ejecución de referencia con `N_dev` de test (32) y `SR_dev = u64::MAX` produjo 78 bloques PoST admitidos, 0 rechazados, en 57,7 s (`release`). |
| V5 (muerte y reinicio, ≥ 10 puntos) | **OK.** `tests/reinicio.rs`, semilla fija, **10** `SIGKILL` en total: 4 en fase PoW (mina de verdad, dificultad inicial real), 1 al final del calentamiento que cruza el corte, y 5 en régimen. Ambas fases con rondas (PoW y régimen) matan esperando un número **acumulado creciente** de eventos del registro (`bloque_minado`/`bloque_producido`), no un tiempo de pared fijo: con `SR_dev` holgado la producción es tan rápida que una espera en milisegundos no discriminaba puntos distintos en régimen (bug de la propia prueba), y en `debug` (sin optimizar, `cargo test --workspace` sin `--release`) minar la primera altura PoW puede tardar más que el tiempo de pared fijo que usaba antes la fase de calentamiento, dando `alturas=[0,0,0,0]` en una ejecución real (`logs/V3-despues.log`) — mismo bug, misma fase, encontrado más tarde; ambos corregidos, ver `PROGRESO.md` puntos 8–9. Verificado: ni las alturas PoW ni los recuentos de régimen se repiten entre rondas; reabre sin corrupción las 10 veces y sigue produciendo tras la última. |
| V5b (testigo PoW corrupto) | **OK.** Corrompida a mano (con `rocksdb` directamente, sin pasar por `Almacen`) la firma del primer testigo no vacío de un bloque PoW ya persistido: `Nodo::arrancar` se niega con error explícito al repetir (el motor de transición rechaza la firma; el almacén, como declara `REVISION-W06b.md`, no la habría detectado por sí solo). |
| V6 (red ≠ dev) | **OK.** `tests/red_no_dev.rs`: `Mainnet` y `Testnet` se rechazan antes de crear directorio de datos o registro. |
| V7 (bloque propio alterado) | **OK.** Test unitario (`nodo::pruebas_v7`, `admitir_pow_interno` es privado a propósito): un PoW propio con `nonce` no minado se rechaza y el resumen de estado no cambia. |
| V8 (10 min, `N_dev` real, `SR_dev` medido) | **PARCIAL.** No se calibró `SR_dev` a «≈ 1 bloque por slot» (D-P11, por medir) ni se corrió 10 min completos; sí se corrió con `N_dev` real 60 slots/99,5 s (1,66 s/slot, ≈ 1,82 bloques/slot con `SR_dev = u64::MAX`, sin calibrar). Ver «V8» abajo. |
| V9 (`dependencias-exactas.sh`, `frontera-crates.sh`, lock) | **OK.** 23 dependencias con versión exacta; las 9 fronteras (incluida la nueva de `zx-node`) en verde; lock: +15 paquetes (clap y su árbol), 0 versiones existentes cambiadas. |

## Tests antes/después

| | Antes (baseline, `logs/V3-antes.log`) | Después (`logs/V3-despues2.log`, corrida final tras el arreglo de `tests/reinicio.rs` fase PoW — ver `PROGRESO.md` puntos 8–9) |
|---|---:|---:|
| Pasan | 680 | 694 |
| Fallan | 0 | 0 |
| Ignorados | 2 | 2 (los mismos; ninguno nuevo) |
| Perdidos | — | 0 |
| Añadidos | — | 14: zx-cadena +2 (`contexto_dag.rs`), zx-post +2 (`insertar_calculado`), zx-node +10 (5 unitarios en `nodo::pruebas_v7`/`claves`, `integracion.rs`×1, `red_no_dev.rs`×2, `reinicio.rs`×2) |

## Cambios mínimos a otros crates (uno a uno)

1. **`crates/zx-cadena/src/cadena.rs`**: `Cadena::contexto_dag(&self) -> Option<&AlmacenGhostdag>`,
   accesor de solo lectura al `AlmacenGhostdag` interno. Autorizado por «Relanzamiento» punto 3
   («si `zx-cadena` no expone lo necesario… añade el accesor mínimo»). Con test
   (`crates/zx-cadena/tests/contexto_dag.rs`, 2 casos). No cambia ningún comportamiento existente.
2. **`crates/zx-post/src/servicio_pot.rs`**: `ServicioPot::insertar_calculado(slot, salida,
   portador)`, inserta una salida/portador ya calculados sin llamar a `prove` (exige
   `slot > slot_actual()`, no exige `== +1`: ver razón en el propio método). Necesario para la
   decisión 7 (reconstruir sin recalcular el flujo). Con 2 tests nuevos. No toca `avanzar` ni el
   resto de `InstantaneaPot`.

Ningún otro crate migrado se tocó.

## Faltas de definición y límites declarados

Registrados con su fecha y razonamiento completo en `PROGRESO.md` (10 decisiones numeradas, 7
errores propios encontrados y corregidos por las propias pruebas, y 2 faltas de definición). Resumen:

- **Identidad GHOSTDAG (`PROGRESO.md` punto 3):** `BloquePost::identidad` es `u64` (dominio de
  fixture de W06a); no representa `IdentidadGhostdag::Billete` real. `zx-node` deriva el `u64` de
  `blake3`/SHA3-256 de la tupla `C-GD-07` truncada a 8 bytes: **no es inyectivo**. No se demuestra
  unicidad exacta de billete (U2) para identidades reales; la colisión práctica en una red de 3
  claves y unos pocos miles de bloques es despreciable, pero no está certificada.
- **Tope de padres (`PROGRESO.md` punto 8):** `zx-cadena` (`inicializar_dag`) nunca acepta más de 3
  padres por bloque PoST, aunque `PERFIL-DEV-v0.md` hable de 15. `zx-node` limita su elección de
  padres a 3.
- **Bloque de transición sin GHOSTDAG real (`PROGRESO.md` punto 10):** el primer bloque de régimen
  se verifica con `ContextoTransicion` (el atajo dev), no con `Cadena::contexto_dag()`, porque este
  último no existe todavía en ese momento. Un único padre posible (el terminal): no hay elección de
  `sp` que temer.
- **Papel de la CLI (`--papel`):** `Minero`/`Productor` se aceptan como valores mas el binario se
  niega a arrancar con ellos: en un proceso sin red no pueden por sí solos alcanzar el corte ni
  producir. Solo `Ambos` (por defecto) es autosuficiente en esta orden.
- **Sector/parcela:** tamaño y protocolo del fixture dev de `zx-poas`/`zx-farmer`
  (`PIEZAS_POR_SECTOR_DEV = 2`); un índice de sector por clave; se plotea una vez y se reabre en
  reinicios.
- **Depósito:** cada clave deposita el importe **exacto** de su primera coinbase madura (sin
  cambio); cubre `q` con margen.

## V8: qué se hizo y por qué no se completó del todo

**No se completó la exigencia exacta** (10 min con `SR_dev` calibrado a «≈ 1 bloque por slot con 3
claves») **por presupuesto de tiempo**, pero sí se ejecutó una corrida real con `N_dev` = 138 873 760
(el valor de red) para no dejar la casilla vacía. Registro crudo:
`deepseek/W06d1/logs/` no lo conserva (se generó en `/tmp`, efímero); la cifra de abajo se leyó de su
`registro.jsonl` antes de descartarlo, y es reproducible con el comando:

```
zx-node --datos DIR --registro DIR/registro.jsonl --red dev --semilla 42 --claves 0,1,2 \
  --n-dev 138873760 --sr-dev 18446744073709551615 --parada-tras-slots 60
```

**Medido** (release, máquina de referencia, carga compartida con otras compilaciones en curso —no es
una medición aislada—): fase PoW hasta el corte, 30 bloques, 33,3 s. Fase de régimen, 60 slots reales
con `N_dev` real: 109 bloques PoST admitidos en 99,5 s ⇒ **1,66 s/slot** en promedio (frente a ≈ 1 s
de solo la cadena AES; el resto es auditoría de las 3 parcelas, verificación PoAS/PoT/GHOSTDAG y
persistencia) y **≈ 1,82 bloques/slot** con `SR_dev = u64::MAX` (sin calibrar: cada clave gana casi
todos los slots, muy por encima de «≈ 1 bloque por slot»). 0 bloques propios rechazados.

**Por qué no es el V8 completo:** con `SR_dev` sin calibrar, esta cifra sobrestima tanto el coste por
slot (más auditorías/admisiones por slot que con un `SR_dev` calibrado) como la tasa de bloques. La
propia orden deja `SR_dev` «por medir» (D-P11, sin controlador); calibrarlo primero (barrido corto de
valores hasta acercarse a 1 bloque/slot) y **luego** correr los 10 minutos completos exige más tiempo
del que quedaba en este encargo. Es una mala noticia que se declara sin envolverla: no hay una cifra
de rendimiento con `SR_dev` calibrado que ofrecer, solo esta medición real pero deliberadamente
holgada.

Lo que sí queda acotado por esta medición: el cableado del nodo (hilo productor, verificación,
persistencia) **no se rompe** con `N_dev` real, y el coste por slot no es solo el de `zx_pot::prove`
(medido por separado en W05b2: 1,389·10⁸ iter/s ⇒ ≈ 1 s) — hay un sobrecoste medible (~66 % en este
escenario denso) de auditoría/admisión/GHOSTDAG que crece con la densidad de bloques por slot,
coherente con lo que `ESCENARIOS-0.0.1.md` §2 ya anticipa para el tiempo de admisión GHOSTDAG frente
a la profundidad del DAG (IPA B-12).

**Recomendación para quien retome V8:** calibrar `SR_dev` primero con una corrida corta (1–2 min,
`N_dev` real) registrando bloques/slot, y luego la corrida de 10 min completa, en una sesión con
presupuesto de tiempo dedicado a eso exclusivamente.

## Lo no demostrado

- Unicidad de billete (U2/C-GD-07) exacta para identidades reales de producción (ver «Identidad
  GHOSTDAG» arriba): el compromiso truncado no es una prueba de inyectividad.
- Rendimiento con `N_dev`/`SR_dev` reales de red (V8, no completado).
- Comportamiento con más de 3 puntas simultáneas (tope real de `zx-cadena`, no ejercitado con 3
  claves en la práctica pero tampoco descartado por prueba negativa dedicada).
- Papel `Minero`/`Productor` de la CLI en un futuro nodo con red (W06d2): solo se decidió que
  `Ambos` es el único autosuficiente aquí; no se probó ningún camino de red.
- Resistencia del nodo a un `SIGKILL` durante la propia escritura del **registro** estructurado
  (no es consensus-critical y no se persiste con `sync`); solo se garantiza la consistencia de
  `zx-storage`.

## Rutas relevantes

- Orden: `P-ZRX/P-NODO/ORDEN-W06d1.md`. Bitácora completa de decisiones: `deepseek/W06d1/PROGRESO.md`.
- Código: `deepseek/W06d1/ws/crates/zx-node/` (nuevo), más los dos cambios en `zx-cadena`/`zx-post`
  citados arriba.
- Entregables: `deepseek/W06d1/cambios.patch`, `deepseek/W06d1/MIGRACION.sha256`,
  `deepseek/W06d1/logs/`, `deepseek/W06d1/HORAS.log`.
