# REVISION-MATEMATICA.md — Dictamen de matemáticas/probabilidad

**Objeto:** `deepseek/veritas/seguridad/coste-rama-privada-v2/` y encargo
`deepseek/ENCARGO-07v2-coste-rama-privada.md` (puntos D2 y D3).
**Rol:** revisor independiente de matemáticas/probabilidad, **en contexto nuevo**.
**Fecha:** 2026-09-18.
**Naturaleza:** revisión adversarial hecha por un revisor independiente. **No** es una firma de
tercero ni un dictamen externo certificado; es evidencia interna de la ejecución, con las mismas
reservas que el encargo aplica a sus demás revisiones. No se editó código fuente, `SPEC.md`,
`TAREAS.md`, el encargo ni su sidecar. No se usaron las otras revisiones presentes en el directorio.

---

## 0 · Alcance

Verificado de primera mano:

- `src/referencia.jl` (fórmulas eventuales, DP exacta racional, regresión `1/(1+ε^(−1/d))`).
- `src/dp.jl` (DP acotada, soporte adaptativo, cotas por fuga, inversión monótona).
- `test/runtests.jl` (suite completa) y `resultados/` (evidencia publicada).
- `INFORME.md` en todo lo que cita números de probabilidad, DP o microbenchmark.
- `ENCARGO-07v2-coste-rama-privada.md` D2/D3 y §4.

Fuera de alcance (otros revisores): GHOSTDAG/GDR, Rust, RCE/ARM semántico, economía, red.

---

## 1 · Método

1. Lectura íntegra de los artefactos, sin asumir que lo escrito es correcto.
2. Ejecución de la suite: `env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl`
   → **128/128 pass, 7.5 s** (coincide con `resultados/TESTS.txt`: 128/128, 7.2 s).
3. Differential testing propio (Julia, sin Python): DP acotada/adaptativa contra la DP exacta
   `Rational{BigInt}` en `p ∈ {0.50,0.60,0.70,0.80,0.90,0.95,0.99}`, `d ∈ {0,…,10}`,
   `T ∈ {1,2,5,20,50}`, para empate y superación. **Error absoluto máximo = 1.11e-16.**
4. Prueba de validez de cotas con truncación forzada (ventana estrecha `[z0−3, z0+3]`): **0
   violaciones** de `P_L ≤ P_exacta ≤ P_U`.
5. Barrido del régimen no cubierto por la suite (`z0 ≥ 65`, `q ≥ p`) para buscar fallos del soporte
   adaptativo.
6. Reproducción independiente de las cifras DAG de `resultados/DAG.txt` con la misma semilla
   `0x5a5a` (coinciden dígito a dígito).
7. Comprobación de procedencia: `sha256sum -c` del encargo y comparación byte a byte con
   `ENTRADA.md` → **coinciden** (`a8912ba5…5c45`).

Comandos usados (reproducibles desde el directorio v2):

```bash
env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl
env -u LD_LIBRARY_PATH julia --project=. -e '<differential tests>'
```

---

## 2 · Verificación de la matemática exigida (D2/D3)

| Requisito | Veredicto | Evidencia |
|---|---|---|
| `P(empate eventual)=(q/p)^d`, `P(superar estricto)=(q/p)^(d+1)` para `q<p` | **Correcto** | `referencia.jl:17-34`; verificado contra DP exacta al crecer `T` (p.ej. `d=6, α=0.4`: exacta `0.0585276634659`, DP `T=1000` `0.05852766346`) |
| `=1` para `q≥p` | **Correcto** | `referencia.jl:22,32`; `prob_superar_eventual(3,1//2,1//2)=1`, `(3,2//5,3//5)=1` |
| DPs separadas de empate (`z=0`) y superación (`z≤−1`) | **Correcto** | `referencia.jl:76-85`, `dp.jl:107-118`; absorciones distintas, verificado |
| Borde `d=0` sin `0^0` ni convención implícita | **Correcto** | `referencia.jl:21`; empate `n=0` cuenta (`=1`), superar exige evento posterior (`q/p`) |
| Cotas `[P_L,P_U]` por fuga acumulada, en todo el horizonte | **Correcto en el rango ensayado**; ver hallazgo F3 | `dp.jl:41,58-59,69`; truncación forzada: 0 violaciones; `fuga` acumulada, no por paso |
| Conservación de masa y publicar masa cruda | **Correcto** | `dp.jl:68`; `CORTO.txt` conserv ≤ `1.2e-14`, tolerancia `1e-12` |
| No renormalización | **Correcto** | No hay división por la masa en `dp.jl` |
| Invariancia de la retícula `z=g·d` | **Parcial / test débil** — F4 | `dp.jl` no recibe `g`; el llamador hace `z0=g·d`; el test solo compara DP vs exacta en el mismo `z0` |
| `1/(1+ε^(−1/d))` converge a `1/2` desde abajo | **Correcto** | `referencia.jl:95-101`; `TEORIA.txt`: todos los `valor−1/2 < 0`, monótono hacia `1/2` |

Conclusión parcial: la matemática **nuclear** de D2/D3 que el instrumento usa es correcta y está
implementada de forma consistente con el encargo.

