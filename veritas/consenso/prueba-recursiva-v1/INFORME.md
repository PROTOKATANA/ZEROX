# INFORME — PRV-v0.1 · ¿Da una prueba recursiva el IBD sin confianza?

**Categoría:** `consenso` (dominante); `criptografía` (secundaria). **Pregunta:** ¿puede una prueba
recursiva dar IBD sin confianza en ZEROX, y a qué coste?

**Respuesta corta.**
1. **Selección: NO.** Una prueba recursiva acredita **validez** de una historia. La cadena canónica
   de GHOSTDAG es una propiedad del **conjunto** de ramas (máximo `blue_work` entre todas las
   puntas). No existe, con los mecanismos examinados, un objeto comprobable sin el DAG que decida
   que ninguna rama competidora tiene más `blue_work`. Es **demostrado** (Proposición §1),
   independiente del coste, y cierra el problema (2) del encargo 05 por una segunda vía.
2. **Coste: no cierra a 1 bloque/s** con Halo2 realista para ventanas de fusión de escala
   finalidad; cerraría solo con `W` pequeña o con un probador entre `10²` y `10⁵`× más rápido
   (§2). Distinto de «no puede funcionar»: es «no a esta tasa con esta tecnología».
3. Lo que sí da una prueba recursiva: IBD **desde un checkpoint confiable** (§12.1, C-CHK) o bajo
   supuesto de disponibilidad completa — que no es «sin confiar en nadie».

---

## 1 · SELECCIÓN: la pregunta del §2, tratada primero

### 1.1 La pregunta, sin adornos

> ¿Existe algo que un nodo nuevo pueda comprobar, **sin el DAG**, que le diga que **ninguna rama
> competidora tiene más `blue_work`**?

### 1.2 Proposición (imposibilidad de la selección por validez) — **demostrado**

Sea `Canon(D)` la punta canónica de un DAG `D` bajo GHOSTDAG: la punta de mayor `blue_work`
(§11, C-GD-03 y C-GD-08), que es función del **conjunto** de bloques de `D`. Sea `V` un verificador
determinista que recibe un génesis `g`, una prueba `π` de **validez de una historia** y parámetros
públicos, y devuelve una punta `t`. Entonces `V` **no** decide `Canon(D)`.

**Demostración.** Consideremos dos mundos con las mismas reglas:

- **Mundo 1:** los bloques publicados forman `D = H1`; punta canónica `Canon(H1)`.
- **Mundo 2:** los bloques publicados forman `D = H1 ∪ H2`, donde `H2` es una rama privada
  **válida** con `max blue_work(H2) > max blue_work(H1)`, que el adversario **retiene** (no la
  publica).

En ambos mundos el nodo nuevo recibe la misma entrada: `(g, π(H1))`, porque `π(H1)` sólo depende de
`H1`, que es idéntica en los dos. Un verificador determinista devuelve lo mismo en ambos:
`V(g, π(H1)) = t`. Pero la punta correcta difiere: en el mundo 1 es `Canon(H1)`; en el mundo 2 es
la punta de `H1 ∪ H2`. Luego `V` yerra en al menos un mundo. ∎

**El punto no es la criptografía, es la lógica.** `Canon` no es una función de una historia
aislada; es una función del conjunto. Una prueba que sólo atestigua un elemento del conjunto no
puede computar una función que depende de los demás. Es el mismo agujero que D5 de PPP-v0.1
(«nada de lo que un tercero puede comprobar sin el DAG determina el DAG»), ahora con el traje de
la prueba recursiva.

**Un enunciado más fuerte no ayuda.** Una prueba podría pretender «ninguna extensión válida de
`H1` supera este `blue_work`». Ese enunciado es falso en general: para cualquier cota, un
adversario con suficiente espacio puede publicar una extensión que la supere. Sólo sería cierto
**relativo a un supuesto de recursos acotados del adversario**, no como teorema. Y ese supuesto es
precisamente el que PPP-v0.1 midió como más débil en PoST que en PoW (doble uso del espacio, D6;
`blue_work` declarado, ATAQUE 8).

### 1.3 Instanciación con el oráculo (GDR-v0.2) — **medido**

`run.jl --seleccion` (semilla `0x5E1EC7`, `n=40`):

```
H1: 40 bloques, canónica = 39, blue_work = 4.083…e+39
H2: 41 bloques, canónica = 41, blue_work = 4.083…e+39   (mayor)
verifica_prueba_validez(H1) = true   verifica_prueba_validez(H2) = true
H1.canonica != H2.canonica : true
```

