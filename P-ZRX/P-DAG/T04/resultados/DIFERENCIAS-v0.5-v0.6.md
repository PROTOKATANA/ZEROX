# DIFERENCIAS v0.5 → v0.6 · T04 SL-4c-O / SL-4c-O-B / SL-4c-O-C

- Entrada comparada: `resultados/vectores-estado-dag-v0.5.txt` (1878 casos congelados de v0.5).
- Salida registrada de v0.5 reproducida con el oráculo corregido (v0.6).
- Casos con algún defecto de forma en sus entradas: 181.
- Casos que cambian de resultado: 135.
- Casos que cambian sin defecto de forma: 0.

Cada caso que cambia lleva al menos una `EvidenceTx` con entradas o
salidas (EV-04), con `cbid` ajeno (RAT-1) o con
`pre_hash(H1) ≥ pre_hash(H2)` (EV-04). El bloque que la contiene pasa de
descartar la transacción y seguir válido a ser **inválido en la admisión**;
sus descendientes caen por `ErrSinPadre` y desaparecen sus
`DESC`/créditos/incidentes. La precedencia corregida es **por transacción**
(SL-4c-O-B/-C): dentro del bloque, en su orden, cada `EvidenceTx` se
comprueba `entradas/salidas/testigos` → `cbid` → orden y la primera
defectuosa fija el motivo. v0.5 no contiene ningún caso con orden no
canónico (el generador anterior siempre ordenaba) ni con estructura
defectuosa (el generador anterior nunca daba entradas/salidas a una
evidencia), así que todos los cambios observados son de `cbid` ajeno y
las precedencias no alteran ningún resultado de este diff. Los casos
nuevos de v0.6 (`forma-cbid`, `forma-orden-desc`, `forma-orden-igual`,
`forma-ambos`, `forma-entradas`, `forma-salidas`,
`forma-entradas-salidas`, `forma-entradas-cbid-orden`,
`forma-dos-evidencias` y los aleatorios) no forman parte de este diff
porque v0.5 no los tenía. T04 no modela `testigos`/`n_wit` (el modelo `Tx`
de T01 solo tiene `entradas` y `salidas`), así que EV-04 solo puede
manifestarse aquí por entradas/salidas.

**VEREDICTO = SIN CAMBIOS INJUSTIFICADOS.**

## Casos que cambian

### Caso 18 · `D-18` · punto=1 k=1 semilla=-

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `DESC`: 2 → 1 líneas
  - `SEL`: 8 → 6
  - `GAR` distinto
  - `EST`: `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=3 peso_sufijo=3` → `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=2`

### Caso 921 · `ev-aleatorio` · punto=1 k=1 semilla=24679

- Bloque 17 con defecto(s): cbid.
  - `RES bloque=17`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 3 → 1 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=50 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=6` → `EST emitido=47 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=6`

### Caso 937 · `ev-aleatorio` · punto=1 k=1 semilla=24695

- Bloque 14 con defecto(s): cbid.
  - `RES bloque=14`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 3 → 2 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=8` → `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=8`

### Caso 939 · `ev-aleatorio` · punto=1 k=1 semilla=24697

- Bloque 8 con defecto(s): cbid.
  - `RES bloque=8`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `DESC`: 4 → 2 líneas
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=55 quemado=6 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5` → `EST emitido=41 quemado=6 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5`

### Caso 942 · `ev-aleatorio` · punto=1 k=1 semilla=24700

- Bloque 9 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 3 líneas
  - `SEL`: 18 → 14
  - `GAR` distinto
  - `EST`: `EST emitido=64 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=6` → `EST emitido=41 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=3`

### Caso 966 · `ev-aleatorio` · punto=1 k=1 semilla=24724

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 1 → 0 líneas
  - `SEL`: 6 → 4
  - `GAR` distinto
  - `EST`: `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=3` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=1`

### Caso 969 · `ev-aleatorio` · punto=1 k=1 semilla=24727

- Bloque 8 con defecto(s): cbid.
  - `RES bloque=8`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=18`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 2 líneas
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=61 quemado=18 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5` → `EST emitido=43 quemado=3 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=5`

### Caso 971 · `ev-aleatorio` · punto=1 k=1 semilla=24729

- Bloque 7 con defecto(s): cbid.
- Bloque 15 con defecto(s): cbid.
  - `RES bloque=7`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 0 líneas
  - `SEL`: 19 → 8
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5` → `EST emitido=32 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=3`

### Caso 972 · `ev-aleatorio` · punto=1 k=1 semilla=24730

- Bloque 16 con defecto(s): cbid.
  - `RES bloque=16`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 3 → 2 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=7 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=4` → `EST emitido=59 quemado=7 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=4`

### Caso 977 · `ev-aleatorio` · punto=1 k=1 semilla=24735

- Bloque 7 con defecto(s): cbid.
- Bloque 16 con defecto(s): cbid.
  - `RES bloque=7`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 2 → 1 líneas
  - `SEL`: 7 → 12
  - `GAR` distinto
  - `EST`: `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=3` → `EST emitido=32 quemado=0 fase=FasePoST terminal=3 altura=2 slot=3 peso_sufijo=3`

