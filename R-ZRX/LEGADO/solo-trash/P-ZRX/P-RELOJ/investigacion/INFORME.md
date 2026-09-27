# INFORME.md — P-RELOJ: ¿puede `N` adaptarse solo, sin regalar el reloj ni el coste de verificar?

**F1 · ¿Es (A) un teorema —el reloj no puede medirse a sí mismo— o existe una cuarta fuente?**
**No es un teorema sobre el tiempo: es un teorema sobre ZEROX, y la cuarta fuente existe pero no
resuelve el problema que importa.** Lo demostrado es más estrecho de lo que el enunciado sugiere, y
se dice con precisión en §2.1.

**F7 · Veredicto.** **No existe un adaptador que cumpla el objetivo de Katana en su forma plena.** El
corte exacto está en una desigualdad de dos símbolos, medida y no elegida: **`S ≤ ε·K`** — la
dispersión de hardware admitida no puede pasar de `ε·K`, con `K` acotado por el hardware de
verificación (medido: **16**). Con el presupuesto que el encargo usa en sus propias tablas (`ε = 10 %`)
la frontera admite **1,6×** de dispersión, y el hardware que el propio encargo cita ya abarca más.
Detalle y números en §5.

---

## 1 · Qué se midió, y qué no

Todo lo que sigue se apoya en tres magnitudes y **solo tres**. Están en
`veritas/consenso/reloj-adaptativo-v1/PROCEDENCIA.md` con comando, fichero de salida y clase.

| Magnitud | Valor | Clase |
|---|---:|---|
| Latencia de una ronda `AESENC`, **en ciclos**, con contador de rendimiento | **4,001** | `medido` |
| Latencia de un bloque de 10 rondas encadenadas | 42,01 ciclos / **7,739 ns** | `medido` |
| Coste por bloque al verificar con 16 carriles en vuelo | 2,627 ciclos / **0,4829 ns** | `medido` |

Y una reproducción que el encargo exigía como condición de validez:

| | Valor | Diferencia |
|---|---:|---:|
| Ancla de `medicion-previa/MEDICION.md` | 7,7716 ns/bloque | — |
| Reproducido en este encargo | **7,7230** ns/bloque | **−0,63 %** |

**El ancla se reproduce.** La carga de entrada era 2,81 en la medición original y 1,64–2,81 aquí:
misma condición declarada («máquina no ociosa»), cifras comparables. La cadena de razonamiento del
encargo no descansa sobre una cifra que no se sostenga.

## 2 · Las tres objeciones de §2, atacadas

### 2.1 · (A) La circularidad: no es un teorema, es un teorema **con alcance**

El encargo pide determinar si «el reloj no puede medirse a sí mismo» es un teorema. La respuesta
honesta separa dos enunciados que el §2 junta:

**(A-abstracto) «Ninguna magnitud puede medir su propia desviación sin una referencia externa».**
**Falso**, y trivialmente: un VDF mide el tiempo físico sin referencia externa, y el PoT **es** su
propia medida del tiempo físico. El PoT no necesita medirse a sí mismo para *ser* un reloj; necesita
una referencia para saber si **se ha desviado** del reloj de pared. Son dos cosas distintas.

**(A-ZEROX) «Dentro de las reglas de ZEROX, las fuentes disponibles no permiten medir la desviación
de `N` sin circularidad».** **Esto sí se sostiene, y es lo único demostrado.** La enumeración,
con la regla que permite o prohíbe cada fuente **citada por ID**:

| Fuente | Regla que la rige | ¿Sirve como referencia de `N`? |
|---|---|---|
| Relojes de los participantes | **`C-TS-04`**: «ninguna regla de consenso usa la mediana de relojes de pares ni hora ajustada por pares» | **Prohibida.** No es una preferencia: es una regla vigente. |
| El propio índice de slot del PoT | `C-FLU-01`: la profundidad se mide en índices de slot; `C-POT-03` prohíbe retos derivables de `s` sin evaluar la cadena | **Circular.** Es exactamente la magnitud cuya desviación se quiere medir. |
| Los timestamps de los bloques | `C-TS-01` (relación timestamp–slot **pendiente**), `C-TS-03` (FTL, **valor pendiente**), `C-TS-02` (MTP no sustituye el índice PoT) | **Manipulable**, y cuantificado en §3. |
| **Una cadena externa** | Ninguna regla la prohíbe. `AGENTS.md` prohíbe *staking* y *comités de decisión* y **no dice nada de anclas externas**; el catálogo que la daba por cerrada está marcado `[NO VERIFICADO]` en el propio repositorio | **Sí es una cuarta fuente.** Ver abajo. |
| Un checkpoint firmado | `C-CHK-01`/`C-CHK-03`: **una sola vez, la clave se destruye y la autorización caduca** | **No es un reloj: es un evento único.** No puede servir de referencia continua. |