`H2` es `H1` más un bloque válido `Y` que fusiona las puntas de `H1`. Ambas historias son válidas
bajo las reglas reales (construidas por el oráculo, ningún bloque rechazado), y sus pruebas de
validez son aceptadas. No es un caso patológico: es la situación normal en que un bloque pesado
llega después.

### 1.4 Por qué las reglas de Mina no se trasladan

Mina usa recursión (Pickles) y reglas de **densidad** y ventanas de *long-range fork* para acotar
ramas privadas. La diferencia clave:

- Mina prueba una **cadena lineal** de consenso *stake-based*: un bloque por slot y por sorteo de
  VRF, con lo que la longitud/densidad de una cadena privada está acotada por la **fracción de
  stake** del adversario. La densidad es una propiedad de **la cadena** y la recursión puede
  demostrarla.
- ZEROX no tiene esa propiedad. La selección es GHOSTDAG sobre un **DAG con mergesets**, y —lo
  decisivo— el recurso no está ligado a la historia: el mismo billete/espacio puede respaldar
  varias ramas y hay varios chunks ganadores por s-bucket (`PROCEDENCIA.md` §3.2 del 05;
  `research/dag-poas-auditoria.md` A3 y ATAQUE 2). Una rama privada puede inflar su `blue_work` sin
  pagar espacio proporcional. Por tanto **la densidad de una cadena no acota una rama privada de
  GHOSTDAG**, y la regla de Mina no es transferible.

Además, `blue_work` declarado en cabecera es gratis bajo PoST (PPP-v0.1, ATAQUE 8): la regla
«adoptar la prueba con más `blue_work` observado» hereda esa debilidad. La recursión **no** la
arregla; sólo hace barata la verificación de la validez.

### 1.5 Qué sí resolvería (y no es «sin confiar en nadie»)

1. **Checkpoint firmado** (§12.1, C-CHK): fija la rama canónica en una altura. A partir de ahí, una
   prueba recursiva extiende la cadena verificando transiciones. Es IBD **desde el checkpoint**, con
   la confianza puesta en el firmante — un único checkpoint, no «sin confiar en nadie».
2. **Disponibilidad completa**: si el nodo recibe todas las puntas (o una prueba de que el
   compromiso del DAG es completo), la validez recursiva del DAG completo sí decide `Canon`. Pero
   eso exige **los datos** (disponibilidad) o confiar en el probador; es el problema (3) del 05, no
   una solución a (2).
3. **Supuesto de mayoría honesta y sincronía**: bajo el modelo de red sincrónica con mayoría
   honesta, la cadena observada es la canónica con alta probabilidad. Es un supuesto, no una
   prueba, y PPP-v0.1 mostró que en ZEROX el margen económico es menor que en PoW.

**Veredicto de selección: NO** — «no existe un objeto comprobable sin el DAG que decida que ninguna
rama competidora tiene más `blue_work`», **demostrado**, no condicionado al coste.

---

## 2 · COSTE de probar GHOSTDAG recursivamente (secundario, tras el «no» de §1)

### 2.1 Método

Se reutiliza **GDR-v0.2** para construir DAGs válidos y se **cuenta** lo que un circuito tendría
que probar por bloque de cadena: candidatos del mergeset, contexto azul, decisiones de ancestría
(reachability) del k-cluster, hashes de identidad de billete, sumas `u256`, comparaciones de orden.
Cada decisión de ancestría se traduce a `ceil(log2(W+1))` hashes Poseidon, y cada hash a
`80 · gates_por_sbox` restricciones. Factores:

- `80` S-boxes por permutación: **CITADO** (`halo2_poseidon` 0.1.0, `P128Pow5T3`: `R_F=8`,
  `R_P=56`, ancho 3, S-box `x^5`; es la primitiva de Orchard, `SPEC.md` §9).
- `gates_por_sbox ∈ {2,4}` y las tasas de campo (`1e6` Halo2 realista, `1e9`, `2,4e10`):
  **DECLARADAS**. El probador Halo2 hace Ω(n) operaciones de campo para n filas; el tiempo es
  `≥ restr / ops_campo` (fuente «Proving system», halo2 Book).

### 2.2 Medición y barrido — **medido + estimado**

`run.jl --barrido --n 512` (DAG de GDR-v0.2): mergeset medio `M = 0,88`, contexto medio `205,5`
(crece con `n`, como corresponde a un DAG sin podar). Modelo por bloque:
`restr = M · W · ceil(log2(W+1)) · 80 · gs`, con `gs=2`.