### Caso 980 · `ev-aleatorio` · punto=1 k=1 semilla=24738

- Bloque 14 con defecto(s): cbid.
- Bloque 16 con defecto(s): cbid.
  - `RES bloque=14`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=16`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 7 → 5 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=12 peso_sufijo=8` → `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=11 peso_sufijo=8`

### Caso 995 · `ev-aleatorio` · punto=1 k=1 semilla=24753

- Bloque 6 con defecto(s): cbid.
- Bloque 7 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 5 → 0 líneas
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=3` → `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=3`

### Caso 1019 · `ev-aleatorio` · punto=1 k=1 semilla=24777

- Bloque 12 con defecto(s): cbid.
- Bloque 13 con defecto(s): cbid.
- Bloque 19 con defecto(s): cbid.
  - `RES bloque=12`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=13`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=14`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 4 → 1 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=50 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=5` → `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=5`

### Caso 1028 · `ev-aleatorio` · punto=1 k=1 semilla=24786

- Bloque 11 con defecto(s): cbid.
  - `RES bloque=11`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1031 · `ev-aleatorio` · punto=1 k=1 semilla=24789

- Bloque 11 con defecto(s): cbid.
- Bloque 14 con defecto(s): cbid.
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 2 → 1 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=38 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5` → `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5`

### Caso 1034 · `ev-aleatorio` · punto=1 k=1 semilla=24792

- Bloque 9 con defecto(s): cbid.
- Bloque 15 con defecto(s): cbid.
  - `RES bloque=15`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 2 → 1 líneas
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=37 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=4` → `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=4`

### Caso 1036 · `ev-aleatorio` · punto=1 k=1 semilla=24794

- Bloque 17 con defecto(s): cbid.
  - `RES bloque=17`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1039 · `ev-aleatorio` · punto=2 k=3 semilla=24777

- Bloque 12 con defecto(s): cbid.
- Bloque 13 con defecto(s): cbid.
- Bloque 19 con defecto(s): cbid.
  - `RES bloque=12`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=13`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=14`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 4 → 1 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=50 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=5` → `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=5`

### Caso 1048 · `ev-aleatorio` · punto=2 k=3 semilla=24786

- Bloque 11 con defecto(s): cbid.
  - `RES bloque=11`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1051 · `ev-aleatorio` · punto=2 k=3 semilla=24789

- Bloque 11 con defecto(s): cbid.
- Bloque 14 con defecto(s): cbid.
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 2 → 1 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=38 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5` → `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5`

### Caso 1054 · `ev-aleatorio` · punto=2 k=3 semilla=24792

- Bloque 9 con defecto(s): cbid.
- Bloque 15 con defecto(s): cbid.
  - `RES bloque=15`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 1 → 1 líneas
  - `UTXO` distinto
  - `EST`: `EST emitido=34 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=4` → `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=4`

### Caso 1056 · `ev-aleatorio` · punto=2 k=3 semilla=24794

- Bloque 17 con defecto(s): cbid.
  - `RES bloque=17`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1060 · `ev-aleatorio` · punto=2 k=3 semilla=24798

- Bloque 5 con defecto(s): cbid.
- Bloque 9 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=18`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 3 → 0 líneas
  - `SEL`: 13 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=1`

### Caso 1064 · `ev-aleatorio` · punto=2 k=3 semilla=24802

- Bloque 9 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `DESC`: 4 → 1 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=6` → `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=6`

### Caso 1065 · `ev-aleatorio` · punto=2 k=3 semilla=24803

- Bloque 13 con defecto(s): cbid.
- Bloque 16 con defecto(s): cbid.
  - `RES bloque=13`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=16`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 8 → 5 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=4` → `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=4`

### Caso 1067 · `ev-aleatorio` · punto=2 k=3 semilla=24805

- Bloque 9 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 3 → 2 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=47 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=6` → `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=6`

### Caso 1068 · `ev-aleatorio` · punto=2 k=3 semilla=24806

- Bloque 6 con defecto(s): cbid.
- Bloque 12 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 5 → 1 líneas
  - `SEL`: 14 → 17
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=6` → `EST emitido=41 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=6`

### Caso 1077 · `ev-aleatorio` · punto=2 k=3 semilla=24815

- Bloque 7 con defecto(s): cbid.
  - `RES bloque=7`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 0 líneas
  - `SEL`: 14 → 6
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=6` → `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=2`

### Caso 1097 · `ev-aleatorio` · punto=2 k=3 semilla=24835

- Bloque 6 con defecto(s): cbid.
- Bloque 9 con defecto(s): cbid.
- Bloque 12 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 0 líneas
  - `SEL`: 19 → 5
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=7` → `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=3 peso_sufijo=2`

### Caso 1099 · `ev-aleatorio` · punto=2 k=3 semilla=24837

- Bloque 7 con defecto(s): cbid.
- Bloque 10 con defecto(s): cbid.
- Bloque 11 con defecto(s): cbid.
  - `RES bloque=7`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `DESC`: 2 → 0 líneas
  - `SEL`: 15 → 6
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=7` → `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=3`