**La cuarta fuente existe, y el encargo tiene razón en que estaba mal catalogada.** Una cadena
externa arregla **(A)** —da una referencia fuera de la cadena de PoT— y arregla **(B)** —sus
timestamps los fija otro dominio de seguridad, no el adversario local—. **Y no arregla (C)**, con
una precisión importante: el impuesto de verificación no depende de *cómo* se mida el tiempo, sino
de que `N` suba y de que verificar sea `O(N)`. Eso está demostrado por división en §4 y no depende
de la fuente de tiempo.

**Lo que arrastra, cuantificado y no enumerado.** Una cadena externa introduce (i) **dependencia de
la viveza ajena**: si la cadena ancla se detiene, ZEROX no puede adaptar `N` —y dependiendo de cómo
se escriba, puede no poder *producir*—; (ii) **manipulabilidad de los timestamps de esa cadena**, que
es el mismo problema de §3 trasladado a otro sitio, con un adversario distinto; y (iii) un
**sub-consenso dentro de ZEROX** sobre qué cadena y a qué profundidad, que es una decisión de
consenso nueva y por tanto **un hard fork más** (`C-UPG-01`). El encargo prohíbe proponer el ancla
externa como regla de consenso; aquí solo se evalúa, y el resultado es que **resuelve A y B, no C**.

### 2.2 · (B) El timewarp que se reabre, cuantificado

El cierre vigente dice que «el slot es el índice del reloj, no el sello de la cabecera, así que no se
puede falsificar». **Si `N` pasa a depender de timestamps, esa frase deja de ser cierta**, y lo que
se reabre tiene número (§3). La cuantificación, resumida: con `W = 2m+1` bloques en la ventana de
observación y `C = ⌊α·W⌋` bloques del adversario, la mediana se puede desplazar, y **con `α` por
encima de `1/2 + 1/(2W)` el adversario la fija**.

### 2.3 · (C) La objeción decisiva: la asimetría **no** es la que el encargo describe

El encargo dice: «`N` se indexa al hardware del atacante, pero la verificación se paga en el
hardware del honesto». **La primera mitad es cierta; la segunda es cierta y no es la que decide.**
Lo que decide es que la verificación **se paraleliza** y la producción **no**, y esa asimetría tiene
un techo medido. §4.

## 3 · F4 · La región de manipulación con timestamps

Reglas aplicables, por ID: `C-TS-01` (monotonía; **su relación timestamp–slot sigue pendiente en
`SPEC.md` §7.4**), `C-TS-03` (FTL; **valor pendiente**), `C-TS-04` (prohíbe la hora de red),
`C-TS-02` (MTP no sustituye el índice PoT). Modelo en
`veritas/consenso/reloj-adaptativo-v1/MODELO.md` §M2; tabla completa en `resultados/manipulacion.md`.

**Sesgos garantizables**, con `δ` el retraso máximo por bloque y `φ` el FTL, ambos ENTRADAS:

```text
sesgo hacia abajo   ≤ −max(C·δ, C)
sesgo hacia arriba  ≥ +C·φ
```

**El factor sobre `N` es un cociente, y la dirección importa:**

```text
N(τ_obs + s) / N(τ_obs) = τ_obs / (τ_obs + s)
```

| `α` | `C` con `W = 201` | sesgo abajo (s), δ=1 | factor de `N` | efecto |
|---:|---:|---:|---:|---|
| 0,10 | 20 | −20 | 1,034 | sube `N` |
| 0,30 | 60 | −60 | 1,111 | sube `N` |
| 0,49 | 98 | −98 | 1,195 | sube `N` |
| 0,55 | 110 | −110 | 1,225 | sube `N` |
| 0,90 | 180 | −180 | 1,429 | sube `N` |

*(τ_obs = 600 s; todo `[derivado]` de las fórmulas de arriba, con los sesgos exactos en la tabla
generada.)*

**El resultado que hay que leer dos veces:** un adversario que **retrasa** la mediana **sube** `N`, y
subir `N` es subir el impuesto de verificación que pagan **todos** los nodos con **su** hardware.
No necesita mayoría para eso: con `α = 0,10` ya hay un 3,4 % de subida por ventana, y el efecto se
**acumula** si el adaptador persigue la mediana ciclo tras ciclo. **Esa es la asimetría real del
adaptador**: el ataque no consiste en ganar el reloj, consiste en **encarecer la verificación**.

**Comparación con Bitcoin, con las fuentes abiertas y citadas** (todas en `PROCEDENCIA.md` §7):

