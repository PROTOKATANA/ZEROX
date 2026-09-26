# REVISIÓN W06d5 — robustez del nodo en red

**Revisor:** Claude (director, sesión que lanzó la orden). **Fecha:** 2026-09-27 00:40. **Ejecutor:**
subagente Sonnet, único, 21:28 → ≈ 00:45, dentro de las 4 h; varias pausas mientras esperaba procesos, y el
director lo retomó. Evidencia: `resultados-W06d5/` (informe, progreso, horas, logs, parche, scripts). Las
ejecuciones reales (`run/`, 2,8 GB) se quedan en `deepseek/W06d5/run/`. **Veredicto: SUPERADO PARCIALMENTE.
Migrada** por parche: 6 rutas, todas en `crates/zx-node/`; base idéntica; `git apply --check` limpio; 6
huellas verificadas en la raíz; `crates/` de la raíz idéntico a `ws/crates`; `Cargo.lock` y `testdata/`
sin cambios.

## Comprobado por el director

- **Suite conjunta W06d4 + SL-4a** (paso 0, primera vez juntas): 735/0/2 (intento 4). Suite final con todos
  los arreglos: **736 pasan, 0 fallan, 2 ignorados** (`logs/V-final.log`, recuento del director). Los dos
  primeros intentos fallaron porque faltaban los vectores de SL-4a en la raíz: error del director,
  corregido en `69cfaa4`.
- **Entrada:** `ENTRADA-W06d5.sha256` da 5/6. `P-SLASHING/REVISION-SL4a.md` cambió porque el director le
  añadió la nota de esa corrección **con la orden en marcha**. Es la cuarta vez que se edita un archivo
  congelado (lección 3 del traspaso). No afecta a la zona.
- **Revisión del código** (`regimen.rs`, `nodo.rs` y `rechazo.rs` leídos):
  - la puerta de garantía (`con_garantia` por slot y antes de la transición);
  - el filtro de padres extra por slot;
  - la clasificación en `Legitimo`, `Pendiente` e `Interno`;
  - `Pendiente` → `Ignorar` con cola de reintento acotada a 64;
  - rechazos legítimos no fatales en PoW y en régimen.
- **Hallazgo del director confirmado por el ejecutor con archivo:línea:** un bloque de red que llegaba
  fuera de orden (`Pot(PasadoIncompleto)`, hueco **local**) se trataba como `Rechazar`. Eso penaliza al
  par (`crates/zx-p2p/src/entrante.rs:77-78`) y, en la vía de sincronización, lo **desconecta**. Era un
  bug real que amplificaba la avalancha de huérfanos del nodo tardío. Corregido.

## Resultado por prueba (procesos reales en 127.0.0.1)

| Prueba | Resultado |
|---|---|
| V4, regresión con tres nodos | **Superado**, tres veces (87, 76 y 345 bloques PoST; 0 fatales; punta convergente) |
| V5, nodo tardío | **No superado.** Ya no muere, pero no converge: sus huérfanos crecen (33 000 → 129 000) |
| V6(a), partición y reunión PoW | **Superado** |
| V6(b), partición y reunión PoST | **No demostrado.** El primer «superado» del ejecutor solo miraba que el nodo nuevo se reincorporara; el director pidió pruebas de fusión. Repetido: 0 bloques de la otra rama admitidos en 90 s y en 150 s |
| V7, `zx-adversario` | **Parcial.** La carrera de suscripción está corregida y verificada. La ráfaga sigue fallando localmente (`gossipsub rechazó la publicación local`), con el motivo real oculto por `P2pError::Transporte` (`crates/zx-p2p/src/servicio.rs:697-707`). El objetivo no aceptó nada indebido ni cayó |

## Causa común de V5 y V6(b) (hallazgo principal)

El nodo resuelve los huérfanos PoST **de uno en uno**: una petición por padre. Mientras la red sigue
produciendo, esa resolución no alcanza a la producción y la brecha **crece**. Se repitió con `N_dev`
pequeño y grande, con retraso y sin él, y hasta 10 minutos. **Falta una sincronización PoST por lotes**,
análoga a `cabeceras_desde` de la fase PoW. Sin ella, ni un nodo tardío ni dos ramas de una partición
convergen con la producción en marcha. **Es prerrequisito de W07.**

## Reservas

1. **Sin test automático** para la decisión 1 (garantía antes de producir, tanto en régimen como en la
   transición), la decisión 2 (padres extra) ni la cola de `Pendiente`. Solo hay 5 tests unitarios de la
   clasificación en `rechazo.rs`; el resto se verificó con ejecuciones reales. La orden pedía un test
   por decisión.
2. **Dial de arranque sin reintento** (`crates/zx-node/src/red/mod.rs:224-228`): si el par aún no
   escucha, el nodo queda aislado para siempre. Reproducido en vivo: un intento de V4 minó en tres
   cadenas aisladas sin fijar nunca el terminal.
3. **Detalles del parche:**
   - la espera de la transición sin garantía propia es un bucle sin límite, aceptable porque ese nodo no
     puede producir;
   - la cola de 64 descarta los bloques pendientes más viejos sin volver a pedirlos;
   - todo lo que no está enumerado queda como `Interno`, que es fatal para un bloque propio; así se
     clasifican por defecto las subvariantes de `ErrTransicion`, salvo `ErrPowTrasCorte`.

## Para W06d6 (lo hace la sesión nueva)

1. Sincronización PoST por lotes (petición del pasado que falta en bloque, en orden causal), con V5 y
   V6(b) como criterio de cierre.
2. Reintento acotado con espera creciente del dial de arranque, con test.
3. Motivo real en `P2pError::Transporte` y `tracing_subscriber` en `zx-adversario`, para cerrar V7.
4. Tests automáticos de las decisiones 1 y 2 y de la cola de pendientes.