### Caso 1103 · `ev-aleatorio` · punto=2 k=3 semilla=24841

- Bloque 12 con defecto(s): cbid.
- Bloque 16 con defecto(s): cbid.
  - `RES bloque=12`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 7 → 3 líneas
  - `SEL`: 19 → 10
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=56 quemado=13 fase=FasePoST terminal=3 altura=2 slot=12 peso_sufijo=10` → `EST emitido=41 quemado=5 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5`

### Caso 1114 · `ev-aleatorio` · punto=2 k=3 semilla=24852

- Bloque 9 con defecto(s): cbid.
- Bloque 16 con defecto(s): cbid.
  - `RES bloque=9`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1117 · `ev-aleatorio` · punto=2 k=3 semilla=24855

- Bloque 14 con defecto(s): cbid.
  - `RES bloque=14`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 5 → 3 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=46 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=6` → `EST emitido=43 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=6`

### Caso 1120 · `ev-aleatorio` · punto=2 k=3 semilla=24858

- Bloque 5 con defecto(s): cbid.
- Bloque 10 con defecto(s): cbid.
  - `RES bloque=5`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1122 · `ev-aleatorio` · punto=2 k=3 semilla=24860

- Bloque 6 con defecto(s): cbid.
- Bloque 9 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=14`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 5 → 1 líneas
  - `SEL`: 18 → 8
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=48 quemado=3 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=6` → `EST emitido=33 quemado=3 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=3`

### Caso 1132 · `ev-aleatorio` · punto=2 k=3 semilla=24870

- Bloque 11 con defecto(s): cbid.
- Bloque 17 con defecto(s): cbid.
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 2 líneas
  - `SEL`: 18 → 15
  - `GAR` distinto
  - `EST`: `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=7` → `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=5`

### Caso 1147 · `ev-aleatorio` · punto=2 k=3 semilla=24885

- Bloque 11 con defecto(s): cbid.
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 4 → 2 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=4` → `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=4`

### Caso 1167 · `ev-aleatorio` · punto=3 k=1 semilla=24885

- Bloque 11 con defecto(s): cbid.
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 4 → 2 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5` → `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5`

### Caso 1182 · `ev-aleatorio` · punto=3 k=1 semilla=24900

- Bloque 6 con defecto(s): cbid.
- Bloque 15 con defecto(s): cbid.
- Bloque 16 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 1 líneas
  - `SEL`: 16 → 5
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=5` → `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=3 peso_sufijo=2`

### Caso 1188 · `ev-aleatorio` · punto=3 k=1 semilla=24906

- Bloque 7 con defecto(s): cbid.
- Bloque 11 con defecto(s): cbid.
  - `RES bloque=7`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 1 líneas
  - `SEL`: 14 → 18
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=58 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=6` → `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=2`

### Caso 1191 · `ev-aleatorio` · punto=3 k=1 semilla=24909

- Bloque 18 con defecto(s): cbid.
  - `RES bloque=18`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 5 → 3 líneas
  - `SEL`: 19 → 17
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=3 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=9` → `EST emitido=56 quemado=3 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=9`

### Caso 1196 · `ev-aleatorio` · punto=3 k=1 semilla=24914

- Bloque 7 con defecto(s): cbid.
- Bloque 18 con defecto(s): cbid.
  - `RES bloque=7`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `DESC`: 2 → 0 líneas
  - `SEL`: 14 → 6
  - `GAR` distinto
  - `EST`: `EST emitido=38 quemado=6 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4` → `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=3`

### Caso 1201 · `ev-aleatorio` · punto=3 k=1 semilla=24919

- Bloque 6 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `GAR` distinto
  - `EST`: `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5` → `EST emitido=38 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5`

### Caso 1206 · `ev-aleatorio` · punto=3 k=1 semilla=24924

- Bloque 9 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 4 → 1 líneas
  - `SEL`: 12 → 15
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=50 quemado=9 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=4` → `EST emitido=43 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=4`

### Caso 1207 · `ev-aleatorio` · punto=3 k=1 semilla=24925

- Bloque 16 con defecto(s): cbid.
  - `RES bloque=16`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 4 → 2 líneas
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=2` → `EST emitido=50 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=2`

### Caso 1215 · `ev-aleatorio` · punto=3 k=1 semilla=24933

- Bloque 14 con defecto(s): cbid.
  - `RES bloque=14`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 3 → 1 líneas
  - `SEL`: 14 → 10
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5` → `EST emitido=50 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4`

### Caso 1223 · `ev-aleatorio` · punto=3 k=1 semilla=24941

- Bloque 6 con defecto(s): cbid.
- Bloque 10 con defecto(s): cbid.
- Bloque 11 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=12`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=13`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 10 → 0 líneas
  - `SEL`: 14 → 5
  - `GAR` distinto
  - `EST`: `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=6` → `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=2`

### Caso 1227 · `ev-aleatorio` · punto=3 k=1 semilla=24945

