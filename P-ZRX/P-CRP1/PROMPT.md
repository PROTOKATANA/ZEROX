Trabajas en el repositorio ZEROX, en /home/katana/zeo/ZEROX. Lee `AGENTS.md` antes de empezar. Responde en español.

**Bloque obligatorio de `veritas/LINEO.md` §8, copiado literalmente:**

Eres especialista senior en Julia para cómputo científico reproducible, teoría de protocolos y
optimización de alto rendimiento. Antes de escribir o modificar código, lee por completo
`veritas/LINEO.md` y cumple todas sus reglas.

Tu prioridad conjunta es: **(1) resultado matemáticamente verdadero y reproducible; (2) el máximo
rendimiento medido compatible con esa verdad.** No aceptes un programa lento sin un perfil, ni una
aceleración sin una prueba contra un oráculo independiente.

Procedimiento obligatorio:

1. Formula el modelo matemático, la complejidad temporal/espacial y el adversario/caso de borde
   relevante antes de elegir la estructura de datos.
2. Diseña la representación para la operación dominante: tipos concretos, arrays contiguos,
   SoA frente a AoS, IDs densos, `BitVector`/CSR/`StaticArrays`/`Dict` solo cuando el caso lo
   justifique. Explica brevemente la elección.
3. Escribe primero una referencia pequeña, transparente y preferiblemente exacta; crea tests de
   bordes, invariantes, contraejemplos previos y semillas fijas.
4. Implementa el kernel rápido dentro de funciones tipoestables, sin globals dinámicos ni `Any`.
   Preasigna memoria, usa versiones mutantes (`!`), evita asignaciones y respeta el orden de
   columnas. No materialices combinaciones, grafos o temporales innecesarios.
5. Valida el kernel rápido contra la referencia en instancias pequeñas, propiedades aleatorias y
   todos los vectores de regresión. Para umbrales numéricos, certifica con exactitud, intervalos o
   aritmética de bolas; si el margen no se puede certificar, declara el resultado inconcluso.
6. Mide el caso representativo tras calentar JIT con `BenchmarkTools`; perfila CPU/memoria con
   `Profile`, `@allocated`, `@code_warntype` y JET. Optimiza el cuello real, no el supuesto.
7. Paraleliza solo trabajo independiente y usa RNG por réplica/chunk, reducción determinista y
   ausencia demostrada de carreras. Arranca batch CPU-bound dentro del tope de 24 hilos (8 lógicos
   quedan para el sistema), mide el escalado `1…24` y conserva la configuración que gane
   realmente, aunque use menos hilos; evita BLAS anidado.
8. Considera `LoopVectorization` o MPI únicamente si el perfil demuestra un kernel regular
   dominante y el coste no lo anula. Para GPU **no uses Julia**: escribe el kernel en C++/CUDA
   (§5.7), con oráculo CPU estricto, transferencias medidas y `compute-sanitizer`. Compara siempre
   con CPU estricta.
9. No uses `@fastmath`. `@inbounds`, `@simd`, `@turbo` o precisión `Float32` requieren prueba de
   equivalencia, comentario de supuestos y benchmark. Nunca dejes que una optimización cambie un
   veredicto sin declararlo.
10. Entrega `Project.toml`, `Manifest.toml`, comando exacto, semilla, versión/hardware, tabla de
    rendimiento, número de asignaciones y resultado de la validación. Distingue con claridad lo
    demostrado, medido, estimado y no demostrado.

11. Declara antes de ejecutar el presupuesto de tiempo, memoria y disco (en la máquina de
    referencia: máximo 64 GiB de RAM y 24 hilos). Si se agota, conserva el checkpoint y reporta
    **inconcluso**; guarda semilla, parámetros, configuración y una entrada mínima reproducible
    para cada fallo. No confundas timeout con evidencia de falsedad.

Si una corrida supera el presupuesto declarado, detente antes de ampliar la exploración y produce
un perfil más una hipótesis de cuello de botella. Propón la mejora algorítmica o de datos de mayor
impacto y verifica que conserva resultados antes de lanzar otra corrida larga.

---