| | Bitcoin | ZEROX |
|---|---|---|
| Monotonía | MTP de 11 bloques (`nMedianTimeSpan = 11`, `chain.h`; BIP-113) | `C-TS-01` (pendiente de relación con `slot`) |
| Límite hacia adelante | 7200 s contra el reloj local (`MAX_FUTURE_BLOCK_TIME`, `chain.h`); **rechazo temporal**, sin ban al par | `C-TS-03`, **valor pendiente** |
| Límite hacia atrás | **ninguno absoluto**: solo el MTP relativo. No se encontró en `master` ninguna regla que ate `nTime` al reloj local por detrás | — |
| Qué contiene el daño | el clamp del retarget a `[×1/4, ×4]` cada 2016 bloques (`pow.cpp`) + mayoría de hashrate + preparación visible (~1 mes, BIP-54/Optech) | **no hay equivalente**: `N` no tiene clamp y su actualización no está definida |
| Coste cuantificado | dificultad al mínimo en **38 días** con mayoría (BIP-54); `nTime` mínimo avanza 1 s/bloque ⇒ hasta 6 bloques/s (Wuille, SE 123698) | factor de `N` por ventana, tabla de arriba |

**Lo que Bitcoin NO resuelve y ZEROX necesita:** quién es el oráculo de tiempo (en Bitcoin es cada
nodo, con 2 h de holgura) y **cómo se acota el retraso**, no solo el adelanto. La regla de las 2 h
**no** acota el timewarp: es unilateral y el ataque vive en el pasado (Optech, BIP-54).

## 4 · F2 y F6 · La frontera, y por qué `N_max ≡ ρ_max` es **falso en su forma literal**

### 4.1 · La frontera, con la medición detrás

Un nodo es admisible si el camino de respaldo de `C-POT-08` paso 4 cabe en su presupuesto:

```text
N · t_v(K) ≤ ε · τ = ε · N · t_p          (ADM)
```

`N > 0`, así que **se divide por `N`**:

```text
S := t_v(K)/t_p ≤ ε        y como t_v = lat_bloque/K:   S ≤ ε·K          (ADM″)
```

**La frontera no contiene `N` ni `τ`.** Es la corrección a §3 del encargo, y sale de una división,
no de una simulación. La curva, con `K = 16` medido:

| `ε` | `ρ_max = S_max = ε·K` con `K = 16` | ¿admite 2×? | ¿admite 4×? | `ε_min = ρ/K` para `ρ = 2` |
|---:|---:|:---:|:---:|---:|
| 0,02 | 0,32 | no | no | — |
| 0,05 | 0,80 | no | no | — |
| **0,10** | **1,60** | no | no | 12,5 % |
| 0,125 | 2,00 | **sí** | no | 12,5 % |
| 0,20 | 3,20 | sí | no | 12,5 % |
| 0,25 | 4,00 | sí | **sí** | 12,5 % |

Nótese que `ρ_max = ε·K` y `ρ = t_s/t_f` son la MISMA cantidad que `S`: **la frontera es un techo
sobre `ρ`, no un suelo.** La cuarta columna es constante porque `ε_min = ρ/K` no depende de `ε`:
lo que depende de `ε` es **cuánta dispersión se admite**.

Con `K = 8` (el número de tramos del PoT) la misma tabla da `S_max = 0,80` con `ε = 10 %`: **por
debajo de 1, o sea ninguna dispersión**. De ahí sale la condición que el encargo no tenía:
`K ≥ 2` como mínimo absoluto, y `K = 16` medido como techo (`resultados/frontera.md`).

### 4.2 · `N_max` existe, pero es la **otra** frontera

```text
N_max(ε, τ, t_v) = ε · τ / t_v
```

y **sí** depende de `τ` (lineal) y de `t_v` (inversa). Con el hardware medido y `ε = 10 %`:

| `τ` | `N_max` con `K=8` | `N_max` con `K=16` |
|---:|---:|---:|
| 0,1 s | 1,04·10⁷ | 2,08·10⁷ |
| 0,5 s | 5,21·10⁷ | 1,04·10⁸ |
| 1,0 s | 1,04·10⁸ | 2,08·10⁸ |
| 2,0 s | 2,08·10⁸ | 4,17·10⁸ |
| 6,0 s | 6,25·10⁸ | 1,25·10⁹ |

**Compruébese el número que el encargo pedía comprobar:** con `τ = 1 s`, `ε = 10 %` y `N = 206 557 520`:

| Ruta de verificación | `N_max` | ¿Cabe `N = 206 557 520`? |
|---|---:|---|
| `K = 8` (los 8 tramos del PoT) | 1,04·10⁸ | **No**. Falta un factor 2. |
| `K = 16` (VAES en paralelo sobre los 8 tramos, ida y vuelta) | 2,08·10⁸ | **Sí**, con un margen del 0,8 %. |