- Bloque 16 con defecto(s): cbid.
  - `RES bloque=16`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 10 → 8 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=66 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=6` → `EST emitido=63 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=6`

### Caso 1230 · `ev-aleatorio` · punto=3 k=1 semilla=24948

- Bloque 13 con defecto(s): cbid.
- Bloque 14 con defecto(s): cbid.
- Bloque 18 con defecto(s): cbid.
  - `RES bloque=13`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=14`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 4 → 1 líneas
  - `SEL`: 18 → 12
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=12 peso_sufijo=9` → `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=7`

### Caso 1235 · `ev-aleatorio` · punto=3 k=1 semilla=24953

- Bloque 9 con defecto(s): cbid.
- Bloque 14 con defecto(s): cbid.
- Bloque 18 con defecto(s): cbid.
  - `RES bloque=9`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=14`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 1 → 0 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5` → `EST emitido=41 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5`

### Caso 1250 · `ev-aleatorio` · punto=3 k=1 semilla=24968

- Bloque 6 con defecto(s): cbid.
- Bloque 14 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 5 → 0 líneas
  - `SEL`: 15 → 7
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=5` → `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=3`

### Caso 1266 · `ev-aleatorio` · punto=3 k=1 semilla=24984

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 1 → 0 líneas
  - `SEL`: 18 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=8` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=1 peso_sufijo=1`

### Caso 1270 · `ev-aleatorio` · punto=3 k=1 semilla=24988

- Bloque 6 con defecto(s): cbid.
- Bloque 9 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 0 líneas
  - `SEL`: 14 → 5
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=52 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=8` → `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=2`

### Caso 1271 · `ev-aleatorio` · punto=3 k=1 semilla=24989

- Bloque 16 con defecto(s): cbid.
  - `RES bloque=16`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 5 → 3 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=51 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=7` → `EST emitido=48 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=7`

### Caso 1274 · `ev-aleatorio` · punto=3 k=1 semilla=24992

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 1 → 0 líneas
  - `SEL`: 5 → 4
  - `GAR` distinto
  - `EST`: `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=3 peso_sufijo=2` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=1 peso_sufijo=1`

### Caso 1286 · `ev-aleatorio` · punto=4 k=3 semilla=24984

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 1 → 0 líneas
  - `SEL`: 18 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=8` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=1 peso_sufijo=1`

### Caso 1290 · `ev-aleatorio` · punto=4 k=3 semilla=24988

- Bloque 6 con defecto(s): cbid.
- Bloque 9 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 0 líneas
  - `SEL`: 14 → 5
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=52 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=8` → `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=2`

### Caso 1291 · `ev-aleatorio` · punto=4 k=3 semilla=24989

- Bloque 16 con defecto(s): cbid.
  - `RES bloque=16`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 5 → 3 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=51 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=7` → `EST emitido=48 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=7`

### Caso 1294 · `ev-aleatorio` · punto=4 k=3 semilla=24992

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 1 → 0 líneas
  - `SEL`: 5 → 4
  - `GAR` distinto
  - `EST`: `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=3 peso_sufijo=2` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=1 peso_sufijo=1`

### Caso 1303 · `ev-aleatorio` · punto=4 k=3 semilla=25001

- Bloque 6 con defecto(s): cbid.
- Bloque 14 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `DESC`: 1 → 0 líneas
  - `SEL`: 17 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=38 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=1`

### Caso 1312 · `ev-aleatorio` · punto=4 k=3 semilla=25010

- Bloque 9 con defecto(s): cbid.
- Bloque 14 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `DESC`: 5 → 2 líneas
  - `SEL`: 17 → 18
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=7` → `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5`

### Caso 1321 · `ev-aleatorio` · punto=4 k=3 semilla=25019

- Bloque 18 con defecto(s): cbid.
  - `RES bloque=18`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 5 → 3 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5` → `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5`

### Caso 1330 · `ev-aleatorio` · punto=4 k=3 semilla=25028

- Bloque 8 con defecto(s): cbid.
  - `RES bloque=8`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `DESC`: 4 → 1 líneas
  - `SEL`: 15 → 6
  - `GAR` distinto
  - `EST`: `EST emitido=47 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=4` → `EST emitido=38 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=3`

### Caso 1334 · `ev-aleatorio` · punto=4 k=3 semilla=25032

- Bloque 11 con defecto(s): cbid.
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 5 → 3 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5` → `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5`

### Caso 1336 · `ev-aleatorio` · punto=4 k=3 semilla=25034

- Bloque 7 con defecto(s): cbid.
  - `RES bloque=7`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1342 · `ev-aleatorio` · punto=4 k=3 semilla=25040

- Bloque 16 con defecto(s): cbid.
- Bloque 18 con defecto(s): cbid.
  - `RES bloque=16`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=18`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 3 → 1 líneas
  - `SEL`: 16 → 12
  - `GAR` distinto
  - `EST`: `EST emitido=55 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=4` → `EST emitido=50 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5`

### Caso 1344 · `ev-aleatorio` · punto=4 k=3 semilla=25042

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 4 → 0 líneas
  - `SEL`: 13 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=46 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=8` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=1`

### Caso 1351 · `ev-aleatorio` · punto=4 k=3 semilla=25049

- Bloque 6 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 1 líneas
  - `SEL`: 19 → 8
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=9` → `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=4`

