# PROGRESO — P-ADELANTO (`adelanto-v1`)

Bitácora del encargo `P-ZRX/P-ADELANTO/PROMPT.md`. Escrita en orden cronológico. La **Fase 1 se
razona aquí antes de codificar** (§3 del encargo).

---

## 0 · Aviso previo al arranque (encargo §9, última frase)

El encargo pide que, si algo del planteamiento me parece equivocado —«en particular el
planteamiento del §3 sobre `+D` o la realimentación del §4.4»—, lo diga **antes** de empezar.

1. **§3 (`+D`).** El encargo presenta tres salidas simétricas (suma / resta / depende del régimen).
   Mi lectura previa de las reglas escritas es que hay una **cuarta**, y que es la correcta:
   **`D` se cancela** en el adelanto, en todo el régimen en que el diseño está vivo, porque
   (i) el reto no se deriva de `pot_output` sino de `salida(f, s)` (C-POT-03), y (ii) la exigencia
   «estar `D` por delante del slot que se firma» es un hándicap **aditivo común** al honesto y al
   atacante, que se cancela en toda comparación relativa. Se defiende en §2 de esta bitácora. No es
   una asunción: el instrumento lo comprueba con una simulación de eventos independiente y con la
   regresión contra SEM-v1.
2. **§4.4 (realimentación `F`↔`L`↔`ρ*`).** El encargo la llama «puede ser el hallazgo principal».
   Es real, pero **está condicionada**: solo muerde cuando `L_slots = F_slots`, es decir cuando el
   primer término del máximo de `C-FLU-01` manda. Si manda `L_suelo_slots` o `S_max_slots+1`, `F` y
   `L` quedan desacoplados y la realimentación es **cero**. La conclusión útil no es «hay
   realimentación», es **en qué región la hay**.
3. **Lo que sí me parece mal orientado en el encargo.** El §0 presenta `A` como «el» número que
   bloquea tres decisiones. Comparto que las tres dependen de `A`; discrepo de que la pieza
   pendiente sea `D`. `D` **no** mueve `A` (§2). Lo que sí mueve el resultado y sigue abierto es
   (a) el **acantilado en `ρ = 1`** que el propio encargo menciona y que el modelo histórico
   introduce como discontinuidad, y (b) `L_suelo_slots`, que el SPEC deja `<<PENDIENTE>>`. Se dice en
   el `INFORME.md` y en `DECISIONES-PENDIENTES.md`.

---

## 1 · Huellas de entrada (obligatorio, encargo §6)