| `W` | restr/bloque (`M=0,88`) | restr/bloque (`M=180`) | bloq/s Halo2 (M=0,88) | bloq/s Halo2 (M=180) |
|---:|---:|---:|---:|---:|
| 10 | 5,64e3 | 1,15e6 | 1,77e2 | 8,68e-1 |
| 100 | 9,87e4 | 2,02e7 | 1,01e1 | 4,96e-2 |
| 1 000 | 1,41e6 | 2,88e8 | 7,10e-1 | **3,47e-3** |
| 10 000 | 1,97e7 | 4,03e9 | 5,07e-2 | 2,48e-4 |
| 100 000 | 2,40e8 | 4,90e10 | 4,17e-3 | 2,04e-5 |

**Ventana crítica `W*`** (mayor potencia de 2 que cierra a 1 bloque/s):

| `M` | Halo2 realista (1e6/s) | optimista (1e9/s) | 24 hilos (2,4e10/s) |
|---|---:|---:|---:|
| medido (0,88) | **512** | 262 144 | 4 194 304 |
| tope C-GD-04 (180) | **8** | 2 048 | 32 768 |

**Comparación con cadena lineal** (`--lineal`, `n=512`, `W=1000`): `2,94e5` frente a `3,20e2`
restricciones por bloque → **factor ≈ 918×**. El factor mide lo que añaden mergeset, coloreo y
reachability.

### 2.3 Lectura

- Con **Halo2 realista**, a `W=1000` y mergeset saturado (`M=180`) el coste es `2,88e8`
  restricciones/bloque: **288 s por bloque en un hilo**, o `3,5e-3` bloq/s. Para cerrar a 1
  bloque/s harían falta `2,88e8` restricciones/s: **~288×** el throughput realista por hilo, o
  ~12× repartido en 24 hilos. **No cierra a 1 bloque/s.**
- Con el mergeset medido (`M=0,88`), a `W=1000`: `1,41e6` restricciones/bloque → `0,71` bloq/s con
  Halo2 realista (**no cierra**); `709` bloq/s con la cota optimista `1e9` (sí). La frontera está
  en `W*≈512`.
- La **cota es inferior**: firmas Ed25519, 2 KZG por cabecera, la cadena PoT (AES por slot) y las
  transiciones UTXO **no están incluidos**. Incluirlos sólo baja la tasa.
- La **recursión añade** además verificar la prueba anterior dentro del circuito, que tampoco se
  cuenta.

**Distinción obligatoria:** esto es **«no cierra a 1 bloque/s con esta tecnología»**, no **«no
puede funcionar»**. Cerraría si: (a) la ventana de fusión `W` es pequeña (≤ ~512 con M medido, ≤ ~8
con M saturado y Halo2 realista); o (b) se dispone de un probador de GHOSTDAG ~10²–10⁵× más rápido;
o (c) la tasa objetivo baja a `~10⁻²–10⁻³` bloq/s (~100–1000 s por bloque). Cuál de las tres es
aceptable es decisión de diseño, no de esta auditoría.

---

## 3 · Qué hace falta que ZEROX no tiene (§3.3)

1. **Estado UTXO con datos de deshacer** (TAREAS §2.6): **hoy no existe** (`TODO(sincronizador)` en
   `crates/zx-node/src/cadena.rs`, citado por TAREAS §2.6). Sin estado, la prueba no tiene qué
   comprometer en su input público; la recursión prueba una transición cuyo resultado no puede
   comprometerse. Es dependencia **dura**, ya señalada en `PROPUESTA.md` P3.3 del 05.
2. **Compromiso de estado verificable** (raíz de UTXO o acumulador). Necesario para que el input
   público exista; su coste se suma al de §2.
3. **Disponibilidad de datos**: la prueba acredita el estado, pero el nodo necesita **los datos**
   para operar (validar nuevas txs, servir a otros). Si salen de archivales, es la capa social del
   encargo 05 y **no cuenta como solución** al IBD sin confianza.

---

## 4 · `orchard = "=0.15.5"`: ¿ventaja de recursión? (§3.4)

**Condición necesaria, no suficiente.** Hechos comprobados:

- `SPEC.md` §9 fija `orchard = "=0.15.5"`; Orchard es Halo2 sobre el ciclo **Pallas/Vesta**
  (`research/orchard-bundle.md:58` «prueba Halo2 agregada»; `:19` clave Pallas; `:128`
  `halo2_gadgets`). El ciclo Pasta es la familia que permite recursión sin *trusted setup*.
- Pero **Halo2 no es un sistema de recursión**. Su libro describe compromisos, FFT/MSM, vanishing
  y argumento de producto interno; la recursión exige implementar el **verificador dentro del
  circuito** más un sistema PCD/IVC (Kimchi/Pickles en Mina). Nada de eso viene con `orchard`.
