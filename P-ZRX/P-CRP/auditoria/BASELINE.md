# P-CRP · BASELINE — qué se puede decir hoy del umbral de una rama privada

**Sustituye al titular «`α = 1/2`, igual que Bitcoin».** Seis escenarios separados, como exige el
encargo 07v2 §1. Ninguna cifra de este documento se apoya en CRP-v0.1: las de v0.1 las mide otro
encargo (`P-ZRX/P-CRP1/`, cuyo `auditoria/INFORME.md` **no existía** cuando este empezó ni durante
su ejecución).

Etiquetas: `demostrado`, `medido`, `derivado`, `inconcluso`, `no determinado`. «Fila de evidencia»
= fichero + resultado concreto. Todo lo citado de v0.2/v0.3 lo he **reejecutado** y coincide
(`INFORME.md` §2.1).

---

## Escenario 0 · Baseline analítico (paseo ±1, un evento por paso, tasas simétricas)

**Qué está.**

- `demostrado`: `P(empate eventual) = (q/p)^d`, `P(superar estricto) = (q/p)^(d+1)` para `q < p`, y
  ambas `1` para `q ≥ p`. `d = 0`: el empate incluye `n = 0`; superar exige un evento posterior.
- `demostrado`: `g_E(α) = α − (1 − α) = 2α − 1` y **`α_drift = 1/2` exacto**. Es una **identidad
  aritmética del baseline**, no una propiedad del protocolo.
- `medido` (comprobación mía, aritmética exacta `Rational{BigInt}`): en las 18 celdas publicadas de
  `resultados/CORTO.txt`, `[P_L, P_U]` **encierra el valor exacto**: peor `P_U − exacto = 5,7e-16`,
  peor `|conservación| = 1,2e-14`. `α_prob(0.05, d=6, T=200)` publicado
  `(0,39466261863708496, 0,39466267824172974)` contiene el cruce exacto: `P(α_inf) < p0 ≤ P(α_sup)`
  certificado con exactitud.
- Fila de evidencia: `copia/coste-rama-privada-v2/resultados/CORTO.txt`, `TEORIA.txt`,
  `resultados/TESTS.txt` (131/131 reproducido); `registros/dp-exacto.txt`.

**Frase que SÍ se puede escribir**

> En el baseline simétrico de un evento por paso, la frontera de deriva es `α_drift = 1/2` exacta
> (`g_E = 2α − 1`), y la DP publicada encierra el valor exacto de `P(superar)` con error ≤ `1e-12`.
> Es una identidad aritmética del baseline, **no** el umbral del protocolo.

**Frase que NO se puede escribir**

> «El diseño aguanta: `α = 1/2`, el mismo umbral que PoW» · «en la liga de PoW» · «seguro al 50 %»
> · «CRP-v0.2/v0.3 cierran el umbral de una rama privada».

**Qué lo cerraría:** nada, ya está demostrado. Lo que falta no es aquí: es el puente
`espacio → tasa` (ver escenario 3 y `DEFECTOS.md` C1), que **no existe en ningún instrumento**.

---

## Escenario 1 · SPEC actualmente escrito

**Qué está.**

- `inconcluso`, por cinco piezas ausentes y ninguna sustituible por una constante elegida:
  1. **controlador C-HDR-06**: ventana, arranque, redondeos y fusiones tardías
     (`TAREAS.md:213-219`; `copia/coste-rama-privada-v2/resultados/RCE.txt`).
  2. **verificador PoT**: `zx-core::wire_dag::verificar_justificacion_pot` devuelve
     `IntegracionPotPendiente` (`TAREAS.md:221-225`, `SPEC.md` §17).
  3. **C-GD-11**: cinco pendientes —métrica, valor, bootstrap, borde, finalidad—
     (`SPEC.md:3786`; `v3/MATRIZ-AUTORIDAD.md:22`).
  4. **finalidad** `C-FIN-01` con `I/F/L_suelo/ρ_max` sin elegir y `F = 2 h` provisional
     (`SPEC.md:2532-2570`, `v3/MATRIZ-AUTORIDAD.md:59`).
  5. **el código de las 31 reglas nuevas**: ninguna tiene una línea (`TAREAS.md:155-156`).
- Fila de evidencia: las cinco anteriores; más `v2/MATRIZ-VALIDEZ.md:9`, `v3/MATRIZ-VALIDEZ.md:6`.

**Frase que SÍ**

