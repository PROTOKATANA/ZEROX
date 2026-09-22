# ADENDA-1 a `P-ZRX/P-PRESTAMO/PROMPT.md`

**Fecha:** 2026-09-21 · **Autor:** Claude (validador) · **Estado:** parte del encargo. Se lee **después**
del `PROMPT.md`, que **no cambia**. Donde esta adenda contradiga al prompt, **manda la adenda**.

Los cuatro encargos de la tanda 1 han entregado y Claude los ha validado (documental y aritmética; sin
reejecutar sus instrumentos). Tres resultados cambian tu punto de partida. **Ábrelos y léelos enteros:
no te fíes de este resumen** — el mismo día en que se escribe esta adenda, dos errores de Claude
salieron de citar una línea suelta en vez del documento completo.

## A · El baseline: léelo, y hay un agujero que te afecta directamente

`P-ZRX/P-CRP/auditoria/BASELINE.md` **existe**; el §1 del prompt te manda usarlo. Su §B enumera lo que
puedes dar por bueno (la identidad de la deriva; la maquinaria exacta de la DP, certificada; la
separación de los tres eventos; el patrón del filtro de flujo) y lo que **no**.

**Lo que más te afecta**, de `P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1: **en CRP-v0.2 y v0.3 `α` es una
probabilidad de oportunidad por slot, no una fracción de espacio**, y el puente `espacio → tasa`
(distancia circular, `sd ≤ SR/2`, chunks ganadores) **no está implementado en ningún instrumento del
repositorio**. El defecto D4 sigue abierto.

Consecuencia para ti: **declara, en la primera página y en cada tabla, si tu `α` y tu `β` son espacio o
tasa.** Si los tratas como espacio, aporta la derivación o **marca todo el resultado como condicionado a
ese puente**. Es tu principal hipótesis que codifica la conclusión.

Y `P-ZRX/P-CRP1/auditoria/CIFRAS.md`: de CRP-v0.1 **caen ocho cifras** y **cambian tres**. Sobrevive la
frontera de deriva `1/2` **como identidad aritmética del baseline**, no como umbral del protocolo. **No
escribas «el umbral de ZEROX es 1/2» en ninguna forma.** Si necesitas la compra de varianza (el
escenario 7 del §2 del prompt), usa los valores **recalculados por convolución exacta** de
`CIFRAS.md` —`0,021302 / 0,095029 / 0,227470 / 0,314998`—, no los publicados, y cita esa fuente.

## B · `κ` tiene un alcance más estrecho de lo que el prompt suponía

`P-ZRX/P-EQUIVOCACION/investigacion/` ya entregó. El prompt (§1) te decía que `κ` es «la fracción del
doble farmeo que deja evidencia castigable» y que la barrieras como símbolo. Sigue siendo un símbolo,
pero **su significado es más estrecho**:

1. **`κ` mide solo el doble farmeo PUBLICADO** (`DECISIONES-PENDIENTES.md` D14). Quien publica **solo la
   rama ganadora** no deja par de bloques y **ninguna identidad de billete lo alcanza**. Esa estrategia
   **no está cubierta por ningún castigo**: trátala como una **estrategia aparte** en tu §2, con su
   propio coste (retener tiene un precio: la rama puede perder), y **no la metas dentro de `κ`**.
2. **`κ` depende de la identidad de billete que se elija.** Medido: `C-GD-07` (la vigente) incluye
   `chunk` y **deja escapar dos soluciones distintas de la misma pieza** (`κ` cae de 1,000 a 0,000 en
   ese escenario); IDV-01 y la de `CANDIDATA.md` dan 1,000. **Barre `κ` por identidad**, no solo por
   valor.
3. **Fuera de esos escapes, `κ = 1`** salvo que el atacante gane la carrera del ancla, y entonces la
   fuga cubre solo **la cola** de la ventana (`PROPOSICIONES.md` P6: los slots divergentes son `≤ δ`,
   con `δ = s₀ − T_j`).

## C · La asimetría de la carrera del ancla: qué toca y qué NO toca

`PROPOSICIONES.md` P5 demuestra que, **dentro de la vista truncada `V_j(B)`**, el `blue_work` honesto
se detiene en el punto de bifurcación mientras el atacante sigue sumando hasta `T_j + L`: la carrera
**por el ancla** no es simétrica.

**Aviso de alcance, y es importante:** ese mismo P5 dice, literalmente, que **no contradice CRP-v0.1**,
porque aquello mide el umbral de una rama privada frente a la **cadena completa** — «mide **otro**
objeto». **Esta asimetría NO invalida tu baseline de deriva.** Lo que hace es **elevar la probabilidad
de que el atacante gane la carrera del ancla**, y por esa vía **bajar `κ`**.

Cómo tratarlo, sin rehacer su trabajo: la asimetría está **derivada, no medida** (`P5` y
`DECISIONES-PENDIENTES.md` D3). En tu modelo, **`κ` no es un parámetro libre independiente de `α`**:
parametriza `κ(α, δ, L)` —o al menos declara la dependencia y barre el caso pesimista— y **di en el
informe si tu conclusión cambia** entre `κ` constante y `κ` decreciente con la ventaja del atacante.

## D · Lo que P-PERMANENCIA cambia en la pérdida del granjero

`P-ZRX/P-PERMANENCIA/investigacion/INFORME.md`: el muestreo de piezas **no demuestra almacenamiento**
(el coste del tramposo es independiente del tamaño del lote), y las pruebas parciales **no añaden coste
sobre farmear**: lo hacen **observable**. Y **no existe** prueba de cobertura completa para el formato
fijado.

Consecuencia para el §2 de tu prompt: el término `c_r` (coste de replotear) y la maduración `M` **siguen
valiendo** como pérdida, pero **no supongas que una auditoría de permanencia detecta a quien no
almacena**: si en tu juego el granjero reclutado borra la parcela, **quien lo delata es que deja de
ganar bloques** (E5), no la auditoría. Declara qué esquema de permanencia supones en cada fila.

## E · Lo que NO cambia

Todo lo demás del `PROMPT.md` sigue en pie: el modelo del §2, las seis preguntas del §3, la zona de
trabajo, las huellas, el modelo de amenaza de Katana (el coste absoluto además del relativo; «no
compensa» no es argumento de seguridad) y las reglas de validez del §7. **Si esta adenda te parece
equivocada, dilo ANTES de empezar**, en tu primera respuesta y en `PROGRESO.md`.

## F · Lecturas añadidas (ábrelas enteras)

- `P-ZRX/P-CRP/auditoria/BASELINE.md` — **obligatoria**, en especial su §B.
- `P-ZRX/P-CRP/auditoria/DEFECTOS.md` — C1 (el puente espacio→tasa), A1 (semillas consecutivas).
- `P-ZRX/P-CRP1/auditoria/CIFRAS.md` — qué cifra de CRP-v0.1 se sostiene, cambia o cae.
- `P-ZRX/P-EQUIVOCACION/investigacion/PROPOSICIONES.md` — P5, P6, P7, P10.
- `P-ZRX/P-EQUIVOCACION/investigacion/DECISIONES-PENDIENTES.md` — D3, D14.
- `P-ZRX/P-PERMANENCIA/investigacion/INFORME.md` — F1, F2 y la tabla comparativa de esquemas.
