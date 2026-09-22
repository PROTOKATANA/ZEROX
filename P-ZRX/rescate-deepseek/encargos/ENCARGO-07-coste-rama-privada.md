# Encargo 07 — ¿Cuánto cuesta construir una rama privada con más `blue_work` que la honesta?

**Ejecutor:** DeepSeek, en la zona aislada `deepseek/`.
**Diseñado por:** Claude (Opus 5), 2026-09-18, bajo decisión de Katana del 2026-09-18.
**Categoría Veritas propuesta:** `seguridad` (dominante); `consenso` secundaria.
**Ruta de trabajo:** `deepseek/veritas/seguridad/coste-rama-privada-v1/`.
**Destino final, si se valida:** `veritas/seguridad/coste-rama-privada-v1/`.

---

## 0 · Antes de escribir una línea

**Lee íntegro `veritas/LINEO.md`.** Obligatorio por `AGENTS.md` y C-SPEC-03; su §8 te aplica entero.

Lee además:

1. **`veritas/consenso/poda-post-v1/`** (tu encargo 05) — en especial **D3** (`SR` endógeno), **D6**
   (multiplicidad de chunks y doble uso) y `PROCEDENCIA.md` §3.
2. **`deepseek/veritas/consenso/prueba-recursiva-v1/`** (tu encargo 06) — **INFORME §1.2 y §1.5.3**.
3. `SPEC.md` §11 completo, **C-HDR-06** (rango esperado contextual), **C-GD-01** (peso),
   **C-GD-02** (`blue_work` u256), **C-GD-07** (U2/U3″) y §7.2.
4. `TAREAS.md` §2.3 — el controlador R-FIN-13′ y lo que le falta.
5. `research/dag-poas-auditoria.md` — ATAQUE 2, A3 y A4.
6. `research/dag-poas-ancla-de-orden.md` — R-FIN-11 (identidad de billete) y R-FIN-8′.

---

## 1 · Por qué existe este encargo

Los encargos 05 y 06 cerraron dos vías de poda. Al validarlos apareció un **sobre-etiquetado** que
este encargo viene a reparar.

PRV-v0.1 concluye «selección: NO, demostrado, **no condicionado al coste**». La demostración es
correcta pero, tal como se enuncia, **aplica igual a Bitcoin**: si un adversario retiene una cadena
con más trabajo, un nodo nuevo que sólo ve la pública también elige mal. Y sin embargo Bitcoin es
utilizable. **Porque su seguridad nunca fue «es imposible engañar», sino «construir esa rama cuesta
mayoría del recurso».**

Así que el veredicto absoluto no distingue a ZEROX de nadie. **Lo que distinguiría a ZEROX es el
coste**, y ese coste no está medido: los dos informes lo dan por heredado de D6, que mide la lectura
de un certificado de niveles, **no el coste de un ataque de selección**.

**Esa medición es este encargo.** Decide algo que ninguna de las dos auditorías anteriores decide:
si ZEROX tiene un problema de **ingeniería** (poda difícil, como Ethereum PoS y su *weak
subjectivity*) o un problema de **consenso** (el umbral de seguridad es bajo).

---

## 2 · La pregunta

> Sea `α` la fracción del espacio total de la red que controla un adversario. **¿Cuál es el `α`
> mínimo con el que puede construir, en privado, una rama cuyo `blue_work` supere al de la rama
> honesta?** ¿Y cómo se compara con el `α > 0,5` que exige PoW?

Se pide **la curva**, no un sí/no: `α_mínimo` en función del horizonte temporal del ataque, de los
parámetros del DAG (`k = 30`, 15 padres, `mergeset ≤ 180`) y de los supuestos que declares.

---

## 3 · Tres trampas, dichas por delante

### 3.1 · El doble uso puede no bajar el umbral — y confundirlo sería el error del encargo

La intuición fácil es: «en PoST el mismo espacio sirve para dos historias, luego el ataque es más
barato». **Compruébalo, no lo asumas.** Hay una lectura alternativa que debes descartar o confirmar:

- **Caso A — publica sus bloques en la honesta y además los usa en la privada.** La honesta crece a
  `λ` (su tasa total, que **incluye** los bloques del adversario) y la privada a `α·λ`. Superarla
  exigiría `α·λ > λ`, es decir **`α > 1`: imposible**.
- **Caso B — no publica, sólo construye en privado.** La honesta crece a `(1−α)·λ` y la suya a
  `α·λ`. Superarla exige `α·λ > (1−α)·λ`, es decir **`α > 0,5`**, igual que PoW.

> ⚠️ **Corrección del 2026-09-18.** Una versión anterior de este encargo decía que el caso A exigía
> `α > 0,5`. **Era un error aritmético**: el caso A da `α > 1`. La conclusión de la trampa no cambia
> —por esta vía el doble uso no baja el umbral— pero la cuenta sí, y una cuenta mal escrita en un
> encargo se propaga al modelo. Si encuentras más errores como éste, dilo antes de ejecutar.

Entonces el doble uso quizá **no cambia el umbral** por esta vía, y lo que cambia es el **coste de
oportunidad**: el adversario puede cobrar recompensas en la pública mientras ataca en privado, que
en PoW no puede.
Eso es *nothing-at-stake*: una diferencia **económica**, no de umbral.

**Distingue las dos cosas explícitamente en el informe.** Son consecuencias muy distintas: la
primera rompe el consenso, la segunda encarece la honestidad. Si el resultado es «el umbral no baja
pero el ataque es gratis», dilo así y cuantifica «gratis».

### 3.2 · El `SR` endógeno puede proteger o puede ser el vector — mide la dirección

Tres hechos del SPEC se combinan y **nadie ha mirado qué sale**:

- `w(B) = ⌊2^128/(SR+1)⌋` (C-GD-01): **`SR` menor ⇒ peso MAYOR**.
- `rango_esperado(B) = controlador(past(B), flow(B, slot(B)))` (C-HDR-06): el `SR` es función
  **exclusiva del pasado de la propia rama**.
- Una rama privada tiene su propio pasado, luego **su propio `SR`**.

Si el controlador reacciona a una rama lenta **subiendo** `SR` (más fácil ganar), los bloques de esa
rama **pesan menos** y el controlador protege. Si reacciona al revés, o si el adversario puede
manipular el flujo o la ventana, la rama privada **infla su `blue_work` sin pagar espacio**, y eso
sí bajaría el umbral.

**Mide la dirección y la magnitud. No supongas cuál es.** PPP-v0.1 D3 dejó dicho que «el problema es
que el `SR` es endógeno» sin medir su efecto sobre `blue_work`.

⚠️ **Dependencia declarada:** R-FIN-13′ **no está completamente especificado** — `TAREAS.md` §2.3
deja pendientes arranque, ventana, redondeos, fusiones fuera de ventana y, literalmente,
«**validación de ramas candidatas con pesos reales**», que es este problema. **No inventes el
controlador.** Modela una **familia** de controladores razonables, declara sus supuestos, y di qué
propiedad tendría que cumplir R-FIN-13′ para que el ataque no funcione. Ese enunciado —«el
controlador **MUST** cumplir X»— es un entregable valioso aunque el resto salga inconcluso.

### 3.3 · Para el IBD el ataque es *long-range*, no una reorg corta

El adversario que engaña a un **nodo nuevo** no compite en tiempo real: puede construir su rama
durante meses y presentarla cuando quiera. Eso es distinto del doble gasto, donde compite contra el
reloj.

En PoW eso lo frena el trabajo acumulado: rehacer un año de cadena cuesta un año de hashrate
mayoritario. **En PoST el espacio se reutiliza en el tiempo**, así que hay que comprobar si la
misma lógica aplica. Modela **los dos** regímenes y no los mezcles:

- **corto** (reorg / doble gasto): el adversario compite contra la red en tiempo real;
- **largo** (IBD / *long-range*): el adversario dispone de tiempo arbitrario y sólo necesita superar
  el `blue_work` acumulado en el momento de presentar.

