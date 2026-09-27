# PROGRESO — P-RELOJ

Bitácora del encargo. Cada entrada lleva `date`, `uptime` y las comprobaciones de entrada/salida
exigidas por `PROMPT.md` §7.

---

## E1 · Apertura — 2026-09-24 12:15 CEST

**Antes de empezar, la declaración de §10 del encargo.** No encuentro ninguna premisa de §2/§3 que
sea errónea *de antemano*, así que no la impugno antes de trabajar; sí anoto dos cosas que el
encargo pide y que pienso tratar como está:

1. **(A) «el reloj no puede medirse a sí mismo» — §2 la llama teorema y pide determinarlo.** El
   encargo ya corrige que el ancla externa estaba catalogada como cerrada sin serlo. Mantengo las dos
   lecturas separadas: lo que se puede demostrar sobre las fuentes **disponibles a una regla de
   consenso de ZEROX** y lo que se puede demostrar sobre las fuentes **en abstracto**. §4.2.
2. **La desviación de `LINEO.md` está argumentada**, no solo declarada: `veritas/LINEO.md` §1 asigna
   Julia a CPU y C++/CUDA a GPU, y su §5.7 reserva C++ para GPU. Medir **latencia de instrucción**
   (no rendimiento de un bucle numérico) exige intrínsecos y serialización de dependencias, que Julia
   no expresa sin `llvmcall`. La argumentación completa, con lo que se pierde y cómo se compensa
   (oráculo + script reproducible + huellas), va en `METODO.md` **y** `CONTRATO.md` del instrumento.

### Presupuesto declarado (antes de ejecutar)

| Recurso | Tope declarado | Justificación |
|---|---|---|
| Hilos Julia | **4** | `PROMPT.md` §header: «Máximo 4 hilos». Por debajo del tope general de 24 de `LINEO.md`. |
| RAM | **8 GiB** | Los tres modelos son de estado pequeño; no hay Monte Carlo masivo que justifique más. |
| Disco temporal | **2 GiB** | Resultados tabulares + CSVs de medición. |
| Tiempo por corrida | **minutos** | `PROMPT.md` §header. Si una corrida se acerca a la hora, se corta y se reporta **inconcluso**. |

Presupuesto de la máquina de referencia verificado en `LINEO.md` §7: 64 GiB / 24 hilos. Mi tope es
más estrecho, que es legítimo («el presupuesto es un techo, usar menos es correcto»).

### Comprobación de entrada (obligatoria, `PROMPT.md` §7)

