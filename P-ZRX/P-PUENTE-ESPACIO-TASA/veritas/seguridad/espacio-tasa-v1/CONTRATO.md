# CONTRATO — espacio-tasa-v1

Qué mide este instrumento, qué **no** mide, y con qué criterio se acepta cada cifra. Es la parte
que impide que un número se lea como un hallazgo que no es.

## 1 · Alcance

**Entrada:** bytes nominales de parcelas PoAS, un `SR` declarado como escenario, y los mapas de
presencia y chunks codificados que produce el código fijado de Autonomys. **Las tablas PoS, la
codificación de borrado y los hashes son reales; los bytes del registro fuente son sintéticos**
(generados con `blake3` desde la semilla de evaluación, no historia archivada). **No** se materializó
un sector físico completo en disco: los bytes escritos son 8 192 000 B de mapas de presencia.

**Salida:** para cada etapa del puente, el valor con unidad, variable y denominador, más el estado
(`medido`, `derivado`, `condicionado`, `pendiente`). Tabla completa en `INFORME.md` §2 y en
`resultados/CIFRAS.tsv`.

**Sujeto de medida:** un conjunto de 1000 piezas (= `MAX_PIECES_IN_SECTOR`) con la geometría de un
sector: 1 056 896 064 B nominales. No es un sector físico materializado, ni una red, ni un nodo, ni
un bloque.

## 2 · Lo que este instrumento NO puede afirmar

| No se afirma | Por qué |
|---|---|
| Que la cadena demuestre cuántos bytes conserva un granjero | `verify_solution` deriva el `sector_id` de la propia solución y no lo contrasta con nada; la preexistencia «hoy **nada** la acredita» (`P-COBERTURA/INFORME.md` §2.4). |
| Una tasa real de la red ZEROX | La red no existe; `SR` es un escenario y el `reto` no está disponible (`C-POT-03` pendiente). |
| Un umbral de seguridad físico | No se mide el coste de un adversario que regenera piezas tras conocer el reto. **CPU equivalente no son bytes almacenados.** |
| Que el doble farmeo esté resuelto | Se mide la **oportunidad** de dos retos sobre la misma parcela, no su legalidad. El factor compartir/repartir es una **identidad algebraica** (`promedio = compartido/2` para todo par; cociente 2 si `compartido > 0` e **indefinido** si los dos buckets están vacíos — 10 de 2016 pares reales), no una medición ni una caída de umbral. `C-FLU-13/14` y el controlador de rango no están implementados. |
| Pruebas verificadas/slot como cifra | La verificación completa de una solución (compromiso, testigo KZG, firma, puerta contextual) no la ejecuta ninguna ruta de ZEROX. Se mide la prueba **PoS** de una muestra. |
| `blue_work/slot` | Falta `β` (H-BETA, hipótesis declarada, no teorema de GHOSTDAG) y faltan las etapas de admisión y color. Se publica la fórmula condicional. |
| Que las fracciones de bytes, piezas, candidatos y trabajo azul sean la misma | Son magnitudes distintas. `f_bytes_solicitados ≠ f_piezas_efectivas` cuando hay sobrantes; `f_candidatos = f_piezas_efectivas` es una **identidad del modelo** con el mismo `SR`, no una validación experimental. |
| Que el trabajo azul del adversario esté acotado por su fracción de bytes | **FALSO y retirado.** La cuota `R_adv/(R_adv+R_hon)` es la magnitud normalizada; con `f = 0,3`, `β_a = 1`, `β_h = 1/2` vale **6/13 ≈ 0,4615 > 0,3**. Si el denominador es cero, la cuota **no está definida** y se devuelve `nothing`. |
| Que la ocupación por bucket sea constante 1/2 | Medido: varianza **163,1689×** (`/(n−1)`) o **163,1664×** (`/n`) sobre los 65 536 buckets del sector, 9,0668 % de buckets vacíos. El cociente **136,4329** de los 512 retos (que cubren solo 510 buckets distintos) y el **66,0167** del índice de Poisson tienen otra población y otro denominador: no son intercambiables. |
| Que la verificación PoS equivalga a verificar la solución | `is_proof_valid` no comprueba compromiso, testigo KZG, firma, cabecera, PoT ni admisión DAG. Se publica como `pruebas_pos_validas`, y «pruebas verificadas/slot» queda `pendiente` con bloqueo reproducible. |
| Que los 2 016 pares sean observaciones independientes | Se forman con 64 retos únicos. La unidad independiente es el reto; la incertidumbre se da por bootstrap sobre retos y cualquier σ que supusiera pares independientes está retirada. |
| Que un porcentaje de bytes sea el presupuesto físico de un actor sin decir el escenario | Hay **dos** escenarios y dan cuotas distintas: (1) presupuestos independientes, cada actor trunca por su cuenta, denominador `Σ piezas_i` —el principal—; (2) sectores ya ploteados y repartidos, el total se trunca una vez. En (2) la cuota de bytes **no** es un presupuesto independiente y el resto sin asignar no se regala. |
| Que repartir el mismo espacio entre más identidades sea neutro | `Σ⌊bytes_i/s⌋ ≤ ⌊(Σbytes_i)/s⌋` (la pérdida **no** es monótona en `N`; solo se afirma la cota `perdidos ≤ N`). El reparto **conserva todos los bytes**, `Σbytes_i = T`, y el agregado se calcula **desde `T`**. |
| Que «N identidades ⇒ cero espacio efectivo» sea una propiedad del formato | **Retirada como enunciado general.** Vale solo **condicionada** a la hipótesis `piezas_por_sector = 1000` (el **máximo**, no una exigencia: `SectorMetadata.pieces_in_sector` es un `u16`). Contraejemplo: con 1 TiB y 1041 identidades, cada presupuesto de 1 056 207 136 B **sí** admite un sector de 999 piezas (`sector_size(999) = 1 055 839 168 B`), incluso con los 131 116 B de metadata externa. |
| Que `sector_size()` sea el tamaño físico total de un sector | Es el tamaño del **fichero de la parcela**; 131 116 B de metadata (`SectorMetadataChecksummed`) viven fuera y hay que declarar si se cuentan. |
| Que la extrapolación a varios sectores sea válida | La tabla de escala supone **independencia entre sectores**, hipótesis **no medida**. Solo la fila de `S = 1` es `medido`. |