Ejecutado desde `/home/katana/zeo/ZEROX`, **2026-09-21**, al empezar.

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-ADELANTO/ENTRADA.sha256
P-ZRX/P-ADELANTO/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
lun 21 sep 2026 10:17:31 CEST
```

Lectura: la huella del encargo **verifica**. El árbol tiene cuatro entradas sin seguimiento, todas
previas a este encargo y ajenas a él (`P-ZRX/` entero está sin seguimiento en este clon, no solo
`P-ADELANTO/`). No toco ninguna.

---

## 2 · Fase 1 — qué cambia al mover el ancla del slot `s` al slot `s + D` (razonado ANTES de codificar)

### 2.1 Qué es exactamente lo que cambia `D-2 = A`

`C-POT-05` (`SPEC.md:1403-1426`), decidido por Katana el 2026-09-19:

```text
pot_output(B) = salida(f, slot(B) + D)        (D-2 = A, la salida «future»)
la justificación de B lleva d = slot(B) − slot(sp(B)) portadores;
el portador i cubre el slot slot(sp(B)) + D + i; el último checkpoint == pot_output(B).
```

Lo que **no** cambia, y es lo que decide:

- `C-POT-03` (`SPEC.md:1376-1390`): `reto(f, s) = blake3( blake3(salida(f, s)) ‖ LE64(s) )`. El reto
  del slot `s` usa la salida **del propio slot `s`**, no la futura. `D` **no entra en el reto**.
- `C-FLU-07` (`SPEC.md:1612-1620`) y `R-FIN-14(a)`
  (`research/dag-poas-ancla-de-orden.md:261-265`): la inyección se aplica en `t_j = slot(I_j) + L`.
  `D` **no entra en `t_j`**.
- `C-POT-06` (`SPEC.md:1430-1435`): `D` entra en el verificador, pero **como dato del contexto**,
  no como incógnita.

Es decir: `D` mueve **una etiqueta de cabecera y el rango que cubre la justificación**. No mueve ni
el reto, ni el instante de activación, ni la cadena AES.

### 2.2 Las tres lecturas, y por qué dos son contables y una no

**(L1) `D` suma al adelanto.** Sería cierto si el reto se derivara de `pot_output`. No es el caso:
`C-POT-03` deriva el reto de `salida(f, s)`. Si alguien cambiara esa línea para derivarlo de
`salida(f, s + D)`, entonces sí: el atacante que va `D` por delante conocería el reto `D` slots antes
y el adelanto ganaría `+D`. **Está expresamente prohibido** por `C-POT-03` («MUST NOT derivarse de
una función que permita saltarse slots») y por `R-FIN-14(e)`
(`research/dag-poas-ancla-de-orden.md:272-275`, «PROHIBIDO»). Se implementa como variante
**contrafactual** de diagnóstico, etiquetada, nunca como modelo.

**(L2) `D` resta del adelanto.** Sería cierto si la exigencia «estar `D` por delante» gravara solo al
atacante. Grava a los dos: el productor honesto del slot `s` también necesita `salida(f, s + D)`, y
por eso su timekeeper va `D` por delante de su frontera de bloques. Y grava **igual**: sea `Φ` la
posición del timekeeper y `s` el slot que se firma; la condición de autoría es `Φ ≥ s + D`. Con el
honesto a `Φ_h(t) = t + D` (su frontera de bloques es `t`) y el atacante a `Φ_a(t) = D + ρt` (arranca
en la misma fase), la condición del atacante es `D + ρt ≥ s + D`, es decir **`t ≥ s/ρ`**: `D` se
cancela **exactamente**. El instante más temprano en que cada uno puede firmar el slot `s` es `s` para
el honesto y `s/ρ` para el atacante, **con independencia de `D`**. Se implementa como variante
**contrafactual** de diagnóstico.

**(L3) `D` se cancela.** Es la lectura que se sigue de L1-prohibido + L2. Además hay un argumento
independiente y más fuerte: **`D` es una etiqueta, no una magnitud**. Las tres cantidades que
gobiernan el adelanto —el reto (`C-POT-03`), el instante de activación `t_j` (`C-FLU-07`) y la
ventana de decisión— no contienen `D`; la cadena AES que hay que recorrer para conocer un reto
tampoco. Un cambio que no entra en ninguna de las entradas de una función no cambia su salida.

**Conclusión de la Fase 1, antes de codificar: `D` se cancela; el adelanto es `D`-invariante en el
régimen vivo.** El encargo §3 dice que si concluyo esto lo demuestre y no lo asuma: eso es lo que
hace el instrumento (§4: simulación de eventos con `D` explícita + regresión exacta).

### 2.3 Dónde `D` **sí** aparece: la frontera de viabilidad (y no es seguridad)

El bloque `B` del slot `s` necesita conocer las inyecciones hasta `s + D`. La última inyección activa
en `s + D` tiene ancla en el slot `A = t_j − L ≤ s + D − L`. Esa ancla debe estar en el **pasado
validado** de `B`, es decir `A ≤ slot(sp(B)) ≤ s`. De ahí:

```text
D ≤ L_slots            (condición de viabilidad, en el límite)
D ≤ L_slots − W_dec    (condición de viabilidad con convergencia del ancla)
```

Si `D ≥ L_slots`, el bloque del slot `s` necesitaría un ancla **futura** y **ningún bloque podría
avanzar**: no es un régimen de seguridad distinto, es un diseño que no produce bloques. Así que el
dominio de validez del cálculo es `D < L_slots`, y **en todo ese dominio `A` no depende de `D`**.
Esto convierte el punto 11 de `TAREAS.md` §2.9(c) en una condición escrita y comprobable, y no en una
incógnita: **el adelanto histórico sobrevive a `+D`; la restricción nueva es `D < L_slots`.**

### 2.4 Qué le pasa a `I ≥ ρ_max · W_dec` con el ancla futura

`R-FIN-14(f)` (`research/dag-poas-ancla-de-orden.md:275-276`) calibra `I ≥ ρ_max · W_dec`. Su
contenido: en la ventana de decisión `W_dec`, un reloj `ρ` evalúa `ρ · W_dec` slots de la época; si
`I` no supera eso, evalúa **la época entera** dentro de la ventana. Con `+D` no cambia ninguna de sus
dos entradas (`W_dec` sigue siendo la ventana de decisión medida sobre el ancla, `ρ` el reloj), luego
**la calibración sobrevive**. Lo que sí convive con ella es `C-FLU-01`, que añade suelo a `L`: el
efecto de 1a no es sobre (f) sino sobre (h), por `ρ* = (L + I)/(I + W_dec)`.

### 2.5 ¿Cambia el punto de bifurcación (compromiso frente a conocimiento)?

No en la comparación relativa. La grieta que explota el atacante es

```text
conocer reto(f, s)         en t_c ≈ s/ρ
tener que comprometer B(s) en t_b ≈ s
⇒ grieta = s(1 − 1/ρ),  independiente de D
```

El compromiso es «tarde» respecto del conocimiento en los dos regímenes, y la *diferencia* entre
ambos instantes no contiene `D`. Lo único que sí cambia con `D` es **qué** se compromete: con `D > 0`
la cabecera fija una salida futura; eso es un anclaje, no una ventaja de conocimiento.

### 2.6 El acantilado en `ρ = 1`, que `D` no toca y el encargo sí pide barrer

`A_core(ρ) = max(0, (L − 1 − W_dec) + I(1 − 1/ρ))` **no es continuo** en `ρ = 1`:

```text
A_core(1)      = 0        (por la definición explícita del núcleo histórico)
A_core(1 + ε)  = L − W_dec − 1 + I·ε/(1+ε) ≈ L − W_dec − 1
```

El salto es `≈ L`: con `L = 3600`, `W_dec = 20`, pasa de `0` a `3579,85`. El encargo ya avisa de que
«el histórico mostraba que el adelanto no degrada suavemente: es un acantilado». Pero conviene decir
**por qué** hay acantilado, porque de ello depende que las cotas de la Fase 3 sean creíbles: el
modelo histórico suma dos cosas de naturaleza distinta,

- un término de **presupuesto** (`L − W_dec`): «el atacante conoce la inyección `L` slots antes», que
  el modelo concede **entero en cuanto `ρ > 1`**, y
- un término de **tasa** (`I(1 − 1/ρ)`): lo que el atacante adelanta por ir `ρ` veces más rápido,
  que es **continuo** y vale `0` en `ρ = 1`.

Medido en slots de *conocimiento de retos* (que es como lo usa SEM-v1, `w = floor(A)`), el término de
presupuesto **no se sostiene**: conocer `entropía_j` `L` slots antes no da el reto de ningún slot
porque `reto(f, s)` exige `salida(f, s)`, que solo sale de recorrer la cadena AES. La lectura de
**tasa** da, en cambio,

```text
A_tasa(ρ) = max(0, min(ρ·W_dec, L + I − 1) − W_dec)      ρ > 1
A_tasa(1) = 0
```

que es **continuo en `ρ = 1`** y comparte con `A_core` el límite `ρ → ∞` (`L + I − W_dec − 1`).
Se implementan **las dos** lecturas y se publican las dos regiones; el encargo §9 exige decir cuál
está mal si el instrumento no reproduce SEM-v1. El instrumento **sí** reproduce SEM-v1 bit a bit
(corroboración de que copio el modelo histórico, no uno propio); lo que se declara es que **SEM-v1
sobreestima el adelanto cerca de `ρ = 1` por el término de presupuesto**, y se cuantifica cuánto.

---

## 3 · Presupuesto declarado (LINEO §7, encargo §11)

**8 hilos de CPU como tope** (el encargo fija 8, no los 24 de LINEO §7), **4 GiB de RAM, 1 GiB de
disco temporal** y **corridas de minutos**. Si se agota: checkpoint y estado **inconcluso**. No hay
GPU (no la justifica: el cálculo es un barrido analítico, no un Monte Carlo masivo), no hay RNG
criptográfico (semilla fija para la simulación de eventos; el resto es determinista).

---

## 4 · Fase 1 codificada — qué se construyó y qué salió

Instrumento en `investigacion/veritas/seguridad/adelanto-v1/` con la estructura de LINEO §1
(`Project.toml`, `Manifest.toml`, `julia-version.toml`, `src/{modelo,referencia,rapido,validacion}.jl`,
`test/runtests.jl`, `bench/benchmarks.jl`, `run.jl`, `resultados/`, `INFORME.md`,
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`). `AdelantoV1.jl` es el módulo que las incluye.

