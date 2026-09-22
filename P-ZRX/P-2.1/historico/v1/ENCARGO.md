# P-2.1 — ¿Existe una ventana de anclaje para la inyección del PoT?

**Ejecutor:** DeepSeek, en la zona aislada `deepseek/P-2.1/`. Este encargo y su prompt viven en `P-2.1/` (solo lectura para el ejecutor).
**Diseñado por:** Claude (Opus 5), 2026-09-18, bajo decisión de Katana del 2026-09-18.
**Categoría Veritas propuesta:** `consenso` (dominante); `seguridad` secundaria.
**Ruta de trabajo:** `deepseek/P-2.1/veritas/consenso/ancla-inyeccion-v1/`.
**Destino final, si se valida:** `veritas/consenso/ancla-inyeccion-v1/`.

---

## 0 · Antes de escribir una línea

**Lee íntegro `veritas/LINEO.md`.** Obligatorio por `AGENTS.md` y C-SPEC-03; su §8 te aplica entero.

Lee además, y en este orden:

1. `research/dag-poas-auditoria.md` — **ATAQUE 1** y **ATAQUE 2** completos. Son el origen.
2. `research/dag-poas-ancla-de-orden.md` — **R-FIN-14 entera** (líneas 258-283), en especial los
   apartados **(e)**, **(f)**, **(g)** y **(h)**; y **R-FIN-5** (línea 223).
