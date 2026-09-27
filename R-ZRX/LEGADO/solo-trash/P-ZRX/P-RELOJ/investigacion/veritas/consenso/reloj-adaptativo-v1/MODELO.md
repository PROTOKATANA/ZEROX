# MODELO.md — los tres modelos del instrumento `reloj-adaptativo-v1`

Categoría: **consenso** (lo dominante es la regla de consenso; secundarias: **rendimiento**, por el
coste de verificación, y **red**, por el presupuesto de `C-NET-33`). Motivo de la categoría, como
pide `veritas/LINEO.md` §1: la pregunta del encargo —si `N` puede adaptarse— solo se puede contestar
dentro de las reglas de consenso vigentes, y lo que decide es un presupuesto de cómputo.

**Todos los símbolos de este documento son ENTRADAS.** El instrumento no fija `N`, `N_max`, `τ`,
`ρ_max`, el presupuesto de verificación `ε`, el FTL, el número de carriles `K` ni la ganancia del
controlador. Lo único que fija son las magnitudes **medidas** en esta máquina, en `PROCEDENCIA.md`.

---

## M0 · Magnitudes medidas

Una iteración del PoT es **un cifrado AES-128 completo encadenado**: diez rondas dependientes, nueve
`AESENC` y una `AESENCLAST`, sobre el mismo registro (`PDF/autonomys-subspace/crates/
subspace-proof-of-time/src/aes/x86_64.rs:22-33`, `verificado en fuente`).

| Magnitud | Valor | Clase |
|---|---:|---|
| Latencia de una ronda `AESENC` aislada | 0,7369 ns (4,001 ciclos) | `medido` |
| Latencia de un bloque de 10 rondas, encadenado | 0,7739 ns (42,0 ciclos) | `medido` |
| Coste por bloque con 8 bloques en vuelo (verificar) | 0,9603 ns (5,24 ciclos) | `medido` |
| Coste por bloque con 16 bloques en vuelo | 0,4829 ns (2,63 ciclos) | `medido` |
| Reloj real bajo carga | 5,428 GHz | `medido` |

El **bloque** es la unidad del PoT (`salida(f,s) = AES128_chain^{N(s)}(semilla(f,s))`, `C-POT-02`),
y `N(s)` cuenta **bloques**, no rondas. `N = 206 557 520` bloques ⇒ 2 065 575 200 rondas.

---

## M1 · La frontera del presupuesto de verificación

### Enunciado

Sean

- `N` — bloques AES-128 encadenados por slot (`pot_slot_iterations`), ENTRADA;
- `t_p` — segundos por bloque del productor **más rápido** admitido, ENTRADA;
- `t_v(K)` — segundos por bloque de **verificación** de un nodo, con `K` bloques en vuelo, ENTRADA;
- `K` — carriles de verificación que el nodo puede llevar a la vez, ENTRADA;
- `ε` — fracción del slot que un nodo admitido puede gastar verificando, ENTRADA.

La duración del slot es una **identidad**, no una decisión:

```text
τ = N · t_p
```

El camino que cuesta `O(N)` es el **respaldo** de `C-POT-08` paso 4 (`aes::verify_sequential`,
`verificado en fuente`): recomputar la cadena cuando no hay entrada de caché con la clave contextual
`C-POT-07`. Tarda `N · t_v(K)`.

Un nodo es **admisible** si eso cabe en `ε · τ`:

```text
N · t_v(K) ≤ ε · τ = ε · N · t_p          (ADM)
```

### La consecuencia que no estaba escrita

Con `N > 0`, `(ADM)` se **divide por `N`** y queda

```text
t_v(K) / t_p ≤ ε                          (ADM′)
```

**ni `N` ni `τ` aparecen.** Y como en la MISMA máquina `t_v(K) = lat_bloque / K` —medido: el factor
de paralelismo por tramos sale **8,02×**, `verificado en fuente` en `verif8.c`— entonces

```text
t_f = segundos por bloque de la máquina MÁS RÁPIDA   (= t_p de arriba)
t_s = segundos por bloque de la máquina MÁS LENTA    (= t_v de arriba)

ρ := t_s / t_f  = cuántas veces MÁS LENTA es la lenta   (≥ 1)
                 es la MISMA cantidad que la dispersión S, no su recíproca

la duración del slot la fija el MÁS RÁPIDO:   τ = N · t_f
el MÁS LENTO verifica en:                     N · t_s / K
cabe en ε del slot  ⟺  N·t_s/K ≤ ε·N·t_f  ⟺  ρ / K ≤ ε          (ADM‴)
```

y por tanto

```text
ρ_max = ε · K        la ventaja máxima que admite el presupuesto
ε_min = ρ / K        el presupuesto mínimo que admite esa ventaja
```

`ρ` es la **dispersión de hardware** (lento/rápido) y **no** su recíproco: `t_s/t_f` es a la vez
«cuánto más lenta es la lenta» y «cuánto saca el rápido a la lenta». La nomenclatura coincide con
la del repositorio: `ρ_max = v_A,max/v_ref` (`SPEC.md` §7.3), o sea **el más rápido dividido por la
referencia**, que es esta misma cantidad. **La frontera es un TECHO sobre `ρ`, no un suelo.**

**El presupuesto de verificación no acota `N`:** acota la **dispersión de hardware** de la red.
Es la corrección al §3 del encargo, y está demostrada por división, no por simulación.