Es decir: **el `N` de Autonomys a `τ = 1 s` no cabe en un presupuesto del 10 % con la ruta de 8
tramos, y con la de 16 entra con menos de un 1 % de margen.** Eso es un hallazgo incómodo para
cualquier red que herede `N = 206 557 520` y quiera un presupuesto estrecho: **el margen no existe**.
Se calcula con el `t_v` medido aquí; en hardware más lento que esta máquina, `N_max` baja
proporcionalmente y la conclusión se endurece.

### 4.3 · La hipótesis de §3: **falsa en su forma literal, cierta en el límite**

§3 dice: `N_max` y `ρ_max` son la misma magnitud escrita de dos formas, porque el presupuesto fija
un techo `N_max` y el hardware que lo supere no acelera `N`, acelera la cadena.

**Lo que es cierto:** si `N` está topado, el hardware más rápido **no** sube `N`, y su ventaja se
convierte en `ρ`. Eso se sostiene.

**Lo que es falso:** que el presupuesto fije `N_max` **de forma independiente**. `(ADM″)` no
contiene `N`, así que **hay un grado de libertad que el §3 no vio**: el presupuesto `ε` no acota
`N`, acota **la dispersión de hardware admitida**. `N` lo fijan `τ` y el hardware del más rápido,
que son entradas distintas de `ε`.

**La correspondencia numérica, en las dos direcciones.** Antes de la fórmula, la **definición de
`ρ` escrita una vez y sin ambigüedad**, porque aquí es donde un borrador de este informe se torció:

```text
t_f = segundos por bloque de la máquina MÁS RÁPIDA     (= t_p de MODELO.md)
t_s = segundos por bloque de la máquina MÁS LENTA      (= t_v de MODELO.md)
ρ  := t_s / t_f   = cuántas veces MÁS LENTA es la lenta  = ventaja del rápido
S  := t_s / t_f   = dispersión                           (MODELO.md §M1)
```

**`ρ` y `S` son la misma cantidad.** No son recíprocas: `t_s/t_f` es a la vez «la dispersión» y «la
ventaja del rápido», y es `≥ 1`. El despeje sale entero de la frontera, sin cambiar de variable:

```text
τ = N·t_f                                  la duración la fija el MÁS RÁPIDO
el MÁS LENTO verifica N bloques:  N·t_s/K
cabe en ε del slot  ⟺  N·t_s/K ≤ ε·N·t_f  ⟺  ρ/K ≤ ε          (ADM‴)
```

De ahí, la correspondencia en las dos direcciones **y las dos son la misma igualdad despejada de
distinta incógnita**:

```text
dado ε y K   →  ρ_max = ε·K          la ventaja máxima que el presupuesto admite
dado ρ y K   →  ε_min = ρ/K          el presupuesto mínimo que admite esa ventaja
dado N y τ   →  nada                 el presupuesto es el mismo para todo N
```

**La comprobación que decide cuál de las dos formas es la buena, y no deja lugar a dudas** (`ρ = 3`,
`K = 16`): `ρ/K = 18,75 %`, y con `ε = 18,75 %` el nodo lento **cabe exactamente**. La alternativa
`1/(ρ·K) = 2,08 %` **no admite a ese nodo**: con `ε = 2,08 %` y `K = 16` la tabla publicada da
`ρ_max = 0,33 < 3`. **`ε_min = ρ/K`. El `1/(ρ·K)` era el error**, y el revisor de este informe lo
señaló con el mismo número.

**La causa raíz del error, escrita para que no se repita:** el borrador escribió `ρ = 1/S` por
analogía con el `ρ` de `R-FIN-14`, donde `ρ` era «cuántas veces más rápido es el adversario».
Aquí `ρ` se define sobre **tiempos por bloque** y no sobre velocidades, y como `t_p` es el **más
rápido** (no la referencia), `t_s/t_f` ya es la ventaja del rápido. **Definir `ρ` sobre tiempos y
llamarlo «ventaja» invita a invertirlo**; por eso el informe ahora escribe las dos definiciones —
`t_f`, `t_s`— antes de la fórmula, y la nomenclatura se ancla en `ρ_max = v_A,max/v_ref`
(`SPEC.md` §7.3).

