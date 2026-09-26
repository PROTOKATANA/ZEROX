# METODO — T01

Método del oráculo de referencia del contrato `P-ZRX/P-TRANSICION/CONTRATO-v0.md`.
Aplica `V-ZRX/LINEO.md` y respeta las decisiones ya tomadas de `ORDEN-T01.md` §3.

## 1. Qué se implementa

Un único módulo Julia (`src/Transicion.jl`) con los tipos de §4.2 y las reglas
TRN-01…TRN-12. No hay criptografía, ni PoW real, ni PoAS/PoT, ni GHOSTDAG: un
bloque es un registro de campos y el identificador entero del bloque hace de
`block_hash` para desempates (menor id gana). La fase PoST es un árbol de
cadenas con un solo padre; el «peso PoST del sufijo» es la suma de pesos
`w ≥ 1` de los bloques PoST de la cadena (abstracción de `blue_work` con
`k = 0`, GHOSTDAG fuera de alcance).

- **Estado** (`mutable struct Estado`): `UTXO` (`Dict{Int,Salida}`), `Garantía`
  por clave (`Dict{Int,Garantia}`), `emitido`/`quemado` (`Int128`), `fase`,
  `terminal`, `altura`, `trabajo_acum`, `slot`, `s0`, registro de sectores,
  `subsidio_acum`, `prox_salida`, `bloque_raiz`, `altura_terminal`, `peso_sufijo`.
- **Transacciones** (`struct Tx` con un `TipoTx`): `Coinbase`, `CoinbasePost`,
  `Transferencia`, `Deposito`, `Retiro`, `Liberacion`, `Evidencia`,
  `AltaSector`, `PruebaSector`.
- **Reglas**: `aplicar(E, B, P)` funcional (clona y muta la copia) aplica el
  orden §3.9: (a) forma y familia; (b) promoción de pendientes; (c) garantía
  del productor y sector `SEC-A`; (d) transacciones con la coinbase primera;
  (e) terminal en PoW.

## 2. Representación y coste

Elección deliberada para un oráculo **pequeño y transparente**, no para un
kernel rápido (ORDEN §6.5 permite no optimizar). Los estados son pequeños
(≤ ~20 bloques por historia), por lo que se usan `Dict` concretos y copia
inmutable en vez de SoA/CSR. Complejidad por historia: `seleccionar` y
`construir_validos` son `O(n²)` con `n` el número de bloques; la batería es
`O(puntos × réplicas × n²)`. Hilos: **1** (`JULIA_NUM_THREADS=1`).

`Emitido` y `Quemado` viven en `Int128` (AMBIGUEDAD-1) porque §3.11 admite el
término negativo `coinbase_pagada − tarifas`; los importes por salida y por
garantía son `UInt64` con `Base.Checked.add_with_overflow`/
`sub_with_overflow`. Un desbordamiento devuelve `ErrDesbordamiento`; un
subtotal insuficiente, `ErrSaldo`.

## 3. Undo

`aplicar_con_undo(E, B, P)` clona `E`, aplica sobre la copia y devuelve
`(E′, undo)` con `undo` siendo la **copia íntegra** del estado previo
(AMBIGUEDAD-12). `deshacer(E′, undo)` restituye esa copia. No hay lógica delta
que pueda desincronizarse: I-2 se cumple por construcción y además se comprueba
contra el hash canónico del estado previo y que `aplicar` no muta su entrada.

## 4. Rejilla y muestreo

La rejilla reducida de ORDEN §6.2 tiene **147 456** puntos (producto cartesiano
completo, incluido `F_slots` y `SEC`). La rejilla «completa» amplía cada valor.

Tiempos medidos (1 hilo, tras calentamiento):

- `escenarios_rechazo` (X-01…X-15): ~0,04 ms por punto.
- `verificar` de una historia aleatoria (I-1…I-7): ~0,04 ms.
- `Pkg.test()` recorre la rejilla **completa** para X-01…X-15 (rechazos, que son
  baratos) y para la batería aleatoria I-*, con `T01_REPLICAS=2`.
- X-16 y X-17…X-20 recorren también los **147 456** puntos. X-16 revisa 7
  órdenes de llegada por punto (identidad, inverso y `T01_I3_PERM=5`
  aleatorios); no agota todas las permutaciones para acotar el coste, pero la
  independencia del orden es estructural (`nodo_en_linea` recalcula
  `seleccionar` sobre el conjunto recibido) y en la batería del test I-3 agota
  las permutaciones para conjuntos con `n ≤ 5`.
- `run.jl` ejecuta **200 réplicas por punto** (29 491 200 historias) y comprueba
  I-1…I-7 en todas; I-3 se muestrea con `--i3-cada` (por defecto 200, es decir,
  1 de cada 200 historias) para acotar el coste. Es la única comprobación
  muestreada; se declara en el informe.

Los valores de la rejilla son de prueba, no propuestas (ORDEN §6.2).

## 5. RNG y reproducibilidad

`StableRNGs.StableRNG(semilla_maestra + réplica)` por réplica (LINEO §7). La
semilla es argumento obligatorio de `run.jl` (`--seed`) y aparece en el
informe. Uso exclusivo de `Test`, `Random`, `SHA`, `Printf`, `StableRNGs`,
`Combinatorics` (las dependencias permitidas por ORDEN §4.1). Sin `Float64` en
ninguna regla. Sin `@fastmath`, `@simd`, `@inbounds` ni `@turbo`.

## 6. Comprobación de la entrada

Al empezar y al terminar se ejecuta
`cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T01.sha256`;
ambas salidas están en `PROGRESO.md`. Nada fuera de `T01/` se modifica.

## 7. Presupuesto y criterio

2 h de reloj, 1 hilo, 8 GiB de RAM, 2 GiB de disco. Criterio fijado antes de
ejecutar: SUPERADO si X-01…X-20 e I-1…I-7 pasan en la rejilla reducida sin
contraejemplos; REFUTADO si aparece un contraejemplo atribuible al contrato;
INCONCLUSO si se agota el presupuesto o hay una ambigüedad que obligue a elegir.
Las 13 ambigüedades de `PROGRESO.md` se resolvieron con la lectura restrictiva o
compatible sin alterar otra regla.