### `N_max` existe, pero es otra frontera

```text
N_max(ε, τ, t_v) = ε · τ / t_v
```

Esta sí depende de `τ` y de `t_v`, y es lineal en `τ` e inversa en `t_v`. Las dos fronteras son
compatibles: `(ADM′)` dice cuándo un nodo admite el `N` vigente; `N_max` dice cuántos bloques caben
en el presupuesto de ese nodo.

### Dominio de `C-POT-04`

`N ≠ 0`, `N ≤ u32::MAX = 4 294 967 295`, `N % 16 == 0`. El mayor `N` del dominio es
**4 294 967 280**. Fuera de dominio el estado es `Pendiente`, nunca `Inválido`.

---

## M2 · La región de manipulación de la mediana

### Enunciado

Con timestamps como fuente de tiempo, el adaptador observa la duración de una ventana de `W` bloques:

```text
τ_obs = ts(fin) − ts(inicio)
```

Reglas aplicables: `C-TS-01` (la relación timestamp–slot, **pendiente** en `SPEC.md` §7.4),
`C-TS-03` (FTL, **valor pendiente**), `C-TS-04` (prohíbe la hora de red), `C-TS-02` (MTP no sustituye
el índice PoT). El adversario controla `C = ⌊α·W⌋` posiciones y puede sesgar cada una hasta `δ` por
debajo y hasta `φ` por encima.

### La aritmética del orden

Con `W = 2m+1`, la mediana es la posición `m+1`. El adversario la **fija** con `C ≥ m+1`, es decir
con `α` por encima de `1/2 + 1/(2W)`. Y con menos posiciones **no desaparece el sesgo**: puede
desplazar la mediana de posición. Los dos efectos se suman, y lo que se publica es una **cota
inferior** del ataque:

```text
sesgo_abajo  ≤  −max(C·δ, C)
sesgo_arriba ≥  +C·φ
```

El factor equivalente sobre `N`, a `τ` objetivo fijo, es un **cociente**, no un producto:

```text
N(τ_obs + s) / N(τ_obs) = τ_obs / (τ_obs + s)
```

**Consecuencia de dirección, y es la que importa:** un sesgo **negativo** (la mediana se acorta)
**sube** `N`; uno positivo lo baja. Un adversario que retrasa la mediana obliga a la red a **más**
iteraciones, y el impuesto de verificación lo pagan todos los nodos con su hardware.

### Límite declarado del oráculo

El oráculo por programación dinámica (`src/referencia.jl`, `sesgo_mediana_dp`) modela los
timestamps como una **única cadena monótona global**. Eso reproduce la cota cuando todos los bloques
del adversario van al final de la ventana, y **se separa del protocolo** fuera de ese régimen: con
`W = 51`, `C = 48`, `δ = φ = 0` da mediana 2 s donde la escala honesta daría 25 s, porque en el
protocolo cada bloque honesto tiene su propio reloj. Está declarado como **inconcluso** fuera de
régimen, con el caso que lo rompe escrito en `resultados/manipulacion.md` §4.

---

## M3 · La dinámica del adaptador

### Enunciado

Controlador multiplicativo discreto sobre slots, con la atenuación de `C-FLU-16` (el cambio de `N`
solo entra en `t_j`, la inyección de entropía) como **retardo** `r` en slots:

```text
τ_obs = N[s−r] · hw[s−r]                  (con hw = segundos por bloque del productor)
e     = τ_obj / τ_obs − 1
N[s+1] = cuant16( clamp( trunc(N[s]·(1 + g·e)), N_min, N_max ) )
```

`cuant16` es el redondeo al múltiplo de 16 de `C-POT-04`; `g` es la ganancia, ENTRADA.

Variantes modeladas, todas ENTRADAS booleanas o enteras:

- **trinquete** (`trinquete = true`): `N` solo sube, como `PotSlotIterationsMustIncrease` de
  Autonomys (`verificado en fuente`, `pallet-subspace/src/lib.rs:630-670`);
- **caducidad** (`caducidad = k`): `N` solo puede bajar dentro de `k` slots de su última subida;
- **histéresis** (`paso_minimo`): no se aplican cambios menores.

### Las dos rutas

1. **`Modelos.simular!`** — transparente, `Float64`, con comprobaciones de longitud y comentarios.
2. **`Rapido.simular_rapido!`** — mismo lazo con `@inbounds` justificado, sin asignaciones.
3. **`Referencia.simular_exacto`** — la misma ley con `Rational{BigInt}`, para comprobar que el
   punto flotante no cambia **el signo de ningún ajuste**. Es lo que se comprueba en
   `resultados/validacion.md` V3: **0 ajustes con signo distinto** en las cuatro configuraciones;
   la discrepancia de trayectoria (16 y 80 unidades de `N`) se declara, porque una recurrencia la
   compone.

### Régimen de conmutación

```text
amplitud_geometrica(N_max, N_min, g) = N_max − max(N_min, N_max·(1−g)^k)
```

con `k` el número de slots hasta saturar. **No es una estimación**: es la suma de la serie
geométrica de decrementos. Cuando el mínimo se alcanza antes de que la serie converja, la amplitud
observada la fija **el rango de `N`**, no la ganancia — y eso se ve en `resultados/adaptador.md`
(`g = 0,05`, retardo 50: amplitud 0,964 de `N_max`, la traza entera).