---

## 3 · Hallazgos

### F1 · Cifra imposible en `INFORME.md` (severidad **ALTA** para el informe)

`INFORME.md:62` afirma para `d=6, α=0.4`:

> `P_eventual` baseline `(q/p)^7 = 0.0343`; DP finito `T=200 = 0.0584`

La fórmula `(q/p)^7 = (0.4/0.6)^7 = 0.05852766346593507`, **no** `0.0343`. Además el valor publicado
`0.0343` es **menor** que el DP finito `0.0584`, lo que es imposible porque
`P_eventual ≥ P_finita(T)` para todo `T`. La cifra correcta (`0.05853`) coincide con
`referencia.jl` y con `CORTO.txt` (`P_sup = 5.839257e-02` a `T=200`). Error aritmético/de
trazabilidad en el informe, no en el código.

### F2 · `INFORME.md` contradice la evidencia de I/O (severidad **MEDIA**)

`INFORME.md:124` publica `p99=0.006 ms` y `~1743 MiB/s`. `resultados/IO.txt` registra
`p99=0.003 ms`, `max=0.086 ms` y `2230.0 MiB/s`. El informe no es reproducible desde sus propios
resultados. No afecta a D2/D3, pero rompe el requisito de que cada cifra cite su fuente real.

### F3 · El soporte adaptativo de superación pierde la frontera absorbente para `z0 ≥ 65` (severidad **MEDIA-ALTA** para D2)

`dp_adaptativa` arranca en `ancho=64` con `lo=z0−64` (`dp.jl:83-85`). `prob_superar_dp` fija
`direccion=:arriba` (`dp.jl:110`), de modo que `dir_lo=0` (`dp.jl:86`): **nunca** baja `lo`. Como la
absorción de superación es `z ≤ −1` (`dp.jl:109`), si `z0 = g·d ≥ 65` la frontera absorbente queda
**fuera del soporte** y toda la masa de éxito se contabiliza solo como fuga. Resultado: `P_L = 0`
(vacua) y una cota superior innecesariamente laxa. Evidencia reproducible
(`p=0.51, q=0.49, T=2000`):

| caso | `lo` adaptativo | `[P_L, P_U]` adaptativo | `[P_L, P_U]` con `lo=−1` (corregido) |
|---|---|---|---|
| `z0=65` | `1` | `[0.0, 0.03082]` | `[0.02891, 0.02915]` |
| `z0=100` | `36` | `[0.0, 0.03082]` | `[0.002323, 0.002567]` |

Es decir, para `z0=100` la cota superior adaptativa es ~12× más laxa que la corregida, y la inferior
es inservible. Además el bucle mal dirigido agota el lado correcto: con `q≥p` expande `hi` hasta
`1 437 057` estados y tarda hasta ~46 s (`p=0.5001,q=0.4999,z0=100,T=20000` → `[0, 0.6374]`).

**No invalida** ninguna cota publicada (la fuga siempre se suma al éxito, así que `P_U` sigue siendo
válida), y **no afecta** a los escenarios publicados (`CORTO.txt` usa `z0 ≤ 12`; el test de retícula
llega a `z0=32`). Pero incumple el mandato D2 de "soporte adaptativo … nunca un corte fijo": es un
corte fijo en `lo` que, con el lado de expansión equivocado, descarta la frontera absorbente. La
suite verde no lo detecta porque no ejercita `z0 ≥ 65`.

### F4 · El test de "invariancia de la retícula" no prueba lo que declara (severidad **BAJA**)

`test/runtests.jl:58-67` (`"D2 · la retícula NO cambia la probabilidad (unidades)"`) recorre
`g ∈ {1,2,4,8}` con `z0=d·g` y compara `prob_superar_dp(z0)` con `prob_superar_finita(z0)`, es decir
**DP truncada vs DP exacta sobre el mismo paseo**. Es un buen chequeo de truncación, pero **no**
compara probabilidades entre distintas `g` para una misma `d` física, y por tanto no demuestra
ninguna "invariancia". La tabla del informe (`INFORME.md:17`) etiqueta esto como "demostrado"; es una
sobreafirmación.

### F5 · Cobertura de mutación incompleta frente al encargo §4 (severidad **BAJA**)

El encargo §4 exige que los mutation tests fallen al introducir `≥` por `>`, **suma por máximo**,
**color global**, **aceptación post-divergencia incompatible** y **renormalización de masa
truncada**. La suite solo ejercita `>` vs `≥` (`runtests.jl:169-177`) y, para "suma vs máximo",
comprueba la desigualdad de la cota de unión (`min(1,Σ) ≥ max`), que es una identidad, no una
mutación del simulador. No hay mutación de color global, de aceptación post-divergencia ni de
renormalización de masa truncada.

### F6 · Intervalo de `α_prob` colapsado en el informe (severidad **BAJA**)

`resultados/CORTO.txt` da el intervalo `(0.39466261863708496, 0.39466267824172974)` (ancho ~6e-8),
pero `INFORME.md:61` lo publica como `(0.394663, 0.394663)`, que se lee como un punto. El dato fuente
es un intervalo; el redondeo lo destruye. Además, la inversión usa `p_exito_lower`
(`run.jl:78`), de modo que el cruce obtenido acota `α_prob` solo por el lado de la cota inferior; con
fuga ~0 aquí da igual, pero no se propaga formalmente `[P_L,P_U]` al intervalo de `α`.

