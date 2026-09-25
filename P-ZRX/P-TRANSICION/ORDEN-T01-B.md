# ORDEN-T01-B — Exportar vectores del oráculo de transición para el diferencial Rust

## 1. Identidad y contexto

- **ID:** T01-B. **Estado:** redactada 2026-09-26; se lanza cuando T01 haya entregado y el director
  la haya revisado. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01/` (la misma de T01).
- **Objetivo único:** añadir al oráculo T01 un exportador determinista que escriba historias,
  resultados esperados y estados canónicos en un **formato de texto neutral** que el motor Rust
  (orden W03) pueda leer sin Julia.
- **Pregunta falsable:** «El exportador produce vectores que, releídos por un lector Julia
  independiente del exportador, reproducen exactamente los resultados del oráculo.» Se refuta con
  una discrepancia en la relectura.
- **Desbloquea:** W03 (motor de estado en Rust con diferencial contra este oráculo).

## 2. Autoridad y entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-TRANSICION/CONTRATO-v0.md`;
`P-ZRX/P-TRANSICION/ORDEN-T01.md`; tu propio `T01/INFORME.md`, `PROGRESO.md` y el código de `T01/`.
Entrada congelada: `P-ZRX/P-TRANSICION/ENTRADA-T01-B.sha256`, al empezar y como último paso.

## 3. Decisiones del director

1. **Solo interfaces por defecto**: `CUT_HWPhi`, `FC3`, `SEC0` (el motor Rust v0 implementa solo
   éstas). Los demás modos siguen siendo del oráculo, no se exportan.
2. **Contenido:** (a) todos los casos dirigidos X-01…X-20 que tengan sentido con las interfaces por
   defecto, en **3** puntos de la rejilla reducida elegidos por su índice (el primero, el del medio y
   el último de la enumeración que ya usa `run.jl`); (b) **2 000** historias aleatorias del generador
   de T01, repartidas uniformemente sobre los puntos de la rejilla reducida con interfaces por
   defecto, semilla maestra `0x5a5a`, réplica `r` con `StableRNG(0x5a5a + r)` como en T01. Cada caso
   lleva su punto de rejilla y su semilla.
3. **Alineación previa con «Ratificaciones v0.1» del contrato** (única modificación permitida de la
   semántica de T01, marcada en el código con `# RATIFICACION-v0.1-Rn`): R-6 coinbase que no es la
   primera transacción ⇒ `ErrEmision`; R-7 coinbase PoW sin salidas ⇒ `ErrEmision`; R-8 importe 0
   en `CoinbasePost`, `Deposito`, `Retiro` o `Liberacion` ⇒ `ErrSaldo`; R-9 transferencia sin
   entradas ⇒ `ErrEmision` (se trata como coinbase fuera de lugar) y transferencia con entradas y
   sin salidas ⇒ `ErrSaldo`. Tras aplicarlas, vuelve a pasar `test/runtests.jl` y ejecuta
   `run.jl --seed 0x5a5a --replicas 50 --rejilla reducida`; guarda ambas salidas. Aparte de eso, el
   exportador solo lee resultados de `aplicar`, `seleccionar` y el estado.
4. **Formato** (UTF-8, una línea por registro, campos `clave=valor` separados por un espacio, sin
   espacios dentro de los valores, listas entre corchetes separadas por comas, enteros en decimal):

       # vectores-transicion-v0 · T01 · <fecha de `date -Is`> · sha256 del contrato <hash>
       CASO n=<entero> nombre=<X-nn|aleatorio> punto=<índice> semilla=<entero|->
       PARAM H_dep=… M_cb=… M_dep=… H_corte_min=… W_min=… S_min=… K_min=… q=… M_res_slots=… M_dep_slots=… M_rec_slots=… R_slots=… F_slots=<entero|inf>
       BLOQUE id=… fam=<Genesis|PoW|PoST> padre=… altura=… trabajo=… pow_ok=<0|1> slot=… prod=… peso=… reqdecl=… ntx=…
       TX tipo=<Coinbase|CoinbasePost|Transferencia|Deposito|Retiro|Liberacion|Evidencia> firmante=… clave=… importe=… ent=[…] sal=[id:valor:dueño,…]
       RES bloque=<id> res=<OK|nombre del Err>
       SEL punta=<id> 
       UTXO dueño=… valor=… origen=<CoinbasePow|Tx|Liberacion> altura=<entero|-> slot=<entero|->
       GAR clave=… activo=… pend=[importe@h<altura>|importe@s<slot>,…] ret=[importe@s<slot>,…] cred=[importe@s<slot>,…] congelado=…
       EST emitido=… quemado=… fase=<FaseGenesis|FasePoW|FasePoST> terminal=<id|-1> altura=… slot=… peso_sufijo=…
       FIN

   Los `BLOQUE`/`TX` van en **orden de entrega** (el que usa el oráculo); cada `TX` pertenece al
   `BLOQUE` inmediatamente anterior, en su orden. `RES` es la validez contextual de cada bloque
   aplicado sobre el estado de su padre (u `ErrSinPadre` si el padre no es válido o no existe:
   añade ese nombre, sin cambiar la semántica de T01 AMBIGUEDAD-13). `SEL` es la punta de
   `seleccionar`. `UTXO`/`GAR`/`EST` describen el estado de esa punta, **ordenados** (UTXO por
   `(dueño, valor, origen, altura, slot)`; GAR por `clave`) y **sin** ids internos de salida.
5. Fichero: `T01/resultados/vectores-transicion-v0.txt` y su `sha256` en
   `T01/resultados/vectores-transicion-v0.sha256`.

## 4. Verificación

- `test/runtests.jl` sigue pasando entero.
- **Relectura independiente:** un lector escrito en un fichero aparte (`src/lector_vectores.jl`), que
  **no** reutiliza funciones del exportador, reconstruye cada caso, lo vuelve a ejecutar con el
  oráculo y compara `RES`, `SEL`, `UTXO`, `GAR` y `EST`. 0 discrepancias.
- Determinismo: dos ejecuciones del exportador producen el mismo `sha256`.
- Presupuesto: 1 h 30 min, 1 hilo, 8 GiB. **Prohibido Python.**

## 5. Entregables y límites

Código del exportador y del lector, el fichero de vectores con su hash, sección «T01-B» en
`INFORME.md` y `PROGRESO.md`, `HORAS.log` actualizado. DeepSeek `deepseek-flash`, esfuerzo `high`;
LINEO; nada fuera de `T01/`; sin commit ni push; sin secretos; fallos reportados literalmente.

## Lanzamiento

    cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T01 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden T01-B. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ORDEN-T01-B.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../T01-B-dsh.stdout 2> ../T01-B-dsh.stderr )