3. `research/pot-aes-asic-chacha.md` — **§3 completo**: los límites **físicos** de `ρ`.
4. `veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1) — el encargo 07, tuyo, ya validado:
   `INFORME.md` §5 (multistream) y `PROCEDENCIA.md`.
5. `TAREAS.md` §2.1 y §3.3.

---

## 1 · El problema, y por qué este encargo existe

ZEROX tiene **un único punto medido que degrada su umbral de seguridad**: el multistream de PoT
(ATAQUE 2). Con `S` flujos simultáneos, `α_mínimo = 1/(S+1)` — **0,040 con `S = 24`**, sin espacio
adicional. El resto del diseño aguanta en `α = 1/2`, igual que PoW (CRP-v0.1).

La defensa es **un flujo global único**, con la entropía de inyección anclada a un **prefijo
estable** de la cadena. Pero el ATAQUE 1 declara una contradicción:

> *«Tomar entropía y target slot de un bloque de cadena a profundidad ≥ finalidad del DAG choca con
> la otra función de la inyección: acotar la ventaja de un VDF rápido. Las dos exigencias —rezago
> corto para el VDF, rezago largo para el DAG— son contradictorias; no hay fuente que las
> reconcilie. Laguna.»*

**Tu pregunta:** ¿existe una profundidad de anclaje `D` que sea a la vez **suficientemente profunda**
para que el ancla sea única entre nodos honestos, y **suficientemente somera** para que el diseño
siga siendo viable? Y si existe, ¿en qué región de `(ρ, F)`?

---

## 2 · Aviso: el modelo del encargo anterior era incorrecto

**Lo escribió Claude y lo corrige aquí antes de que lo heredes.** En una discusión previa se modeló
la ventaja del VDF rápido como un **adelanto temporal** `(ρ−1)·D`, del tipo «con lookback de 12 h y
`ρ = 2`, el atacante va 12 h por delante».

**Ese no es el modelo del repositorio, y R-FIN-14 ya tiene el correcto.** El ataque no es ir por
delante en el reloj: es **steering por elección de ancla** — evaluar candidatos a ancla antes de
tener que elegir uno. Su magnitud, según R-FIN-14: **`n_eval = ρ·W_dec`** tras un *bootstrap* de
días, y con `ρ ≤ 1` el steering es **0**, porque evaluar un candidato exige conocer la cadena común
`L` slots por delante.

La calibración que R-FIN-14(f) ya prescribe es **`I ≥ ρ_max · W_dec`**, con `W_dec ≤ 45 s` **medida**
en la ronda 9c. Eso da del orden de **112–135 s**, no de horas.

**Consecuencia:** las dos exigencias del ATAQUE 1 pueden no ser contradictorias, porque hablan de
cosas distintas — `D` es una **profundidad** (estabilidad del ancla) e `I` es un **periodo** (entre
inyecciones). Confundirlas es lo que hace parecer imposible el problema. **Comprueba esto antes de
nada: si es correcto, cambia el encargo entero y hay que decirlo el primer día.**

---

## 3 · Las tres mediciones

### 3.1 · Cota INFERIOR de `D`: ¿cuándo es única el ancla? — prioridad máxima

**Es la medición central y la que nadie ha hecho.**

El ATAQUE 1 dice que a `q = 1` la posición `N` es ambigua «con probabilidad no despreciable en cada
época». Nunca se midió **cuánto** ni **a qué profundidad deja de serlo**.

Mide, con **GDR-v0.2** (`veritas/consenso/ghostdag-rank-v1/`, no lo reimplementes): dos observadores
honestos con puntas distintas, ¿con qué probabilidad discrepan sobre **qué bloque ocupa la posición
`N` de la cadena seleccionada a profundidad `D`**? Entrega `P(discrepancia)` en función de:

- `D`, barrido en órdenes de magnitud: de **1 slot a varias horas**;
- la Δ de red, tomada de `veritas/finalidad/delta-medido-v1/` (Δ_99 p99 **0,26–0,60 s**);
- `k = 30`, `λ = 1 bloque/s`, 15 padres, `mergeset ≤ 180`.

**La pregunta concreta:** ¿a qué `D` cae `P(discrepancia)` por debajo de umbrales de `10⁻³`, `10⁻⁶`,
`10⁻⁹`? Con la Δ medida —sub-segundo— la sospecha es que la estabilidad llega **mucho antes** que la
finalidad. **Si `D_min ≪ F`, la contradicción del ATAQUE 1 se disuelve.** Pero puede que no, y
entonces hay que decirlo igual de claro.

⚠️ **No confundas estabilidad del ancla con finalidad.** La finalidad es una garantía de
irreversibilidad; la estabilidad del ancla es una probabilidad de coincidencia entre observadores.
La segunda puede alcanzarse a profundidades muy inferiores. El ATAQUE 1 asumió que hacía falta
finalidad, y tomó las constantes de Kaspa (`MERGE_DEPTH_DURATION = 3 600 s`,
`FINALITY_DURATION = 43 200 s`). **Ese supuesto es justo lo que hay que comprobar, no heredar.**

### 3.2 · Cota SUPERIOR: cuánto steering compra un `ρ` físico

Cuantifica `n_eval = ρ·W_dec` y el margen de R-FIN-14(f) `I ≥ ρ_max·W_dec`, **dentro del rango
físico de `ρ`**:

- `research/pot-aes-asic-chacha.md` §3 mide la ventaja realista de un ASIC de latencia frente a un
  14900KS en **~1,5–2,5×**, y explica por qué: *«con AES la CPU ya es el ASIC»*. Un 19× **no es
  físicamente alcanzable** (exigiría 25 ps por ronda de AES).
- El precedente de Chia da 3,1–3,8× con ASIC **de grupos de clase**, una operación que ninguna CPU
  acelera — **no es transferible a AES**, y hay que decir por qué si se usa como cota conservadora.

Barre `ρ ∈ [1, 4]` cubriendo el rango físico y un margen por encima. **No fijes `ρ_max`**: es
decisión de Katana y está pendiente (`TAREAS` §3.3).

### 3.3 · ¿Se cruzan las cotas? El mapa `(ρ, F)`

**El entregable principal.** Una tabla o mapa que, para cada par `(ρ, F)` en los rangos de arriba,
diga si existe una `D` admisible. Tres salidas posibles, y las tres son publicables:

| resultado | qué significa |
|---|---|
| **La ventana existe con holgura** | La opción «PoT global con inyección desde prefijo estable» es viable; entrega la región y el margen |
| **Existe solo en parte de la región** | Entrega la frontera: qué `F` y qué `ρ_max` hacen falta. Eso convierte dos pendientes vagos en un requisito |
| **No existe** | La contradicción del ATAQUE 1 es real y el diseño necesita la opción (h) o un fallback. **Dilo con todas las letras** |

### 3.4 · La opción (h): revelación retardada

R-FIN-14(h) ofrece una alternativa: `entropía_j = VDF(chunk(I_j) ‖ salida(I_j), L·iter)`, revelada
en `t_j`, que *«lleva la evaluación del atacante a 0 para cualquier `ρ` al coste de un VDF más»*.

Evalúala **solo si la ventana del §3.3 no existe o sale estrecha**: qué cuesta (un segundo VDF en la
ruta crítica), y hasta dónde llega —la línea 283 apunta `ρ* = (L+I)/(I+W_dec)`—. **No la adoptes**;
es una de las dos alternativas entre las que Katana tiene pendiente decidir.

---

## 4 · Trampas

1. **Estabilidad ≠ finalidad** (§3.1). Es el supuesto que hundió al ATAQUE 1.
2. **`D` es profundidad, `I` es periodo.** No son la misma magnitud y no compiten directamente.
3. **`ρ` no es libre**: está acotada por física. Usar `ρ = 19` sería modelar algo imposible.
4. **No rompas R-FIN-14(e).** La secuencialidad del PoT es lo único que impide evaluar la época
   entera de un candidato. Cualquier propuesta que permita saltar slots está **prohibida** por esa
   regla, no es una opción de diseño.
5. **R-FIN-5 ya existe.** «Pasado consistente de flujo» está escrita; es necesaria y no suficiente.
   No la propongas como hallazgo.

---

## 5 · Prohibiciones explícitas

1. **No fijes `ρ_max`, `F`, `I`, `L` ni `D`.** Todo va como función o como región.
2. **No uses `F = 2 h` como valor cerrado**: es provisional. Bárrelo.
3. **No edites `SPEC.md` ni `TAREAS.md`.** Tus salidas van en `PROPUESTA.md`.
4. **Nada de Python.** Julia en CPU; C++/CUDA sólo si el perfil lo justifica.
5. **No toques nada fuera de `deepseek/P-2.1/`.** Registra `git -C /home/katana/zeo/ZEROX status
   --short` al empezar y al terminar, en `PROGRESO.md`.
6. **Recorta el `Project.toml`**: solo lo que uses, stdlib incluida.
7. **No heredes veredictos de encargos anteriores sin recalcularlos** para esta pregunta.
8. **No cites un archivo sin comprobar que existe**, con ruta desde la raíz del repositorio.
9. **Reutiliza GDR-v0.2 como oráculo de GHOSTDAG.** No lo reimplementes.

---

## 6 · Entregables

En `deepseek/P-2.1/veritas/consenso/ancla-inyeccion-v1/`, estructura de LINEO §1:

| Archivo | Contenido |
|---|---|
| `CONTRATO.md` | qué calcula, qué **no** acredita, presupuesto declarado **antes** de ejecutar |
| `MODELO.md` | modelo de ambigüedad del ancla, adversario, supuestos de red |
| `INFORME.md` | **§3.1 primero** (la curva `P(discrepancia)` vs `D`), después el mapa `(ρ,F)`. Etiquetas `demostrado`/`medido`/`estimado`/`no demostrado`/`inconcluso` |
| `PROPUESTA.md` | qué propiedad debería cumplir la regla de anclaje, y qué queda abierto. **Propuesta, no SPEC** |
| `PROGRESO.md` | bitácora con `date`, no estimaciones |
| `HUELLAS.sha256` | rutas **desde la raíz del repo** |
| `src/`, `test/`, `bench/`, `run.jl`, `resultados/` | según LINEO §1 |

---

## 7 · Criterio de terminación

LINEO §10, y además:

**Lo que más valor tiene es la curva del §3.1.** Si sólo te da tiempo a una cosa, que sea
`P(discrepancia del ancla)` en función de `D`, bien medida y con la Δ real. De ahí sale todo lo
demás, y es lo único que nadie ha medido nunca.

**Se rechaza:** heredar el supuesto «hace falta profundidad ≥ finalidad» sin comprobarlo; usar `ρ`
fuera del rango físico sin declararlo; confundir `D` con `I`; y fijar cualquier constante.

**Si agotas el presupuesto:** para, checkpoint, **inconcluso**, con entrada mínima reproducible.

---

## 8 · Después

Claude valida **reejecutando**, no leyendo tus `resultados/`. Sólo entonces se migra y se commitea.

**Y una cosa aprendida de los encargos 05, 06 y 07:** los tres produjeron resultados correctos con
**alcance estrecho presentados con etiqueta ancha**, y en el 06 dos defectos que invalidaban su
conclusión principal estaban escritos en los docstrings del propio código. **Etiqueta el alcance de
cada afirmación tan estrechamente como sea verdad.** Un «no lo sé» explícito vale más que un
veredicto que haya que retirar después.

Si algo de este encargo te parece equivocado —y en particular si el §2 (la corrección del modelo) te
parece mal— **dilo antes de ejecutarlo**, no después.