### Caso 1364 · `ev-aleatorio` · punto=4 k=3 semilla=25062

- Bloque 7 con defecto(s): cbid.
- Bloque 15 con defecto(s): cbid.
  - `RES bloque=7`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 8 → 2 líneas
  - `SEL`: 16 → 12
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=18 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5` → `EST emitido=38 quemado=9 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=3`

### Caso 1365 · `ev-aleatorio` · punto=4 k=3 semilla=25063

- Bloque 15 con defecto(s): cbid.
  - `RES bloque=15`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `DESC`: 2 → 0 líneas
  - `SEL`: 17 → 18
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=7` → `EST emitido=47 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=6`

### Caso 1372 · `ev-aleatorio` · punto=4 k=3 semilla=25070

- Bloque 12 con defecto(s): cbid.
  - `RES bloque=12`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 3 líneas
  - `SEL`: 15 → 14
  - `GAR` distinto
  - `EST`: `EST emitido=61 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=8` → `EST emitido=49 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=7`

### Caso 1382 · `ev-aleatorio` · punto=4 k=3 semilla=25080

- Bloque 11 con defecto(s): cbid.
- Bloque 16 con defecto(s): cbid.
  - `RES bloque=11`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1402 · `ev-aleatorio` · punto=5 k=1 semilla=25080

- Bloque 11 con defecto(s): cbid.
- Bloque 16 con defecto(s): cbid.
  - `RES bloque=11`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1419 · `ev-aleatorio` · punto=5 k=1 semilla=25097

- Bloque 9 con defecto(s): cbid.
- Bloque 11 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 7 → 0 líneas
  - `SEL`: 18 → 15
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=6 fase=FasePoST terminal=3 altura=2 slot=12 peso_sufijo=8` → `EST emitido=41 quemado=6 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5`

### Caso 1431 · `ev-aleatorio` · punto=5 k=1 semilla=25109

- Bloque 14 con defecto(s): cbid.
  - `RES bloque=14`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 6 → 5 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=27 fase=FasePoST terminal=3 altura=2 slot=14 peso_sufijo=8` → `EST emitido=59 quemado=27 fase=FasePoST terminal=3 altura=2 slot=14 peso_sufijo=8`

### Caso 1438 · `ev-aleatorio` · punto=5 k=1 semilla=25116

- Bloque 5 con defecto(s): cbid.
- Bloque 15 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=16`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 1 → 0 líneas
  - `SEL`: 7 → 18
  - `GAR` distinto
  - `EST`: `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=3` → `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=2`

### Caso 1450 · `ev-aleatorio` · punto=5 k=1 semilla=25128

- Bloque 10 con defecto(s): cbid.
- Bloque 18 con defecto(s): cbid.
  - `RES bloque=10`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 1 → 0 líneas
  - `SEL`: 10 → 7
  - `GAR` distinto
  - `EST`: `EST emitido=38 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4` → `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=3`

### Caso 1468 · `ev-aleatorio` · punto=5 k=1 semilla=25146

- Bloque 17 con defecto(s): cbid.
  - `RES bloque=17`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1470 · `ev-aleatorio` · punto=5 k=1 semilla=25148

- Bloque 5 con defecto(s): cbid.
- Bloque 6 con defecto(s): cbid.
- Bloque 15 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 0 líneas
  - `SEL`: 18 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=60 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=7` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=1`

### Caso 1476 · `ev-aleatorio` · punto=5 k=1 semilla=25154

- Bloque 8 con defecto(s): cbid.
  - `RES bloque=8`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 4 → 2 líneas
  - `SEL`: 18 → 16
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=7` → `EST emitido=41 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5`

### Caso 1484 · `ev-aleatorio` · punto=5 k=1 semilla=25162

- Bloque 12 con defecto(s): cbid.
- Bloque 16 con defecto(s): cbid.
  - `RES bloque=12`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 2 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=61 quemado=0 fase=FasePoST terminal=3 altura=2 slot=13 peso_sufijo=7` → `EST emitido=52 quemado=0 fase=FasePoST terminal=3 altura=2 slot=11 peso_sufijo=7`

### Caso 1487 · `ev-aleatorio` · punto=5 k=1 semilla=25165

- Bloque 9 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 3 → 1 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=52 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5` → `EST emitido=40 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5`

### Caso 1490 · `ev-aleatorio` · punto=5 k=1 semilla=25168

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `DESC`: 1 → 1 líneas
  - `SEL`: 16 → 7
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=33 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=4` → `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=2`

### Caso 1498 · `ev-aleatorio` · punto=5 k=1 semilla=25176

- Bloque 8 con defecto(s): cbid.
- Bloque 11 con defecto(s): cbid.
- Bloque 18 con defecto(s): cbid.
  - `RES bloque=8`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `DESC`: 5 → 1 líneas
  - `SEL`: 17 → 6
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=7` → `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=3 peso_sufijo=2`