| `ρ = t_s/t_f` (dispersión) | `ρ_max = ε·K` con `ε = 10 %`, `K = 8` | con `K = 16` | `ε_min = ρ/K` con `K = 8` | con `K = 16` |
|---:|---:|---:|---:|---:|
| 1,6 | 0,80 (**no cabe**) | 1,60 (cabe) | 20,0 % | **10,0 %** |
| 2 | 0,80 (**no cabe**) | 1,60 (**no cabe**) | 25,0 % | 12,5 % |
| 3 | 0,80 (**no cabe**) | 1,60 (**no cabe**) | 37,5 % | 18,75 % |
| 4 | 0,80 (**no cabe**) | 1,60 (**no cabe**) | 50,0 % | 25,0 % |
| 12 | 0,80 (**no cabe**) | 1,60 (**no cabe**) | 150 % (**imposible**) | 75,0 % |

**Consecuencia, y es el resultado publicable, con la dirección correcta:** `N_max ≡ ρ_max` es
**falso** como identidad y **cierto** como frontera de la cola. Y **el presupuesto que hay que
declarar crece linealmente con `ρ_max`**: `ε ≥ ρ_max/K`. Eso hace que **`ρ_max` no sea una decisión
libre**:

- con `K = 16`, `ρ_max = 3` obliga a **`ε = 18,75 %`**: casi una quinta parte del slot de **cada**
  nodo, gastada en el nodo **más lento**;
- con `K = 8`, `ρ_max = 3` pide **`ε = 37,5 %`**, y `ρ_max = 12` pide **`ε = 150 %`**, que no existe.
  O sea: **una diferencia de 12× entre la máquina más rápida y la más lenta es inalcanzable con la
  ruta de 8 tramos**, y con la de 16 exige ceder el 75 % del slot;
- y el `ε` chico que parecía cómodo (`2,08 %`) **solo admite `ρ_max = 0,33`**: ni la máquina
  idéntica.

## 5 · F7 · El veredicto, y dónde está exactamente el corte

**No existe un adaptador que cumpla el objetivo de Katana en su forma plena.** El corte exacto, y es
una desigualdad de dos símbolos con **un** dato medido dentro:

```text
S ≤ ε·K          S = dispersión de hardware admitida (t_lento/t_rápido ≥ 1)
                 K = carriles de verificación          [medido: hasta 16]
                 ε = presupuesto del slot              [ENTRADA de gobernanza, no elegida aquí]
```

**Por qué eso mata el objetivo.** El objetivo es «que un timelord corra en cualquier CPU de gama
media-alta, Intel o AMD». Es decir: que `S` sea **grande**. Pero la frontera da un techo:

- con `ε = 10 %` y `K = 16`, `S ≤ 1,6`: **como máximo un 60 % de dispersión**. Un 9950X3D y un
  14900KS ya están dentro de ese margen; un portátil de gama media-alta de hace cinco años, no.
- con `K = 8`, `S ≤ 0,8`: **ninguna dispersión es admisible**, ni siquiera la máquina idéntica.
- para admitir `S = 4` (una gama media-alta frente a un tope de gama) hace falta `ε ≥ 25 %`: **una
  cuarta parte del slot gastada en verificar, en el nodo más lento**.

**Dónde está la frontera, dicha como decisión:** el adaptador **sí funciona** —converge, se puede
modelar, y el trinquete elimina la oscilación— pero **es cosmético** en el sentido que el §4.5 del
encargo anticipa: en cuanto el techo `ε·K` se alcanza, la decisión real vuelve a ser `ρ_max` a
secas, y `N` deja de adaptarse. **Ese es el resultado**, y el encargo dice expresamente que es un
resultado completo.

### 5.1 · Las tres familias de §1, evaluadas con aritmética