## 3 · Criterio de aceptación por cifra

1. **Contraste con el código fijado.** El orden de bytes, la derivación del bucket, el `rank/select`
   y el predicado se comparan contra valores producidos por el clon. Si discrepa, el programa
   **falla**; no promedia ni avisa.
2. **Dos caminos independientes para el conteo central.** Julia deriva el bucket de cada reto a
   partir del `sector_id` y el reto reales y lee su propia tabla de ocupación; Rust audita la misma
   parcela. Deben coincidir en los 512 retos (`AUDITORIA.tsv`).
3. **Aritmética exacta donde la decisión es discreta.** `A(SR)`, `w(SR)`, la cancelación y la
   paridad se calculan en `BigInt`/`Rational{BigInt}`. `Float64` solo resume muestras.
4. **Cero observado no es probabilidad cero.** Las celdas con `k = 0` se publican con la cota
   superior **exacta** `1 − (1−conf)^{1/n}`.
5. **Nada se etiqueta `medido` sin medición.** Las etapas no observables se marcan `pendiente` o
   `condicionado`; no se sustituyen por `η = 1`, por un `SR` aceptado sin contexto ni por un bloque
   sintético.
6. **Conservación de contadores en cada etapa.** El kernel optimizado y el paralelo deben reproducir
   **exactamente** el oráculo lento, y se comprueba antes de publicar cualquier tiempo.
7. **Presupuesto.** 16 hilos, 8 GiB, 6 GiB de disco, 3 h. Agotarlo produce `inconcluso`, nunca un
   resultado negativo.

## 4 · Frontera de lo que se publica como cifra

* `medido`: sale de una ejecución del oráculo Rust sobre datos reales, o de una muestra de la
  parcela real analizada en Julia. Unidades y denominador explícitos.
* `derivado`: aritmética exacta o estadística sobre lo medido. Se declara la fórmula.
* `condicionado`: fórmula con un símbolo (`β`) cuya medición falta. Se publica la fórmula y el dato
  que falta; **no** se elige un valor cómodo.
* `pendiente`: etapa no implementada en ZEROX. No se estima.

## 5 · Frontera de integración (declarada, no disimulada)

* `zx-node` sigue con **cabecera lineal** de 92 B frente a los 556 B de la base PoAS: nada de este
  instrumento se ejecuta en producción.
* `C-HDR-06` (rango esperado contextual), el controlador de rango, el retarget causal y la red
  **no** están implementados.
* `AlmacGhostdag::admitir` es una **puerta parcial** del rango, **no** validación PoST completa.
* `zx-core::wire_dag::verificar_justificacion_pot` sigue devolviendo `IntegracionPotPendiente`.
* La semilla y `N(s)` del PoT no viajan en los checkpoints del wire, así que el reto real de un slot
  no está disponible.

## 6 · Presupuesto y zona de escritura

Techo declarado en `PRESUPUESTO.md`: **16 hilos, 8 GiB de RAM, 6 GiB de disco, 3 h de pared**, por
debajo de los topes de LINEO (24 hilos, 64 GiB). Consumo real: ≤ 16 hilos, ≤ 2 GiB, 552 MiB de
disco, 90 s de corrida más larga. **Sin resultados inconclusos por presupuesto.**

Zona de escritura: `P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1/`, el único punto
escribible del árbol en esta sesión (el resto de `/home/katana/zeo/ZEROX` está montado de solo
lectura). El clon de Autonomys se usó **solo** como dependencia por ruta y quedó limpio.