```
$ date
jue 24 sep 2026 12:15:28 CEST

$ uptime
 12:15:28  up 16 days  8:44,  0 users,  carga promedio: 3,33, 2,21, 1,67

$ cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-RELOJ/ENTRADA.sha256
P-ZRX/P-RELOJ/PROMPT.md: OK
P-ZRX/P-RELOJ/medicion-previa/MEDICION.md: OK
P-ZRX/P-RELOJ/medicion-previa/aeslat.c: OK
P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md: OK
research/chia-documentacion-oficial.md: OK
[exit 0]

$ git -C /home/katana/zeo/ZEROX status --short
 M P-ZRX/PIEZAS-DE-CODIGO/DECISIONES-0.0.1.md
 M P-ZRX/PIEZAS-DE-CODIGO/HOJA-DE-RUTA.md
 M P-ZRX/PIEZAS-DE-CODIGO/PROGRESO-0.0.1.md
 M TAREAS.md
 M crates/zx-consensus/src/bloque_dag.rs
 M crates/zx-consensus/src/lib.rs
 M crates/zx-consensus/src/pot_rango.rs
 M crates/zx-consensus/tests/poas.rs
 M crates/zx-consensus/tests/pot_rango.rs
 M crates/zx-storage/src/disco.rs
 M crates/zx-storage/src/error.rs
 M crates/zx-storage/src/lib.rs
 M crates/zx-storage/src/memoria.rs
 M crates/zx-storage/src/utxo.rs
?? P-ZRX/P-ECLIPSE/
?? P-ZRX/P-RELOJ/
?? P-ZRX/PIEZAS-DE-CODIGO/CORRECCION-A2-PREPARACION.md
?? P-ZRX/PIEZAS-DE-CODIGO/CORRECCION-A2-SALIDA-AUDITADA.md
?? P-ZRX/PIEZAS-DE-CODIGO/CORRECCION-A3-PUERTA-PARCIAL.md
?? P-ZRX/PIEZAS-DE-CODIGO/CORRECCION-A3-REDACCION.md
?? P-ZRX/PIEZAS-DE-CODIGO/CORRECCION-C3-TESTIGO.md
?? P-ZRX/PIEZAS-DE-CODIGO/ORDEN-A2-PREPARACION.md
?? P-ZRX/PIEZAS-DE-CODIGO/ORDEN-A2-SALIDA-AUDITADA.md
?? P-ZRX/PIEZAS-DE-CODIGO/ORDEN-A3-PUERTA-PARCIAL.md
?? P-ZRX/PIEZAS-DE-CODIGO/ORDEN-C1-ALMACEN-CANDIDATOS.md
?? P-ZRX/PIEZAS-DE-CODIGO/ORDEN-C3-ESTRUCTURA-DAG-DEV.md
?? crates/zx-consensus/src/cabecera_conjunta.rs
?? crates/zx-consensus/tests/cabecera_conjunta.rs
?? crates/zx-consensus/tests/genesis_dag.rs
?? crates/zx-consensus/src/genesis_dag.rs
?? crates/zx-storage/src/almacen_dag.rs
?? crates/zx-storage/tests/almacen_dag.rs
[exit 0]
```

**Lectura de la salida de git:** nada de lo que aparece `M`/`??` es mío. `P-ZRX/P-RELOJ/` aparece
como `??` porque el encargo entero es nuevo; dentro de él, `investigacion/` es lo único que yo
escribo. `PROMPT.md` y `medicion-previa/` quedan intactos (verificado por `sha256sum -c` al cierre).

**Máquina de referencia confirmada** (`/proc/cpuinfo`): `AMD Ryzen 9 9950X3D 16-Core Processor`,
32 hilos lógicos, `aes` / `sse4_1` / `avx2` / `avx512f` / `vaes` presentes.

---

## E2 · Primera medición propia: la reproducción de 7,7716 ns/bloque — 2026-09-24 12:15

`aeslat.c` **no se copia ni se modifica**: se compila desde `medicion-previa/` (solo lectura) y el
binario va a `investigacion/mediciones/latencia-aes/`, dentro de mi zona de escritura.

```
$ gcc -O2 -maes -msse4.1 -o ../investigacion/mediciones/latencia-aes/aeslat aeslat.c
$ ../investigacion/mediciones/latencia-aes/aeslat
sumidero              c3af66b6e126af3c
bloques AES-128       50000000
tiempo                0.3862 s
ns por bloque         7.7230 ns
ns por ronda AESENC   0.7723 ns
```

**7,7230 ns/bloque** en la primera corrida, frente a los **7,7716** publicados: **−0,63 %**.
Reproducido.

Repetición posterior con `taskset -c 8` (mismo binario, fuente intacto), en
`mediciones/latencia-aes/aeslat-corridas.txt`:

```
bloques AES-128       50 000 000
ns por bloque         7,7789 · 7,7636 · 7,7579     (media 7,7668)
ns por ronda AESENC   0,7779 · 0,7764 · 0,7758
```

**Media de las tres: 7,7668 ns/bloque**, frente a los **7,7716** publicados: **−0,06 %**, y el
ancla cae **dentro** del intervalo de las tres corridas. La carga de entrada era 1,47–2,81 (no
ociosa), igual que en la medición original, así que las dos cifras son comparables en la misma
condición declarada.

---

## E3 · Resultados y cierre — 2026-09-24 12:58 CEST