> Con el SPEC de hoy, la corrida del controlador del SPEC y la del escenario flujo quedan
> **Pendiente**; el primer dato ausente del controlador es **la ventana**. Ninguna de las 31 reglas
> nuevas de §7.1 tiene implementación.

**Frase que NO**

> «El protocolo ZEROX tiene umbral `1/2`» · «el umbral es `1/(S+1)` = 0,04 con `S = 24`» · «el
> adversario necesita el 4 %» · «la rama privada es un problema solo de ingeniería».

**Qué lo cerraría:** redactar e implementar la ventana/arranque del controlador, integrar el
verificador PoT, cerrar los cinco pendientes de C-GD-11 y elegir `I/F/L_suelo/ρ_max`.

---

## Escenario 2 · DAG con red (GDR-v0.2, vistas locales, `rojo_k` contextual)

**Qué está.**

- `medido`: el DAG simulado **no es una cadena**. Concurrencia real, puntas, anticonos y rojos
  contextuales. Con `k=2`, Δ=4, n=8, 64 réplicas: **tasa de bloques rojos 0,6044** y **fracción de
  réplicas con ≥1 rojo = 1,000**, IC95 **(0,943, 1,000)**; con `k=30`, **0 rojos**, cota superior
  0,057. `reproducido` byte a byte.
- `medido`: fixtures deterministas de color: `k=1,2,5` dan `rojo_k` en el último hermano;
  `k=3,30` dan cero rojos. `reproducido`.
- `inconcluso`: **no hay frontera de deriva medida con R-FIN-5**. En el barrido de v0.2
  (`resultados/DAG.txt`) **todas** las celdas `max(RFIN5)` son `0/64`, en las 9 combinaciones de
  `S∈{1,2,4}` × `α∈{0,1;0,2;0,3}` × `d∈{0,2}`. En v0.3 (`resultados/SWEEP-DAG.txt`) las celdas
  `max_terminal` son `0/24` salvo el borde `α=0,45` (S=1: 2/24; S=2: 2/24; S=4: 4/24; S=8: 5/24;
  S=16: 6/24; S=24: 6/24). Lo único con señal positiva es el **contrafactual aditivo**.
- `inconcluso`: `η_h` y `η_a`. v0.3 mide `η_h ≈ 0,99 – 0,994` y **`η_a = 1,0` en todas las
  réplicas**, pero `η_a ≡ 1` es **tautológico** (`DEFECTOS.md` C4); sin muestra de rojos
  (`ETA.txt`: 0 rojos a `k=30`) no hay IC y la curva con rojos asimétricos queda inconclusa —
  como el propio instrumento declara.
- Fila de evidencia: `resultados/DAG.txt`, `resultados/SWEEP-DAG.txt`, `resultados/ETA.txt`,
  `resultados/CORRELACION.txt`, `resultados/VARIOS.txt`, `resultados/TESTS.txt`.

**Frase que SÍ**

> En el DAG simulado con vistas locales y latencia fija en slots se producen puntas, anticonos y
> `rojo_k` reales (`k=2`: fracción de réplicas con rojo 1,000, IC95 0,943–1,000; `k=30`: 0 rojos,
> cota superior 0,057). **Las celdas de frontera con R-FIN-5 son 0/n y solo acotan superiormente**;
> no hay frontera de deriva medida con la regla de flujo.

**Frase que NO**

> «El DAG aporta menos varianza, no menos umbral» (eso es de CRP-v0.1 y las cifras no están
> revalidadas) · «la frontera medida es `1/2`» · «`η_h = η_a`» · «los rojos honestos y adversarios
> son iguales» · «la red está modelada» (Δ es fija en slots, sin colas ni régimen degradado).

**Qué lo cerraría:** (a) una medición de `η_h` y `η_a` con la definición de D6 —post-fork, sin
prefijo común, por contexto— y con muestra de rojos suficiente para un IC; (b) una red con Δ medido
y colas, no Δ fija; (c) más réplicas por celda para que una celda `0/n` deje de acotar solo `≈0,25`.

---

## Escenario 3 · Escenario con filtro de flujo (hoy `C-FLU-14`, SPEC vigente)

**Qué está.**

- `verificado en fuente`: `C-FLU-13` y `C-FLU-14` están **redactadas en `SPEC.md` §7.1.5**
  (`SPEC.md:1699-1731`), con fecha 2026-09-19/20. `C-FLU-14` exige, para todo `X ∈ past(B)`,
  `flujo(X, slot(X)) == flujo(B, slot(X))`, comprobación **estructural y antes de tocar PoT**, y
  `Pendiente` —nunca `Inválido`— si falta `past(B)`.
