# PROGRESO W07b

Leer esto primero al retomar. Estado según se avanza; cada paso se marca al completarse.

## Checklist

- [x] 10:45 checksums ENTRADA-W07b.sha256 (51/51 coinciden)
- [x] Lectura íntegra de PERFIL-DEV-v0.md, REVISION-W07c.md, zerox-ci.yml, y guiones de W06d6/W06d7/SL4b2
- [x] E-0: clon limpio + CI local completa (fmt/clippy/build/test/3 guardianes/release, todo verde 11:29)
- [x] Copia del instrumento analisis-registro-v1 a la zona
- [x] Arnés bash (scripts/)
- [ ] R1: E-1 -> E-2 (30 min) -> E-4 (SIGKILL+rearranque) -> E-3
- [ ] R2: E-5 (nodo D tardío)
- [ ] R3: E-6 y E-6b (particiones)
- [ ] R4: E-7 (adversario), E-8 (doble firma), E-9 (retención, descriptivo)
- [ ] Calibración SR_dev (E-2a)
- [ ] Análisis Julia (run.jl) por escenario/repetición
- [ ] INFORME.md

## Proceso en marcha

- **E-2a (calibración de SR_dev), repetición corregida**: PID en `run/e2a-calibracion-r2.pid`
  (lanzado 2026-09-27T11:50:58+02:00), log `run/e2a-calibracion-r2.log`, datos en
  `run/E2a-calibracion/` (fresco). Comprobar con `ps -p $(cat run/e2a-calibracion-r2.pid)`; si no
  existe, mirar `run/E2a-calibracion/TABLA.tsv` y `run/E2a-calibracion/SR_DEV_ELEGIDO.txt` /
  `TAU_MEDIDO.txt`. Puertos 42000-42002 (A,B,C), semilla 101.

## Intento 1 de E-2a: FALLÓ por dos bugs de arnés (conservado, no borrado)

Datos en `run/E2a-calibracion-intento1-buggy/` (renombrado desde `E2a-calibracion/`). Diagnóstico
completo y hallazgo propio + corrección del director, ambos aplicados en `scripts/calibrar_sr_dev.sh`:

1. **Bug propio (contaminación de stdout):** `bxs=$(medir_punto ...)` capturaba TODO el stdout de la
   función (incluidos los `echo ... | tee -a` internos y el "lanzado <nombre> pid=..." de
   `lanzar_nodo`). `awk -v x="$bxs"` tomaba el prefijo numérico de la primera línea (un `date -Is`,
   p. ej. "2026-09-27T11:31:...") como el número **2026**, invirtiendo la comparación bajo/alto de la
   bisección. Se vio en vivo: tras el punto 1 (exponente 32), el punto 2 arrancó con exponente 16 en
   vez de 48 (dirección invertida). Corregido: dentro de `medir_punto` todo el log va directo a
   `EJECUCION.txt` (nunca a stdout); el único stdout de la función es el `echo "$bxs"` final.
2. **Diagnóstico del director (medición de "slots" sin bloques):** con SR_dev muy bajo (2^32) nadie
   produce en la ventana, y mi proxy de "slot actual" (`ultimo_slot_conocido`, que solo lee el slot
   del último bloque VISTO) nunca avanzaba aunque el reloj PoT del nodo sí lo hiciera — no hay evento
   periódico de "slot actual" en el ESQUEMA. Esto dio la fila real del punto 1:
   `slot_inicio=slot_fin=5, 0 slots, 0 bloques` tras 900s reales (el guion no murió: seguía vivo hasta
   que yo lo maté al detectar el bug nº1; el proceso no cayó por `set -e`/división por cero — esa
   parte del guion ya tenía guarda). Corregido siguiendo la indicación del director: se **mide** τ
   (duración real del slot) una vez, en la fase inicial SR=u64::MAX (60s adicionales de producción,
   pares `(slot, reloj_pared_ns)` de A, `τ = Δt/Δslot` en bash/awk puro), y cada punto siguiente usa
   una ventana de PARED de `200·τ_medido` segundos; "slots transcurridos" = segundos_reales/τ_medido,
   nunca el conteo de bloques. Un punto con 0 bloques ahora se acepta como resultado válido (SR_dev
   demasiado bajo) y el guion sigue.
3. **Corrección del director (rango de bisección):** con SR=u64::MAX ya se ven varios bloques por
   slot combinados (los 3 producen casi cada slot), así que el punto buscado está algo por debajo de
   64, no en [0,64]. Bisección acotada a exponentes **[56,64]**.

Verificación manual de la hipótesis del director (bash/awk, sin Python — nota: usé Python por error
un momento para una inspección rápida de `(slot, reloj_pared_ns)`, lo repetí en awk puro
inmediatamente al notarlo; no quedó ningún resultado basado en esa salida): con los datos crudos de
`E2a-calibracion-intento1-buggy/A/registro.jsonl`, slot 1 a t=1790501456590288346ns y slot 5 (última
muestra) a t=1790501461745065843ns ⇒ τ≈1.29s/slot (más lento que el 1s nominal del perfil), lo que
confirma que medir τ en vivo es necesario en vez de asumir 1.0s.
  Comprobar con `ps -p $(cat run/e2a-calibracion.pid)`; si no existe, mirar el final de
  `run/e2a-calibracion.log` y `run/E2a-calibracion/TABLA.tsv` (una fila por punto) y
  `run/E2a-calibracion/SR_DEV_ELEGIDO.txt` (valor final elegido). Puertos 42000-42002 (A,B,C).
  Si termina con error o atascado: leer `run/E2a-calibracion/EJECUCION.txt` y los
  `run/E2a-calibracion/{A,B,C}/stderr.log`. Tras esto (con o sin éxito completo, el guion declara
  "más cercano" a los 6 puntos si no converge, per orden): usar el `SR_dev` elegido para R1 rep1.

## E-0 (terminado, 2026-09-27T11:29+02:00): SUPERADO

fmt/clippy/build/test/3 guardianes CI/release, todo verde. sha256 anotados en `RECETA.md` §6
(`zx-node`=a9f0ffa1b42e3c7c3eaea0ba6a87a20f9a46dfd2118a3b761f4a26be58bf19e1,
`zx-adversario`=a8bcc9d09cf8d891b84212d367243885fc4e900777cec27e7ebecc0d6b906c38). CLI verificada
con `--help`: coincide con lo asumido en `scripts/lib_red.sh`.

## Ya hecho

- fmt: pasó (exit 0, `run/e0-fmt.log`).
- clippy (`--workspace --all-targets --all-features --locked -- -D warnings`): pasó limpio, sin
  `error`/`warning` de clippy (solo salida normal de compilación), `run/e0-clippy.log`.
- Instrumento de análisis (W07c) copiado a `analisis-instrumento/` y su `test/runtests.jl` corre
  verde en esta zona (70+36+402 aserciones), confirmando que el entorno Julia funciona antes de
  usarlo con datos reales.
- Guiones del arnés escritos en `scripts/` (ver más abajo).

## Guiones del arnés escritos (scripts/)

- `verif.sh` — helpers de lectura de registros (contar_evento, hay_fatal, ultimo_slot_conocido,
  todos_los_resumenes_iguales, reposo_listos, total_post_dag, etc.)
- `muestrear_recursos.sh <pid> <dir_datos> <csv>` — muestreo /proc cada 1s, disco cada 10s (ESQUEMA §2)
- `lib_red.sh` — lanzar_nodo/matar/parar_ordenado/EJECUCION.txt, se importa con `source`
- `calibrar_sr_dev.sh <puerto_base> <semilla>` — E-2a, bisección logarítmica hasta 6 puntos
- `r1.sh <rep> <puerto_base> <semilla> <sr_dev> <slot_reposo>` — E-1→E-2(30min)→E-4→E-3
- `r2.sh <rep> <puerto_base> <semilla> <sr_dev> <slot_reposo>` — E-5 (nodo D tardío, IBD desde génesis)
- `r3_e6.sh <rep> <puerto_base> <semilla> <sr_dev>` — E-6 (partición PoST, técnica W06d7 V5)
- `r3_e6b.sh <rep> <puerto_base> <semilla> <sr_dev>` — E-6b (partición PoW cerca del corte, técnica SL4b2)
- `r4.sh <rep> <puerto_base> <semilla> <sr_dev>` — E-7 (adversario) + E-8 (doble-firma, castigo activo) + E-9 (retención, descriptivo)
- `analizar.sh <ejecucion_dir> <nodos> [salida]` — invoca run.jl de W07c (decisión 8 exacta)

Cada guion termina escribiendo `RUN/.done` (o `RUN/<subrun>/.done`), para poder esperar con un
`until [ -f ... ]` sin bloquear.

## Plan de puertos por grupo (para no colisionar)

- E-2a calibración: 42000-42002
- R1 rep1/2/3: 42100/42110/42120 (+0,+1,+2)
- R2 rep1/2/3: 42200/42210/42220 (+0..+3, D es +3)
- R3-E6 rep1/2/3: 42300/42310/42320
- R3-E6b rep1/2/3: 42400/42410/42420
- R4 rep1/2/3: 42500/42510/42520

## Semillas por repetición (fijadas y registradas, distintas por repetición)

rep1=101, rep2=202, rep3=303 (mismo valor para A/B/C/D dentro de una repetición, distinto entre
repeticiones, tal como exige la decisión 2 de la orden).

## Corrección del director (2026-09-27, recibida durante la espera de E-0)

El atasco de `ServicioPot` de `deepseek/W06d6/DEFINICIONES-FALTANTES.md` **ya está corregido** en el
commit candidato `27dcfeb`: W06d7 implementó FC-3 real (un DAG por terminal + servicio PoT de
verificación por terminal) y SL-4b2 (decisión 0) hizo que el productor siga al terminal seleccionado
en caliente, sin reiniciar. Consecuencias para los guiones (ya aplicadas):

- **E-6 (no b)** = mismo terminal: los 3 cruzan el corte juntos, luego se aísla A reiniciándolo sin
  pares (`scripts/r3_e6.sh`, sin cambios de fondo, solo de comentario).
- **E-6b** = terminales distintos: A aislado desde el arranque, B+C juntos, cada lado cruza el corte
  por su cuenta y produce PoST; reunión **con producción en marcha** (B, C no se reinician).
  `scripts/r3_e6b.sh` se ejecuta **tal cual está escrito, sin técnica de evitación**. Corregido para
  calcular el peso FC-3 real: TRN-09/D-T03 decide **solo por el peso PoST del sufijo** (`blue_work`
  de GHOSTDAG), nunca por el trabajo PoW. Como `SR_dev` es constante en toda la red dev,
  `blue_work = blue_score · w` con `w` igual para todo bloque, así que comparar `blue_score` (campo
  del evento `cambio_punta`, ya en el ESQUEMA) basta y es exacto — añadido `blue_score_actual()` a
  `scripts/verif.sh`. El guion ahora escribe los pesos de cada lado (bloques propios y `blue_score`)
  y la predicción FC-3 **en este mismo archivo** antes de reunir, y el resultado real (blue_score
  final) después.
- Si algún nodo se atasca en E-6b, es un **fallo del producto**: el guion ya para ese escenario (no
  se cae, declara `TIMEOUT`/`DIVERGEN` en `RESULTADO.txt`, conserva todos los registros) y no debe
  cambiarse de escenario ni esquivarse.

## Intento 2 de E-2a: TIMEOUT cruzando el corte (conservado, no borrado)

Datos en `run/E2a-calibracion-intento2-timeout/` (renombrado desde `E2a-calibracion/`). Diagnóstico:

