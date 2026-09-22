# PROCEDENCIA — PRV-v0.1

Instrumento ejecutado por **DeepSeek** en la zona aislada `deepseek/`, según
`ENCARGO-06-prueba-recursiva.md`. **Validado por Claude reejecutando** y migrado el 2026-09-18.

> ## ⚠️ LEER ANTES DE CITAR NADA DE ESTE INSTRUMENTO
>
> **Su §1 (la demostración de imposibilidad de la selección) NO acredita lo que afirma.** Dos
> defectos verificados en el código lo invalidan como evidencia, y están detallados en §3.
> **No cites `INFORME.md` §1.2 ni §1.3 como demostración.**
>
> **Su §2 (coste de probar GHOSTDAG) sí vale**, con una etiqueta que el informe no pone con
> suficiente claridad: es una **estimación por conteo de operaciones con factores citados**, no una
> medición. No existe circuito Halo2 ni banco de probador.
>
> Se conserva porque el conteo de operaciones es reutilizable y porque los defectos son
> contraejemplos útiles —el repositorio conserva evidencia histórica, incluidas propuestas
> descartadas—, no porque su veredicto principal se sostenga.

## 1 · Qué reejecutó Claude

| Comprobación | Resultado |
|---|---|
| Suite `--check-bounds=yes` | **20/20** ✓ |
| `HUELLAS.sha256` desde la raíz | **exit 0** ✓ |
| Experimento de selección (`--seleccion`) | reproducido ✓ |
| Factor DAG/lineal (`--lineal`) | **918×** reproducido ✓ |
| Aritmética: `2,88e8` restricciones → 288 s/bloque | cuadra ✓ |
| `git status` del ejecutor | intacto ✓ |
| `Project.toml` | 9 dependencias, solo las usadas ✓ |

**La reproducibilidad interna es correcta. Eso acredita que el instrumento hace lo que dice hacer,
no que lo que hace demuestre la conclusión.** Es justamente la distinción que faltó en la primera
validación.

### 1.1 · Tres huellas que ya no coinciden, a propósito

`sha256sum -c` da `SPEC.md: FAILED`, `TAREAS.md: FAILED` y
`veritas/consenso/poda-post-v1/PROCEDENCIA.md: FAILED`. Es correcto y no se «arregla»: los tres se
editaron **después** de que el ejecutor tomara la huella, y se editaron **con el resultado de este
instrumento y con los defectos que la revisión externa encontró**. Actualizar la huella borraría la
prueba de qué versión se auditó. Mismo criterio que `veritas/consenso/poda-post-v1/PROCEDENCIA.md`
§1.1 y que `veritas/finalidad/delta-medido-v1/METODO.md` §84.

## 2 · Lo que sí se sostiene

- **El coste es alto y la cota es inferior.** `2,88e8` restricciones por bloque con `M=180`,
  `W=1000` y Halo2 realista (`1e6` restricciones/s) son **288 s/bloque**: no cierra a 1 bloque/s.
  Excluye explícitamente Ed25519, KZG, PoT, UTXO y la verificación recursiva de la prueba anterior,
  así que incluirlos sólo lo empeora.
- **El factor Poseidon está citado**: `P128Pow5T3`, 80 S-boxes (`halo2_poseidon` 0.1.0), que es la
  primitiva de Orchard (SPEC §9).
- **La distinción «no cierra a esta tasa» ≠ «no puede funcionar»** está bien hecha, con las tres
  salidas cuantificadas (`W` pequeña, probador 10²–10⁵× más rápido, o tasa objetivo menor).
- **Tener `orchard` en el árbol no entrega recursión.** Correcto como afirmación sobre la
  implementación: `zcash/halo2` no expone verificador-en-circuito listo para usar. ⚠️ Matiz: decir
  que «Halo2 no es un sistema de recursión» es **demasiado categórico** — el esquema Halo se diseñó
  con *accumulation* precisamente para recursión; lo que falta es implementación disponible, no
  posibilidad teórica.
- **El factor 918× es conservador.** Se calcula sobre el DAG medido (contexto real ≈205 en `n=512`),
  no sobre el estacionario del modelo paramétrico. Con contexto lleno a `W=1000` saldría ≈4 400×.
  Las dos cifras son legítimas y el código las declara, pero el informe las presenta seguidas sin
  decir que vienen de modelos distintos.

