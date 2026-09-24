# Hoja de ruta de ZEROX 0.0.1

Estado: en ejecución desde 2026-09-24. Las órdenes detalladas se incorporan antes de abrir cada pieza; la primera es [ORDEN-A1.md](ORDEN-A1.md). Una pieza solo se cierra tras las seis condiciones de `PROMPT.md` §6.

## Recuento y alcance

La lista de `PROMPT.md` contiene **18** casillas: 3 A + 3 B + 3 C + 3 D + 2 E + 4 F. Sus menciones a «17» son un error aritmético. Se conserva cada identificador; el avance se expresará como **n/18** y se indicará la discrepancia al usuario.

La 0.0.1 usa una ruta DAG construida al lado de `Cadena` lineal y conmuta al final. Solo coinbase; el rango y la configuración de una red de desarrollo deben permanecer marcados como desarrollo, sin convertirse en parámetros de producción. Ninguna aceptación de PoAS, PoT, rango o flujo puede quedar simulada en la ruta que declare validez.

## Orden y dependencias

| Tramo | Piezas | Dependencia para empezar | Salida comprobable |
|---|---|---|---|
| 1 | A1 | API pública de Autonomys fijada; contexto de pieza explícito | Solución PoAS completa aceptada/rechazada; distancia calculada |
| 1, en paralelo tras delimitar interfaces | preparación estructural de A3, preparación de B1, C3, F1, F3 | Ninguna modificación concurrente del mismo fichero | Codec/cabecera, reparación de undo, génesis y sondas aislados |
| 2 | A2 | A3 estructural y pasado DAG contextual; núcleo `pot_rango.rs` | PoT con tres estados, flujo/contexto acreditados |
| 2 | cierre de A3 | A2 y contexto causal de altura, rama, rango y pieza | Puerta conjunta que rechaza con motivo, conserva pendientes y solo acepta una cabecera completa tras todas las pruebas |
| 2 | B2 | B1 | UTXO/undo durables con reinicio |
| 2 | D1 | A1 | Parcela reproducible y auditor por slot |
| 3 | C1 | A1, A2, A3, C3 | Cabecera DAG atraviesa nodo/almacén; test 556 sin `ignore` |
| 3 | E1 | A3, C1 | Anuncios `/blocks/2` despachados y relé compacto conectado |
| 4 | C2 | B1, C1 | `ContextoDag` desde almacén; orden y reorg deterministas |
| 4 | B3 y cierre de B1 | A1, A2, motor de B1, C1, C2 | `bloque_difundido` valida; estado UTXO se aplica solo al orden DAG de bloques completos válidos y revierte atómicamente |
| 4 | E2 | C2, B2, B3 | IBD DAG y recuperación autónoma |
| 4 | F2 | C2 | Contadores de DAG/orden/reorg exportables |
| 5 | D2 | C2, D1, C3, B3 | Padre barajado, coinbase, sello, publicación |
| 5 | D3 | D2 | Durabilidad `oportunidad → pre_hash` antes de firmar |
| 6 | F4 | D1, D2, D3, E1, E2, F1-F3 | Red local repetible de N nodos |
| 7 | Cierre integral | Las 18 piezas | 3 nodos/30 min, convergencia demostrada, recuperación, rechazo PoAS, métricas |

El orden de la tabla es de implementación, no de activación: los módulos aislados no admiten bloques hasta que toda la ruta de validez esté conectada. `C-FLU-13/14` y `C-HDR-06` siguen siendo requisitos normativos; «un flujo» y «rango fijo» solo pueden vivir en una red de desarrollo explícita mientras el controlador y el derivador permanezcan pendientes.

**Dependencia B1 descubierta por revisión independiente:** `Cadena::adoptar/extender` recibe únicamente cabeceras y el cuerpo llega después. `C-ORD-03/04` exige aplicar la proyección económica del DAG, no todos los cuerpos por llegada ni una cadena lineal. Por ello B1 puede empezar con un motor aislado para bloques completos ya validados, pero no se marca hasta que B3 y C1/C2 le den orden y validación activos. `C-REORG-02` además exige comparar el contenido de cada salida creada durante el undo; hoy `UndoData.creados` conserva solo `OutPoint`. Ver `PROGRESO-0.0.1.md`.

**Dependencia A3 descubierta por revisión independiente:** el codec canónico, `pre_hash`, `block_hash`, sello ZIP-215, límites wire y comprobaciones contextuales de padres/rango ya existen por separado. Falta la puerta conjunta. `C-HDR-02` deja pendiente la semántica de altura DAG, `C-HDR-06` carece de controlador del rango derivado del pasado, y A2 aún no acredita la salida PoT del slot auditado ni el contexto de pieza. Una puerta estructural puede devolver `Inválido` o `Pendiente`; no puede devolver `Válido` global hasta tener esas fuentes causales. No usar `header.height` como altura acreditada para `C-HDR-02b` ni `header.pot_output` futuro como salida PoT de A1.

**Orden obligatorio A2→A3:** `C-POT-08` pide estructura (1), flujo (1b), sello (2), caché (3), AES (4), PoAS (5). `verificar_rango_pot` hoy reúne 1/1b/3/4; llamar al núcleo entero antes del sello gasta AES demasiado pronto, y llamarlo después invierte los pasos 1/1b y 2. La integración debe separar las fases o darles una interfaz equivalente que preserve ese orden. Pruebas espía: sello inválido no consume AES ni consulta caché; flujo/padres inválidos no verifica sello; PoT pendiente no invoca PoAS ni admite bloque.

## Órdenes y revisión

- **A1:** [ORDEN-A1.md](ORDEN-A1.md) y [CORRECCION-A1.md](CORRECCION-A1.md), enviadas a DeepSeek Harness, ruta `deepseek-official/deepseek-flash` (catálogo local: DeepSeek-V41-Flash), esfuerzo `high`. Adaptador y 14 tests verificados. Katana autorizó la excepción acotada para `Cargo.toml`, `Cargo.lock` y `ci/consenso-pendiente.txt`; guardianes y gates Rust verdes. **Cerrada como adaptador del paso 5 de C-POT-08, todavía sin ruta activa del nodo; se cablea en C1/B3.**
- **A2–F4:** no emitidas todavía. Antes de cada envío se especificarán firma, API concreta, archivos permitidos, errores, tests y regla aplicable, después de leer el módulo y el SPEC. No se anticipa una firma basada en código aún inexistente.

Al cerrar cada pieza: inspección de diff y `git status`, pruebas y guardianes pertinentes, commit local propio con IDs de SPEC, actualización de `PROGRESO-0.0.1.md`. Nunca push.