### Caso 1503 · `ev-aleatorio` · punto=5 k=1 semilla=25181

- Bloque 9 con defecto(s): cbid.
- Bloque 11 con defecto(s): cbid.
- Bloque 18 con defecto(s): cbid.
  - `RES bloque=9`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 5 → 3 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4` → `EST emitido=41 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4`

### Caso 1523 · `ev-aleatorio` · punto=6 k=3 semilla=25181

- Bloque 9 con defecto(s): cbid.
- Bloque 11 con defecto(s): cbid.
- Bloque 18 con defecto(s): cbid.
  - `RES bloque=9`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 5 → 3 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4` → `EST emitido=41 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4`

### Caso 1540 · `ev-aleatorio` · punto=6 k=3 semilla=25198

- Bloque 9 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 0 líneas
  - `SEL`: 15 → 14
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=4` → `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=4`

### Caso 1543 · `ev-aleatorio` · punto=6 k=3 semilla=25201

- Bloque 8 con defecto(s): cbid.
  - `RES bloque=8`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1547 · `ev-aleatorio` · punto=6 k=3 semilla=25205

- Bloque 13 con defecto(s): cbid.
- Bloque 18 con defecto(s): cbid.
  - `RES bloque=13`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=18`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 2 → 1 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=47 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=8` → `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=3 peso_sufijo=8`

### Caso 1549 · `ev-aleatorio` · punto=6 k=3 semilla=25207

- Bloque 9 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 5 → 4 líneas
  - `SEL`: 18 → 19
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=34 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5` → `EST emitido=62 quemado=25 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=7`

### Caso 1551 · `ev-aleatorio` · punto=6 k=3 semilla=25209

- Bloque 5 con defecto(s): cbid.
- Bloque 11 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 6 → 1 líneas
  - `SEL`: 16 → 9
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=6` → `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=3`

### Caso 1557 · `ev-aleatorio` · punto=6 k=3 semilla=25215

- Bloque 9 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 7 → 3 líneas
  - `SEL`: 18 → 15
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5` → `EST emitido=44 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=5`

### Caso 1563 · `ev-aleatorio` · punto=6 k=3 semilla=25221

- Bloque 6 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 0 líneas
  - `SEL`: 19 → 11
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=64 quemado=0 fase=FasePoST terminal=3 altura=2 slot=13 peso_sufijo=8` → `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=3`

### Caso 1578 · `ev-aleatorio` · punto=6 k=3 semilla=25236

- Bloque 9 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 1 líneas
  - `SEL`: 12 → 14
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=50 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5` → `EST emitido=41 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=4`

### Caso 1582 · `ev-aleatorio` · punto=6 k=3 semilla=25240

- Bloque 14 con defecto(s): cbid.
  - `RES bloque=14`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `DESC`: 7 → 6 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=7` → `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=7`

### Caso 1587 · `ev-aleatorio` · punto=6 k=3 semilla=25245

- Bloque 6 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 0 líneas
  - `SEL`: 18 → 16
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=27 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=9` → `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=2`

### Caso 1604 · `ev-aleatorio` · punto=6 k=3 semilla=25262

- Bloque 15 con defecto(s): cbid.
  - `RES bloque=15`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1605 · `ev-aleatorio` · punto=6 k=3 semilla=25263

- Bloque 8 con defecto(s): cbid.
  - `RES bloque=8`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=9`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 1 líneas
  - `SEL`: 19 → 16
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=61 quemado=11 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=7` → `EST emitido=43 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4`

### Caso 1607 · `ev-aleatorio` · punto=6 k=3 semilla=25265

- Bloque 10 con defecto(s): cbid.
  - `RES bloque=10`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 2 → 0 líneas
  - `SEL`: 14 → 13
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=46 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=7` → `EST emitido=40 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=6`

### Caso 1610 · `ev-aleatorio` · punto=6 k=3 semilla=25268

- Bloque 6 con defecto(s): cbid.
- Bloque 9 con defecto(s): cbid.
  - `RES bloque=6`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1620 · `ev-aleatorio` · punto=6 k=3 semilla=25278

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=16`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 4 → 0 líneas
  - `SEL`: 11 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=47 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=5` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=1 peso_sufijo=1`

### Caso 1638 · `ev-aleatorio` · punto=6 k=3 semilla=25296

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=17`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 4 → 0 líneas
  - `SEL`: 18 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=11 peso_sufijo=8` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=1`

### Caso 1640 · `ev-aleatorio` · punto=7 k=1 semilla=25278

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=16`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 4 → 0 líneas
  - `SEL`: 11 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=47 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=5` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=1 peso_sufijo=1`