- Lo que `orchard` aporta: la primitiva **Poseidon P128Pow5T3** y un probador Halo2. No un circuito
  de consenso ni de fork-choice.

Conclusión: tener Halo2 en el árbol evita cambiar de curvas, pero **no es recursión disponible**.
Presentarlo como tal sería el error que el §6 del encargo rechaza.

---

## 5 · Vectores adversariales (§3.5)

1. **Rama privada probada recursivamente (§2):** la prueba verifica correctamente y no revela la
   rama canónica. Es el resultado de §1.
2. **Long-range fork desde un punto antiguo:** la recursión no cambia la selección; las reglas de
   densidad de Mina no se trasladan (§1.4). El coste para el adversario depende del recurso, que en
   PoST no está ligado a la historia.
3. **DoS asimétrico por generación de pruebas:** verificar una prueba es barato; generarla es caro
   (§2). Un adversario puede inundar con pruebas válidas de ramas no canónicas y forzar trabajo de
   verificación/reorganización, mientras elige cuándo probar. La asimetría es del propio esquema.
4. **El probador honesto no sigue el ritmo:** a 1 bloque/s el honesto debe generar una prueba por
   segundo. Con Halo2 realista y ventana de escala finalidad, §2.2 da `~10⁻²–10⁻³` bloq/s por hilo:
   **no llega**. Con 24 hilos tampoco para ventanas grandes.

---

## 6 · Las cinco preguntas de LINEO

**1. Complejidad.** Referencia (recomputación independiente): `O(n²)` por los anticonos. Kernel
`contar_rapido`: `O(n + Σ|blueset|)`; medido `0,129 ms` para `n=512`. Modelo de coste: `O(1)`.
Parámetro dominante del circuito: `W` (y `M`).

**2. Perfil y asignaciones.** `contar_rapido`: 21 asignaciones, `0,13 ms` (`n=512`);
`coste_restricciones`: 0 asignaciones, `0,08 µs` (`resultados/BENCH.txt`). Escalado por réplicas
independientes (`128` DAGs × `1024` bloques) 1→24 hilos: `7,27e5 → 3,25e6` bloques contados/s
(×4,5; se aplana en 8–24 por ser el conteo ligado a `Dict`/memoria, no por CPU). Sin BLAS.

**3. Oráculo.** GDR-v0.2 (auditado) para GHOSTDAG; referencia **independiente** para el conteo
recomputando mergeset por conjuntos y anticono por ancestría. Equivalencia: **0 fallos** en DAGs
aleatorios.

**4. Tipos numéricos.** `blue_work` es `BigInt` en el oráculo (exacto); el coste usa `Float64` para
una **estimación** declarada con rango, nunca para un veredicto discreto. Sin `@fastmath`.

**5. Semilla, versión y hardware.** Cada `resultados/run-*.txt` lleva hash Git, fecha, `julia
1.13.0`, CPU `znver5`, hilos, comando y semilla. `Project.toml` recortado a **9** dependencias.

---

## 7 · Límites declarados

- **Cota de coste inferior** (excluye Ed25519, KZG, PoT, UTXO y el verificador recursivo).
- La **tasa de operaciones de campo es declarada**, no medida en esta máquina; por eso se dan tres
  escenarios y la frontera `W*` para cada uno.
- El **orden en `W`** del coloreo asume la definición (par candidato×azul); una implementación
  incremental reduce constantes, no la dependencia en `W`.
- **`W` no se fija** (C-GD-11 pendiente): todo va como función de `W`.
- La proposición de §1 es sobre pruebas que sólo acreditan validez; con checkpoint o disponibilidad
  completa cambia, y se dice.
- **No demostrado:** que la cota `M·W` sea la del algoritmo incremental real de rusty-kaspa (se
  modela la definición); el coste exacto de KZG/Ed25519 en circuito; la tasa real de un probador
  Halo2 en `znver5`.

---

## 8 · Lo que se rechaza, explícitamente

- **No se presenta «se puede probar la transición» como «IBD resuelto»**: §1 demuestra justo lo
  contrario.
- **No se da por buena una estimación de restricciones sin fuente**: el factor de 80 S-boxes está
  citado; el resto va marcado DECLARADO con rango.
- **No se presenta Halo2-en-el-árbol como recursión disponible** (§4).
- **No se omite la dependencia de §2.6** (estado UTXO inexistente).
- **No se fija ningún parámetro** ni se usa `F = 2 h`.