ADAPTACIÓN DEL BLOQUE ANTERIOR A ESTE ENCARGO: es una **auditoría de un instrumento Julia ya escrito**, con
recálculos propios pequeños y exactos (el bloque te aplica entero para ellos). **Máximo 4 hilos**: hay
otros encargos en la misma máquina y el tope conjunto es 24. Julia en CPU con `./veritas/julia.sh`;
**nada de Python**. Anota `uptime` antes de cada corrida: tus resultados son deterministas, pero **todo
tiempo publicado se etiqueta «medido con carga ajena»** si la carga supera tus hilos.

# ENCARGO P-CRP1 — ¿Son reales los diez defectos atribuidos a CRP-v0.1, y cuánto mueven sus cifras?

## 0 · Por qué existe este encargo

Sobre el mismo instrumento hay **dos documentos del proyecto que se contradicen**, y los dos los escribió
el validador (Claude):

- `veritas/seguridad/coste-rama-privada-v1/PROCEDENCIA.md` (2026-09-18): CRP-v0.1 fue *«validado por
  Claude reejecutando»*, es *«el único cuyo veredicto principal sobrevive a la validación sin recortes»*,
  y *«el umbral es `1/2`, igual que PoW»*.
- `P-ZRX/rescate-deepseek/encargos/ENCARGO-07v2-coste-rama-privada.md` §2: enumera **diez defectos de
  CRP-v0.1 (D1–D10)**, lo rebaja a *«baseline idealizado útil; veredicto protocolario inconcluso»* y
  **prohíbe** escribir «en la liga de PoW» o «seguro al 50 %».

**Nadie ha comprobado los diez defectos contra el código de CRP-v0.1.** La propia `PROCEDENCIA.md`
advierte, a propósito de otro encargo, que *«reproducir no es validar»*: Claude reejecutó, vio que las
cifras salían y dio por bueno el veredicto. Mientras tanto, las cifras de CRP-v0.1 **se citan en
`SPEC.md` y en `TAREAS.md`**, el 2026-09-21 Claude usó «el umbral ya es el 50 %, igual que Bitcoin» como
titular de una sesión entera de diseño, y los documentos de `P-ZRX/T-ZRX/` se apoyan en dos cifras suyas:
la **compra de varianza** con `sr` bajo (`P` de 2,2 % a 30,8 %) y la tabla del **multistream**
(`α_mín = 1/(S+1)`).

Otro encargo, `P-ZRX/P-CRP/`, audita si CRP-v0.2 y v0.3 **corrigieron** esos defectos. **El tuyo es
anterior en la lógica: ¿los defectos son reales, y cuánto mueve cada uno las cifras publicadas?** No
reescribes CRP-v0.1 ni haces una versión nueva: compruebas, recalculas lo que haga falta con un método
independiente y exacto, y dejas dicho **qué cifras se sostienen, cuáles cambian y cuáles caen**.

## 1 · Entradas (todas de SOLO LECTURA; sus huellas están en `ENTRADA.sha256`)

- `veritas/seguridad/coste-rama-privada-v1/` — los 34 ficheros de CRP-v0.1: `INFORME.md`, `MODELO.md`,
  `CONTRATO.md`, `METODO.md`, `PROPUESTA.md`, `PROCEDENCIA.md`, `BITACORA.md`, `src/`, `test/`, `bench/`,
  `run.jl`, `resultados/`.
- `P-ZRX/rescate-deepseek/encargos/ENCARGO-07-coste-rama-privada.md` — el encargo **original** de
  CRP-v0.1 (qué se le pidió).
- `P-ZRX/rescate-deepseek/encargos/ENCARGO-07v2-coste-rama-privada.md` — **§2 es tu lista de cargos**:
  D1 «el supuesto DAG era una cadena» · D2 «la DP de granularidad perdía casi toda la masa» · D3
  «empatar no es superar estrictamente» · D4 «`λ ∝ SR` era un supuesto, no una derivación» · D5 «el
  controlador real no se modeló» · D6 «los rojos asimétricos no estaban medidos» · D7 «multistream era
  una identidad tautológica» · D8 «el fixture U2/U3″ entre ramas era insuficiente» · D9 «`S = 24` no fue
  una medición del v1» · D10 «"ataque gratis" estaba sobre-enunciado».