### 3.4 · U2/U3″ es contextual, y eso importa para el doble uso

C-GD-07 invalida o vuelve inerte la copia de un billete **dentro del pasado que la ve**. Una rama
privada **disjunta** de la pública sólo ve su propio pasado, así que un billete usado en ambas
**no es detectable desde dentro de ninguna de las dos**. Compruébalo contra el oráculo antes de
apoyarte en ello, en los dos sentidos: que U3″ **sí** bloquea el doble uso dentro de una rama, y que
**no** lo bloquea entre ramas disjuntas.

---

### 3.5 · Cuatro defectos de los encargos 05 y 06 que NO puedes heredar

Una revisión externa del 2026-09-18 encontró esto, y está verificado. **No construyas sobre ninguno
de los cuatro.**

1. **`H2` del encargo 06 no es una rama privada.** `src/rapido.jl:86` la construye como «`H1` más un
   bloque válido `Y` que **fusiona las puntas de `H1`**»: es una **extensión** de `H1`, no una rama
   competidora disjunta. El escenario del teorema (una `H2` retenida y disjunta con más `blue_work`)
   **nunca se instanció**. Si necesitas ese escenario, **constrúyelo de verdad**: ramas disjuntas
   desde un ancestro común, con billetes propios.
2. **El «verificador» del 06 no verifica nada sustantivo.** `src/rapido.jl:114` sólo comprueba
   `n ≥ 1`, que el índice de la punta esté en rango y que cada padre tenga índice menor. **No**
   verifica PoAS, PoT, GHOSTDAG ni recomputa `blue_work`. Que devuelva `true` no acredita validez.
3. **Contradicción interna del 05 sobre la población de bloques.** `MODELO.md:18` modela la
   distancia de un bloque como `D = min(d_1,…,d_C)` —un bloque por slot, el mejor chunk—, pero
   **D6 del mismo informe** dice que cada chunk ganador es **un billete distinto que puede ser su
   propio bloque**, y `map_winning_chunks` devuelve un `Vec<ChunkCandidate>`
   (`PDF/autonomys-subspace/crates/subspace-farmer-components/src/auditing.rs:236`). **Las dos
   descripciones no pueden ser ambas correctas.** Resuélvelo antes de modelar la tasa de producción
   del adversario, porque de ahí sale toda la curva `α`: si son `C` billetes independientes, un
   adversario produce más bloques por sector-slot de lo que `min(C)` sugiere.
4. **§12.1 no ofrece la salida que el 06 le atribuye.** El 06 propone «IBD desde checkpoint firmado
   (§12.1, C-CHK)». Pero **C-CHK-01** dice que existe **un único** checkpoint en la vida de la
   cadena y que **la clave se destruye** tras emitirlo, y **C-CHK-03** lo hace **caducar** en
   `ALTURA_CADUCIDAD`. Un checkpoint único y caducable **no** sirve como ancla de arranque
   permanente. No lo des por disponible.

## 4 · Alcance obligatorio

1. **La curva `α_mínimo`** para los dos regímenes del §3.3, con el DAG real (reutiliza **GDR-v0.2**,
   no reimplementes GHOSTDAG).
2. **Comparación con dos referencias**, bajo el mismo escenario y el mismo criterio de éxito:
   **PoW lineal** (Bitcoin, `α > 0,5`) y **GHOSTDAG sobre PoW** (Kaspa), para separar lo que aporta
   el DAG de lo que aporta el PoST. Sin esta comparación el número no significa nada.
3. **Umbral frente a coste económico** (§3.1), cuantificados por separado.
4. **El efecto del `SR` endógeno** sobre `blue_work` de una rama privada (§3.2), con la familia de
   controladores y la propiedad que R-FIN-13′ debería cumplir.