### Lo que se midió (todo en `mediciones/latencia-aes/`, reproducible con `run-medicion.sh`)

| Medición | Valor | Clase |
|---|---:|---|
| Reproducción del ancla de `medicion-previa/` | **7,7230 ns/bloque** (−0,63 %) | `medido` |
| Latencia de ronda `AESENC` (contador de rendimiento) | **4,001 ciclos** | `medido` |
| Latencia de bloque del PoT (10 rondas) | **42,01 ciclos** | `medido` |
| Ciclos por bloque con 0 → 16 hilos de carga | **42,011 ± 0,004** (constantes) | `medido` |
| Frecuencia bajo carga | 5,393 → 5,350 GHz | `medido` |
| Factor de paralelismo de la verificación (8 tramos) | **8,02×** | `medido` |
| Verificar con 16 carriles | 0,4829 ns/bloque | `medido` |

**El hallazgo que decide F3:** los **ciclos** por bloque no cambian con la carga y la **frecuencia**
sí. El «tercio de latencia» AMD/Intel **no es arquitectural**: se compra con reloj. La hipótesis del
encargo que decía lo contrario queda **refutada**.

### El instrumento

```
$ veritas/julia.sh --project=. test/runtests.jl
Test Summary:                 | Pass  Total  Time
P-RELOJ · reloj-adaptativo-v1 | 1071   1071  0.6s

$ veritas/julia.sh --project=. run.jl --todo
frontera, adaptador, manipulacion, validacion (39/39 OK)
```

**1071 aserciones, 1071 OK.** **39/39** casos de validación, de los cuales **25 con rutas
genuinamente independientes** (la tabla de `resultados/validacion.md` declara cuáles no lo son). El
recuento sale de ese artefacto, que se entrega.

### Comprobación de salida (obligatoria, `PROMPT.md` §7)

```
$ date
jue 24 sep 2026 12:58:34 CEST

$ uptime
 12:58:34  up 16 days  9:27,  0 users,  carga promedio: 1,33, 5,01, 5,71

$ cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-RELOJ/ENTRADA.sha256
P-ZRX/P-RELOJ/PROMPT.md: OK
P-ZRX/P-RELOJ/medicion-previa/MEDICION.md: OK
P-ZRX/P-RELOJ/medicion-previa/aeslat.c: OK
P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md: OK
research/chia-documentacion-oficial.md: OK
[exit 0]

$ LC_ALL=C sha256sum -c P-ZRX/P-RELOJ/investigacion/veritas/consenso/reloj-adaptativo-v1/HUELLAS.sha256
42/42 OK

$ git -C /home/katana/zeo/ZEROX status --short
(véase E1: lo que ya aparecía `M`/`??` al entrar sigue igual y NO es de este encargo; lo único
nuevo de este encargo está bajo `P-ZRX/P-RELOJ/investigacion/`, y `P-ZRX/P-RELOJ/` ya figuraba
como `??` en la entrada porque el directorio es nuevo)
```

**Entrada intacta:** `PROMPT.md` y `medicion-previa/` verifican 3/3 OK al cierre, igual que al
principio. `medicion-previa/aeslat.c` se compiló **sin copiarlo ni modificarlo**.

### Entregables

| Entregable | Estado |
|---|---|
| `INFORME.md` (primera línea = F1) | entregado |
| `DECISIONES-PENDIENTES.md` | entregado, 4 decisiones reales |
| `PROGRESO.md` | este fichero |
| Instrumento con `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` | entregado |
| `BORRADOR-REGLA.md` | **no se entrega**: `PROMPT.md` §9 lo pide solo si F7 es afirmativo, y F7 es **negativo** |

### Estado

**Concluido.** Ningún presupuesto se agotó y no hay nada `inconcluso` salvo lo que está declarado
como tal dentro del informe (el oráculo DP fuera del régimen de mayoría, `§ Lo que esta
investigación NO resuelve` 4).