- `veritas/consenso/ghostdag-rank-v1/` — GDR-v0.2, el oráculo de GHOSTDAG que CRP-v0.1 reutiliza.
- `veritas/consenso/puerta-cobertura-v1/` — PCO-v0.1, que demostró **por otra vía** (en
  `Rational{BigInt}`) que el `SR` se cancela, con un residuo `1/(SR+1)` para `SR` impar. Es tu contraste
  independiente para D4.

**Para ejecutar, copia CRP-v0.1 a tu zona** (`cp -a`): correrlo en su sitio sobrescribiría `resultados/`.
CRP-v0.1 busca GDR por rutas relativas (`src/rapido.jl:161-162`, `run.jl:62-64`) y desde una copia puede
no encontrarlo: si hace falta, corrige **solo esa ruta y solo en tu copia**, y guarda el `diff` en
`PROGRESO.md`. Es la única modificación permitida.

## 2 · Qué hay que hacer con cada defecto

Para **cada uno** de D1…D10, la misma ficha:

1. **El cargo**, citado literalmente del encargo 07v2.
2. **Dónde está en el código** de CRP-v0.1: fichero, función y línea. Si no está, dilo.
3. **Reproducción mínima**: el comando o las pocas líneas de Julia que lo hacen visible, con su salida.
4. **Veredicto: real / real a medias / no real / no aplicable.** Un cargo puede ser injusto: si lo es,
   defiéndelo con la misma evidencia.
5. **Qué cifras publicadas toca** (de `INFORME.md`, `PROPUESTA.md` y `PROCEDENCIA.md`) y **cuánto**:
   recalcula con un método **independiente y exacto** y da el valor corregido con su error o su intervalo.

Guía, que **no sustituye a leer el código**:

- **D1.** Ejecuta la construcción de ramas con GDR y mira `n_azules` frente a `n_total`, puntas por slot
  y si **algún** test o resultado ejercita anticonos o `rojo_k`. ¿Qué resultados dependen de ello
  (`run-gdr.txt`, el §6 sobre U2/U3″)?
- **D2.** **Suma la masa de la DP** para `g ∈ {1, 4, 16, 64, 256}`. La tabla publicada de `P(alcance)`
  (`α = 0,4`, `d = 6`) va de `8,0·10⁻²` a `3,2·10⁻²⁶`: recalcúlala bien —ruina exacta en
  `Rational{BigInt}`, unidades de peso explícitas (`d` en trabajo es `d·g` en la retícula), soporte
  adaptativo con masa conservada— y di si la frase *«la contribución del DAG es de varianza, no de
  umbral»* **sobrevive** con la tabla corregida.
- **D3.** ¿Qué evento usa cada tabla, **empatar** `(q/p)^d` o **superar** `(q/p)^(d+1)`? La curva
  `α_mín(d, ε) = 1/(1 + ε^(−1/d))`, ¿cuál es? Da la tabla con el evento estricto.
- **D4.** ¿`λ ∝ SR` está **derivado** del predicado de aceptación PoAS (distancia circular,
  `solution_distance ≤ solution_range/2`, extremos de dominio) o **supuesto**? Contrástalo con PCO-v0.1.
  Si la cancelación es cierta pero CRP-v0.1 la «demostró» con un supuesto, el veredicto es *«conclusión
  correcta, demostración circular»*: dilo así.
- **D5 — y la cifra que más importa.** Los controladores `CTRL_FIJO/REACTIVO/INVERSO` son una familia de
  juguete; el controlador del SPEC está pendiente (`TAREAS.md` §2.3). La tabla de **compra de varianza**
  —`α = 0,45`, `T = 400` slots, `K = sr0/sr ∈ {1, 4, 16, 64}`, `P(adv > hon)` = 0,022 / 0,097 / 0,244 /
  0,308— **es la evidencia del agujero A2 de `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` y de la propuesta
  P1–P3 para R-FIN-13′.** Recalcúlala **sin Monte Carlo** (convolución exacta de dos procesos de Poisson
  compuestos, o DP con masa conservada) y, aparte, con MC bien hecho: réplicas e IC declarados, RNG por
  réplica y **semillas no consecutivas** (`P-ZRX/P-PUERTA/` encontró que las consecutivas de `StableRNG`
  sesgan el MC). ¿El evento es superar o empatar? ¿Depende del defecto D1?