## 3 · Lo que NO se sostiene — defectos verificados

Encontrados por una **revisión externa del 2026-09-18** y confirmados por Claude en el código.

### 3.1 · `H2` no es una rama privada competidora

`src/rapido.jl:86`, en su propio docstring: «`H2` = `H1` más un bloque válido `Y` que **fusiona las
puntas de `H1`**». Eso es una **extensión** de `H1`, no una rama disjunta retenida.

El teorema de §1.2 habla de un mundo 2 donde existe «`H2`, una rama privada **válida** con
`max blue_work(H2) > max blue_work(H1)`, que el adversario **retiene**». **Ese escenario nunca se
construyó.** Lo que el experimento muestra es que añadir un bloque a un DAG cambia su punta
canónica, que es el comportamiento normal de GHOSTDAG y no necesita demostración.

### 3.2 · El «verificador de validez» no verifica validez

`src/rapido.jl:114` comprueba exactamente tres cosas: que `n ≥ 1`, que el índice de la punta esté en
rango, y que cada padre tenga índice menor que su hijo. **No verifica PoAS, ni PoT, ni GHOSTDAG, ni
recomputa `blue_work`.** Es una comprobación de que el grafo está bien formado.

Por tanto `verifica_prueba_validez(H1) = true` en `run-certificado.txt` **no acredita** que `H1` sea
una historia válida bajo las reglas del protocolo, y la tabla de §1.3 no dice lo que parece decir.

### 3.3 · El argumento prueba demasiado

Aun concediendo la lógica de §1.2, lo que demuestra es que **un verificador determinista no puede
saber de una rama que no ha recibido**. Eso es cierto en **Bitcoin igualmente**, y Bitcoin es
utilizable: su seguridad nunca fue «es imposible engañar» sino «construir esa rama cuesta mayoría
del recurso».

El informe reconoce esto en dos sitios —§1.2 final («sólo sería cierto relativo a un supuesto de
recursos acotados») y §1.5.3 («es un supuesto, no una prueba»)— pero su **veredicto** lo contradice:
«**NO**, demostrado, **no condicionado al coste**». Un teorema no condicionado al coste no puede
explicar por qué ZEROX estaría peor que Bitcoin, porque no los distingue.

**Lo resolvió el encargo 07** (`veritas/seguridad/coste-rama-privada-v1/`), midiendo el coste: el
umbral resultó ser `α = 1/2`, **el mismo que PoW**.

### 3.4 · §12.1 no ofrece la salida que se le atribuye

`INFORME.md` §1.5.1 propone «IBD desde checkpoint firmado (§12.1, C-CHK)» como lo que sí resolvería
el arranque. Pero el SPEC dice otra cosa:

- **C-CHK-01**: existe **un único** checkpoint en la vida de la cadena, y **la clave se destruye**
  tras emitirlo;
- **C-CHK-03**: la autorización **caduca** en `ALTURA_CADUCIDAD`.

Un checkpoint **único y caducable** no puede ser el ancla de arranque permanente de todo nodo nuevo.
Usarlo así exigiría cambiar C-CHK-01 y C-CHK-03 —pasar a checkpoints recurrentes—, que es un
**cambio material del modelo de confianza**, no un detalle de integración.

## 4 · Dos errores de Claude en la primera validación

1. **Validé la reproducibilidad y llamé «sólido» al resultado.** Reejecuté la suite, las huellas y
   los experimentos, todos correctos, y de ahí pasé a dar por bueno el veredicto. Reproducir no es
   validar: los defectos de §3.1 y §3.2 estaban **escritos en los docstrings del código** que
   reejecuté. Reproducir un experimento no comprueba que el experimento pruebe lo que dice.
2. **Sobreafirmé al resumir**: dije «dos caminos cerrados con evidencia» cuando el coste era una
   estimación declarada y el argumento de selección no acreditaba lo suyo.

## 5 · Estado

**Conservado como instrumento de estudio, no como veredicto.** Su §2 (coste) es reutilizable con la
etiqueta de estimación. Su §1 (selección) queda **superado** por el encargo 07, que respondió la
pregunta correcta —cuánto cuesta— en vez de la trivial —si es posible engañar sin ver los datos.