### Caso 1658 · `ev-aleatorio` · punto=7 k=1 semilla=25296

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=17`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 4 → 0 líneas
  - `SEL`: 18 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=11 peso_sufijo=8` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=1`

### Caso 1674 · `ev-aleatorio` · punto=7 k=1 semilla=25312

- Bloque 6 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 0 líneas
  - `SEL`: 16 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=8` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=1 peso_sufijo=1`

### Caso 1676 · `ev-aleatorio` · punto=7 k=1 semilla=25314

- Bloque 7 con defecto(s): cbid.
- Bloque 17 con defecto(s): cbid.
  - `RES bloque=7`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 1 → 0 líneas
  - `SEL`: 10 → 14
  - `GAR` distinto
  - `EST`: `EST emitido=50 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=5` → `EST emitido=32 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4`

### Caso 1685 · `ev-aleatorio` · punto=7 k=1 semilla=25323

- Bloque 10 con defecto(s): cbid.
  - `RES bloque=10`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 1 líneas
  - `SEL`: 19 → 18
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=7` → `EST emitido=50 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=6`

### Caso 1687 · `ev-aleatorio` · punto=7 k=1 semilla=25325

- Bloque 8 con defecto(s): cbid.
  - `RES bloque=8`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1694 · `ev-aleatorio` · punto=7 k=1 semilla=25332

- Bloque 7 con defecto(s): cbid.
- Bloque 13 con defecto(s): cbid.
  - `RES bloque=7`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1697 · `ev-aleatorio` · punto=7 k=1 semilla=25335

- Bloque 11 con defecto(s): cbid.
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 5 → 3 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=6` → `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=6`

### Caso 1705 · `ev-aleatorio` · punto=7 k=1 semilla=25343

- Bloque 7 con defecto(s): cbid.
  - `RES bloque=7`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1710 · `ev-aleatorio` · punto=7 k=1 semilla=25348

- Bloque 5 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 4 → 0 líneas
  - `SEL`: 18 → 7
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=9 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5` → `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=1 peso_sufijo=2`

### Caso 1714 · `ev-aleatorio` · punto=7 k=1 semilla=25352

- Bloque 11 con defecto(s): cbid.
  - `RES bloque=11`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `DESC`: 7 → 6 líneas
  - `SEL`: 16 → 17
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=7` → `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=7`

### Caso 1715 · `ev-aleatorio` · punto=7 k=1 semilla=25353

- Bloque 6 con defecto(s): cbid.
- Bloque 13 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 0 líneas
  - `SEL`: 14 → 18
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=6` → `EST emitido=32 quemado=0 fase=FasePoST terminal=3 altura=2 slot=1 peso_sufijo=4`

### Caso 1718 · `ev-aleatorio` · punto=7 k=1 semilla=25356

- Bloque 9 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 3 → 1 líneas
  - `SEL`: 15 → 8
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=6` → `EST emitido=41 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=4`

### Caso 1723 · `ev-aleatorio` · punto=7 k=1 semilla=25361

- Bloque 5 con defecto(s): cbid.
- Bloque 14 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 5 → 0 líneas
  - `SEL`: 19 → 10
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=7` → `EST emitido=29 quemado=0 fase=FasePoST terminal=3 altura=2 slot=3 peso_sufijo=3`

### Caso 1724 · `ev-aleatorio` · punto=7 k=1 semilla=25362

- Bloque 8 con defecto(s): cbid.
- Bloque 11 con defecto(s): cbid.
  - `RES bloque=8`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1725 · `ev-aleatorio` · punto=7 k=1 semilla=25363

- Bloque 8 con defecto(s): cbid.
  - `RES bloque=8`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 4 líneas
  - `SEL`: 18 → 15
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=64 quemado=0 fase=FasePoST terminal=3 altura=2 slot=11 peso_sufijo=8` → `EST emitido=49 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=7`

### Caso 1727 · `ev-aleatorio` · punto=7 k=1 semilla=25365

- Bloque 6 con defecto(s): cbid.
- Bloque 12 con defecto(s): cbid.
- Bloque 17 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 0 líneas
  - `SEL`: 19 → 14
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=0 fase=FasePoST terminal=3 altura=2 slot=9 peso_sufijo=6` → `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=4`

### Caso 1732 · `ev-aleatorio` · punto=7 k=1 semilla=25370

- Bloque 9 con defecto(s): cbid.
- Bloque 17 con defecto(s): cbid.
  - `RES bloque=9`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `DESC`: 3 → 2 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=38 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4` → `EST emitido=35 quemado=0 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=4`

### Caso 1736 · `ev-aleatorio` · punto=7 k=1 semilla=25374

- Bloque 16 con defecto(s): cbid.
  - `RES bloque=16`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1744 · `ev-aleatorio` · punto=7 k=1 semilla=25382

- Bloque 12 con defecto(s): cbid.
  - `RES bloque=12`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 4 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=7` → `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=7`

### Caso 1745 · `ev-aleatorio` · punto=7 k=1 semilla=25383

- Bloque 16 con defecto(s): cbid.
- Bloque 17 con defecto(s): cbid.
  - `RES bloque=17`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 1 → 0 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=41 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=5` → `EST emitido=38 quemado=0 fase=FasePoST terminal=3 altura=2 slot=5 peso_sufijo=5`

### Caso 1764 · `ev-aleatorio` · punto=8 k=3 semilla=25382

- Bloque 12 con defecto(s): cbid.
  - `RES bloque=12`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `DESC`: 6 → 4 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=7` → `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=10 peso_sufijo=7`

