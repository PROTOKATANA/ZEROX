# ORDEN-RI-3 — Revisión independiente del código de red, nodo y castigo (W06d2–W06d5, SL-4a)

- **ID:** RI-3, en tres partes: **RI-3a** (red), **RI-3b** (evidencia y castigo) y **RI-3c** (lógica del nodo,
  tras la migración de W06d5). **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagentes Claude
  Sonnet (revisión con criterio propio; `P-ZRX/PLAN-0.0.1.md` D-P06).
- **Motivo:** IPA E-11. El código de W06d2, W06d3, W06d4 y SL-4a (red, nodo y castigo) no ha tenido revisor
  independiente; W07 no se lanza con hallazgos altos sin corregir (`R-ZRX/TRASPASO-2026-09-26.md` §3.2).
- **Zona escribible:** `/home/katana/zeo/ZEROX/deepseek/RI-3a/`, `…/RI-3b/` o `…/RI-3c/` (la tuya). **Nada**
  fuera de ella: ni `crates/`, ni `P-ZRX/`, ni git, ni **`deepseek/W06d5/`** (otra sesión trabaja allí con
  procesos vivos: no los toques ni los mates).

## Alcance

| Revisor | Código (en la raíz, commit `7810f51` o posterior) | Contratos contra los que se revisa |
|---|---|---|
| **RI-3a** | `crates/zx-p2p/` entero (transporte, códec, límites C-NET, presupuestos, límites por IP, servicio) y `crates/zx-node/src/red/` (`mod.rs`, `manejador.rs`, `huerfanos.rs`, `sync.rs`, `vista.rs`) | `P-ZRX/P-NODO/PLAN-W06.md` (D-N01, D-N04, D-N05), `ORDEN-W06c.md`, `ORDEN-W06d2.md`, `ORDEN-W06d3.md`, `P-ZRX/P-FORMATO/FORMATO-v0.md` (bloques en red) |
| **RI-3b** | Evidencia y castigo de SL-4a: `crates/zx-consensus/src/transicion/{aplicar.rs, estado.rs, fusion.rs, seleccion.rs, tipos.rs, error.rs}`; `crates/zx-core/src/{forma.rs, tx.rs, hash.rs, wire.rs, preimage/tx.rs, preimage/mod.rs}` (`EvidenceTx` v4); `crates/zx-cadena/src/cadena.rs` (evidencia en fusión, más lo que tocaron W06d2 y W06d3: error de padre no definitivo, bifurcaciones PoW, equivocación) | `P-ZRX/P-SLASHING/CONTRATO-EVIDENCIA-v0.md` **con su «Ratificación v0» (prevalece)**, `P-ZRX/P-SLASHING/DECISIONES.md` (DS-L01…DS-L05), `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`, `P-ZRX/P-TRANSICION/CONTRATO-v0.md` |
| **RI-3c** | `crates/zx-node/src/{nodo.rs, regimen.rs, pow.rs}` y lo que añada W06d5 (p. ej. `rechazo.rs`), `crates/zx-node/src/bin/zx-adversario.rs`, `crates/zx-post/src/servicio_pot.rs` | `PLAN-W06.md`, `ORDEN-W06d1.md` («Relanzamiento»), `ORDEN-W06d2…d5.md`, `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`. **Se lanza tras la migración de W06d5.** |

**Excluido (ya conocido, no lo reportes):** coste de admisión GHOSTDAG no acotado (IPA B-12); reinicio sin
instantáneas (E-10); testigos PoW no comprometidos en la cabecera (REVISION-W06b); todo lo marcado «no
activo en 0.0.1» en `D-ZRX/SPEC-0.0.1.md` §7 **salvo** la evidencia y el castigo de RI-3b, que están
implementados en motor y cadena aunque el nodo aún no los active; ausencia de relevo de transacciones;
hallazgos ya corregidos de RI-1 y RI-2 (`P-ZRX/P-REVISION-CODIGO/REVISION-RI-*.md`); semilla del corte (A-07).

## Qué buscar