### F7 · Robustez de `prob_superar_dp` con `q≥p` (severidad **BAJA**, latente)

Para `q≥p` el evento eventual vale 1 (`referencia.jl:32`), pero `prob_superar_dp` no lo cortocircuita
y devuelve `[0,1]` tras expandir `hi` hasta el tope (`p=0.1,q=0.9,z0=100,T=200` → `[0, 1.0000…]`,
`hi=1 437 057`, 0.46 s). No es incorrecto (la cota superior es válida) pero es inútil y costoso.
Relacionado: `dp_acotada` no valida `p+q=1`; `prob_superar_eventual` no valida `p,q>0` como sí hace
`prob_empate_eventual` (`referencia.jl:19` vs `29`).

### F8 · Tests tautológicos de los controles toy (severidad **BAJA**)

`control_escalar_S` calcula `raiz` con la misma forma cerrada (`rfin5.jl:89`) que el test compara
(`runtests.jl:145`, `164`) y `toy_S_deriva` es una identidad algebraica (`validacion.jl:53`). El
"control escalar recupera `1/(S+1)` por DP" (`runtests.jl:153-160`) solo verifica
`alto.P_U > bajo.P_U` a `±0.03` de la frontera; **no** resuelve una raíz de la DP estocástica ni
comprueba deriva nula. El propio instrumento lo reconoce parcialmente en
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` (H2/H4), pero la tabla del informe lo rotula
"demostrado".

### Controles positivos

- No he encontrado **signos invertidos** ni **desigualdades inválidas** en las fórmulas D3 ni en las
  absorciones del DP.
- No he encontrado **cotas inválidas**: `P_L ≤ P_exacta ≤ P_U` se cumple incluso con truncación
  agresiva (0 violaciones).
- Las cifras DAG de `INFORME.md` §1/§8 (`0.5599`, `1.000`, `IC (0.912,1.000)`, `k=30` → `0.000`,
  `IC (0.000,0.088)`) se reproducen exactamente y son coherentes con `resultados/DAG.txt`.

---

## 4 · Lo que NO he podido verificar

1. **La conversión física `d·g`** contra un modelo independiente (continuo o de bloques con peso
   real). Solo he verificado que el mapa `z0=g·d` se aplica una vez y que la DP coincide con el
   paseo `±1` resultante; no existe una referencia externa que fije la semántica física de `g`.
2. **La corrección de coloreo GHOSTDAG/GDR** y de los fixtures de color (alcance de las revisiones
   Julia/Rust, no matemática del paseo).
3. **La cota de error de la identidad iid** `1−E[F(W_pub)^S]`: solo la vi pasar el test a 4000
   réplicas con `atol=0.05`; no la acoté analíticamente.
4. **Las afirmaciones económicas y de `S_adversario`** (D9/D10): fuera de alcance; el informe ya las
   declara pendientes.
5. **La semántica del controlador RCE/ARM** y la asociación DAG→cohorte (declarada oráculo).
6. **El error de truncación a horizonte infinito** más allá de la comparación con la forma cerrada
   para `q<p`; para `q≈p` y `d` grande no dispongo de una referencia exacta tratable.
7. Que el fallo F3 sea o no alcanzable por algún escenario futuro previsto: con los parámetros
   publicados no lo es, pero no puedo descartarlo para `d` grande.

---

## 5 · Veredicto

**La matemática de D2/D3 en el rango ensayado es correcta.** Las fórmulas exactas, la separación
empate/superación, el borde `d=0`, las cotas por fuga acumulada, la conservación de masa, la
prohibición de renormalizar y la regresión "desde abajo" se verifican de forma independiente; la
suite pasa 128/128 y reproduce las cifras DAG.

**No obstante, la revisión no puede cerrarse favorablemente tal cual**, por:

- **F1** (cifra imposible en el informe) y **F2** (informe ≠ `resultados/IO.txt`): el `INFORME.md`
  no es trazable a su propia evidencia.
- **F3** (no conformidad D2 fuera del rango ensayado): el soporte adaptativo de superación es un
  corte fijo direccional que excluye la frontera absorbente para `z0≥65`, con cota inferior vacua.
- **F4/F5** (tests que no prueban lo que declaran): el rótulo "demostrado" de la invariancia de
  retícula y la cobertura de mutación exigida por el encargo están incompletos.

**Etiqueta:** *revisión matemática independiente favorable con reservas*. Corregir F1, F2, F3 (y, ya
que se toca, F4/F5) es condición para volver a pedir un cierre de validación matemática; ningún
hallazgo cambia el veredicto protocolario global, que en el propio informe es
**inconcluso por reglas pendientes**.

---

*Dictamen redactado en contexto independiente por el revisor de matemáticas/probabilidad. No
constituye firma de tercero. Sin autorización para editar código fuente, `SPEC.md`, `TAREAS.md` ni
el encargo.*