- **D6.** `PROCEDENCIA.md` §3.2 acota los rojos asimétricos con `α > (1−f)/(2−f)` y afirma que *«la Δ
  medida es 0,26–0,60 s»*. Comprueba la fórmula y **la etiqueta**: `P-ZRX/P-2.1/SINTESIS.md` dice que esa
  `Δ` es **simulada (DMS-v0.1), no medida en red**.
- **D7.** ¿El test del multistream compara `S·α/(1−α+S·α)` **con esa misma fórmula**? Muéstralo. Di qué
  queda realmente demostrado: que la fórmula es la que es, o que `S` flujos **se pueden sumar**.
- **D8, D9, D10.** Qué cubre y qué no el fixture U2/U3″; de dónde sale `S ≈ 24` (¿una cota de IOPS
  citada, o algo medido?); y qué calcula de verdad el §4 del informe cuando escribe «gratis».

**Si encuentras defectos que no están en la lista, añádelos** como D11, D12… con la misma ficha.

## 3 · Zona de trabajo y huellas

**Escribes SOLO en `P-ZRX/P-CRP1/auditoria/`** (tu copia de CRP-v0.1 en `auditoria/copia/`; tus
recálculos en `auditoria/veritas/seguridad/crp1-defectos-v1/`, con la estructura de LINEO §1). No edites
ni muevas nada de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`
—**incluido `veritas/seguridad/coste-rama-privada-v1/`**—, `PDF/` ni del resto de `P-ZRX/`. En
`P-ZRX/P-CRP1/` son de solo lectura `PROMPT.md` y `ENTRADA.sha256`. Al empezar y al terminar, desde la
raíz:

```bash
LC_ALL=C sha256sum -c P-ZRX/P-CRP1/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

con las tres salidas en `PROGRESO.md`. `ENTRADA.sha256` cubre este prompt, los dos encargos y **los 34
ficheros de CRP-v0.1**.

## 4 · Entregables (`P-ZRX/P-CRP1/auditoria/`)

- `INFORME.md` — **su primera línea es la respuesta**: cuántos de los diez defectos son reales, **qué
  cifras publicadas caen o cambian y cuáles se sostienen**, y si el veredicto de `PROCEDENCIA.md`
  («sobrevive sin recortes») se mantiene. Después, las diez fichas.
- `CIFRAS.md` — **una fila por cada cifra publicada** en `INFORME.md`, `PROPUESTA.md` y `PROCEDENCIA.md`
  de CRP-v0.1: valor publicado · defecto o defectos que la tocan · valor recalculado con su error · 
  estado: **se sostiene / cambia / cae / no determinable** · método del recálculo.
- `DEPENDIENTES.md` — las frases de `SPEC.md`, `TAREAS.md`,
  `veritas/seguridad/coste-rama-privada-v1/PROCEDENCIA.md`, `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md`,
  `P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md` y los `PROMPT.md` de `P-ZRX/` que citan una cifra
  afectada, con la **redacción que proponen tus resultados**. **No edites ninguno.**
- `PROGRESO.md` — bitácora con `date`, `uptime`, las comprobaciones de entrada y salida y el `diff` de la
  ruta de GDR si lo hubo.
- Tus recálculos, con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 5 · Reglas de validez

- **No cites un archivo, una línea ni un artículo sin abrirlo.** Rutas completas desde la raíz.
- **Etiqueta cada afirmación:** `demostrado`, `verificado en fuente`, `reproducido`, `recalculado` (con
  qué método), `medido`, `derivado`, `estimado`, `no determinado`.
- **No valides por autoridad, en ninguna dirección.** Ni `PROCEDENCIA.md` ni el encargo 07v2 tienen razón
  por haberlo escrito Claude: los dos pueden estar equivocados, y no en lo mismo.
- **Un test que compara una fórmula consigo misma no es un test**: tus recálculos se contrastan con una
  referencia que no salga de ellos.
- **No fijes** ningún parámetro de consenso. Y el veredicto del encargo 07v2 §1 sigue en vigor: **no se
  admite «en la liga de PoW» ni «seguro al 50 %»** mientras quede una hipótesis necesaria pendiente.
- Cierra con **«Lo que esta auditoría NO resuelve»**.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y en
`PROGRESO.md`. Después Claude lee tu trabajo cita por cita y repite los recálculos clave, y Katana decide.