### Caso 1765 · `ev-aleatorio` · punto=8 k=3 semilla=25383

- Bloque 16 con defecto(s): cbid.
- Bloque 17 con defecto(s): cbid.
  - `RES bloque=17`: `OK` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1781 · `ev-aleatorio` · punto=8 k=3 semilla=25399

- Bloque 12 con defecto(s): cbid.
  - `RES bloque=12`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1784 · `ev-aleatorio` · punto=8 k=3 semilla=25402

- Bloque 8 con defecto(s): cbid.
  - `RES bloque=8`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

### Caso 1791 · `ev-aleatorio` · punto=8 k=3 semilla=25409

- Bloque 5 con defecto(s): cbid.
- Bloque 14 con defecto(s): cbid.
  - `RES bloque=5`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=6`: `OK` → `ErrSinPadre`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `ErrGarantia` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 1 → 0 líneas
  - `SEL`: 13 → 4
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=53 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=6` → `EST emitido=23 quemado=0 fase=FasePoST terminal=3 altura=2 slot=2 peso_sufijo=1`

### Caso 1815 · `ev-aleatorio` · punto=8 k=3 semilla=25433

- Bloque 14 con defecto(s): cbid.
  - `RES bloque=14`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 8 → 7 líneas
  - `EST`: `EST emitido=67 quemado=51 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5` → `EST emitido=64 quemado=48 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5`

### Caso 1821 · `ev-aleatorio` · punto=8 k=3 semilla=25439

- Bloque 15 con defecto(s): cbid.
  - `RES bloque=15`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `DESC`: 2 → 1 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=37 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=3` → `EST emitido=31 quemado=0 fase=FasePoST terminal=3 altura=2 slot=4 peso_sufijo=3`

### Caso 1839 · `ev-aleatorio` · punto=8 k=3 semilla=25457

- Bloque 17 con defecto(s): cbid.
  - `RES bloque=17`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=59 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5` → `EST emitido=56 quemado=0 fase=FasePoST terminal=3 altura=2 slot=7 peso_sufijo=5`

### Caso 1851 · `ev-aleatorio` · punto=8 k=3 semilla=25469

- Bloque 13 con defecto(s): cbid.
- Bloque 17 con defecto(s): cbid.
  - `RES bloque=13`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=17`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=18`: `OK` → `ErrSinPadre`
  - `RES bloque=19`: `OK` → `ErrSinPadre`
  - `DESC`: 5 → 0 líneas
  - `SEL`: 19 → 16
  - `GAR` distinto
  - `EST`: `EST emitido=65 quemado=9 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=8` → `EST emitido=53 quemado=15 fase=FasePoST terminal=3 altura=2 slot=6 peso_sufijo=6`

### Caso 1854 · `ev-aleatorio` · punto=8 k=3 semilla=25472

- Bloque 6 con defecto(s): cbid.
- Bloque 9 con defecto(s): cbid.
  - `RES bloque=6`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `RES bloque=7`: `OK` → `ErrSinPadre`
  - `RES bloque=8`: `OK` → `ErrSinPadre`
  - `RES bloque=9`: `OK` → `ErrSinPadre`
  - `RES bloque=10`: `OK` → `ErrSinPadre`
  - `RES bloque=11`: `OK` → `ErrSinPadre`
  - `RES bloque=12`: `OK` → `ErrSinPadre`
  - `RES bloque=13`: `OK` → `ErrSinPadre`
  - `RES bloque=14`: `OK` → `ErrSinPadre`
  - `RES bloque=15`: `OK` → `ErrSinPadre`
  - `RES bloque=16`: `OK` → `ErrSinPadre`
  - `RES bloque=17`: `OK` → `ErrSinPadre`
  - `RES bloque=18`: `ErrGarantia` → `ErrSinPadre`
  - `DESC`: 7 → 0 líneas
  - `SEL`: 13 → 5
  - `UTXO` distinto
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=0 fase=FasePoST terminal=3 altura=2 slot=12 peso_sufijo=9` → `EST emitido=26 quemado=0 fase=FasePoST terminal=3 altura=2 slot=3 peso_sufijo=2`

### Caso 1861 · `ev-aleatorio` · punto=8 k=3 semilla=25479

- Bloque 14 con defecto(s): cbid.
  - `RES bloque=14`: `OK` → `ErrForma(EvidenciaCbidAjeno)`
  - `DESC`: 4 → 3 líneas
  - `GAR` distinto
  - `EST`: `EST emitido=62 quemado=13 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=6` → `EST emitido=59 quemado=13 fase=FasePoST terminal=3 altura=2 slot=8 peso_sufijo=6`

### Caso 1867 · `ev-aleatorio` · punto=8 k=3 semilla=25485

- Bloque 12 con defecto(s): cbid.
  - `RES bloque=12`: `ErrGarantia` → `ErrForma(EvidenciaCbidAjeno)`