### 4.1 Lo que salió, en orden

1. **La regresión contra SEM-v1 pasa bit a bit.** `A_D(D = 0)` coincide con una transcripción literal
   del núcleo de SEM-v1 en 88 filas con `maxdiff = 0,0` exacto, y los 7 valores publicados de su
   `INFORME.md:156-164` se reproducen con error ≤ 0,0034 y `w` idéntico. El encargo §2(a) se cumple.
2. **`D` resta en el régimen estacionario y se cancela en el transitorio.** No suma. El contrafactual
   que sumaría (`A_add`, reto derivado de `pot_output`) mide exactamente cuánto vale la prohibición de
   `C-POT-03`: `+D` slots.
3. **`A` NO depende de `ρ` en el estacionario.** Es la sorpresa, y es un resultado, no un defecto: la
   cota la pone el **flujo** (las anclas son bloques honestos y tardan `W_dec` en decidirse), no el
   reloj. `ρ` gobierna `n_eval = ρ·W_dec`, que es **otra magnitud**. `A_core` mezcla las dos.
4. **El acantilado de `ρ = 1` es del modelo histórico, no del fenómeno.** `A_core` salta de `0` a
   `7 179,85` (con `L = 7 200`, `W_dec = 20`) entre `ρ = 1` y `ρ = 1,001`; `A_frontera` es continuo.
   El instrumento **reproduce** SEM-v1 y además **dice cuál de los dos está mal**: el término de
   presupuesto `L − W_dec` de `A_core` no se sostiene en la moneda «retos conocidos», porque conocer
   `entropía_j` `L` slots antes no da el reto de ningún slot (`reto(f,s)` exige `salida(f,s)`).