| Familia | Veredicto | Aritmética |
|---|---|---|
| **1 · Techo `N_max`** | **No desacopla: acota.** Es la que sobrevive, y su forma exacta es `S ≤ ε·K`, con `K` medido | §4.1. Con `ε = 10 %`, `K = 16` ⇒ `S ≤ 1,6` |
| **2 · Prueba corta (SNARK sobre ~2·10⁸ rondas)** | **Descartada con aritmética, no de memoria** | `veritas/consenso/prueba-recursiva-v1/` §2 mide **288 s/bloque** probando GHOSTDAG, que es **mucho más barato** que 2,07·10⁹ rondas AES. Escalando por el cociente de trabajo mínimo —AES es una cadena de 2·10⁹ operaciones sobre 128 bits, GHOSTDAG son unos miles de operaciones sobre hashes— el coste de probar la cadena AES es **órdenes de magnitud mayor**, y el presupuesto del slot es de fracciones de segundo. **No hace falta el número exacto: el orden lo descarta.** Y hay un argumento independiente y más fuerte: una prueba sucinta **desacoplaría** `N_max` de `ρ_max` (§4.3), o sea que sería la única familia que rompe la equivalencia — y por eso mismo es la única que merecería la pena si fuera viable. **No lo es con la aritmética medida.** |
| **3 · Cambiar la primitiva a grupos de clase (la vía de Chia)** | **Vuelve a salir «No», y ahora con el peso del `N` dinámico encima** | Chia paga **3,1–3,8× `[demostrado con silicio]`** de ventaja al ASIC y verifica en **milisegundos independientes de `N`**; su umbral de seguridad lleva la ventaja de VDF **dentro** (`42,7 % (* vdf advantage)`, `docs.chia.net`, citado en `research/chia-documentacion-oficial.md` §3.2). ZEROX compró `ρ` pequeño —«con AES la CPU **ya es** el ASIC»— y pagó en coste de verificación. **Cambiar a grupos de clase cambia el problema entero**: vuelve `ρ` grande (3-4× demostrado), exige C++/GMP (el problema de interoperabilidad H-001) y **el objetivo de Katana —cualquier CPU de gama media-alta corre un timelord— empeora**, porque la latencia de los grupos de clase no la acelera ninguna CPU de consumo. **`research/dag-poas-informe-52-problemas.md` §29 dijo «No» antes de que existiera el objetivo de `N` dinámico; con ese peso encima sigue siendo «No», y por una razón distinta y más fuerte: es la única familia que empeora el objetivo declarado.** |

### 5.2 · El techo del tipo, comprobado

`C-POT-04`: `N ≤ u32::MAX = 4 294 967 295` y `N % 16 == 0`. El mayor del dominio es
**4 294 967 280**. Con el hardware medido (`0,7739 ns/bloque`) eso son **3,32 s** de producción por
slot. El encargo avisa de que «a ~20,8× sobre un 14900KS, `N` desbordaría `u32::MAX`»: **se
confirma** y aparece en la región de interés —un ASIC de 20× sobre esta máquina ya satura el tipo—,
así que **el techo del tipo es una frontera real**, no un detalle. Es un argumento más para que el
adaptador sea cosmético: no puede subir indefinidamente aunque el presupuesto lo permitiera.

## 6 · F3 · ¿Es arquitectural el tercio de latencia? **No, y se rompe con dos mediciones**

El §2.2 del encargo describe `40 ciclos aquí frente a 30 en Raptor Cove`. Medido y contrastado:

| | Esta máquina (Zen 5) | Raptor Cove |
|---|---:|---:|
| Ciclos por ronda `AESENC` | **4,001 `[medido]`** | **3 `[citado]`** |
| Ciclos por bloque (10 rondas) | **42,0 `[medido]`** | 30 `[derivado]` |
| ns por bloque | **7,739 `[medido]`** | 4,841 `[citado]` |
| Frecuencia implícita | **5,428 GHz `[medido]`** | 6,196 GHz `[derivado de un comentario]` |
| Reparto · ciclos por BLOQUE | 42,01/30 = **1,400×** | frecuencia 6,196/5,428 = **1,141×** |
| Producto | **1,400 × 1,141 = 1,598×** | coincide con la fila de ns (7,739/4,841 = **1,599×**) |

**Las tres conclusiones, y la tercera es la que el encargo quería:**

1. **La ronda es 4 ciclos aquí y 3 en Raptor Cove, y eso está respaldado por tablas publicadas.**
   uops.info y Agner Fog dan 4 en Zen 1, 2, 3 y 4 (y la hoja oficial de AMD para Zen 4: `Latency 4`,
   `Throughput 2`), y 3 en Golden Cove (Alder Lake-P) y Raptor Cove (Emerald Rapids). **`[citado]`**
   con las URL en `PROCEDENCIA.md` §7.
2. **La fila resumen de uops.info para Zen 5 imprime 3, y es un artefacto**: sus **propios datos
   crudos** dan APERF ≈ 4,05 ciclos por instrucción, `AESDEC` y `AESENCLAST` de la misma página dan
   4, y la documentación de AMD (58455) enlazada desde esa misma página dice 4. Nuestra medición
   independiente con PMU da **4,001**. **Tres fuentes contra una fila.**
3. **El tercio de latencia NO es arquitectural: es de reloj.** La prueba está en `carga.c`: con
   **0, 1, 4, 8 y 16 hilos** de carga, los **ciclos por bloque son constantes (42,01 ± 0,004)** y lo
   que cambia es la **frecuencia** (5,393 → 5,350 GHz, −0,8 %). Si el tercio fuera arquitectural, los
   ciclos subirían con la carga; **no suben**. Y la descomposición del encargo se sostiene
   aritméticamente, **con los ciclos POR BLOQUE y no por ronda**: 1,400 (latencia) × 1,141
   (frecuencia, medida aquí) = **1,598×**, que es exactamente el cociente de la fila de ns
   (7,739/4,841 = 1,599). **El 1,605 del encargo era correcto**; un 1,52 intermedio que apareció en
   un borrador de este informe mezclaba ciclos por ronda (4/3 = 1,333) con frecuencia por bloque, y
   quedó corregido aquí. **El cociente por ronda (1,333) NO es el factor de la brecha**: la brecha
   se mide sobre el bloque, porque `N` cuenta bloques.