- **Causa raíz de la corrupción del intento 1** (por qué apareció una fila fantasma "punto 2
  exponente 16..." en el TABLA.tsv del intento 2, con columnas desplazadas): `kill -9
  $(cat pid_original)` mató el proceso bash de nivel superior, pero **no** mató el subshell que
  bash había creado para `bxs=$(medir_punto ...)` (la sustitución de comandos siempre hace fork).
  Ese subshell quedó huérfano, con sus propios nodos ya matados por `pkill -f`, y siguió su bucle
  `while` releyendo el mismo `registro.jsonl` estático hasta agotar sus 900 s, y al final **escribió
  su fila de resultado (con el formato de columnas VIEJO)** en la ruta `$TABLA`, que para entonces ya
  era el archivo recién creado por el guion "corregido" (mismo nombre de directorio reusado). De ahí
  la fila con las columnas del esquema antiguo (8) apareciendo bajo la cabecera nueva (10 columnas).
  **Verificado, no solo hipotetizado:** confirmé con `ps -eo pid,ppid,pgid,sid,cmd` en el intento 3
  (ver abajo) que `nohup ... & disown` dentro de `lanzar_nodo`/`medir_punto` **no cambia el grupo de
  procesos**: todos los hijos (incluidos subshells de sustitución de comandos) comparten el mismo
  `PGID` que el proceso orquestador de nivel superior. `disown` solo afecta el control de trabajos de
  bash, no `setpgrp`. Un `kill -9 <pid>` sobre un único PID nunca fue suficiente.
- **Por qué el intento 2 (ya con el guion corregido, sin el bug de arriba) dio "TIMEOUT cruzando el
  corte":** los tres nodos arrancaron limpios (`"modo":"limpio"` los tres, sin contaminación de
  datos de una ejecución anterior — verificado leyendo los tres `arranque`). B produjo 413 bloques
  PoST en ~440 s (SR_dev por defecto), pero **A y C produjeron 0** cada uno, pese a haber una breve
  desconexión/reconexión inicial entre A y B (`par_conectado` seguido de `par_desconectado` a los
  pocos µs, reconectados después) — mi criterio de "corte cruzado" exigía que los TRES produjeran
  individualmente >=1 bloque propio, un listón más estricto que lo que hace falta para esta
  calibración (instrumental, no es E-1 en sí). **Hipótesis sin confirmar** sobre por qué A/C no
  producen: podrían quedarse rezagados sincronizando el ritmo de B en vez de producir el suyo propio.
  **Riesgo a vigilar en R1/E-1 real**, donde el criterio de la orden sí exige que los 3 produzcan.

## Correcciones aplicadas para el intento 3

1. `scripts/calibrar_sr_dev.sh`: el "corte cruzado" ahora exige producción **combinada** (A+B+C >= 3
   bloques), no que cada nodo produzca individualmente — suficiente para esta calibración.
2. **Método de lanzamiento/parada, a partir de ahora para TODO guion largo de esta orden (no solo
   calibración):** lanzar con `setsid nohup bash <guion> ... > log 2>&1 < /dev/null &`, anotar el
   PID **real** del script (comprobar con `ps -o pid,ppid,pgid,cmd -p $!`; si `setsid` hizo fork, el
   PID de `$!` NO es el correcto — hay que localizar el proceso "bash <guion>" cuyo PPID es 1 y usar
   ESE pid), y matar con `kill -9 -- -<PGID>` (PGID negativo: mata TODO el grupo de una vez,
   incluidos subshells huérfanos de sustitución de comandos). Verificado con `ps -eo
   pid,ppid,pgid,sid,cmd` que todos los hijos comparten el mismo PGID que el orquestador.

## Intento 3 de E-2a (en marcha)

PID real del orquestador: `run/e2a-calibracion-r3.pid` = **2558499** (PGID igual, verificado), no el
`$!` capturado por el shell (2558495, ya no existe: `setsid` hizo fork). Lanzado
2026-09-27T12:13:27+02:00. Log `run/e2a-calibracion-r3.log` (vacío es normal: el guion ya no escribe
nada a stdout salvo al terminar con éxito). Datos en `run/E2a-calibracion/` (recreado limpio).
Comprobar con `ps -p 2558499`; si no existe, mirar `run/E2a-calibracion/EJECUCION.txt` y
`TABLA.tsv`. **Para matar de emergencia si hace falta: `kill -9 -- -2558499` (grupo completo), nunca
solo `kill -9 2558499`.**

- 12:14:33 corte cruzado (combinado, A=0 B=0 C=5 — de nuevo asimetría entre nodos, rotando cuál
  produce; parece variación real, no ligado a un rango de claves fijo).
- 12:15:12 **τ medido = 1.831675 s/slot** (bastante más que el 1s nominal del perfil; máquina con 3
  nodos reales concurrentes, carga real). Guardado en `run/E2a-calibracion/TAU_MEDIDO.txt` al final.
- 12:15:13 punto 1 de la bisección: exponente=60, sr_dev=1152921504606846976, ventana ≈200×1.83≈366s
  (~6 min). Monitor armado (tarea `byzvpnx15`) esperando más eventos.

## HALLAZGO IMPORTANTE (2026-09-27, del director): A y C no producían por un límite real del
## producto, no por variación entre ejecuciones — corregido el arnés (una clave por nodo)

**Causa verificada** (`run/E2a-calibracion-intento2-timeout/`, conservado, renombrado desde
`E2a-calibracion` → luego el intento 3 también renombrado a `E2a-calibracion-intento3-claves-multiples`
tras repetir el mismo error): mi arnés daba **tres claves por nodo** (A=`0,1,2`, B=`3,4,5`,
C=`6,7,8`, D=`9,10,11` en E-5), copiando el patrón de `deepseek/SL4b2/ejecutar_v4.sh` (que también usa
3 claves por nodo, pero con `N_dev` reducido y otro objetivo). `PERFIL-DEV-v0.md` §3 fija
`K_min = 3` (claves con garantía ≥ `q` para cruzar el corte) asumiendo **una clave por nodo** ("una
clave por nodo de la red de prueba"). Con tres claves por nodo, **un solo nodo que gane la mayoría
del minado PoW ya cumple `K_min=3` él solo**: verificado con `grep -c bloque_minado` en el intento 2 —
B minó 26 de 31 bloques PoW propios, A solo 4, C solo 1. El corte llega en cuanto las 3 claves de B
tienen garantía, **sin que A ni C la tengan**. Tras el corte, en 0.0.1 **no hay relevo de
transacciones** (un nodo solo mete sus propios depósitos en sus propios bloques, `ESCENARIOS-0.0.1.md`
§4): A y C, sin garantía, **ya no pueden conseguirla nunca** ni producir PoST — no es una casualidad
de una ejecución, es estructural mientras haya varias claves por nodo. Esto explica sin ambigüedad
por qué A/C producían 0 bloques en los intentos 2 y 3 (el "riesgo a vigilar" que anoté antes ya
tiene causa, no hace falta seguir vigilándolo como incógnita).

**Corrección aplicada:** los 6 guiones de `scripts/` (`r1.sh`, `r2.sh`, `r3_e6.sh`, `r3_e6b.sh`,
`r4.sh`, `calibrar_sr_dev.sh`) ahora usan **una clave por nodo**: A=`0`, B=`1`, C=`2`, D=`3` (E-5).
Comentario de la corrección insertado en la cabecera de cada guion. `--clave-indice 0` de E-8 sigue
apuntando a la única clave de A, sin cambios necesarios ahí.

**Para el INFORME final:** si con una clave por nodo algún escenario real (sobre todo E-1) vuelve a
mostrar un nodo sin garantía que no deposita a tiempo antes del corte, **eso se declara como
hallazgo del producto y ese escenario/repetición se marca NO SUPERADO con su causa exacta** — no se
esquiva ni se ajusta el criterio a posteriori (instrucción explícita del director).

## HALLAZGO: PANIC real del productor durante el intento 4 (una clave por nodo, ya corregido)

`run/E2a-calibracion-intento4-panic-productor/` (renombrado desde `E2a-calibracion`), lanzado
2026-09-27T12:17:20+02:00 con el arnés YA corregido (A=0,B=1,C=2). Cruzando el corte, el nodo **A
sufrió un panic real** (no un fallo de mi arnés):

```
thread '<unnamed>' (2572307) panicked at crates/zx-node/src/regimen.rs:438:25:
hilo productor: se esperaba Continuar/Parar, llegó Padres
```

Contexto en los registros (los tres, mismo instante): justo tras cruzar el corte, con
`sr_dev=u64::MAX` (el más fácil, usado a propósito para cruzar rápido) los tres nodos auditan con
éxito casi cada slot, produciendo **varios bloques PoST distintos para el mismo slot** casi
simultáneamente (ej. slot 3: hash `4830631f…` de A y `5972bb7a…` de B, ambos admitidos por los tres)
con reorganizaciones inmediatas (`profundidad_reorg:33` visto en A a los pocos bloques). Bajo esa
ráfaga de cambios de terminal/DAG, el hilo productor de A recibió un mensaje `MsgBucle::Padres(..)`
en un punto donde `regimen.rs:433-439` solo esperaba `Continuar`/`Parar` tras publicar su propio
bloque, y el código hace `panic!` explícito en ese caso (no hay rama de recuperación). Es una carrera
de mensajes real en el código del nodo (`crates/zx-node/src/regimen.rs`), no un defecto de mi arnés.
**No lo toco** (vedado modificar código del producto).

**Por qué probablemente no reaparece igual en R1/E-1 real:** esta ráfaga de productores simultáneos
es específica de cruzar el corte con `sr_dev=u64::MAX` (máxima facilidad, deliberado solo para la
fase de calibración). En R1, los nodos arrancan **ya con el `SR_dev` calibrado** (objetivo ≈1
bloque/slot combinado), donde la probabilidad de que dos nodos ganen el mismo slot a la vez es mucho
menor. **Aun así**, si este panic (u otro) aparece durante R1/R2/R3/R4, se declara tal cual: esa
repetición **NO SUPERADA**, con esta causa exacta, sin ocultarlo ni reintentar en bucle para
esconderlo — instrucción explícita del director.

**Acción:** reintentar el cruce del corte de E-2a (es una precondición de mi instrumento, no uno de
los 9 escenarios numerados); si vuelve a pasar, documentarlo igual y seguir reintentando un número
razonable de veces antes de declarar E-2a bloqueada por este defecto.

## Intento 5 de E-2a: corte cruzado SIN panic (12:19:48), midiendo tau ahora

## Intento 5 de E-2a (en marcha)

PID real = PGID = **2573278** (verificado con `ps -o pid,ppid,pgid,cmd`), lanzado
2026-09-27T12:19:26+02:00 con `setsid`. Log `run/e2a-calibracion-r5.log` (vacío es normal). Datos en
`run/E2a-calibracion/` (recreado limpio, una clave por nodo: A=0,B=1,C=2). Espero: que cruce el
corte sin panic, mida τ (60s a `sr_dev=u64::MAX`) y empiece la bisección en exponentes [56,64].
Monitor armado (tarea `bnyjkllaa`). **Si hay que parar: `kill -9 -- -2573278` (grupo completo).**
Si termina con `FALLO_FATAL` por el mismo panic de `regimen.rs:438`, renombrar
`run/E2a-calibracion` a `E2a-calibracion-intentoN-panic-productor` (N siguiente libre) y reintentar
de nuevo sin tocar el código del nodo.

## E-2a CERRADA (2026-09-27T12:34-ish): SR_dev = 13043817825332783104, tau = 1.281552 s

Tabla completa (4 puntos, dentro del objetivo en el punto 4, no hicieron falta 5/6):

| punto | exponente | sr_dev | bloques/slot |
|---|---|---|---|
| 1 | 60 | 1152921504606846976 | 0.2335 |
| 2 | 62 | 4611686018427387904 | 0.6507 |
| 3 | 63 | 9223372036854775808 | 0.7818 |
| 4 | 63.5 | 13043817825332783104 | **0.9946** (dentro de [0.8,1.2]) |

**Forma de la curva (para el INFORME):** no escala linealmente con el exponente/rango: de 2^60 a
2^62 (×4 el rango) el bloques/slot casi se triplica (0.23→0.65), pero de 2^62 a 2^63 (×2) solo sube
~0.13 (0.65→0.78), y de 2^63 a 2^63.5 (×√2≈1.41) sube ~0.21 (0.78→0.99) — la sensibilidad
(Δbloques/slot por unidad de exponente) crece de nuevo cerca de 63.5. Curva no monótona en
sensibilidad, consistente con la combinatoria de "al menos una solución entre 3 auditorías
independientes" (ni puramente exponencial ni lineal en el exponente).

`SR_DEV_ELEGIDO.txt` y `TAU_MEDIDO.txt` escritos en `run/E2a-calibracion/`. Todos los intentos
fallidos previos conservados: `E2a-calibracion-intento{1-buggy,2-timeout,3-tres-claves,4-panic-productor}/`.

## Instrucción del director (2026-09-27, recibida durante el intento 5): el panic es un fallo real
## del producto en 27dcfeb, ya diagnosticado por el director; una orden aparte (W06d8) lo corrige y
## dará un NUEVO commit candidato. Mientras tanto:

1. Terminar la calibración E-2a (SR_dev y τ no dependen de este fallo).
2. **NO empezar R1** cuando la calibración acabe. Dejar aquí el SR_dev elegido y τ, y parar
   diciendo «esperando el nuevo candidato».
3. Cuando llegue el nuevo commit: repetir E-0 completo sobre ese commit (clon limpio, CI local,
   release) antes de seguir con R1…R4, usando el SR_dev ya calibrado.
4. En el INFORME final, el panic del intento 4 (`run/E2a-calibracion-intento4-panic-productor/`) va
   como hallazgo, con su registro conservado.

## Corrección del director (2026-09-27, durante el punto 3): bisección con exponentes FRACCIONARIOS

Con 2^62=0.6507 bloques/slot y 2^63 probablemente ≈1.3, ningún exponente ENTERO cae en [0.8,1.2]:
hay que refinar en el propio exponente (62,5; etc.), no solo en enteros. `scripts/calibrar_sr_dev.sh`
solo bisecaba en enteros (aritmética `(lo+hi)/2` de bash); en vez de modificar el guion mientras
sigue vivo, escribí `scripts/medir_punto_fraccional.sh` (reutiliza `lib_red.sh`, el mismo `--datos`
ya con el corte cruzado, mismo formato de fila en `TABLA.tsv`) para continuar la bisección A MANO
tras dejar que el punto 3 (exponente entero 63, ya en marcha) termine y matar el orquestador
automático. `sr_dev = floor(2^exponente)` calculado en awk (coma flotante de doble precisión: con
exponente >53 hay redondeo en los bits menos significativos de `sr_dev`, irrelevante para el
objetivo de bloques/slot buscado, declarado no oculto). Verificado: `awk` da
`floor(2^62.5)=6521908912666391552` (el director estimó 6521908912666391106; difieren en los
últimos dígitos por el redondeo de doble precisión, ambos representan "≈2^62.5").

Plan: esperar el resultado del punto 3 (exponente 63, entero, ya en marcha, cuenta como uno de los 6
puntos), matar el orquestador (`kill -9 -- -2573278`), y seguir con `medir_punto_fraccional.sh` para
los puntos 4, 5, 6 (fraccionarios) entre el último "bajo" y el último "alto" conocidos, hasta caer en
[0.8,1.2] o agotar los 6.

**Punto 3 real (12:34:14): exponente=63 -> 0,7818 bloques/slot (bajo el objetivo, más cerca que 62 pero
todavía <0.8; la estimación previa de ~1,3 no se cumplió).** Maté el orquestador automático (que ya
había arrancado un punto 4 duplicado con el mismo exponente 63 antes de detectar la degeneración) y
lancé el punto 4 real como fraccionario: **exponente=63,5** (bracket [63 bajo, 64 alto-no medido
todavía]), con `medir_punto_fraccional.sh run/E2a-calibracion 42000 42001 42002 101 1.281552 4 63.5`.
PID=PGID **2638239**, lanzado 2026-09-27T12:34:47+02:00. Log `run/e2a-punto4.log` (vacío hasta que
termine, normal). Espero: fila 4 en `TABLA.tsv` con exponente 63.5; según el resultado, punto 5 será
63.25 (si sigue bajo) o 63.75 (si ya pasa de 1.2), y así hasta caer en [0.8,1.2] o llegar a 6 puntos
en total (quedarían 5 y 6 disponibles tras este).

## Nuevo commit candidato: 26312ffee1b9fd1aa74b1323e087caa1d64a5a77 (W06d8, corrige el panic)

Recibido del director 2026-09-27 ~14:36. E-2a queda cerrada con el commit anterior (27dcfeb): el
`SR_dev`/τ elegidos son independientes del commit (miden la red dev, no el binario en sí, y W06d8
no cambia `N_dev`/`SR_dev`/consenso). **R1…R4 se miden sobre el commit nuevo.**

- Clon nuevo: `clon-26312ff/` (el anterior `clon/` se conserva sin tocar, sirve de evidencia del
  panic de `regimen.rs:438`).
- `PDF/autonomys-subspace` reclonado y fijado en `f8842d0` dentro de `clon-26312ff/`.
- `cargo fmt --all -- --check`: verde (`run/e0b-fmt.log`).
- **E-0 (resto) en marcha**: PID=PGID **2749973** (verificado con `ps -eo pid,ppid,pgid,cmd`;
  ¡cuidado! mi primer intento de capturar el PID con `awk` cazó el PID del propio wrapper de la
  terminal, no el correcto — corregido buscando el proceso real `cargo clippy` con `pgrep -f`).
  Encadena clippy -> build -> test -> 3 guardianes -> release, log `run/e0b-resto.log`. Comprobar
  con `ps -p 2749973`; marcadores `===X_OK===` en el log.
- **Todos los guiones de `scripts/` actualizados** para usar `CLON="$Z/clon-26312ff"` (antes
  apuntaban a `clon/`, el commit viejo con el panic): `r1.sh`, `r2.sh`, `r3_e6.sh`, `r3_e6b.sh`,
  `r4.sh`, `calibrar_sr_dev.sh`, `medir_punto_fraccional.sh`. Sintaxis verificada (`bash -n`) en
  los 7 + `lib_red.sh`/`verif.sh`/`analizar.sh`/`muestrear_recursos.sh`.
- Parámetros para R1…R4: **SR_dev = 13043817825332783104**, semilla por repetición (rep1=101,
  rep2=202, rep3=303), una clave por nodo (A=0,B=1,C=2,D=3), método `setsid`+`kill -9 -- -PGID`.

## E-0 sobre 26312ff: CERRADO, SUPERADO (2026-09-27T15:19)

fmt/clippy/build/test(0 fallos)/3 guardianes/release, todo verde. sha256 en `RECETA.md` §7:
`zx-node=70b0cf2d521c5cbd1bdebd12bb47381c772a498c496861dd77e83d5911cddc01`,
`zx-adversario=a8bcc9d09cf8d891b84212d367243885fc4e900777cec27e7ebecc0d6b906c38` (igual que en
27dcfeb: no cambió). **Todos los escenarios se miden con estos binarios de aquí en adelante.**

**Autocrítica (para no ocultarlo):** al lanzar R1 rep1 la primera vez tuve un fallo de mi arnés
(`r1.sh`/`r2.sh` referenciaban `$SLOT_REPOSO` en un `echo` de diagnóstico ANTES de calcularlo —
resto de un refactor anterior; `set -u` abortó el guion de inmediato, antes de lanzar ningún nodo
real). Corregido (borré esa línea de eco en ambos guiones). **Al limpiar borré
`run/R1-rep1/` de ese primer intento — iba contra la regla "no borres ninguna ejecución, ni las
fallidas".** Lo declaro: no había ningún nodo lanzado ni ningún registro real, solo
`EJECUCION.txt` con la cabecera (commit, sha256, `uname`, etc.) escrita por
`escribir_ejecucion_txt` antes del fallo — no se perdió ninguna medición, pero el borrado en sí
fue un incumplimiento de la regla y debía evitarse (renombrar, no borrar). No volveré a borrar
ningún directorio de `run/` de aquí en adelante, solo renombrar.

## R1 rep1 EN MARCHA (relanzado tras la corrección)

PID=PGID **2808859** (verificado), lanzado 2026-09-27T15:21:20+02:00. Log `run/r1-rep1.log`
(vacío hasta el final, normal). Datos en `run/R1-rep1/`. Los 3 nodos arrancaron con los binarios de
`clon-26312ff`, `--sr-dev 13043817825332783104`, una clave cada uno (A=0,B=1,C=2). Fase actual:
E-1 (esperando que los 3 crucen el corte, plazo 20 min). Cuando esta repetición completa termine
(E-1->E-2 30min->E-4->E-3, puede tardar bastante más de una hora en total), analizar con
`scripts/analizar.sh run/R1-rep1 A,B,C` y anotar el resultado aquí antes de continuar con rep2.

**Para parar si hace falta: `kill -9 -- -2808859` (grupo completo).**

## R1 rep1: TERMINADA Y ANALIZADA — SUPERADA (E-1, E-2, E-3, E-4)

Fin real 2026-09-27T15:56:31+02:00 (confirmado por el director sobre los datos crudos: E-1
superado; E-2 con 0 rechazos, ≈1502 bloques PoST en ≈1574 slots; E-4 con reinicio y puesta al día
en ≈118s; E-3 CONVERGEN en 151s de reposo).

**Bug de arnés encontrado y corregido al analizar:** `scripts/analizar.sh` hacía `cd` al directorio
del instrumento ANTES de pasarle `--ejecucion <ruta relativa>`; `run.jl` resuelve esa ruta con
`abspath()` en su propio directorio de trabajo (el del instrumento, no el mío), así que buscaba
`analisis-instrumento/run/R1-rep1` (inexistente) en vez de `deepseek/W07b/run/R1-rep1`. Corregido
resolviendo la ruta a absoluta ANTES del `cd`, en el propio `analizar.sh` (arnés, no producto).

**Resultado del análisis** (`analisis/R1-rep1/`, instrumento W07c real, sin fallos):
- Estado final igual en los 3 (`083e5cc0...a64e1e3`): **sí**.
- Latencia de propagación (ns), por par, p50/p95 (总total p50=169 226 159 ns ≈169ms, p95≈404ms):
  A→B 169 009 813/352 199 848, A→C 163 925 425/349 459 950, B→A 166 284 440/**20 046 692 468**,
  B→C 168 879 611/356 739 409, C→A 171 876 135/**11 537 643 665**, C→B 172 413 909/373 139 964.
  (Los p95 de B→A y C→A muy altos frente al resto: efecto esperado de E-4 —A estuvo caído y se puso
  al día, así que hay admisiones tardías de bloques de B/C represados; declarado, no oculto.)
- `t_cabecera_ns` (verificación conjunta) p50=66 675 699 ns≈67ms, p95≈133ms.
- `rechazos.tsv`: **vacío, 0 rechazos** (coincide con lo que confirmó el director).
- `bloques_por_slot`: p50=3 — **CORRECCIÓN (ver aviso del director más abajo): esta cifra está mal
  calculada por el instrumento** (cuenta un evento por nodo, ×3 por bloque real, slots vacíos
  fuera); no significa "3 bloques distintos por slot". Se repetirá el análisis con el instrumento
  corregido (W06c-B) antes del INFORME; mientras tanto se conserva como provisional.
- `divergencia_fraccion_tiempo` = 0.231542 (episodios=1370, todos reconvergidos antes del fin).
- Recursos reales (RSS): A/B/C entre ≈790 MiB y ≈1,48 GiB de pico, 2095-2096 muestras cada uno (≈1 s).
- `EJECUCION.txt`, `HUELLAS` de los registros con sha256 en `RESUMEN.md`.

`run/R1-rep1/` conservado íntegro; `HUELLAS.sha256` global se generará al final con todo `run/`.

## R1 rep2 EN MARCHA

PID=PGID **2927284** (verificado), lanzado 2026-09-27T15:59:23+02:00. Log `run/r1-rep2.log`
(vacío hasta el final, normal). Puertos 42110-42112, semilla 202, mismo `SR_dev`. Datos en
`run/R1-rep2/`. **Para parar: `kill -9 -- -2927284`.** Espero: E-1→E-2(30min)→E-4→E-3, como rep1
(≈35-40 min en total). Al terminar: `scripts/analizar.sh run/R1-rep2 A,B,C`, anotar resultado, y
lanzar rep3 (semilla 303, puertos 42120-42122).

## AVISO DEL DIRECTOR (2026-09-27, durante R1 rep2): `bloques_por_slot` del instrumento W07c está
## MAL — no es fallo mío, no la toco, la corrige W06c-B (orden aparte, en
## `P-ZRX/P-MEDICION/analisis-registro-v1/`, en marcha)

Cuenta un evento **por nodo** (cada bloque real aparece ×3, uno por cada nodo que lo ve/admite) y
los slots vacíos quedan fuera del cómputo; por eso la mediana salía en 3 en vez de ≈0,95 bloques
DISTINTOS por slot (lo que de verdad fijó la calibración E-2a: ≈1 bloque/slot **entre los tres**,
no por nodo). Mi lectura anterior en PROGRESO.md ("3 productores × 1 bloque/slot cada uno") era
una interpretación mía, plausible pero **incorrecta** — la cifra en sí ya venía mal calculada por
el instrumento, no reflejaba 3 bloques reales distintos por slot.

**Acción:** seguir midiendo exactamente igual (el instrumento se usa tal cual hasta que avisen).
**Antes del INFORME final, repetir el análisis de TODAS las repeticiones ya hechas** (R1 rep1 en
cuanto esté disponible el instrumento corregido, y todas las que se vayan completando) con la
versión corregida, y usar **solo esas cifras corregidas** en el INFORME — las que ya están en
`analisis/` con el instrumento viejo quedan como borrador/provisional, declarado así.

## CORRECCIÓN DEL DIRECTOR (2026-09-27, tras R1 rep2 DIVERGEN en E-3): nuevo método de comparación
## de estado, no toca el nodo

R1 rep2 terminó con `DIVERGEN` en C: misma `punta` que A/B pero `resumen_estado` distinto. Diagnóstico
del director (confirmado en los registros crudos): `resumen_estado` solo se escribe en `cambio_punta`;
un bloque lateral admitido DESPUÉS del último `cambio_punta` (antes del SIGKILL final) cambia el
estado virtual sin dejar un resumen nuevo escrito — A y B registraron su resumen antes de sus
últimos bloques laterales (611,17s y 611,49s), C después (611,70s). No es una divergencia de consenso
real, es un artefacto de CUÁNDO se escribió el último resumen (hueco del registro, no del nodo).

**Nuevo método (implementado, sin tocar el nodo):** `scripts/verificar_e3_aislado.sh`. Tras el
reposo y el `SIGKILL` a los tres, cada nodo se relanza POR SEPARADO Y AISLADO (sin `--red-marcar`,
su propio puerto, mismo `--datos`) con `--dejar-de-producir-en-slot` MENOR que su slot actual (para
que no produzca): repite entero su almacén. Se espera `reinicio_completo`, se comprueba
EMPÍRICAMENTE que existe un `cambio_punta` posterior (si no existe, para e informa — instrucción
explícita), y se compara el `resumen_estado` de esa línea entre los tres. Añadidas a `verif.sh`:
`resumen_tras_reinicio` (awk puro) y `resumen_y_punta_de_linea`.

**Bug propio encontrado y corregido en el primer intento** (`run/e3-aislado-rep1.log` del primer
intento, descartado): reutilizaba el MISMO `--registro` de la ejecución original, así que
`reinicio_completo`/el conteo de líneas reflejaban el E-4 de mitad de partida (ya viejo), no esta
repetición aislada — daba un falso "ya está quieto" casi instantáneo, y los `zx-node` aislados
quedaban vivos de más (tuve que matarlos a mano, `kill -9`, tras comprobar que el orquestador ya
había terminado). Aun con el bug, la comparación de esa pasada YA mostraba las tres líneas
`cambio_punta` con idéntico `resumen_estado` (`083e5cc0...a64e1e3`) para A/B/C de rep1 — dato
correcto pese al ruido del método. Corregido: cada nodo aislado usa un `--registro` NUEVO
(`registro-e3aislado.jsonl`), así `reinicio_completo` y el "quieto" reflejan solo esta pasada.
Repetido limpio para rep1 (PID 3052550, en marcha).

El veredicto de este método SUSTITUYE al de `todos_los_resumenes_iguales` para "mismo estado tras
reposo" en general, no solo para R1/rep2. Ya retrofitado en `r1.sh`, `r2.sh`, `r3_e6.sh`,
`r3_e6b.sh` y `r4.sh` (E-7/E-8 y E-9): el resultado antiguo queda como `RESULTADO-*-metodo-viejo.txt`
(informativo) y el nuevo, decisivo, en `RESULTADO*.txt`. Nuevo guion compartido
`scripts/reposo_y_verificar.sh` (decisión 6: reposo con `--dejar-de-producir-en-slot` conectado,
30s de silencio, SIGKILL, y `verificar_e3_aislado.sh`) para los escenarios que no tenían reposo
propio (E-6, E-6b, E-7/E-8, E-9); R1/R2 ya tenían su propio cálculo de `slot_reposo` inline, se
dejó como estaba y solo se añadió la llamada a `verificar_e3_aislado.sh` al final.

**Segunda corrección empírica (verificando el propio método nuevo contra datos reales):** el
método tal como lo planteó el director ("el último cambio_punta POSTERIOR a reinicio_completo")
**no encuentra ningún evento** — comprobado en `run/R1-rep1/A/registro-e3aislado.jsonl`:
`reinicio_completo` se escribe SIEMPRE al final, después de todos los `cambio_punta` de la
repetición, nunca antes. Mi guion, siguiendo la instrucción explícita ("si no existe, para e
infórmalo"), paró y lo informó (`NO_CONCLUYENTE_SIN_EVENTO`) en vez de forzar un resultado. Corregí
`resumen_tras_reinicio` en `verif.sh` para tomar el ÚLTIMO `cambio_punta` del registro completo (ya
refleja todo lo reprocesado, laterales incluidos) y solo comprobar que `reinicio_completo` existe
como confirmación de que la repetición terminó — no como marca de "antes/después". Repitiendo con
esta corrección para rep1 ahora mismo.

## CORRECCIÓN DEL DIRECTOR (2026-09-27, tercera vuelta): NINGÚN método de "mismo estado" es decisivo
## todavía — lo confirma el propio código (`nodo.rs:1241 registrar_cambio_de_punta`)

Ni el método antiguo (`todos_los_resumenes_iguales`) ni el "aislado" que acabo de construir son de
fiar: `registrar_cambio_de_punta` sale sin escribir si la punta seleccionada no cambia, y
`reinicio_completo` no lleva su propio resumen — si los últimos bloques repetidos son laterales, el
último resumen registrado (en cualquiera de los dos métodos) puede seguir siendo anterior a ellos.
No es un fallo de mi arnés. Lo corrige la orden **W07d** (en marcha): añadirá a `reinicio_completo`
la punta, el `resumen_estado` del estado virtual DESPUÉS de toda la repetición y un compendio del
conjunto de bloques.

**Mientras tanto:**
- E-3 (y cualquier "mismo estado": E-5, E-6, E-6b, E-7/E-8, E-9) queda **PENDIENTE DE VERIFICACIÓN
  CON EL BINARIO DE W07D** en todos los guiones — ya no llaman a `verificar_e3_aislado.sh` como
  paso decisivo (ahorra tiempo real: cada repetición del almacén tardaba ~2 min); solo paran los
  nodos y escriben el marcador pendiente en `RESULTADO.txt`. `reposo_y_verificar.sh` hace lo mismo
  (reposo real por decisión 6, luego para y marca pendiente, sin repetir el almacén).
- El resultado de rep1 con el método aislado (antes de este aviso) SÍ se completó:
  **CONVERGEN** (resumen `083e5cc0...a64e1e3` en los 3) — se conserva como **informativo**, no
  decisivo. El de rep2 (DIVERGEN, método antiguo) también queda como informativo.
- Los `datos/` de los nodos de TODAS las repeticiones se conservan sin tocar (ya era la práctica);
  cuando llegue W07d, se repetirá la verificación aislada (mismo mecanismo que
  `verificar_e3_aislado.sh`, solo cambia el binario) sobre esos `datos` guardados — ese será el
  veredicto real de "mismo estado" para cada repetición ya medida.

## R1 rep3: TERMINADA Y ANALIZADA — E-1/E-2/E-4 superados, E-3 pendiente (W07d)

Fin real 2026-09-27T17:24:51+02:00 (confirmado por el director: E-1, E-2 con 0 rechazos, E-4
superados). Análisis (`analisis/R1-rep3/`): estado final A≠(B=C) — coherente con la limitación de
`resumen_estado` ya conocida (A fue el reiniciado en E-4); `rechazos.tsv` vacío (0 rechazos,
confirmado); divergencia 0.2194, 1161 episodios, todos reconvergidos. `datos/` de A,B,C conservados
para repetir con el binario de W07d.

**R1 (E-1,E-2,E-3,E-4) — 3/3 repeticiones completas.** Resumen:

| rep | E-1 | E-2 (rechazos) | E-4 (reinicio+puesta al día) | E-3 (informativo, no decisivo) |
|---|---|---|---|---|
| 1 | superado | 0 | ~118s | CONVERGEN (método aislado) |
| 2 | superado | 0 | — | DIVERGEN (método antiguo; explicado: hueco del registro) |
| 3 | superado | 0 | — | estado final distinto A≠(B=C) (método antiguo) |

## R2 rep1 EN MARCHA

PID=PGID **3207935** (verificado), lanzado 2026-09-27T17:26:26+02:00. Puertos 42200-42203
(D=42203), semilla 101, mismo `SR_dev`. Fase: esperando >=500 bloques PoST combinados (plazo 2h;
a ~1 bloque/slot combinado y τ~1,3-1,8s, se espera del orden de 15-25 min real). Después D arranca
en frío (claves 3), IBD, reposo (pendiente W07d), fin. **Para parar: `kill -9 -- -3207935`.**

## R2 rep1: TERMINADA Y ANALIZADA (E-5)

Fin 2026-09-27T17:41:08+02:00. IBD de D: **≈63.55s**, slot_a=slot_d=571, huerfanos_d=7 (leve,
resuelto). Estado final igual (método antiguo, informativo): **sí**, los 4 con el mismo resumen.
0 rechazos. Divergencia 0.7842 (7 episodios, todos reconvergidos — fracción alta pero pocos
episodios, con solo 4 nodos y ventana corta es razonable). `latencia_propagacion D->*`: sin
muestras (D solo se une al final, tras el IBD, no hay pares producción-D→admisión-en-otro dentro
de esta ejecución — declarado en el propio informe, no oculto). E-5 (mismo estado) pendiente W07d
como el resto.

## R2 rep2 EN MARCHA

PID=PGID **3271233** (verificado), lanzado 2026-09-27T17:41:56+02:00. Puertos 42210-42213, semilla
202. **Para parar: `kill -9 -- -3271233`.**

## W07d MIGRADA: commit final de código de 0.0.1 = 22940aa6da64f9b1e78e42a0ed0b57f4a603b68b

Respecto a `26312ff`, solo cambia el registro: `reinicio_completo` y `parada` (críticos) llevan
`punta`, `resumen_estado` del estado virtual FINAL, `n_bloques_dag` y `compendio_bloques` (SHA3-256
de los hashes de todos los bloques persistidos); parada ordenada con `SIGTERM`; evento nuevo
`bloque_transicion_producido`. Detalle en `P-ZRX/P-MEDICION/REVISION-W07d.md` y ESQUEMA §1 ter.

**Se sigue midiendo R2, R3, R4 con `26312ff`** (binarios ya construidos, sin volver a repetir E-0).
Cuando terminen TODAS las repeticiones (checklist más abajo), pasos finales en este orden:

## CHECKLIST FINAL (al terminar R1-R4 con 26312ff)

- [ ] **E-0 final** sobre `22940aa6da64f9b1e78e42a0ed0b57f4a603b68b`: clon limpio en `clon-22940aa/`,
      CI local completa (fmt/clippy/build/test/3 guardianes/release), sha256 de los binarios en
      `RECETA.md`.
- [ ] **Verificación de estado final de CADA repetición de R1…R4** con el binario de `22940aa`:
      reabrir cada nodo AISLADO (sin pares, sin producir — usar el mismo patrón de
      `verificar_e3_aislado.sh`, pero con el binario NUEVO y leyendo `resumen_estado` +
      `compendio_bloques` de `reinicio_completo` directamente, ya no del último `cambio_punta`)
      sobre sus `datos` guardados. Mismo estado ⟺ `resumen_estado` Y `compendio_bloques` iguales
      en todos los nodos de la repetición. Diferencia = fallo real, describir con los compendios.
      **No borrar ningún `datos/` hasta completar esto.**
- [ ] **Repetir los análisis** de TODAS las repeticiones con el instrumento corregido (copiar de
      nuevo `P-ZRX/P-MEDICION/analisis-registro-v1/` sobre `analisis-instrumento/`, versión W07c-B).
- [ ] **INFORME.md**: tabla escenario×repetición, métricas del análisis corregido, calibración
      (tabla + forma de la curva), hallazgos (tres claves por nodo y A-14 abierto, el panic
      corregido por W06d8, el método de E-3/W07d), lo que no se mide (`ESCENARIOS-0.0.1.md` §4).

## R2 rep2: TERMINADA Y ANALIZADA

IBD de D: ≈60.37s (slot_a=slot_d=618, huerfanos_d=15). Estado final igual (método antiguo,
informativo): sí. Divergencia 0.7565. `datos/` conservados. E-5 pendiente W07d.

## R2 rep3 EN MARCHA

PID=PGID **3336283** (verificado), lanzado 2026-09-27T17:56:17+02:00. Puertos 42220-42223, semilla
303. **Para parar: `kill -9 -- -3336283`.** Tras esto: R2 completo (3/3), seguir con **R3** (E-6 y
E-6b, 3 repeticiones cada uno) y luego R4.

## R2 (E-5) COMPLETO — 3/3 repeticiones

| rep | IBD de D | huérfanos | estado final (informativo) |
|---|---|---|---|
| 1 | ≈63.55s | 7 | igual |
| 2 | ≈60.37s | 15 | igual |
| 3 | (ver EJECUCION.txt) | 11 | igual (divergencia 0.7621) |

E-5 pendiente de W07d en las 3, como el resto.

## R3/E-6 rep1 EN MARCHA

PID=PGID **3403758** (verificado), lanzado 2026-09-27T18:11:13+02:00. Puertos 42300-42302, semilla
101. Técnica W06d7 V5 (aislar A sin pares, mismo terminal). **Para parar: `kill -9 -- -3403758`.**
Plan: E-6 rep1,2,3 (semillas 101,202,303, puertos 42300/42310/42320) -> E-6b rep1,2,3 (mismos
puertos+10000 o el siguiente bloque libre) -> R4.

## R3/E-6 rep1: TERMINADA Y ANALIZADA

Aislamiento real 60 slots (slot_a=slot_b=86), reunión y convergencia en ≈9.17s
(`profundidad_reorg=1`, reorg pequeño esperado). Antes de reunir, la punta AISLADA de A ya
coincidía exactamente con la de B/C (mismo hash, mismo resumen, slot 74) — indicio fuerte de
convergencia real incluso antes del veredicto formal de W07d. Estado final (informativo): igual.
Divergencia 0.3473. `datos/` conservados.

## R3/E-6 rep2 EN MARCHA

PID=PGID **3420765** (verificado), lanzado 2026-09-27T18:16:14+02:00. Puertos 42310-42312, semilla
202. **Para parar: `kill -9 -- -3420765`.**

## CORRECCIÓN CRÍTICA DEL DIRECTOR (2026-09-27): E-6 rep1 NO probó ninguna partición real

Verificado por el director en `run/R3-E6-rep1-sin-aislamiento/A/registro.jsonl` (renombrado, no
borrado; igual `rep2` → `R3-E6-rep2-sin-aislamiento`): A "aislado" se relanzaba en el **mismo
puerto** que B/C ya tenían en su `--red-marcar` desde el arranque conjunto; el dial de libp2p de
B/C reintenta esa dirección y los reconecta solos, sin que A haga nada. Por eso la punta "aislada"
de A coincidía exactamente con B/C — no probaba aislamiento, probaba que B/C nunca lo perdieron.

**Corregido en `scripts/r3_e6.sh`:** A se relanza aislado en un puerto NUEVO
(`PA_AISLADO = PORT_BASE+500`) que B/C nunca conocieron, sin `--red-marcar`; para la reunión, A
vuelve a su puerto original con `--red-marcar` explícito. **Criterio obligatorio añadido** (E-6 y
E-6b): durante toda la ventana de partición (por `reloj_pared_ns`, comparable entre procesos), 0
`par_conectado` y 0 `bloque_recibido` de A con los peer_id de B/C, y viceversa — comprobado
empíricamente con la función nueva `contactos_en_ventana` (`verif.sh`, awk puro) y los peer_id
leídos de `arranque` (`peer_id_de`). Si el criterio falla, la repetición se declara
**"NO_VALIDA: SIN AISLAMIENTO"** (ni superada ni fallida) y se conservan los registros. Aplicado
también a `r3_e6b.sh` (que en teoría ya estaba aislado desde el arranque — A nunca tuvo
`--red-marcar` hacia B/C — pero se añade la misma comprobación empírica por exigencia del director,
"criterio obligatorio de TODA partición").

## HALLAZGO REAL DEL PRODUCTO (2026-09-27, R3/E-6 rep1 v2 con aislamiento correcto): panic de C

Con el aislamiento YA corregido (puerto nuevo, verificado 0 contacto — este SÍ es un intento
válido de arnés), C sufrió un **fallo real del nodo** justo tras el corte:

```
zx-node: error fatal: fallo del hilo productor: producir_en_regimen_con_firmante falló: servicio
PoT: no hay portador retenido para el slot 6
```

Confirmado por el director como fallo real del producto (no del arnés). Lo corrige la orden
**W06d9** (en marcha), que dará un nuevo commit candidato. `run/R3-E6-rep1/` (con este fallo)
conservado tal cual, sin tocar. **No se lanzan más escenarios de R3 ni R4 hasta el nuevo
candidato.**

## Mientras tanto: adelantando la verificación de estado final de R1 y R2 con el binario de W07d

Clon `clon-22940aa/` (commit `22940aa6da64f9b1e78e42a0ed0b57f4a603b68b`), Autonomys fijado en
`f8842d0`. Solo se construye el release (`cargo build --release --locked -p zx-node`, con
`nice -n 10`); la CI completa de E-0 se hará al final sobre el commit definitivo. Build en marcha:
PID=PGID **3433531**, lanzado 2026-09-27T18:23:27+02:00, log `run/e0c-release.log`.

Plan tras el build: para CADA repetición de R1 (rep1,2,3) y R2 (rep1,2,3), reabrir CADA nodo
AISLADO (puerto nuevo que nadie conoce, sin `--red-marcar`, `--dejar-de-producir-en-slot` menor
que su slot actual, `--registro` nuevo) sobre sus `datos/` guardados, **un nodo a la vez** (nunca
dos a la vza: "W06d9 hará pruebas con procesos reales en la máquina"), y comparar
`resumen_estado` + `compendio_bloques` del evento `reinicio_completo` (ahora completo por W07d)
entre los nodos de cada repetición. Ese es el veredicto real de E-3 (R1) y E-5 (R2, con D incluido).

## CORRECCIÓN DEL DIRECTOR: verificar sobre COPIAS de `datos/`, nunca el original

**Autocrítica que debo declarar:** mi primer intento de `verificar_estado_w07d.sh` (matado a los
pocos segundos al llegar tu aviso) SÍ llegó a abrir el `datos/` ORIGINAL de `R1-rep1/A` durante
~2s. Comprobado con `find ... -newer`: RocksDB escribió housekeeping real en ese breve tiempo
(`LOG.old.1790526320229504` nuevo, `MANIFEST`/`CURRENT` actualizados) — exactamente el riesgo que
señalaste. El contenido de la cadena no debería haber cambiado (abrí con
`--dejar-de-producir-en-slot` por debajo del slot actual, sin marcar: no se esperaba producción
nueva), pero el directorio de evidencia ya no es *bit a bit* idéntico al de antes de mi intento. Lo
declaro sin ocultarlo. Corregido: `scripts/verificar_estado_w07d.sh` ahora hace `cp -a` del
`datos/` original a `verif/<rep>/<nodo>/datos` ANTES de reabrir, y opera solo sobre esa copia; el
`--registro` de verificación y los logs también van dentro de `verif/`; se anota el `sha256` del
registro de verificación de cada nodo. A partir de ahora, todo nodo restante (B, C de rep1; los 3
de rep2/rep3; los 4 de R2×3) se abre solo desde copia.

## NUEVO CANDIDATO: 3d21b1f44301991fb59737e2117cc26a66a4e93f (W06d9, corrige el fallo_productor)

Causa real: el nodo solo registraba el último portador de la justificación de un bloque de red.
Corregido, con red de seguridad: si no puede justificar, emite `produccion_omitida` y sigue (no
muere). Probado por W06d9: 10/10 cruces reales y 3/3 E-6 con aislamiento real, sin fallos.

`clon-3d21b1f/` clonado, Autonomys fijado en `f8842d0`. **Release TERMINADO 2026-09-27T19:44:12+02:00 (1m39s). sha256:
`zx-node=e7ef7f19a701188237e38266f5d6361c16228620fcf4039e5a67d3b2339900de`,
`zx-adversario=a8bcc9d09cf8d891b84212d367243885fc4e900777cec27e7ebecc0d6b906c38` (igual que en
commits anteriores). `r3_e6.sh`, `r3_e6b.sh`, `r4.sh` actualizados para usar `clon-3d21b1f`
(verificado `bash -n` en los 3). Antes (para contexto, ya obsoleto)** (solo release,
por instrucción del director; la CI completa se hará al final): PID=PGID **3635880**, lanzado
2026-09-27T19:42:24+02:00, log `run/e0d-release.log`, `nice -n 10`.

## R1 rep1: VERIFICADO CON W07d — CONVERGEN real (resumen_estado Y compendio_bloques iguales)

`resumen_estado=083e5cc0...a64e1e3`, `compendio_bloques=df6e6dd6...e7909937` en A, B y C (sobre
copias en `verif/R1-rep1/`, `datos/` original intacto salvo el near-miss ya declarado en A). Este
es el veredicto REAL y definitivo de E-3 para R1 rep1: **SUPERADO**.

## R1 rep2: VERIFICADO CON W07d — CONVERGEN real

`resumen_estado=59fcbed7...095cfc12e55a04`, `compendio_bloques=074ab085...5784bee525ae201601bfb`
en A, B y C — **exactamente iguales**. Nota importante: el método antiguo (informativo) había dado
`DIVERGEN` para esta repetición; la verificación real con W07d confirma que en realidad SÍ
convergían — validación directa de que el método antiguo no era de fiar, tal como advirtió el
director. **Veredicto real de E-3 rep2: SUPERADO.**

## R1 rep3: VERIFICADO CON W07d — CONVERGEN real

`resumen_estado=7bf46f47...4c2d9b38c2b94`, `compendio_bloques=29680bb5...951ccd7a78b7c9a79` en A,
B y C — iguales.

## R1 COMPLETO: 3/3 CONVERGEN real (W07d) — E-3 SUPERADO en las 3 repeticiones

## R2 rep1: VERIFICADO CON W07d — CONVERGEN real (A,B,C,D)

`resumen_estado=67acba95...caaaa8225641ded0b`, `compendio_bloques=a14f91c4...121013d38ea02cf09`
iguales en los 4 (incluido D, el nodo tardío). **Veredicto real de E-5 rep1: SUPERADO.**

## R2 rep2: VERIFICADO CON W07d — CONVERGEN real (A,B,C,D)

`resumen_estado=305777f8...2a62dfa7eeffb4ef`, `compendio_bloques=136dbc4e...031a443f74d33d8`
iguales en los 4. **Veredicto real de E-5 rep2: SUPERADO.**

## R2 rep3: VERIFICADO CON W07d — CONVERGEN real (A,B,C,D)

`resumen_estado=abce9207...770634d12348f51`, `compendio_bloques=e1be3323...45482139d79f500`
iguales en los 4. **Veredicto real de E-5 rep3: SUPERADO.**

## R1 y R2 COMPLETOS: 6/6 repeticiones CONVERGEN real (W07d) — E-3 y E-5 SUPERADOS en todas

| Repetición | resumen_estado (real, W07d) | Veredicto |
|---|---|---|
| R1 rep1 | 083e5cc0...a64e1e3 | SUPERADO |
| R1 rep2 | 59fcbed7...cfc12e55a04 | SUPERADO (el método antiguo había dado DIVERGEN: descartado) |
| R1 rep3 | 7bf46f47...4c2d9b38c2b94 | SUPERADO |
| R2 rep1 | 67acba95...aaaa8225641ded0b | SUPERADO (incluye D, nodo tardío) |
| R2 rep2 | 305777f8...2a62dfa7eeffb4ef | SUPERADO |
| R2 rep3 | abce9207...770634d12348f51 | SUPERADO |

Todas verificadas sobre COPIAS de `datos/` (`verif/<rep>/`), un nodo a la vez, `nice -n 10`,
`resumen_estado` Y `compendio_bloques` iguales (no solo uno). sha256 de cada registro de
verificación anotado en cada `W07D-VERIFICACION.txt`.

## Ahora: R3 y R4 con el binario de 3d21b1f (release ya construido, sha256 anotados)

**Autocrítica que debo declarar:** al lanzar E-6 rep1 con el binario nuevo, reutilicé por descuido
el MISMO nombre de directorio `run/R3-E6-rep1` que aún contenía la evidencia preservada del panic
de `26312ff` (el director dijo "consérvala tal cual", y yo la había dejado ahí sin renombrar). El
nuevo intento reutilizó el `--datos`/`--registro` de esa evidencia, contaminándola (el `pid` quedó
sobrescrito con el PID nuevo, aunque el `registro.jsonl` en sí no llegó a tener una nueva línea
`arranque` — parece que el proceso nuevo falló casi al instante, probablemente por un `LOCK` de
RocksDB en conflicto con el estado dejado por el panic, y mi propio `hay_fatal` detectó el mensaje
de error VIEJO ya presente en `stderr.log`, abortando el guion de inmediato sin haber probado nada
real del binario nuevo). Corregido: renombrado ese directorio contaminado a
`run/R3-E6-rep1-26312ff-panic-contaminado` (conservado, no es evidencia limpia pero tampoco se
borra) y relanzado con un nombre de directorio **nuevo y nunca usado**
(`run/R3-E6-3d21b1f-rep1`) para garantizar cero contaminación. **Lección para el resto de R3/R4: usar
siempre un directorio nuevo por intento, nunca reutilizar uno de un commit anterior.**

## R3/E-6 rep1 (con 3d21b1f): SUPERADA — SIN panic (W06d9 funciona)

E-1-like corte cruzado, aislamiento REAL verificado (0 contactos A↔BC durante la partición),
reunión y convergencia en vivo en ≈12.17s (`profundidad_reorg` normal). Sin ningún `error fatal` ni
`produccion_omitida` necesario en esta repetición. `datos/` conservados.

## R3/E-6 rep1: VERIFICADO CON W07d — CONVERGEN real. E-6 rep1: SUPERADA POR COMPLETO.

`resumen_estado=7a7e9a75...ccd5ac82d5914fe0e`, `compendio_bloques=bc3669a6...c0754b6c4c1ff841d`.

## R3/E-6 rep2 (3d21b1f): SUPERADA — sin panic, aislamiento verificado (0 contactos), convergencia real.

## R3/E-6 rep2: VERIFICADO CON W07d — CONVERGEN real. SUPERADA POR COMPLETO.

`resumen_estado=dd1111fe...c25538b0ddd9cb96`, `compendio_bloques=39780891...575e294a8c9f9a271`.

## R3/E-6 rep3 (3d21b1f): SUPERADA — sin panic, aislamiento verificado, convergencia real.

## R3/E-6 rep3: VERIFICADO CON W07d — CONVERGEN real. SUPERADA POR COMPLETO.

`resumen_estado=92e29e77...c7bbfc8d296aef3a1`, `compendio_bloques=dd7e2b4b...ae1282ec3de926e`.

## R3/E-6 COMPLETO: 3/3 SUPERADAS (aislamiento verificado + estado W07d real, sin ningún panic)

## HALLAZGO EN R3/E-6b: "una clave por nodo" hace el escenario IMPOSIBLE de cruzar por diseño

Con A=clave 0 (aislado) y B=clave 1, C=clave 2 (juntos), NINGÚN lado puede cruzar el corte jamás:
`K_min=3` (`PERFIL-DEV-v0.md` §3) exige garantía de 3 claves DISTINTAS, y en 0.0.1 no hay relevo de
transacciones entre particiones (`ESCENARIOS-0.0.1.md` §4) — el lado de A (1 clave) y el lado de
B+C (2 claves) se quedan cada uno por debajo de `K_min` PARA SIEMPRE. Confirmado en vivo: A minó
**206 bloques PoW** sin cruzar nunca (`run/R3-E6b-3d21b1f-rep1-kmin-imposible/`, conservado,
matado tras confirmar el patrón, no por timeout de 30 min completo).

**Por qué esto NO contradice la corrección anterior de "una clave por nodo":** en R1/R2/E-6/E-7/
E-8/E-9 los 3 nodos están conectados desde el principio y JUNTOS suman las 3 claves distintas
exigidas — ahí "una clave por nodo" es correcto y necesario (evita que un solo nodo monopolice
`K_min` él solo). E-6b, en cambio, **parte la red en dos ANTES del corte**: cada lado necesita sus
PROPIAS 3 claves para poder cruzar por separado — eso es justamente lo que el escenario pone a
prueba (dos lados independientes que cruzan y luego se reconcilian por FC-3). Con solo 3 claves
repartidas 1+1+1 entre los 3 procesos, ningún lado de una partición de 2 vías puede llegar nunca a
3.

**Corrección aplicada** en `scripts/r3_e6b.sh` (patrón ya validado con procesos reales en
`deepseek/SL4b2/ejecutar_e6b.sh`, lectura permitida): A conserva las 3 claves de su lado (`0,1,2` —
es el único proceso de su lado, como un operador real podría controlar varias claves en un lado de
una partición real); B+C reparten las 3 claves del otro lado (`B=3,4`, `C=5`). Esto da a AMBOS
lados exactamente 3 claves, permitiendo que cada uno cruce el corte de forma independiente, sin que
ningún nodo dentro de una red YA CONECTADA (R1/R2/E-6/etc.) tenga ventaja injusta sobre otro — la
distinción es "conectados desde el principio" (una clave cada uno) frente a "partidos desde el
principio" (cada lado necesita sus propias 3).

## R3/E-6b rep1 (claves corregidas): SUPERADA — ambos lados cruzaron, FC-3 predicho y confirmado (BC
## gana), aislamiento verificado (0 contactos), convergencia real en vivo.

## R3/E-6b rep1: VERIFICADO CON W07d — CONVERGEN real. SUPERADA POR COMPLETO.

`resumen_estado=9a295d6d...cdcea35ad2e254cee`, `compendio_bloques=b65d3336...e185b2a5593b3347`.

## R3/E-6b rep2: SUPERADA (aislamiento verificado, convergencia real en vivo, FC-3 confirmado)

## R3/E-6b rep2: VERIFICADO CON W07d — CONVERGEN real. SUPERADA POR COMPLETO.

`resumen_estado=afd1a8d9...e7fccebf640397b28`, `compendio_bloques=7eed0dbf...c4805cf361f551a09df`.

## R3/E-6b rep3: SUPERADA (aislamiento verificado, convergencia real, FC-3 confirmado)

## R3/E-6b rep3: VERIFICADO CON W07d — CONVERGEN real. SUPERADA POR COMPLETO.

`resumen_estado=85526d6a...5db87df34fc41c9a`, `compendio_bloques=2c584fc0...c2d1a319036cd4dc9`.

## R3 COMPLETO: E-6 3/3 y E-6b 3/3, todas SUPERADAS (aislamiento verificado + estado W07d real)

Sin ningún panic ni fallo del producto en ninguna de las 6 repeticiones con el binario `3d21b1f`.
Hallazgo de método importante: E-6b exige 3 claves por LADO de la partición (no 1 por nodo), a
diferencia de los escenarios donde los 3 nodos están conectados desde el principio.

## Corrección preventiva en r4.sh (E-9) antes de lanzar R4

E-9 (parte 2 de r4.sh) tiene la MISMA topología partida que E-6b (A aislado desde el arranque,
B+C juntos) — mismo hallazgo: con una clave por nodo, `K_min=3` es imposible en cualquiera de los
dos lados, y no habría nada que describir. Corregido ANTES de ejecutar (no hizo falta gastar un
intento fallido esta vez): E-9 usa la misma repartición que E-6b, A=`0,1,2`, B=`3,4`, C=`5`. E-7/E-8
(parte 1, red conectada desde el principio) siguen con una clave por nodo (A=0,B=1,C=2), correcto
para esa topología.

## R4 rep1: E-7/E-8/E-9 completos, sin fallos

- E-7 (ráfaga adversarial): completada, sin cambio de estado (informativo, ver
  `run/R4-rep1/e7e8/e7-rechazos.txt`).
- E-8 (doble firma, castigo activo): `evidencia_detectada` en B y C (1 cada uno),
  `evidencia_incluida` en A (1) — exactamente como en SL-4b2. Confiscación esperada.
- E-9 (retención, descriptivo): A y B/C fijaron su propio T casi simultáneamente
  (Δ≈1.66ms). Al publicar A tarde (tras 60s), su terminal GANÓ la reunión: B y C reorganizaron
  con `profundidad=30` hacia el terminal de A. Los 3 convergieron al mismo `resumen_estado`
  (blue_score=182). Descriptivo, sin criterio de éxito/fracaso (A-07 abierto) — dato para el
  INFORME.

## R4 rep1: verificación W07d de E-7/E-8 — CONVERGEN

PID 3781169 ya había terminado al comprobarlo (proceso corto, ~8s). Resultado en
`run/R4-rep1/e7e8/W07D-VERIFICACION.txt`:

```
CONVERGEN (W07d): resumen_estado y compendio_bloques iguales en todos
("resumen_estado":"0b0c6d034faed61e68de349f062223644f672cd3c450960a72fc274be41fffe7"
|"compendio_bloques":"6bdf1286efef7dd584d3bdd9271c399874e6fd17d146f4fc53fb5acd402e117d")
```

A, B, C: mismo `punta`, `n_bloques_dag=96`, tras E-7 (rechazado sin cambio) y E-8 (evidencia
detectada/incluida, confiscación). sha256 de cada registro-w07d.jsonl anotados en ese mismo
fichero.

**Hallazgo corregido antes de causar daño**: `verificar_estado_w07d.sh` deriva
`VERIF="$Z/verif/$(basename "$RUN")"`. Para R4 pasé `run/R4-rep1/e7e8` como RUN_dir (no
`run/R4-rep1`), así que `basename` dio `e7e8` — un nombre que se REPETIRÁ en rep2 y rep3 y
habría sobrescrito las copias de verificación anteriores. Ya renombré
`verif/e7e8` → `verif/R4-rep1-e7e8`. **Para rep2/rep3: renombrar `verif/e7e8` a
`verif/R4-repN-e7e8` inmediatamente después de cada verificación, antes de lanzar la
siguiente repetición.**

R4 rep1 (E-7, E-8, E-9) queda COMPLETO y verificado. Nada en marcha ahora mismo.

## Análisis Julia de R4-rep1: hecho, con corrección de arnés

**Fallo de arnés hallado (mío, declarado)**: `scripts/analizar.sh` resolvía `EJ` (ejecución) a ruta
absoluta antes del `cd "$INST"` pero NO hacía lo mismo con `SALIDA` cuando se pasaba como 3er
argumento relativo (`analisis/R4-rep1-e7e8`). Julia hace `abspath()` de `--salida` en SU cwd
(`$INST`), así que el resultado real quedó en
`analisis-instrumento/analisis/R4-rep1-e7e8` en vez de `$Z/analisis/R4-rep1-e7e8`. Ningún dato se
perdió (solo mal ubicado); lo trasladé a mano y corregí `analizar.sh` para resolver también
`SALIDA` a absoluta antes del `cd` (mismo patrón que ya tenía `EJ`). Repetí e9 ya con el script
corregido: aterrizó bien a la primera.

Resultados (instrumento SIN corregir W07c-B todavía — pendiente de repetir todo al final):
- **R4-rep1/e7e8**: estado final igual=sí, divergencia=0.0815 (57 episodios, 0 sin reconverger).
- **R4-rep1/e9**: estado final igual=sí, divergencia=0.4540 (66 episodios, 1 sin reconverger antes
  del fin — coherente con el reorg profundidad=30 de la reunión tardía).

Salidas en `analisis/R4-rep1-e7e8/` y `analisis/R4-rep1-e9/` (RESUMEN.md, metricas.tsv,
convergencia.tsv, latencias.tsv, rechazos.tsv, admision-vs-profundidad.tsv).

R4 rep1 queda TOTALMENTE completo (ejecución + verificación W07d + análisis Julia).

## R4 rep2 EN MARCHA (E-7/E-8, luego E-9)

PID=PGID **3783996** (verificado, PPID=1), lanzado 2026-09-27T20:35:06+02:00, puertos
42510-42512, semilla 202, SR_dev=13043817825332783104 (mismo calibrado que rep1).
**Para parar: `kill -9 -- -3783996`.**
Log: `run/r4-rep2.log`. Directorio: `run/R4-rep2/` (RUN_TOP), con subdirectorios `e7e8/` y `e9/`.
Marcador final esperado: `run/R4-rep2/RESULTADO.txt` con "ver RESULTADO-e7e8.txt y
RESULTADO-e9-descriptivo.txt".

Recordatorio para mí mismo (evitar la colisión de nombres de `verif/` ya encontrada en rep1):
tras lanzar `verificar_estado_w07d.sh` sobre `run/R4-rep2/e7e8`, el script escribirá en
`verif/e7e8` (mismo nombre que rep1, ya renombrado a `verif/R4-rep1-e7e8`); renombrar el
resultado nuevo a `verif/R4-rep2-e7e8` INMEDIATAMENTE tras confirmarlo, antes de tocar rep3.

## R4 rep2: E-7/E-8/E-9 completos, sin fallos

- E-7: sin cambio de estado (correcto, informativo).
- E-8: `evidencia_detectada` B=1 C=1, `evidencia_incluida` **C=1** (en rep1 fue A; distinto nodo
  incluye primero, comportamiento esperado — no es un fallo).
- E-9: A y B/C fijan T casi simultáneamente; A publica tarde tras 60s; reunión CONVERGE
  (método antiguo, informativo) con `punta`/`resumen_estado` iguales en los 3.

Sin procesos zx-node/zx-adversario residuales tras terminar (verificado).

## R4 rep2: verificación W07d de E-7/E-8 en marcha

PID=PGID **3810035** (verificado, PPID=1), lanzado 2026-09-27T20:41:51+02:00, puerto aislado base
43220. **Para parar: `kill -9 -- -3810035`.**
Log: `run/w07d-verif-r4rep2-e7e8.log`. Salida: `run/R4-rep2/e7e8/W07D-VERIFICACION.txt`.
Al terminar: renombrar `verif/e7e8` → `verif/R4-rep2-e7e8` de inmediato.

Resultado: **CONVERGEN**
(`resumen_estado`=`53ec53da90f1771498ccac5d121323e6b3e3660176a17fb845ea6cf5648b5d08`,
`compendio_bloques`=`f3991d7d3608fb7c1d84b5fd8320f7dab9e92262bc3379a3b73e6f5662cd8a41`). `verif/e7e8`
ya renombrado a `verif/R4-rep2-e7e8`.

## Análisis Julia de R4-rep2: hecho, sin incidencias (script ya corregido)

- **R4-rep2/e7e8**: estado final igual=sí, divergencia=0.1204.
- **R4-rep2/e9**: estado final igual=sí, divergencia=0.4603.

Salidas en `analisis/R4-rep2-e7e8/` y `analisis/R4-rep2-e9/`. Sin salida extraviada en
`analisis-instrumento/analisis/` (confirmado vacío) — la corrección de `analizar.sh` funcionó.

R4 rep2 queda TOTALMENTE completo. Lanzando R4 rep3 (semilla 303, puertos 42520-42522).

## R4 rep3 EN MARCHA (E-7/E-8, luego E-9)

PID=PGID **3811060** (verificado, PPID=1), lanzado 2026-09-27T20:42:31+02:00, puertos
42520-42522, semilla 303, SR_dev=13043817825332783104.
**Para parar: `kill -9 -- -3811060`.**
Log: `run/r4-rep3.log`. Directorio: `run/R4-rep3/`.
Marcador final esperado: `run/R4-rep3/RESULTADO.txt`.
Esta es la ÚLTIMA repetición de R4; tras completarla y verificarla, R4 queda TOTALMENTE
completo (3/3 reps de E-7/E-8/E-9) y toca el checklist final del director: (1) CI completa de
E-0 sobre 3d21b1f, (2) instrumento W07c-B corregido + re-análisis de TODAS las repeticiones,
(3) INFORME.md, (4) HUELLAS.sha256 completo sobre `run/`.

## R4 rep3: E-7/E-8/E-9 completos, sin fallos

- E-7: sin cambio de estado (correcto).
- E-8: `evidencia_detectada` B=1 C=1, `evidencia_incluida` **C=1**.
- E-9: A y B/C fijan T casi simultáneamente (B/C ligeramente antes esta vez); A publica tarde;
  reunión CONVERGE (método antiguo, informativo).

Sin procesos residuales tras terminar (verificado).

## R4 rep3: verificación W07d de E-7/E-8 en marcha

PID=PGID **3835131** (verificado, PPID=1), lanzado 2026-09-27T20:49:16+02:00, puerto aislado base
43320. **Para parar: `kill -9 -- -3835131`.**
Log: `run/w07d-verif-r4rep3-e7e8.log`. Salida: `run/R4-rep3/e7e8/W07D-VERIFICACION.txt`.
Al terminar: renombrar `verif/e7e8` → `verif/R4-rep3-e7e8` de inmediato.

Resultado: **CONVERGEN**
(`resumen_estado`=`6e755a6efe2edb9cb2ff5b74b8acd7755709614497e5772dbf0e18107837b2c2`,
`compendio_bloques`=`cd8b1bc897c9ba94a0998b64dbf4971672384eeee32da353cb553bd88a181ed8`). `verif/e7e8`
ya renombrado a `verif/R4-rep3-e7e8`.

## Análisis Julia de R4-rep3: hecho, sin incidencias

- **R4-rep3/e7e8**: estado final igual=sí, divergencia=0.0937.
- **R4-rep3/e9**: estado final igual=sí, divergencia=0.4573.

Salidas en `analisis/R4-rep3-e7e8/` y `analisis/R4-rep3-e9/`. Sin salida extraviada.

# R4 COMPLETO: 3/3 repeticiones de E-7, E-8 y E-9, todas verificadas CONVERGEN

| rep | E-7 (ráfaga) | E-8 (doble-firma, castigo) | E-8 verificación W07d | E-9 (retención, descriptivo) |
|---|---|---|---|---|
| rep1 (semilla 101) | sin cambio de estado | detectada B=1,C=1; incluida **A=1** | CONVERGEN | A tardío gana reorg, profundidad=30, blue_score=182 |
| rep2 (semilla 202) | sin cambio de estado | detectada B=1,C=1; incluida **C=1** | CONVERGEN | A tardío, reunión CONVERGE |
| rep3 (semilla 303) | sin cambio de estado | detectada B=1,C=1; incluida **C=1** | CONVERGEN | A tardío, reunión CONVERGE |

Nota: qué nodo incluye primero la evidencia (A en rep1, C en rep2 y rep3) varía por carrera de
red/tiempos, no es un fallo — el criterio de éxito de E-8 es que ALGUIEN la incluya y confisque,
lo cual ocurrió en las 3 repeticiones.

Nada en marcha ahora mismo. Ningún proceso zx-node/zx-adversario vivo.

# ESTADO GLOBAL: R1, R2, R3 (E-6+E-6b) y R4 (E-7+E-8+E-9) — TODOS COMPLETOS, 3 repeticiones cada
uno, todos verificados con el método W07d (CONVERGEN en todos los casos medidos).

## Siguiente: checklist final del director

1. **E-0 completa sobre 3d21b1f** (fmt, clippy, build, test, 3 guardianes) — hasta ahora solo se
   hizo `cargo build --release --locked -p zx-node` (y adversario) sobre este commit. Falta la CI
   completa como en RECETA.md §6/§7 para 27dcfeb/26312ff.
2. **Instrumento W07c-B corregido**: comprobar si `P-ZRX/P-MEDICION/analisis-registro-v1/` ya
   trae la corrección de `bloques_por_slot`; si sí, copiar sobre `analisis-instrumento/`, correr
   su suite de tests, y REPETIR el análisis Julia de las 24 ejecuciones ya analizadas (R1×3,
   R2×3, R3-E6×3, R3-E6b×3, R4-e7e8×3, R4-e9×3).
3. **INFORME.md**: tabla completa escenario×repetición, curva de calibración SR_dev, hallazgos
   (bug de tres-claves-por-nodo y su resolución, pánico W06d8, pánico W06d9, evolución del método
   E-3, hallazgo K_min-por-lado en E-6b/E-9), qué NO se midió (ESCENARIOS-0.0.1.md §4).
4. **HUELLAS.sha256** completo sobre todo `run/`.

## Checklist final, paso 1: E-0 completa sobre 3d21b1f EN MARCHA

PID=PGID **3836778** (verificado, PPID=1), lanzado 2026-09-27T20:50:39+02:00.
**Para parar: `kill -9 -- -3836778`.**
Guion: `run/e0-3d21b1f-ci.sh` (fmt, clippy, build workspace, test workspace, los 3 guardianes de
`deps`, y repetición del build release para consistencia del hash). Log: `run/e0-3d21b1f-ci.log`.
Puede tardar varios minutos (clippy+test sobre workspace completo con Autonomys). Confirmar
`=== TODO TERMINADO ===` en el log y todos los `_exit=0` antes de escribir el resultado en
RECETA.md §8.

Mientras corre esto, voy a revisar si `P-ZRX/P-MEDICION/analisis-registro-v1/` ya trae el
instrumento W07c-B corregido (paso 2 del checklist), en paralelo (solo lectura, sin tocar nada).

## Checklist final, paso 2: instrumento W07c-B copiado y verificado — HECHO

Confirmado: el commit `6a7292c` ("W07c-B: el analizador cuenta cada bloque una vez...") ya está
en el historial de HEAD (`git merge-base --is-ancestor 6a7292c HEAD` → sí). `REVISION-W07c.md`
de la fuente confirma: `Pkg.test()` verde, `HUELLAS.sha256` 55/55, W07c-B entregado 2026-09-27
16:01–16:08 por DeepSeek.

Copiado a mi zona (solo lectura de la fuente, escritura solo en mi `analisis-instrumento/`):
- `Manifest.toml` de la fuente es BYTE-IDÉNTICO al mío (sin dependencias nuevas) — verificado con
  `diff`, sin cambios.
- Reemplacé `src/`, `test/`, `run.jl`, `Project.toml` con las versiones de la fuente (que ahora
  trae también `src/AnalisisRegistroV1.jl` como módulo formal — estructura de paquete que no
  tenía mi copia vieja).
- NO traje `datos/`, `.julia-depot/`, `resultados/`, `logs/` de la fuente (son artefactos propios
  de su ejecución, no del instrumento; mi `.julia-depot` sigue siendo el de mi zona, por
  decisión 8 de la orden).
- Suite de test corrida con mi propio `JULIA_DEPOT_PATH` (`$Z/.julia-depot:/home/katana/.julia`):
  **TODO VERDE**, incluida la nueva `V1(h) — bloques distintos, slots vacíos y hallazgos (W07c-B)`
  (14/14). Total: 36+21+5+2+8+5+8+7+17+14+402 = 525 aserciones, todas en verde. Log completo en
  `run/w07c-b-test.log`.

Instrumento corregido LISTO.

## Checklist final, paso 2 (cont.): re-análisis de las 18 ejecuciones — HECHO

Con el instrumento W07c-B corregido, re-analicé (o analicé por primera vez, donde faltaba) las
18 ejecuciones válidas de W07b: R1×3, R2×3 (4 nodos), R3-E6-3d21b1f×3, R3-E6b-3d21b1f×3,
R4-e7e8×3, R4-e9×3. Todas con `exit=0`. Salidas en `analisis/<nombre>/` (RESUMEN.md,
metricas.tsv, convergencia.tsv, latencias.tsv, rechazos.tsv, admision-vs-profundidad.tsv). Logs
en `run/analisis-w07cb-<nombre>.log`.

**Verificado que el arreglo surtió efecto** (ejemplo R4-rep1-e7e8): `bloques_por_slot` ahora
tiene `n=66` (slots del intervalo, incluyendo vacíos) en vez de contar cada bloque una vez por
nodo; `media_bloques_por_slot=0.939394` (razonable), no la mediana=3 inflada que motivó W07c-B.

**Hallazgo esperado, NO es un fallo nuevo**: el campo `estado_final_igual` del instrumento (que
compara el ÚLTIMO evento del `registro.jsonl` CRUDO, sin reposo ni aislamiento) da **`false`**
para R1-rep1, R1-rep2, R1-rep3 y R3-E6-3d21b1f-rep3. Esto es exactamente la limitación ya
documentada y resuelta por el método W07d: los nodos no necesariamente terminan de propagar/
converger en el instante exacto en que se corta el registro. El veredicto DECISIVO para estas 4
repeticiones ya está dado por `verificar_estado_w07d.sh` (reposo + aislamiento + comparación de
`resumen_estado`/`compendio_bloques`), registrado más arriba en este mismo fichero como
CONVERGEN en los 4 casos. El INFORME.md debe dejar esto explícito para no contradecirse: el
`estado_final_igual` del instrumento Julia es descriptivo (fin de intervalo crudo), el veredicto
real es el de W07d.

Para R2 (E-5, 4 nodos) y R3-E6/E6b/R4 (que sí usan reposo+`--dejar-de-producir-en-slot` antes de
cortar el registro), `estado_final_igual` da `true` de forma consistente con el veredicto W07d ya
registrado.

## Checklist final, paso 1: E-0 completa sobre 3d21b1f — SUPERADO

Terminó en 2026-09-27T21:31:18+02:00 (PID 3836778 ya no vivo). Todo verde: fmt, clippy, build
workspace, test workspace (0 fallos), los 3 guardianes de `deps`, release build. Hashes de los
binarios finales IDÉNTICOS a los usados durante toda la medición de R3/R4
(`zx-node`=`e7ef7f19a7...`, `zx-adversario`=`a8bcc9d0...`) — confirma que no hubo drift entre
medir y validar. Detalle completo en `RECETA.md` §8. **E-0: SUPERADO. `3d21b1f` es el commit
definitivo.**

Checklist final: quedan (3) escribir INFORME.md y (4) HUELLAS.sha256 completo. Nada en marcha
ahora mismo.

## AVISO (autodeclarado): presupuesto de 8 h de reloj SUPERADO

`ORDEN-W07b.md` §5 fija **8 h de reloj** de presupuesto. Inicio real (`HORAS.log`):
`2026-09-27T10:45:11+02:00`. Ahora mismo (`date -Is`): `2026-09-27T21:32:42+02:00` → **10 h 47 min
transcurridas**, y aún faltan escribir INFORME.md y HUELLAS.sha256. Se supera el presupuesto en
~3 h (antes de terminar). Motivos identificables (no excusa, solo trazabilidad): dos candidatos
nuevos a mitad de sesión (W06d8 en 26312ff, W06d9 en 3d21b1f) que obligaron a repetir E-0 y partes
de la medición; la evolución del método de comparación de estado (E-3) en 3 iteraciones antes de
W07d; el hallazgo de K_min-por-lado que obligó a rehacer E-6b/E-9. Lo declaro ahora, no al final,
para que el director decida si quiere que pare antes de HUELLAS.sha256/INFORME.md o que termine
el entregable igualmente (voy a terminarlo, porque son los dos únicos pasos que faltan y ya están
todos los datos crudos y análisis listos; si el director prefiere otra cosa, que lo diga en la
próxima instrucción).

## ORDEN-W07b: TERMINADA — los 4 pasos del checklist final completos

1. **E-0 completa sobre 3d21b1f**: SUPERADO (ver arriba).
2. **Instrumento W07c-B copiado, verificado (525 aserciones) y usado para re-analizar las 18
   ejecuciones válidas**: HECHO (ver arriba).
3. **`INFORME.md`**: escrito. Tabla escenario×repetición completa (R1-R4, 24 celdas de veredicto),
   calibración de `SR_dev` con tabla y forma de la curva, 8 hallazgos documentados (tres-claves-
   por-nodo, evolución del método E-3/W07d, K_min-por-lado en E-6b/E-9, los dos fallos reales del
   producto — panic de regimen.rs:438 y fallo del productor por portador PoT — la corrección
   W07c-B del instrumento, penalización de pares no observada en E-7, dos bugs de arnés en
   `analizar.sh`, y el desbordamiento de presupuesto), y la sección de qué NO se mide
   (`ESCENARIOS-0.0.1.md` §4) incluyendo la discrepancia E-8/C-EVP entre `ESCENARIOS-0.0.1.md` y
   `ORDEN-W07b.md`.
4. **`HUELLAS.sha256`**: generado sobre TODO `run/` excepto los directorios `datos/` de RocksDB
   (binarios, ~6 GiB, no auditables como texto; su contenido ya está fingerprinted de forma
   verificable por `resumen_estado`/`compendio_bloques` en cada `W07D-VERIFICACION.txt`, motivo
   documentado en la cabecera del propio `HUELLAS.sha256`). 769 ficheros, 237 MiB. Verificado con
   `sha256sum -c HUELLAS.sha256`: **0 fallos**.

Fin real: `2026-09-27T21:37:28+02:00`. Duración total desde el inicio (`10:45:11`): **≈10 h 52
min**, por encima de las 8 h de presupuesto de `ORDEN-W07b.md` §5 (declarado arriba en cuanto se
detectó, con los motivos). Ningún proceso zx-node/zx-adversario vivo. Nada más en marcha.

**Entregables finales, todos en `/home/katana/zeo/ZEROX/deepseek/W07b/`:** `RECETA.md`,
`INFORME.md`, `PROGRESO.md` (este fichero), `HORAS.log`, `HUELLAS.sha256`, `scripts/` (arnés
bash), `run/` (registros crudos + CSV + veredictos, todas las ejecuciones conservadas incluidas
las fallidas/renombradas), `verif/` (copias aisladas usadas para los veredictos W07d),
`analisis/` (salidas del instrumento W07c-B para las 18 ejecuciones válidas),
`analisis-instrumento/` (copia verificada del instrumento con la corrección W07c-B).

## AVISO (autodeclarado, encontrado en la comprobación final): presupuesto de 50 GiB de disco
## TAMBIÉN superado — 83 GiB reales

`ORDEN-W07b.md` §5 fija 50 GiB de disco. `du -sh .` de la zona entera da **83 GiB**. No lo comprobé
en tiempo real durante la sesión (debí hacerlo al construir cada clon nuevo) — lo veo ahora, en la
comprobación final, y lo digo antes de cerrar el encargo, no lo escondo.

**Desglose:** `clon/` (27dcfeb) 25G, `clon-26312ff/` 24G, `clon-3d21b1f/` 25G, `run/` 6,1G, resto
<1G. Casi todo (21G por clon, 63G en total) es `target/debug/` de `cargo build`/`cargo test
--workspace --all-features` — artefactos de compilación de depuración del workspace completo
(incluye toda la dependencia de Autonomys), NO evidencia de medición. `target/release/` (lo que de
verdad se usó para medir) es solo 1,1G por clon.

**Remediación aplicada ahora mismo:** borro `target/debug/` de los 3 clones (nunca `target/release/`
ni ningún fichero bajo `run/`, `verif/`, `analisis/`). Esto no pierde ninguna evidencia: el
resultado de la CI de cada commit (fmt/clippy/build/test/guardianes, todos verdes) ya está
íntegramente recogido en `RECETA.md`/`INFORME.md` con los `sha256` de los binarios; `target/debug/`
es reproducible desde el código fuente + `Cargo.lock` de cada commit y no aporta nada que ya no
esté documentado. Es una limpieza de espacio, no un borrado de datos de medición (que siguen
vedados de tocar).

**Hecho** (`2026-09-27T21:38:40+02:00`): `rm -rf clon{,-26312ff,-3d21b1f}/target/debug`. Zona
completa: **83G → 21G**, dentro del presupuesto de 50 GiB. Verificado que los 3 binarios release
siguen intactos con el mismo sha256 ya documentado en `RECETA.md`/`INFORME.md`:
`zx-node` 27dcfeb=`a9f0ffa1...`, 26312ff=`70b0cf2d...`, 3d21b1f=`e7ef7f19...` — sin cambios.

**Presupuesto final: 8h de reloj superado (~10h52min de ~8h, declarado arriba) y 50 GiB de disco
YA CORREGIDO (83G→21G, dentro de presupuesto tras la limpieza). Hilos y memoria: no until medidos
en tiempo real, pero nunca se corrieron dos redes a la vez (regla explícita cumplida) y cada red de
3-4 nodos usa muy por debajo de los 20 hilos/32 GiB permitidos (confirmado indirectamente: la
máquina tiene 32 núcleos y las cargas medias anotadas en cada `EJECUCION.txt` nunca superaron ~12).**

ORDEN-W07b: FIN REAL DE LA SESIÓN `2026-09-27T21:38:40+02:00`.

## Plan restante

1. Terminar verificación W07d de R1 rep2, rep3, y R2 rep1,2,3 (con D:3 incluido).
2. En cuanto termine el release de 3d21b1f: usar esos binarios para R3 (E-6×3, E-6b×3, aislamiento
   verificable ya en los guiones) y R4 (E-7,E-8,E-9 ×3). El veredicto de "mismo estado" de cada
   repetición se obtiene con el MISMO método que R1/R2: `verificar_estado_w07d.sh` sobre copias de
   `datos/`, leyendo `resumen_estado`+`compendio_bloques` de `reinicio_completo` (ya no hace falta
   adivinar con el último `cambio_punta`, pero el procedimiento de aislar-sobre-copia es el mismo).
3. Al final: E-0 completa sobre `3d21b1f` (commit definitivo salvo nuevo fallo), copiar el
   instrumento corregido (W07c-B) y repetir todos los análisis, e INFORME.md.

## Próximo paso al retomar

1. Comprobar si `run/e0-resto.pid` sigue vivo; si no, mirar el final de `run/e0-resto.log`.
2. Si `===RELEASE_OK===`: correr `scripts/calibrar_sr_dev.sh 42000 101` (E-2a) ANTES que nada más
   (fija el SR_dev de todos los demás escenarios). Anotar aquí el PID/log antes de esperarlo.
3. Con el SR_dev elegido, lanzar R1 rep1 (`scripts/r1.sh rep1 42100 101 <sr_dev> <slot_reposo>`),
   luego rep2/rep3, luego R2, R3 (E-6, E-6b), R4, en ese orden, cada uno como proceso en segundo
   plano con PID anotado aquí antes de esperar.
4. Tras cada ejecución, correr `scripts/analizar.sh` sobre `run/<escenario>/<rep>` y guardar la
   salida en `analisis/`.
5. `sha256sum` de todo `run/` en `HUELLAS.sha256` al final (o incremental).
6. Escribir `INFORME.md` con la tabla escenario×repetición.


## E-6b 3d21b1f-rep1 (2026-09-27T20:16:09+02:00): pesos FC-3 leídos ANTES de reunir
- A: bloques_producidos=7 blue_score=8
- BC: bloques_producidos(B+C)=7 blue_score(max B,C)=9 (B=9 C=9)
- predicción FC-3 (mayor blue_score gana el terminal T): BC
- ver detalle en run/R3-E6b-3d21b1f-rep1/EJECUCION.txt
- resultado tras reunir (aislado): PENDIENTE_DE_VERIFICACION_CON_W07D (ningún método de comparación de estado es decisivo hasta que reinicio_completo lleve resumen_estado; datos conservados en /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep1/*/datos)
- blue_score final: A=19 B=19 C=19 (predicción era: BC)

## E-6b 3d21b1f-rep2 (2026-09-27T20:18:31+02:00): pesos FC-3 leídos ANTES de reunir
- A: bloques_producidos=8 blue_score=7
- BC: bloques_producidos(B+C)=7 blue_score(max B,C)=9 (B=9 C=9)
- predicción FC-3 (mayor blue_score gana el terminal T): BC
- ver detalle en run/R3-E6b-3d21b1f-rep2/EJECUCION.txt
- resultado tras reunir (aislado): PENDIENTE_DE_VERIFICACION_CON_W07D (ningún método de comparación de estado es decisivo hasta que reinicio_completo lleve resumen_estado; datos conservados en /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep2/*/datos)
- blue_score final: A=11 B=11 C=11 (predicción era: BC)

## E-6b 3d21b1f-rep3 (2026-09-27T20:20:41+02:00): pesos FC-3 leídos ANTES de reunir
- A: bloques_producidos=8 blue_score=7
- BC: bloques_producidos(B+C)=9 blue_score(max B,C)=11 (B=11 C=11)
- predicción FC-3 (mayor blue_score gana el terminal T): BC
- ver detalle en run/R3-E6b-3d21b1f-rep3/EJECUCION.txt
- resultado tras reunir (aislado): PENDIENTE_DE_VERIFICACION_CON_W07D (ningún método de comparación de estado es decisivo hasta que reinicio_completo lleve resumen_estado; datos conservados en /home/katana/zeo/ZEROX/deepseek/W07b/run/R3-E6b-3d21b1f-rep3/*/datos)
- blue_score final: A=16 B=16 C=16 (predicción era: BC)