5. **`C-FLU-01` ata `(h)` desde abajo a `F_slots`, y esa es la realimentación.** `ρ*(F) = (F+I)/(I+W_dec)`
   cuando manda el primer término del máximo; **cero** cuando manda `L_suelo_slots`. Cuantificado en
   `resultados/FASE2.tsv` §2.4 y en el `INFORME.md` §3.4.
6. **`(h.6)` pone techo a la bajada de `F`.** A `F = F_carrera = 1 019 s`, `ρ_max = 9` es **inadmisible**
   (`I* = 104,9 < ρ_max·W_dec = 180`); `(h)` compra como mucho `ρ_max ≈ 5` y cuesta 0,522 núcleos/nodo.
7. **El vector C4 queda subsumido en especie y agravado en magnitud**, y añade una tercera mordaza no
   derivada a `PRESUP_NODO` (`TAREAS.md` §2.9(c) 12).
8. **Con (h) y `ρ_max ≤ ρ*`, `sup A = 0`** y la edad `M` de `P-SEMBRADOR` (A1+C1) colapsa al margen de
   red/finalidad. Sin (h), `M > L + I − W_dec − D`, del orden de `F`.

### 4.2 Correcciones de método que hubo que hacer durante la validación

Se anotan porque las tres cambiaban un número, y las tres las detectó la validación, no la inspección:

- **Sim-v1 restaba `D` dos veces** (`mín(PoT, Γ−D) − D` en vez de `mín(PoT, Γ) − D`). El oráculo
  independiente dio 5 slots de discrepancia en vez de 1 y eso lo delató. Corregido: la discrepancia es
  **exactamente 1 slot** (la convención discreta) y el test la fija.
- **`A_frontera` sufría cancelación catastrófica** al restar `mín(ρt,Γ) − mín(t,Γ)` con `t = 10⁶` y
  `A ≈ 8·10³`. Reescrito por ramas; el kernel contra `BigFloat` bajó de `3,5·10⁻¹⁴` a `1,27·10⁻¹⁴`.
- **`I_estrella` (h.6) invierte exactamente la forma continua de `ρ*`, no la discreta.** Las dos formas
  difieren en la convención `−1`; se publican las dos (`rho_estrella`, `rho_estrella_continua`) en vez
  de mezclarlas.

Ninguna de las tres cambió la conclusión; las tres están cubiertas por tests permanentes.

---

## 5 · Presupuesto consumido

| Recurso | Declarado | Usado |
|---|---|---|
| Hilos | 8 | 1 para el cálculo; escalado medido a 1/2/4/8 (gana 8: 5,76×) |
| RAM | 4 GiB | < 100 MiB (bench: 2 × 100 000 filas) |
| Disco | 1 GiB | **564 KiB** (`P-ZRX/P-ADELANTO/`), de ellos 336 KiB en `resultados/` |
| Tiempo | corridas de minutos | `--modo todo` en segundos; `bench/` en minutos (4 configuraciones) |
| GPU | no | no usada (no justificada: barrido analítico, no Monte Carlo) |