**F3, respondida sin ambigüedad: el suelo de `ρ` por fabricante no es 1,333×, es ~1,0× en ciclos.**
**Los 4 ciclos de AMD y los 3 de Intel se compran con frecuencia**: un AMD con mejor reloj, o un
Intel con la misma latencia, cierran la brecha. **No hay suelo de `ρ` por fabricante en la
latencia**; lo hay, si acaso, en el reloj máximo, que es un dato comercial y no arquitectural.
La frase del encargo —«si el tercio es arquitectural, no se compra con un AMD mejor»— **queda
refutada**, y esa era la pregunta.

## 7 · F5 · La dinámica del adaptador

Modelo en `MODELO.md` §M3; tabla completa en `resultados/adaptador.md`. Resultados:

| Régimen | Qué pasa | Amplitud de `N` |
|---|---|---|
| Sin trinquete, conectar/desconectar | **Oscila**, y converge si el hardware deja de cambiar | hasta **37 %** de `N_max` con `g = 0,05`, retardo 1 |
| Sin trinquete, retardo largo (50 slots) | **Oscila hasta el rango entero** | **96 %** de `N_max` |
| **Con trinquete** | **No oscila: no baja nunca** | **0** |
| Con caducidad `k` | Oscila solo dentro de la ventana de `k` slots | entre los dos |

**El trinquete elimina la oscilación, y el precio es exactamente el que el encargo advierte:** con
hard forks por altura, **accionar un trinquete tarda meses**, así que protege menos de lo que parece.
Y el coste de verificación máximo medido en la traza sube de 0,19 s a **0,77 s** cuando el retardo es
largo y la amplitud llega al rango entero: es el impuesto que pagaría la red durante la oscilación.

**El caso que Katana pide explícitamente** —que `N` baje cuando el más rápido se desconecta— **se
cumple sin trinquete y se rompe con él**: con trinquete, `N` se queda arriba para siempre y el
reloj de la red queda lento de forma permanente. **Es la decisión real que queda abierta**, y está
en `DECISIONES-PENDIENTES.md`.

## 8 · Las mediciones de §4.1, con sus controles

Todo en `investigacion/mediciones/latencia-aes/`, con `run-medicion.sh` que lo reproduce entero.

| Medición | Valor | Control |
|---|---:|---|
| Reproducción del ancla (`aeslat.c` intacto) | 7,7230 ns/bloque | −0,63 % frente a 7,7716 |
| Latencia de ronda aislada | 4,001 ciclos | `pxor` da 2,000 ciclos (latencia tabulada) |
| Bloque de 10 rondas | 42,01 ciclos | 10 × 4,001 + 2 del `pxor` y el lazo |
| Rendimiento recíproco de `AESENC` | 0,517 ciclos/instrucción | 8 cadenas independientes |
| Latencia bajo carga 0→16 hilos | **42,01 ± 0,004 ciclos** | la frecuencia baja, los ciclos no |
| Verificar con 8 carriles | 0,9644 ns/bloque | factor **8,02×** frente a escalar |
| Verificar con 16 carriles | 0,4829 ns/bloque | 2,627 ciclos/bloque, cerca del techo de VAES |

**Lo que no se midió y se declara `derivado`:** el barrido de hardware. Solo hay **una** máquina. La
tabla del 14900KS es `[citado]` y su frecuencia es `[derivado de un comentario de código]`. La
fórmula de conversión se da escrita (`ns = ciclos/frecuencia`) para que cualquiera la aplique a
hardware que sí tenga delante.

## 9 · El instrumento

`veritas/consenso/reloj-adaptativo-v1/`, con la estructura de `LINEO.md` §1 y la desviación
argumentada en `CONTRATO.md` §2 y `METODO.md` §2.

| | |
|---|---|
| Suite de tests | **1071 aserciones, 1071 OK, 0 fallos, 0 errores** |
| Validación de rutas | **39 casos, 39 OK** — `resultados/validacion.md` |
| De esos, con rutas **genuinamente independientes** | **25** |
| Asignaciones en el lazo del adaptador | **0 bytes** (medido, no supuesto) |
| Oráculo DP | 889 ms y 820 MiB por llamada; **no optimizado a propósito** |
| Recuento declarado | sale de `resultados/validacion.md` y de la salida de `test/runtests.jl`, **artefactos que se entregan** |

