# W05b3 — faltas de definición detectadas antes de editar (2026-09-26)

Leídos íntegros: `ORDEN-W05b3.md`, `V-ZRX/LINEO.md`, `DECISIONES-W05.md`, `PERFIL-DEV-v0.md`,
`FORMATO-v0.md` (con v0.1), `REVISION-W05b2.md`, `REVISION-RI-1b.md`, y el código de
`crates/zx-post/` y `crates/zx-dag/` de la raíz (base tras W02b). Se informa **antes** de tocar
código. En cada punto se declara la interpretación con la que se ejecuta, siguiendo el patrón de
W05b2 (`logs/faltas…` + interpretación declarada).

## 1. `InstantaneaPot::pasado()` no se deduce del estado PoT
La orden (§3.2) describe `ServicioPot` como «salidas y checkpoints de una ventana acotada de
slots»; de ahí **no** se pueden derivar los `(hash, slot)` de los bloques padre que
`pot_rango` paso 1 necesita para localizar `slot(sp(B))`. Interpretación: `ServicioPot` gana una
API de **registro** explícito (`registrar_validado(hash, slot)`) acotada por la misma ventana; el
servicio **nunca inventa** hashes. `pasado()` devuelve solo lo registrado (terminal + bloques
dentro de ventana), y un padre fuera de ella produce `PotPendiente(PasadoIncompleto)`.

## 2. Cuerpo que recibe `producir_en_regimen`
La orden (§3.3) dice «las transacciones del cuerpo (la coinbase v3 la construye el productor con
el `slot` del bloque)», pero no precisa si la lista incluye la coinbase ni si llegan los testigos.
Interpretación: el llamante entrega las transacciones **sin** la coinbase y sus testigos en
vectores paralelos; el productor **antepone** la coinbase v3 con testigos vacíos. Una transacción
coinbase en la lista de entrada es error explícito (`ErrorCuerpo::CoinbaseEnCuerpo`), porque
produciría dos coinbases.

## 3. Semántica de «slot objetivo»
Interpretación: es el slot **exacto** del bloque. El productor avanza el `ServicioPot` hasta ese
slot si hace falta, y audita `FuenteSoluciones` **solo** en él. Sin solución en ese slot:
`SinSolucion { slot }`. Permitir un objetivo anterior al `slot_actual` del servicio si la salida
sigue en ventana es lo que hace posibles los hermanos de un slot ya avanzado.

## 4. `N_dev` duplicado en `ParametrosProductor` y `ServicioPot`
El productor recibe ambos. Interpretación: el `N` que manda en la cadena PoT es el del servicio;
si `ParametrosProductor::n_dev` difiere, error explícito (`ErrorRegimen::NDevDiscrepante`) en vez
de ignorar silenciosamente uno de los dos.

## 5. Coinbase v3 con `slot` ≠ bloque
La puerta conjunta de `zx-post` **no** inspecciona el cuerpo (§documentado en su módulo). La
regla F-17 se rechaza en `zx-consensus` (`transicion::aplicar::aplicar_coinbase_post`,
`crates/zx-consensus/src/transicion/aplicar.rs:370-373` → `ErrorTransicion::ErrEmision`).
Interpretación: el negativo se comprueba **en el motor de consenso** con un test real sobre
`aplicar`, además de dejar escrito que la puerta conjunta no lo ve (su alcance es cabecera y
justificación).

## 6. «Padres no canónicos o > 15»
Ambos se rechazan en la **frontera de formato** de `zx-core`, antes de cualquier contexto DAG:
`PadresDag::nuevo` → `EncodingError::DemasiadosPadres` (> 15) y el parser de cabecera →
`EncodingError::PadresNoCanonicos` (extras no ascendentes). No son motivos nuevos de `zx-post`;
se prueban y se documenta dónde.

## 7. `ContextoRangoDag`
La orden exige `ContextoDag` e `InstantaneaPot` reales (GHOSTDAG y `ServicioPot`), pero **no**
existe el controlador de rango (D-P11). Interpretación: en los tests el rango es la constante dev
`SR_dev` (contexto declarado, no un mock que devuelva «válido»).

## 8. `frontera-crates.sh`
La raíz ya incluye la frontera `zx-post → {zx-core, zx-pot, zx-dag, zx-poas}` (migración W05b2).
No hay que añadirla; se ejecuta y se comprueba.

Presupuesto declarado (LINEO §7): **2 h, 8 hilos, 16 GiB, 40 GiB de disco**; prohibido Python. Si
se agota: checkpoint y **inconcluso**, nunca un `Ok` ficticio.
