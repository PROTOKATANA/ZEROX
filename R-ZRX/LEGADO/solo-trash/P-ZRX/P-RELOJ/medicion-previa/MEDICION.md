# Medición previa — latencia de AES-128 encadenado en la máquina de referencia

**Medido por Claude el 2026-09-24**, antes de escribir el encargo, para que `P-RELOJ` no
descanse en una cifra ajena. **Es la única magnitud medida de toda la cadena de razonamiento
que abre este encargo**; todo lo demás es derivado o citado.

## Qué se mide y por qué

Una iteración del PoT es **un cifrado AES-128 completo encadenado** — verificado en fuente:
`PDF/autonomys-subspace/crates/subspace-proof-of-time/src/aes.rs:36-46`
(`create_generic`: `cipher.encrypt_block(&mut cur_block)` dentro de dos bucles anidados).
Son 10 rondas dependientes, así que el coste es **latencia**, no rendimiento: no se
paraleliza dentro de una iteración.

`aeslat.c` reproduce exactamente esa dependencia: `x = AES128(rk, x)`, 50 000 000 de veces,
con la salida de cada bloque como entrada del siguiente. Los valores de la clave son
irrelevantes para la latencia; lo que se mide es la cadena de dependencias.

## Resultado `[medido]`

```
bloques AES-128       50 000 000
tiempo                0,3886 s
ns por bloque         7,7716 ns
ns por ronda AESENC   0,7772 ns
```

**Máquina:** Ryzen 9 9950X3D (Zen 5), la misma de `veritas/rendimiento/coste-salto-v1/`.
**Condición declarada:** la máquina **no estaba ociosa** (un proceso Julia al ~48 % de una
CPU). Si eso sesga, sesga hacia arriba: la cifra real en reposo sería igual o menor.

**Comando exacto:**

```bash
gcc -O2 -maes -msse4.1 -o aeslat aeslat.c && ./aeslat
```

## Control: concuerda con la medición previa del repositorio

`research/dag-poas-ancla-de-orden.md:342` mide `prove = 1,561 s/slot` con
200 032 000 iteraciones (Criterion, 100 muestras, IC ±0,07 %), lo que da **7,804 ns** por
iteración. Esta medición da **7,7716 ns**. **Concuerdan al 0,4 %**, por dos caminos
independientes (Criterion sobre el crate de Autonomys frente a un bucle en C con
intrínsecos). La cifra de 1,561 s queda **confirmada**.

## Descomposición de la brecha con el 14900KS `[derivado]`

| | ns/bloque | ciclos/bloque | ciclos/ronda | frecuencia implícita |
|---|---:|---:|---:|---:|
| 14900KS `[citado]` | 4,841 | 30 | 3 | 6,196 GHz |
| Esta máquina `[medido]` | 7,772 | 40 | 4 | 5,147 GHz |

- **Latencia:** 40/30 = **1,333×**
- **Frecuencia:** 6,196/5,147 = **1,204×**
- **Producto: 1,605×**, que es la brecha observada.

**Etiqueta honesta:** los 4,841 ns del 14900KS **no están medidos por nosotros**. Salen de
dividir 1 s entre 206 557 520, y ese «1 s» es un **comentario** en
`PDF/autonomys-subspace/crates/subspace-node/src/chain_spec.rs:129`
(*«About 1s on 6.2 GHz Raptor Lake CPU (14900KS)»*), no una medición publicada. La fila de
esa tabla es `[citado]`, no `[medido]`; la asignación de 3 y 4 ciclos por ronda es
`[derivado]` de que los ciclos salgan enteros a las frecuencias nominales, y **está sin
confirmar contra documentación de arquitectura**.

**Consecuencia que el encargo debe tomar en serio:** si el tercio de latencia es
arquitectural, es **independiente de la frecuencia** y no se compra con un AMD mejor. Eso
convertiría la elección de fabricante en un suelo de `ρ`. **Confirmarlo o romperlo es
trabajo de `P-RELOJ` §4.1.**