5. **Multiplicidad de billetes** (`m` ganadores por sector-slot, D6): efecto sobre la curva.
6. **U2/U3″ entre ramas disjuntas** (§3.4), comprobado contra el oráculo.
7. **Qué supuesto de red** usas (sincronía, Δ medida en `veritas/finalidad/delta-medido-v1/`), y
   cómo cambia la curva si se relaja.

---

## 5 · Prohibiciones explícitas

1. **No fijes parámetros** ni propongas constantes de producción.
2. **No uses `F = 2 h`**: es provisional.
3. **No inventes el controlador R-FIN-13′** (§3.2). Familia de controladores y supuestos declarados.
4. **No edites `SPEC.md` ni `TAREAS.md`.** Tus salidas van en `PROPUESTA.md`.
5. **Nada de Python.** Julia en CPU; C++/CUDA sólo si el perfil lo justifica.
6. **No toques nada fuera de `deepseek/`.** Registra `git status --short` al empezar y al terminar.
7. **Recorta el `Project.toml`**: solo lo que uses, stdlib incluida. (En el 06 lo hiciste bien.)
8. **No heredes un veredicto de los encargos 05 o 06 sin recalcularlo.** Este encargo existe
   precisamente porque un resultado se dio por heredado. Si usas D6, recalcúlalo para esta pregunta.
9. **No cites un archivo sin comprobar que existe**, con ruta desde la raíz del repositorio.

---

## 6 · Entregables

En `deepseek/veritas/seguridad/coste-rama-privada-v1/`, estructura de LINEO §1:

| Archivo | Contenido |
|---|---|
| `CONTRATO.md` | qué calcula, qué **no** acredita, presupuesto declarado **antes** de ejecutar |
| `MODELO.md` | el modelo: adversario, regímenes, supuestos de red, familia de controladores |
| `INFORME.md` | **la curva `α_mínimo` y la comparación con PoW/Kaspa primero**; después umbral vs coste, `SR` endógeno, multiplicidad, U3″. Etiquetas `demostrado`/`medido`/`estimado`/`no demostrado`/`inconcluso` |
| `PROPUESTA.md` | qué propiedad debería cumplir R-FIN-13′, y qué haría falta para cerrar lo inconcluso. **Propuesta, no SPEC** |
| `PROGRESO.md` | bitácora con `date`, no estimaciones |
| `HUELLAS.sha256` | rutas **desde la raíz del repo** |
| `src/`, `test/`, `bench/`, `run.jl`, `resultados/` | según LINEO §1 |

---

## 7 · Criterio de terminación

LINEO §10, y además:

**Los tres resultados posibles, y los tres son publicables:**

- **`α_mínimo ≈ 0,5`** → ZEROX está en la liga de PoW y el problema es de **ingeniería de poda**,
  como la *weak subjectivity* de Ethereum PoS. Es la mejor noticia posible.
- **`α_mínimo` sensiblemente menor** → el problema **no es la poda, es el consenso**, y afecta a
  todo el diseño, no sólo al IBD. Es la peor, y hay que decirla con todas las letras.
- **Inconcluso porque depende de R-FIN-13′** → entonces el entregable es **qué propiedad tiene que
  cumplir el controlador**, que es trabajo útil y convierte un pendiente vago en un requisito.

**Se rechaza:** dar por hecho que el doble uso baja el umbral sin demostrarlo (§3.1); suponer la
dirección del controlador (§3.2); mezclar los regímenes corto y largo (§3.3); y publicar un
`α_mínimo` sin la comparación con PoW y Kaspa bajo el mismo escenario.

**Si agotas el presupuesto:** para, checkpoint, **inconcluso**, con entrada mínima reproducible. Un
resultado parcial bien acotado en el régimen largo vale más que una curva completa en el corto.

---

## 8 · Después

Claude valida **reejecutando**, no leyendo tus `resultados/`. Sólo entonces se migra y se commitea.
`deepseek/` se borra al cerrar el encargo.

Si algo de este encargo te parece equivocado —y en particular si crees que alguna de las cuatro
trampas del §3 está mal planteada— **dilo antes de ejecutarlo**, no después.
