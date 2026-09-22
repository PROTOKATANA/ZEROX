# P-FLUJO — Propuesta de SPEC para la regla de flujo del PoT (perfil 1a, `L ≥ F`)

**Ejecutor:** agente independiente. **Zona de trabajo: `P-FLUJO/propuesta/`.**
**Diseñado por:** Claude, 2026-09-19, con las decisiones DF-1…DF-4 de Katana del mismo día.
**Tipo de trabajo:** redacción de una **propuesta de SPEC** con citas a fuente y demostraciones cortas.
**No es una auditoría de cálculo** y **no escribes código del nodo.**
**Entregable principal:** `P-FLUJO/propuesta/PROPUESTA-SPEC.md`.

## 0 · Dónde encaja

`TAREAS.md` §2.1 (verificación conjunta PoAS/PoT) se cierra con **dos** propuestas que encajan por una
interfaz: `P-POT/propuesta/PROPUESTA-SPEC.md` (**ya hecha y validada**: el PoT como primitiva, el
verificador, la caché y el orden de validación; reglas `C-POT-01…08`) y **esta**, que define lo que
aquella dejó como **entradas que aporta el contexto**: qué es el **flujo**, quién es el **ancla**, cuándo
se **activa** la entropía, y qué pasa con flujos distintos. `P-POT` trata el flujo como un valor opaco de
32 bytes y recibe del contexto `semilla(f,s)`, la entropía de cada inyección, su slot de activación y el
origen `semilla(f,0)`: **tú defines de dónde sale todo eso.**

La fase de medición está cerrada y validada. **Lee primero `P-2.1/SINTESIS.md`**: es una página y resume
lo establecido, con su alcance.

## 1 · Decisiones ya tomadas por Katana (2026-09-19) — no las reabras

| # | Decisión |
|---|---|
| **DF-1** | **Perfil 1a: `L ≥ F`**, expresado como **`L` atada a `F`** (si `F` baja en producción, `L` baja con ella). El perfil 1b (`L < F`) queda **fuera**: solo se menciona como mejora futura condicionada a medir la Δ real en una testnet y el ataque de equilibrio adaptativo |
| **DF-2** | **No se añade ninguna regla de adopción entre flujos.** La selección de cadena ordinaria y la finalidad ya lo cubren |
| **DF-3 / DF-4** | Se reducen a **declarar** que una partición de flujo **equivale a una violación de finalidad** y se trata como tal. No se legisla el nodo recién llegado ni la producción en un flujo no seleccionado más allá de esa declaración |
| D-1 / D-2 (de `P-POT`) | Las derivaciones del PoT conservan **`blake3` byte a byte** como Autonomys; el `pot_output` único de la cabecera es la **salida futura** `salida(f, slot(B)+D)` |

## 2 · La afirmación central — DEMUÉSTRALA O REFÚTALA, no la supongas

Es razonamiento del diseñador y **nadie lo ha revisado**. Toda la propuesta cuelga de ella:

> Dos nodos derivan flujos distintos solo si tienen **anclas distintas** `I_j`. Anclas distintas implican
> que sus **cadenas seleccionadas difieren desde la posición del ancla**, y en el instante de activación
> `t_j = slot(I_j) + L_slots` esa divergencia tiene profundidad `≥ L`. Con **`L ≥ F`**, es una divergencia
> **más profunda que la finalidad**: la regla de finalidad ya manda ignorar la rama rival. Luego, bajo 1a:
> **(a)** una partición de flujo solo puede nacer de una **violación de finalidad**; **(b)** un nodo
> honesto **nunca necesita verificar el PoT de un flujo ajeno** —ver un ancla distinta ya es evidencia
> **estructural** de una bifurcación más profunda que `F`—, así que R-FIN-5 conserva intacta su virtud y
> no se reabre ningún DoS de verificación; **(c)** la ventana en la que cabría «adoptar» el flujo rival es
> `F − L ≤ 0`: vacía.

Entrega la demostración con sus hipótesis explícitas, o el contraejemplo. **Tres bordes que debes resolver:**

1. **`L = F` exacto.** ¿La finalidad prohíbe reorganizar «por debajo de `F`» con desigualdad estricta o
   no? Un caso con profundidad exactamente `F` en el instante de activación, ¿cae dentro o fuera? Propón
   la desigualdad que cierra el borde y di si hace falta un margen (`L ≥ F + algo`).
2. **Unidades.** `L_slots` es un número de slots de PoT; `F` está escrita en **segundos de slot**
   (`τ_nom = 1 s/slot`). `slot(I_j) ∈ [T_j, T_j + S_max_slots)`. Usa el contrato de unidades de
   `SPEC.md` §7.3 y di en qué magnitud se compara la profundidad.