- `medido`: v0.3 reproduce **la forma** del filtro: compara prefijos en `slot(X)`, sobre **todo**
  `past(B)`, antes de U2/U3 y de colorear; con `t_fork=5` da `VALIDA` en el slot 5 e `INVALIDA` en
  el 15; una fusión público+rama divergente se registra `:rechazada_rfin5`; un descriptor sin
  autenticar da `PENDIENTE`. `reproducido` (`resultados/U2U3.txt`, `test/runtests.jl:85-100` — 76/76 reproducidos).
- **Dónde NO coincide con la letra de `C-FLU-14`:**
  1. `flujo(B, ·)` en el SPEC es el identificador de 32 bytes **derivado de `past(B)`**
     (`C-FLU-10`, `C-FLU-11`: «**MUST NOT** declararse»). En v0.3 es un `DescriptorFlujo`
     **declarado** por el fixture (`autenticado=true` lo fija `construir_flujo`,
     `v3/src/flujo.jl:79`), con `pot_origin="ZEROX-PoAS"` y `dominio="ZEROX-v0"` literales.
  2. La condición de `Pendiente` implementada es «descriptor no autenticado», no «falta `past(B)`»
     como dice el SPEC.
  3. `N(s)` es constante (`N = N0` en todos los eventos, `flujo.jl:72`), así que la parte de D7 que
     exige ordenar `(slot, entropía, N_efectivo)` con `N` variable no se ejercita.
  4. `horizonte_justificacion_ok` (`flujo.jl:55-59`) es vacuo (`DEFECTOS.md` C6).
  5. No hay PoT AES: el propio instrumento lo declara (`INFORME.md:46-49`, `CONTRATO.md:38`).
- Fila de evidencia: `SPEC.md:1718-1731`; `copia/coste-rama-privada-v3/src/flujo.jl:30-99`,
  `resultados/U2U3.txt`, `tests` 76/76 reproducidos.

**Frase que SÍ**

> Con `C-FLU-14` vigente, un bloque no puede referenciar un bloque de otro flujo, y la comprobación
> es estructural y precede a todo PoT. El instrumento v0.3 reproduce esa comprobación sobre un
> **descriptor declarado**, no derivado de `past(B)`, y sin verificador PoT: es **compatibilidad
> estructural de flujo**, no «PoT verificado».

**Frase que NO**

> «R-FIN-5 es una regla candidata» (está redactada y vigente en §7.1.5) · «PoT verificado» · «el
> filtro de flujo está validado» · «el instrumento demuestra `C-FLU-14`» (no puede: el flujo se
> declara en vez de derivarse).

**Qué lo cerraría:** derivar `flujo(B, ·)` del pasado validado (C-FLU-10/11) e integrar el
verificador PoT (C-POT-06/07/08) bajo el presupuesto de `C-NET-33`.

---

## Escenario 4 · Contrafactual aditivo sin filtro de flujo

**Qué está.**

- `medido`: es el **único** escenario con señal positiva fuerte, y es explícitamente **una regla que
  no está adoptada**. v0.2 (64 réplicas/celda, T=400, Δ=4): `S=4, α=0,2, d=0` → **0,766
  (0,649–0,853)**; `S=4, α=0,3` → **1,000 (0,943–1,000)**. v0.3 (24 réplicas/celda, T=200, Δ=2):
  `S=4` `0/24` en `α=0,15`, `13/24` en `0,20`, `24/24` en `0,25`; `S=16` `0/24` en `0,01`, `16/24`
  en `0,06`; `S=24` `17/24` en `0,04`. `reproducido`.
- `derivado`: en el toy escalar de suma íntegra la cuota es `S·α/(1−α+S·α)` y el cruce
  `α_drift = 1/(S+1)` (S=24 → 0,040). Es una **identidad del toy**, no un teorema sobre el DAG; los
  tests que la comprueban comparan la fórmula consigo misma (`DEFECTOS.md` C-nota en §2.2 de
  `INFORME.md`).
- `demostrado` (por el SPEC, no por medición): `C-FLU-13` cierra el multistream «porque un flujo
  fabricado por el atacante no es el flujo de ningún bloque honesto y sus bloques no se pueden
  referenciar» (`SPEC.md:1709-1716`). Con eso, este contrafactual **no representa ninguna regla
  vigente**.