Lo de `ORDEN-RI-1.md` §«Qué buscar» (aceptar lo inválido o rechazar lo válido, no determinismo, desbordes,
undo inexacto, divergencia con el contrato citando la regla exacta, verificación saltada en algún camino,
consumo no acotado antes de validar, parámetros dev activables fuera de `Red::Dev`, tests que no prueban lo
que dicen), más, según tu parte:

- **RI-3a (red):** trabajo o memoria que un par sin coste puede forzar antes de la validación barata
  (amplificación: bytes decodificados, verificaciones PoT/PoAS lanzadas, huérfanos retenidos, peticiones
  en vuelo); límites C-NET declarados pero no aplicados en algún camino; penalización que un par puede
  eludir reconectando o que un par honesto puede recibir por un caso de borde legítimo (p. ej. un bloque
  válido que llega antes que su padre); localizador PoW y sincronización que un par puede atascar o hacer
  divergir; decodificación no canónica aceptada; mensajes que llegan en orden distinto a nodos distintos y
  dejan estados distintos.
- **RI-3b (castigo):** falso castigo de un honesto (dos cabeceras que no son doble firma según RAT-1:
  otra red, otro slot, otro sector, otra `history_size`, otro `chunk`, misma cabecera dos veces); doble
  firma real que escapa (deduplicación de incidentes mal indexada, evidencia descartada como tardía antes
  de tiempo, identidad calculada sobre campos distintos a los de RAT-1); conservación monetaria de
  `C = mín(V, techo(f·V))`, `suelo(C·2/8)` al incluidor y quema (RAT-2′); puerta de RAT-3 y liberación
  (EV-15b); undo exacto al reorganizar un bloque que aplicó evidencia; evidencia repetida en fusión
  (debe ser descarte, no invalidar el bloque); `EvidenceTx` que viola la forma v4 y aun así se acepta.
- **RI-3c (nodo):** estados que divergen entre nodos según el orden de llegada; ventanas en que un fallo
  deja el almacén y `zx-cadena` desalineados; doble firma posible tras reiniciar o tras reorganizar;
  rechazos clasificados como «legítimos» que en realidad ocultan una violación de invariante (W06d5
  decisión 3) o al revés; productor que produce sin garantía; atajos de desarrollo en la ruta de
  producción.

## Método, evidencia y entregable

Como `ORDEN-RI-1.md` §«Método y evidencia»: cada hallazgo con archivo y línea, regla del contrato,
escenario concreto (entrada → resultado erróneo), gravedad (**crítica / alta / media / baja**) y
**CONFIRMADO** (solo si lo reprodujiste en una copia de la raíz en tu zona —
`tar --exclude=./PDF --exclude=./deepseek --exclude=./target`, enlace `PDF` a `/home/katana/zeo/ZEROX/PDF`—
con un test mínimo en la copia, `CARGO_TARGET_DIR` y `CARGO_HOME` en tu zona, `--locked`, **como mucho 4
hilos** (`-j 4`, `RUST_TEST_THREADS=4`), pegando comando y salida literal) o **PLAUSIBLE**. Puedes copiar
la caché de dependencias de `deepseek/RI-2b/.cargo-home` (o `deepseek/SL4a/.cargo-home`) a tu zona; no la
uses en su sitio. Distingue hecho, derivación e hipótesis. No inventes números.

**No lances subagentes ni forks.** **Prohibido Python** (ni para auditar ni para probar). No leas ni
muestres credenciales (`.env`, `~/.dsh`, tokens). **`V-ZRX/LINEO.md` rige todo código que escribas** (el
test de reproducción incluido): léelo antes de escribir. Procesos largos en segundo plano con su PID
anotado; al terminar, ninguno vivo. Presupuesto: **2 h** de reloj.

**Entregable:** `deepseek/RI-3x/INFORME.md`: tabla de hallazgos ordenada por gravedad, detalle de cada
uno, y «revisado sin hallazgos» con la lista de archivos leídos enteros y los muestreados. En español. Si
no encuentras nada grave, dilo así; no rellenes.
