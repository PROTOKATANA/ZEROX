# PROPUESTA — PRV-v0.1

**Propuesta, no SPEC.** Nada de aquí es texto normativo. El SPEC lo redacta Claude.

## P1. El IBD sin confianza no se resuelve con una prueba de validez

La conclusión de §1 del INFORME es que ninguna prueba que sólo acredite **validez de una historia**
decide la cadena canónica de GHOSTDAG, porque ésta depende del conjunto de ramas. La propuesta es
**no presentar la prueba recursiva como solución a (2) del encargo 05**. Si se implanta, que sea
por lo que sí da: verificación barata de transiciones **desde un ancla confiable**.

## P2. Lo que sí cabe hoy: recursión sobre el checkpoint

Combinar la infraestructura prevista —checkpoint firmado del periodo frágil (§12.1, C-CHK)— con una
prueba recursiva de las transiciones **a partir** del checkpoint:

- el nodo nuevo confía en el checkpoint (un firmante, clave destruida tras emitirlo);
- verifica con la prueba recursiva que la cadena desde el checkpoint es válida y su `blue_work`;
- obtiene los datos de archivales o de la red.

**No es «sin confiar en nadie»** y debe decirse con esas palabras. Es la única vía que el SPEC ya
admite y que no requiere resolver la selección.

## P3. Dependencia dura: estado UTXO y compromiso de estado

Sin el estado UTXO con datos de deshacer (TAREAS §2.6, **hoy no existe**) no hay input público de
estado que la prueba comprometa, y sin un compromiso verificable (raíz de UTXO o acumulador) la
prueba no tiene qué atestar. **Recomendación:** no emprender un circuito de consenso recursivo antes
de cerrar TAREAS §2.6. Ya lo avisaba `PROPUESTA.md` P3.3 del encargo 05.

## P4. Si se explora el coste: los dos mandos, sin fijarlos

El coste medido va como `M · W · log W` (M = mergeset, W = profundidad de fusión, C-GD-11). Cerrar
a 1 bloque/s exige elegir entre:

1. **ventana pequeña** (`W*` de §2.2: ~512 con M medido, ~8 con M saturado, Halo2 realista);
2. **probador mucho más rápido** (entre `10²` y `10⁵`×);
3. **tasa objetivo menor** (`10⁻²–10⁻³` bloq/s).

Ninguna de las tres se elige aquí. Se entregan como funciones de `W` para que Katana/Claude
decidan. **No fijar `W`** ni derivarlo de `F = 2 h`.

## P5. Lo que NO proponer

- No reabrir §6.1 ni añadir `parents_by_level`: PPP-v0.1 ya demostró que el problema es el anclaje,
  no el formato (§4 de su INFORME). La prueba recursiva no cambia eso.
- No presentar `orchard` en el árbol como recursión disponible (§4 del INFORME): falta el
  verificador en circuito y un sistema PCD/IVC.
- No sustituir la verificación de la justificación PoT ni el estado UTXO por «la prueba ya lo
  acredita»: la prueba acredita lo que el circuito incluya, y eso no está construido.