- Fila de evidencia: `v2/resultados/DAG.txt`, `v3/resultados/SWEEP-DAG.txt`,
  `v3/resultados/SWEEP-TOY.txt`.

**Frase que SÍ**

> En el contrafactual aditivo —que ninguna regla vigente autoriza— la cuota del toy es
> `S·α/(1−α+S·α)` y su cruce medio `1/(S+1)`; el DAG completo **no está obligado** a reproducirlo,
> porque GHOSTDAG no suma ramas incompatibles y `C-FLU-14` prohíbe referenciarlas. El contrafactual
> cuantifica sensibilidad, no el protocolo.

**Frase que NO**

> «`α = 0,040` con `S = 24` es el umbral» · «ataque del 4 %» · «el límite de IOPS de un SSD de
> 100 k» · «sin espacio adicional» como coste acreditado · «el multistream es el vector medido que
> baja el umbral» (hoy no es una opción del diseño vigente).

**Qué lo cerraría:** no se cierra como regla: lo que lo cierra es que `C-FLU-14` la hace imposible.
Para afirmar **algo económico** haría falta `S_adversario` medido con perfil de hardware compatible
(I/O con colas, CPU/PoAS/KZG y PoT por slot): hoy `pendiente` y **no** derivable de los 100 k IOPS.

---

## Escenario 5 · Regímenes corto y largo

**Qué está.**

- `demostrado` (corto, baseline): separación de tres objetos
  `P_terminal ≤ P_first_passage ≤ P_eventual`; verificado con exactitud para `z0=4, α=1/5, T=10,20`
  (`registros/dp-exacto.txt`). `α_prob` distinto por evento (`v3/resultados/EVENTOS.txt`:
  terminal 0,4431; paso 0,3546; eventual 0,3545).
- `medido` (corto, DAG): primera pasada por slot contra la punta pública de cada slot
  (`W_priv_paso`), con el déficit en unidades de `blue_work`. Es un **proxy declarado**: la punta
  pública cambia de slot en slot y no hay un `W_pub` final único.
- `inconcluso` (largo): `g_E(α)` no se mide; la frontera implícita con eficiencias
  `α·c_a^∞·η_a^∞ = (1−α)·c_h^∞·η_h^∞` no se puede resolver porque **no hay `c_x^∞` ni `η_x^∞`
  medidos** y `η_a` es tautológico. La forma cerrada solo vale si `c_x^∞η_x^∞` no cambia con α.
- `inconcluso` (largo, protocolo): la finalidad `C-FIN-01` y `F` provisional con `Δ` sin medir en
  red DAG ⇒ el «tiempo arbitrario» no congela nada (`SPEC.md:2532-2570`,
  `v3/MATRIZ-AUTORIDAD.md:59`).
- Fila de evidencia: `v3/resultados/EVENTOS.txt`, `v3/resultados/VARIOS.txt`,
  `v2/INFORME.md:70-81`, `registros/dp-exacto.txt`.

**Frase que SÍ**

> En horizonte corto, `P_terminal`, `P_first_passage` y `P_eventual` son objetos distintos y se
> publican por separado; `P_eventual` es exacto en el baseline (`(q/p)^(d+1)`). En horizonte largo,
> `α_drift` **no está medido**: falta `c_x^∞`, `η_x^∞` y la finalidad con `F` y `Δ` de red.

**Frase que NO**

> «`α_drift` es `1/2` en régimen largo» · «el horizonte largo no cambia nada» · «`P = 1/2` por
> defecto» · «el tiempo arbitrario basta para congelar la historia honesta».

**Qué lo cerraría:** `finalidad R-FIN-7` con `F` y `Δ` medidos en red DAG; y `c_x^∞`, `η_x^∞` con
ventana explícita y muestra de rojos suficiente.

---

## A · Frases de `SPEC.md` y `TAREAS.md` que citan CRP-v0.1 — **propuesta de redacción**

> **No he editado `SPEC.md` ni `TAREAS.md`** (prohibido por el encargo §4 y por `AGENTS.md`).
> Esto es solo una propuesta, con la cita localizada.

### A.1 · `SPEC.md` §7.1.5, líneas 1709-1716 (nota de `C-FLU-13`)

- **Dice hoy:** «…se abriría el **multistream** —`α_mínimo = 1/(S+1)`, medido en
  `veritas/seguridad/coste-rama-privada-v1/`—…»
- **Problema:** una regla **vigente** apoya su justificación en un instrumento que (a) no está
  revalidado, (b) su sucesor v0.2 declara sustituirlo y (c) v0.3 lo deja inconcluso. Y la cifra
  `1/(S+1)` es la identidad del **toy aditivo**, no del DAG.