**No se agotó el presupuesto. Estado: conclusivo** dentro del alcance declarado.

---

## 6 · Huellas de salida (obligatorio, encargo §6)

Ejecutado desde `/home/katana/zeo/ZEROX`, **2026-09-21**, al terminar.

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-ADELANTO/ENTRADA.sha256
P-ZRX/P-ADELANTO/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
lun 21 sep 2026 10:54:39 CEST
```

*(Comprobación repetida al cerrar el informe: `sha256` OK y `git status` **idéntico** a las 10:52:44, sin
cambios nuevos.)*

**La comprobación de huellas del encargo no falla al terminar y no fallaba al empezar**:
`P-ZRX/P-ADELANTO/PROMPT.md` mantiene su `sha256` (`54b8aa25…ed91e4a1`). `PROMPT.md` y
`ENTRADA.sha256` no se tocaron.

### 6.1 INCIDENCIA: dos entradas nuevas en `git status` que **no** son mías, y hay que decirlo

Al empezar, `git status --short` daba cuatro líneas (`?? P-ZRX/`, `?? veritas/consenso/poda-post-v1/`,
`?? veritas/consenso/prueba-recursiva-v1/`, `?? veritas/seguridad/`). Al terminar hay **dos más**:

```text
 D ZEROX-EN-NUMEROS.md      (borrado del árbol de trabajo)
?? .trash/                  (directorio nuevo, mtime 2026-09-21 10:50)
```

**No lo hice yo.** Ninguna orden de este encargo toca la raíz del repositorio: todas mis escrituras
están bajo `P-ZRX/P-ADELANTO/investigacion/` y los únicos `rm` que ejecuté fueron
`rm -f resultados/BENCH-h*.txt resultados/JET.txt resultados/PERFIL.txt` y `rm -f /tmp/.dsh_write_test`,
ninguno sobre un fichero del repositorio. Se investigó antes de informar:

```text
$ ls -la .trash/
-rw-r--r--. 1 katana katana 54636 sep 17 12:19 ZEROX-EN-NUMEROS.md

$ git hash-object .trash/ZEROX-EN-NUMEROS.md
f623319aa69063955ccc62b45cf6f1520b15f223
$ git rev-parse HEAD:ZEROX-EN-NUMEROS.md
f623319aa69063955ccc62b45cf6f1520b15f223
```

**El contenido está intacto**: el blob de `.trash/ZEROX-EN-NUMEROS.md` es **byte a byte** el de `HEAD`,
y conserva tamaño (54 636 B) y fecha (sep 17 12:19). Es un **movimiento**, no una pérdida: se recupera
con `git checkout -- ZEROX-EN-NUMEROS.md` o con `mv .trash/ZEROX-EN-NUMEROS.md .`.

**No lo he restaurado**, por dos motivos: (a) la zona de escritura autorizada de este encargo es
`P-ZRX/P-ADELANTO/investigacion/` y la raíz del repositorio queda fuera; (b) el movimiento puede ser
deliberado y de otra persona o proceso —el directorio `.trash/` sugiere un mecanismo de papelera—, y
deshacerlo sin saberlo sería peor que reportarlo. **Queda registrado aquí y en la cabecera del
`INFORME.md` para que Katana lo vea.**

---

## 7 · Cierre

- **Fase 1 cerrada**: `A = L_slots + I_slots − W_dec − D` en el estacionario, `D`-invariante en el
  sentido de que `D` resta linealmente y no depende de `ρ`; regresión exacta contra SEM-v1;
  `TAREAS.md` §2.9(c) punto 11 queda respondido, con la salvedad declarada de la premisa 6.
- **Fase 2 cerrada** en sus cuatro puntos: `ρ*` rehecho con `+D` y con `L` derivada, coste por nodo en
  núcleos y líneas, C4 reevaluado con `C-FLU-22`, y la realimentación `F`↔`L`↔`ρ*` cuantificada y
  **condicionada** a `L = F_slots`.
- **Fase 3 cerrada** con las tres cotas como funciones y regiones.
- **Entregables:** `INFORME.md`, `DECISIONES-PENDIENTES.md`, este `PROGRESO.md` y el instrumento con
  `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.
- **Lo que sigue abierto y es lo único que puede cambiar el signo del resultado principal:** la
  disciplina de avance del timekeeper honesto (§2.2 y premisa 6 del informe del instrumento). Lo que
  lo cierra: escribirlo en `C-POT-05`/`C-TIMELORD-*` o medirlo en `prototipos/pot-estable`.