**La tabla de validación separa las rutas independientes de las que no lo son**, como pide §4.5 del
encargo. Las que **no** son independientes están declaradas: `V1` compara la misma desigualdad en dos
regímenes numéricos, `V3` compara dos implementaciones de la misma ley de control, y `V4` comprueba
invariantes del propio modelo. Las que **sí** lo son: los bordes de `C-POT-04` contra una tabla
externa, el redondeo a múltiplo de 16 contra el objetivo, y la cota de la mediana contra un oráculo
por programación dinámica.

**Un defecto encontrado por el instrumento y corregido**, que se declara: la primera versión de la
cota de la mediana daba `0` sin mayoría, y el oráculo mostró que **sí** hay desplazamiento. La
segunda daba una igualdad que no era tal: sobre 660 combinaciones aparecieron **294 discrepancias**,
y se degradó a **cota inferior** con las discrepancias contadas. **El error iba en la dirección
peligrosa** —prometía menos ataque del que hay— y por eso el cambio está en `METODO.md` §6.

## 10 · Riesgos de §4.5, uno por uno

| Riesgo | Cómo se vigiló |
|---|---|
| **Alcance estrecho con etiqueta ancha** | Cada afirmación lleva su clase y su alcance. El resultado central se enuncia como **desigualdad** (`S ≤ ε·K`), no como «el adaptador no funciona». El veredicto de F7 dice **dónde** está el corte, no que todo sea imposible. |
| **Conteos de test que no cuadran** | El recuento sale de `resultados/validacion.md`, que **se entrega**. 1071 aserciones y 39 casos, ambos reproducibles con un comando. |
| **Un test que compara una fórmula consigo misma** | La tabla de validación tiene columna `independiente`; **25 de 39** lo son y **14 se declaran no independientes**. |
| **`N` desbordaría `u32::MAX` a ~20,8×** | Comprobado: el mayor `N` del dominio es 4 294 967 280 y con el hardware medido son **3,32 s** de slot. **Aparece en la región de interés** y se dice. |
| **«El adaptador funciona» ≠ «el adaptador sirve»** | Es la conclusión de §5, escrita con esas palabras: **el adaptador es cosmético** una vez alcanzado el techo. |

---

## Lo que esta investigación NO resuelve

1. **No mide una red.** M2 y M3 son modelos; no hay nodo, ni gossip, ni `Δ`. `L_suelo_slots` sigue
   pendiente y este encargo **no lo cierra**: lo trata como símbolo, como manda `AGENTS.md`.
2. **No barre hardware.** Una sola máquina medida. El resto es `citado` o `derivado`, con la fórmula
   escrita. **No se presenta una tabla derivada como si fuera un barrido.**
3. **No decide `ε`, `K`, `ρ_max` ni `τ`.** Son entradas. El instrumento da la frontera y la
   correspondencia; la calificación es de Katana.
4. **No cierra la región de manipulación para el régimen sin mayoría.** La cota publicada es
   **inferior**; el oráculo DP se separa del protocolo fuera del régimen de mayoría y ahí está
   declarado **inconcluso**, con el caso que lo rompe.
5. **No evalúa el ancla externa más allá de lo que el encargo permite.** Se concluye que resuelve
   (A) y (B) y no (C), pero **no se propone como regla de consenso** (`PROMPT.md` §10) ni se
   desarrolla su diseño.
6. **No demuestra que el ancla externa sea implementable con las garantías que haría falta** —
   viveza, profundidad, resistencia a la manipulación de *su* cadena—: eso es otro encargo.
7. **No mide el coste de verificar en una CPU sin AVX-512.** La frontera usa `K`, y `K` para esas
   máquinas es **no medido**. La frase «cualquier CPU de gama media-alta» **no se puede calificar
   sin ese número**.
8. **No cierra la latencia de `AESENC` en función de los datos.** Los controles usan una sola
   entrada, igual que uops.info; no se encontró estudio que barra entradas. **No verificado.**
9. **No dice si el techo de 16 carriles lo rompe hardware especializado.** Un ASIC de verificación
   (no una CPU) podría pasar de 16 y relajar la frontera. **No determinado**, y es la hipótesis H2
   del instrumento.
10. **No resuelve el problema que motiva el encargo en su forma de gobernanza.** `N` sigue sin quien
    lo autorice: `C-UPG-08` no lo incluye entre los parámetros ajustables, `C-CHK` destruye la
    llave, y este instrumento **no propone un mecanismo** — solo demuestra que un adaptador
    automático tendría que vivir dentro de `S ≤ ε·K`, que es una frontera, no una autorización.