- **Propuesta:**
  > …se abriría el multistream: la cuota del **contrafactual aditivo** sería `S·α/(1−α+S·α)` y su
  > cruce medio `1/(S+1)`. Esa cuota es una identidad del modelo escalar, **no** un umbral medido
  > del protocolo, y la evidencia que la sostiene (`veritas/seguridad/coste-rama-privada-v1/`) está
  > pendiente de revalidación (`TAREAS.md` §2.9 (e)). Siendo la validez **absoluta**, el multistream
  > queda cerrado porque un flujo fabricado no es el de ningún bloque honesto y sus bloques no se
  > pueden referenciar (`C-FLU-14`).

### A.2 · `SPEC.md` §17, línea 3782 (fila «Prueba de espacio/tiempo»)

- **Dice hoy:** «`veritas/seguridad/coste-rama-privada-v1/` (CRP-v0.1, 2026-09-18) mide
  `α_mínimo = 1/2` … con `S` flujos simultáneos la cuota efectiva es `S·α/(1−α+S·α)` y el umbral
  cae a `α = 1/(S+1)`: **0,040 con `S = 24`**, que es el límite de IOPS de un SSD de 100 k, **sin
  espacio adicional**. … Es el ATAQUE 2 …»
- **Problemas:** cita CRP-v0.1 como medida vigente; presenta `0,040` como umbral; usa «100 k IOPS»
  como capacidad acreditada; usa «sin espacio adicional» en el sentido que el encargo D10 prohíbe
  («ataque gratis»). Todo eso convive con «El multistream queda cerrado» en el mismo párrafo.
- **Propuesta:**
  > **Prueba de espacio/tiempo.** Verificación conjunta de solución, KZG, sello, reto secuencial,
  > autoría y flujos. La regla de dependencias por flujo ya está redactada (§7.1.5, `C-FLU-13/14`).
  > **La evidencia cuantitativa del coste de una rama privada está pendiente de revalidación**:
  > `veritas/seguridad/coste-rama-privada-v1/` es un baseline idealizado con veredicto inconcluso, y
  > sus sucesores CRP-v0.2 y CRP-v0.3 (rescatados en `P-ZRX/rescate-deepseek/`) **no están
  > validados ni migrados** (`TAREAS.md` §2.9 (e)). Lo que hoy puede afirmarse: en el **contrafactual
  > aditivo** la cuota del toy es `S·α/(1−α+S·α)` con cruce `1/(S+1)`, y **no es una regla
  > vigente**; el coste real de construir una rama privada con más `blue_work`, las eficiencias
  > `η_h`/`η_a` con muestra de rojos y el número de flujos que un adversario puede costear
  > (`S_adversario`) **siguen sin medir**. No se cita ningún valor de IOPS como capacidad.

### A.3 · `TAREAS.md` §2.1

- **Ya corregido** el titular del 4 % (líneas 126-141) y la afirmación de que `C-FLU-14` cierra el
  multistream (líneas 184-187). Correcto. Quedan dos frases del **registro histórico**
  (líneas 173-199) que se leen como vigentes:
  - **Línea 176-178:** «**El diseño base aguanta.** `α_mínimo = 1/2`, **el mismo umbral que PoW y
    que GHOSTDAG sobre PoW**, en los dos regímenes…».
  - **Línea 193-194:** «`S ≈ 24` es el techo de IOPS de un SSD de 100 k. **Coste: `S` núcleos e
    IOPS, cero espacio adicional.**»
- **Propuesta:** anteponer esas dos frases con la marca de procedencia y su estado real:
  > *Registro histórico de CRP-v0.1, no revalidado.* «`α_mínimo = 1/2`» es una **identidad del
  > baseline** (un evento por paso, tasas simétricas), no un umbral del protocolo; CRP-v0.2 declara
  > sustituir esta evidencia y **no se cierra**; CRP-v0.3 lo deja **inconcluso**. `S ≈ 24` es un
  > **escenario** de barrido, no una capacidad acreditada, y «cero espacio adicional» es una
  > afirmación sobre el **espacio plotteado**, no un ataque gratis: los costes de CPU/PoT/IOPS,
  > energía y recompensa renunciada **no están medidos**.

---

## B · Qué puede tomar `P-ZRX/P-PRESTAMO/` como punto de partida

**Puede darlo por bueno (con estas condiciones):**