3. **Qué regla de finalidad.** El repositorio tiene **dos**: R-FIN-7 (`research/`, «no reorganizar por
   debajo de `F` segundos de slot», `F = 2 h` **provisional**) y `C-REORG-07` en el SPEC vivo
   (`MAX_REORG_LENGTH`, en bloques, con semántica *fail-stop*). Localízalas, di de cuál cuelga tu
   demostración, y si la elección no está determinada, **elévala como decisión**; no la tomes.

## 3 · Lecturas obligatorias (acotadas; ábrelas antes de citarlas)

1. `P-2.1/SINTESIS.md` entero.
2. `P-POT/propuesta/PROPUESTA-SPEC.md` entero: es la **interfaz** con la que tienes que encajar, y tu
   plantilla de estilo y de etiquetado. Forma general: `veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md`.
3. `research/dag-poas-ancla-de-orden.md`: R-FIN-1 (l. 169-191, con su «cierre pendiente», su corrección de
   alcance del 2026-09-10 y el historial de anclas), R-FIN-1a (l. 203-210), R-FIN-2…5 (l. 212-225),
   R-FIN-14 (l. 258-296), R-FIN-7 (l. 301-307), R-FIN-9 (l. 377-381). **Evidencia histórica**
   (`research/README.md`): da el diseño candidato, no texto normativo.
4. `research/dag-poas-inyeccion-auditoria.md` l. 80-115, l. 218 y l. 477: la **circularidad E1** y su reparación,
   `S_max < L`, la cascada, y que la equivocación no parte el flujo.
5. `research/scripts/d9-ronda11c/informe.md` l. 39-65: Prop. 1, «R-FIN-1 ≡ primer cruce de `T_j`».
   Ojo: esa ronda **murió por cuota**; la proposición está demostrada en el texto, sus mediciones no
   están verificadas.
6. `SPEC.md`: §6.1 (**C-HDR-05, C-HDR-06** —que ya usa `flow(B, slot(B))` sin definirlo—, **C-HDR-07**),
   §7.1 y §7.3 (l. 1278-1473, el contrato de unidades), la cabecera de §11, C-HASH-06 (lista **cerrada**
   de etiquetas de dominio de 16 bytes), y `C-REORG-07`.
7. `TAREAS.md` §2.1 y §4.2 (IDs de regla nuevos y estables; nunca reutilizar uno retirado).

## 4 · Lo que tienes que proponer

Reglas con IDs nuevos (familia propuesta **`C-FLU-NN`**; hoy no existe ninguna), en el estilo normativo
del SPEC, cada una con su justificación, su cita y su etiqueta.

1. **El ancla, bien fundada.** R-FIN-1 es **circular** tal como está escrita (E1: el ancla depende de la
   cadena, la cadena de la validez, la validez del ancla) y su reparación, conocida desde 2026-09-07,
   nunca se incorporó: el ancla de la época `j` se calcula sobre `past(B) ∩ {slot < t_j}`, por inducción
   sobre `j`. Redáctala ya reparada, como **primer cruce de `T_j = j·I_slots`** por la cadena seleccionada
   (menor `blue_work` entre los de `slot ≥ T_j`; cita la Prop. 1), con R-FIN-1a no estricta, y **demuestra
   que queda bien fundada**: existencia y unicidad para todo `j`.
2. **El caso sin ancla y el arranque.** Qué flujo rige mientras la cadena no alcanza `T_j`; el flujo del
   génesis y el origen de `semilla(f, 0)` (lo que `P-POT` dejó abierto); la primera época.
3. **Activación retardada.** `t_j = slot(I_j) + L_slots`; hasta `t_j` rige el flujo anterior (**una sola
   lotería**); a lo sumo una inyección por slot y `t_j` distintos dos a dos; y las dos condiciones sobre
   `S_max_slots`: `S_max_slots < L_slots` (**de corrección**: sin ella un bloque retenido con slot junto a
   `T_j` cambia el ancla tras la activación) y `S_max_slots < I_slots` (suficiente del perfil).
4. **El identificador de flujo**, acumulativo y **derivado del pasado, nunca declarado** por quien
   construye el bloque (el principio de C-HDR-06: la circularidad **imposible**, no desaconsejada). Encaja
   la definición con el `flow(B, slot(B))` que C-HDR-06 ya usa.
5. **La entropía de la inyección** que recibe `P-POT`.
6. **Validez absoluta y pasado consistente de flujo** (R-FIN-4, R-FIN-5): comprobación **estructural y
   anterior a cualquier PoT**, encajada con el orden de validación de `C-POT-08`.
7. **La declaración DF-3/DF-4:** partición de flujo ≡ violación de finalidad, con lo que eso implica para
   un nodo que sincroniza desde cero (remite a los mecanismos que el SPEC ya tiene; no inventes otros).