1. **La identidad de la deriva, en el baseline**, es `g_E(α) = α·c_a·η_a − (1−α)·c_h·η_h` y la
   frontera es su raíz. Con `c_h = c_a = η_h = η_a = 1` da `α_drift = 1/2` exacto; con `S` ramas
   aditivas da `1/(S+1)`. Es aritmética, no protocolo.
2. **La forma implícita de una `α` propia más una `β` prestada**, siempre que `c_x^∞` y `η_x^∞`
   existan y se midan: `α·c_a^∞(α,β)·η_a^∞(α,β) = (1−α−β)·c_h^∞(α,β)·η_h^∞(α,β)`. La forma
   cerrada `c_hη_h/(c_hη_h+c_aη_a)` **solo** vale si esos productos no cambian con `α`; si cambian,
   hay que resolver y publicar todas las raíces y regiones de signo.
3. **La maquinaria exacta de la DP** (`src/dp.jl` + `src/referencia.jl`): masa cruda, soporte
   adaptativo, `[P_L,P_U]` con fuga acumulada, absorción separada `z=0` / `z≤−1`, y oráculo exacto
   `Rational{BigInt}`. Está **certificada** (error ≤ `5,7e-16` en la rejilla publicada) y es
   reutilizable tal cual, con el aviso C9 de `DEFECTOS.md` (`max_ancho` puede devolver una corrida
   no certificada sin marcarla).
4. **La separación de los tres objetos** `P_terminal` / `P_first_passage` / `P_eventual`
   (`src/eventos.jl`) y el cálculo de `α_prob` con cobertura simultánea (Clopper–Pearson +
   Bonferroni), con la regla «una celda `0/n` nunca es una frontera».
5. **El patrón de filtro de flujo**: comparar prefijos en `slot(X)` de **todo** `past(B)`, antes de
   U2/U3 y de colorear; divergencia futura no invalida pasado común. La **forma** es la de
   `C-FLU-14` y es correcta.
6. **El hecho de que el DAG con red produce rojos reales** y que la métrica de rojos debe ser por
   contexto, no una unión.

**NO puede darlo por sentado:**

1. **Que `α` sea una fracción de espacio.** En v0.2/v0.3 `α` es una **probabilidad de oportunidad
   por slot**; el puente `espacio → tasa` (distancia circular, `sd ≤ SR/2`, chunks ganadores) **no
   existe** en el código (`DEFECTOS.md` C1). Cualquier `α` propio de P-PRESTAMO tiene que declarar
   si es espacio o tasa y, si es espacio, aportar la derivación.
2. **Que `η_a` sea 1.** Lo es por construcción en el DAG de v0.3 (rama = cadena): es una identidad,
   no una medición (`DEFECTOS.md` C4). `η_h` está medido sin IC y sin excluir el prefijo común.
3. **Que las réplicas sean independientes.** Las semillas son `StableRNG(SEMILLA + r)`,
   consecutivas, con autocorrelación lag-1 medida de **−0,43 / +0,71**; el efecto sobre las cifras
   publicadas **no está determinado** (`DEFECTOS.md` A1). Para `β` prestado hay que usar un RNG
   contracorriente bien derivado (`set_counter!(r, (0, id))`, ver A2) y **no** reutilizar los IC
   publicados como si fueran exactos.
4. **Que un IC de Wilson sobre 24 (o 64) réplicas acote lo que dice acotar.** Esos IC suponen iid.
5. **Que `S·α` sea un riesgo del protocolo vigente.** `C-FLU-13` cierra el multistream; `C-FLU-14`
   prohíbe referenciar otro flujo. `S·α` pertenece al contrafactual aditivo.
6. **Que `S = 24` esté acreditado.** Es un escenario de barrido; `S_adversario` está pendiente y
   **no** se deriva de 100 k IOPS ni de un microbenchmark de page cache.
7. **Que `α = 1/2` o `α = 1/(S+1)` sean el umbral.** Lo primero es una identidad del baseline; lo
   segundo, una identidad del toy aditivo.
8. **Que la validez de fusión esté cerrada.** C-GD-11 tiene cinco pendientes y el controlador del
   SPEC no tiene ventana.
9. **Que el filtro de flujo esté validado.** El flujo se **declara** (`DescriptorFlujo`) en vez de
   derivarse de `past(B)`, y no hay PoT AES.
10. **Que la red esté modelada.** Δ es fija en slots, sin colas, sin régimen degradado, sin
    presupuesto de eclipse.