8. **El cambio de `N(s)`** coincide con `t_j` (R-FIN-9); su autoridad de actualización está pendiente:
   va como símbolo.

## 5 · Decisiones que NO te toca tomar: preséntalas con su coste

En `DECISIONES-PENDIENTES.md`, cada una con lo que gana, lo que paga y lo que cierra, y tu recomendación
**marcada como tal**. Como mínimo:

- **Contenido de la entropía.** `blake3(chunk ‖ pot_output)` como Autonomys y R-FIN-2 (coherente con D-1)
  frente a incluir la **identidad completa del billete** `(public_key, sector_index, history_size, chunk,
  slot)`, que ata §2.2 con §2.1 y evita que dos billetes con el mismo chunk den la misma entropía, pero
  obliga a cerrar §2.2 antes o a la vez.
- **Hash del identificador de flujo.** Es un objeto propio de ZEROX, no de Autonomys: `H_d` con una
  etiqueta nueva de 16 bytes (coherente con C-HASH-06, que habría que ampliar) frente a `blake3`.
- **El borde `L = F`** y **la regla de finalidad de la que cuelga** (§2, bordes 1 y 3), si no quedan
  determinados.
- Cualquier otra bifurcación real que encuentres.

## 6 · Fuera de alcance — si lo tocas, se rechaza

El PoT como primitiva, el verificador, la caché y el orden de validación (son de `P-POT`; **encaja con
ellos, no los reescribas**; si ves un defecto, anótalo aparte). Los **valores** de `I`, `F`, `ρ_max`, `D`
y `N(s)`: van como **símbolos**. La revelación retardada R-FIN-14(h). El perfil 1b. Cualquier regla de
adopción entre flujos.

## 7 · «Lo que esta propuesta NO resuelve» — sección obligatoria de cierre

Con etiqueta estrecha, como mínimo: la evidencia de medición es **simulada** (la Δ de DMS-v0.1 no es una
medición de red); las vías de ataque medidas son las simples (A3 **estática**, V1 con tope de 8
candidatos y ventana de 45 slots) y **no** el equilibrio adaptativo, el soborno del ancla, el sembrador ni
un adversario con VDF más rápido; la convergencia del orden de GHOSTDAG (Prop. 7) está probada sobre
GHOSTDAG **puro** y no bajo U3″ + R-FIN-5 + R-FIN-8′ («la deuda principal» de `ancla-de-orden.md` §5); el
coste de 1a (adelanto `L` de la entropía; margen histórico frente al sembrador 1,91×, con precios
supuestos); y el camino a 1b con sus condiciones.

## 8 · Reglas de trabajo

1. **Escribes solo dentro de `P-FLUJO/propuesta/`.** No edites `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`,
   `research/`, `P-2.1/`, `P-POT/`, `P-PUERTA/` ni `deepseek/`. **No muevas ni reorganices archivos ajenos.**
2. `P-FLUJO/ENCARGO.md`, `PROMPT.md` y `ENTRADA.sha256` son de **solo lectura**. Al empezar y al terminar,
   desde la raíz: `LC_ALL=C sha256sum -c P-FLUJO/ENTRADA.sha256` y `git status --short`, con su salida y la
   de `date` en `PROGRESO.md`. `P-FLUJO/` saldrá como `?? P-FLUJO/`; el resto debe quedar idéntico.
3. **Nada de Python.** No hace falta cómputo; si una demostración pide una comprobación de juguete,
   Julia con `./veritas/julia.sh`, ≤ 2 hilos y segundos, dentro de tu zona.
4. **No cites un archivo o una línea sin abrirlo.** Rutas completas desde la raíz del repo, **también en
   las repeticiones** (nada de `pot.rs:284` a secas).
5. **Etiqueta cada afirmación:** `demostrado` (con la prueba), `verificado en fuente` (con cita),
   `propuesto`, `medido en simulación` (con el instrumento y su alcance), `no determinado por el SPEC`.
   El patrón que este repositorio lleva repitiendo es el resultado de alcance estrecho con etiqueta ancha:
   no lo repitas. Un «no lo sé» explícito vale más que una regla que haya que retirar.

## 9 · Entregables (`P-FLUJO/propuesta/`)

`PROPUESTA-SPEC.md` · `DECISIONES-PENDIENTES.md` · `PROGRESO.md`.

**Si algo de este encargo te parece equivocado —en particular la afirmación central del §2— dilo ANTES
de redactar**, en tu primera respuesta. Después Claude valida tus citas y tus demostraciones contra la
fuente, Katana decide lo pendiente, y solo entonces algo de esto pasa al SPEC.
