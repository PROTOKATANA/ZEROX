# MODELO — PRV-v0.1

## 1. Qué probaría el circuito (modelo de Mina, trasladado a ZEROX)

Una **prueba recursiva** (PCD/IVC, el modelo de Mina con Pickles) prueba, de forma sucinta y
verificable por un tercero, que una secuencia de transiciones es válida:

```
S_0 = génesis
S_{i+1} = F(S_i, B_i)          para i = 0..n−1
```

donde `F` es la **función de transición del consenso**: valida la cabecera y el cuerpo del bloque
`B_i` (solución PoAS, KZG, sello Ed25519, PoT, rango contextual) y actualiza el estado —el DAG de
GHOSTDAG (§11: mergeset, coloreo k-cluster, U2/U3″, `blue_score`, `blue_work` en `u256`) y el
conjunto UTXO—. El input público típico es `(génesis, compromiso de estado final, blue_work)`.

El instrumento **no** implementa `F` ni el circuito. Cuenta las operaciones de la parte GHOSTDAG
de `F` y las traduce a restricciones. La parte criptográfica (KZG, Ed25519, PoT) queda **fuera de
la cota**, porque sólo puede aumentarla.

## 2. Validez frente a selección (el objeto del §2)

- **Validez**: la relación `Válida(génesis, B_0..B_{n−1})` es cierta. Es una propiedad de **una
  historia**.
- **Selección**: la cadena canónica de ZEROX no es una propiedad de una historia aislada. En
  GHOSTDAG es la cadena seleccionada de la **punta virtual**, que es la punta de **mayor
  `blue_work`** entre TODAS las puntas del DAG (§11, C-GD-03, C-GD-08). Es una propiedad del
  **conjunto** de historias publicadas.

El instrumento instancia ambas con el oráculo GDR-v0.2: `virtual_sp` da la punta canónica y
`gd[v].bw` su `blue_work`.

## 3. Adversario

Adversario estándar de un sistema de prueba de validez, más:

1. **Retiene ramas privadas válidas** y elige cuándo publicarlas (el ataque de *long-range fork* y
   el de rama privada del §3.5).
2. Conoce el verificador y puede **producir pruebas de validez correctas de sus ramas**.
3. No rompe el sistema de prueba, las firmas ni los compromisos (supuestos criptográficos
   estándar: sonido de la prueba, binding de los compromisos, resistencia a colisiones de
   Poseidon).

No se le concede minar `blue_work` de la nada: `blue_work` se computa sobre bloques válidos. Pero
**sí** hereda de PPP-v0.1 (`DERIVACIONES.md` D6, `INFORME.md` §1.2) que el recurso de un billete no
está ligado a una historia: el mismo espacio-tiempo puede respaldar varias ramas (doble uso), y
`blue_work` declarado en cabecera es gratis (ATAQUE 8). Eso debilita la cota de recursos de
cualquier regla de selección por «más `blue_work` observado», y es la parte que **no** arregla la
recursión.

## 4. Qué es una prueba «de validez» para esta auditoría

El verificador `verifica_prueba_validez` recibe una `PruebaValidez`, que contiene una `Historia`
(DAG + punta canónica declarada + `blue_work`), y comprueba que la historia es internamente
consistente y que su punta declarada es la canónica **de esa historia**. Es el máximo que puede
comprobar sin el DAG. El teorema de imposibilidad (§1 del INFORME) muestra que ningún verificador
así decide la canónica del **conjunto**.

Un objeto más fuerte —una prueba que además atestigüe que el conjunto de bloques es **completo**—
no es una prueba de validez: es una afirmación de **disponibilidad de datos**, y exige o bien
confiar en el probador, o bien que el nodo reciba todos los bloques (y entonces ya tiene el DAG
cerca de la punta).

## 5. Modelo de coste

Por bloque de cadena, con `M = |mergeset|`, `W` = profundidad de fusión (ventana; constante
PENDIENTE, C-GD-11) y contexto azul acotado por `W`:

```
restr/bloque ≈ M · W · ceil(log2(W+1)) · 80 · gates_por_sbox      (cota inferior)
```

- `80` = S-boxes por permutación Poseidon P128Pow5T3 (`R_F=8`, `R_P=56`, ancho 3) — **CITADO**
  (`halo2_poseidon` 0.1.0, `p128pow5t3.rs`; es lo que usa Orchard, `SPEC.md` §9).
- `ceil(log2(W+1))` hashes por decisión de ancestría (ruta de Merkle/intervalo).
- `gates_por_sbox ∈ {2,4}` y las tasas de operaciones de campo — **DECLARADAS**, con rango.
- Se excluyen Ed25519, KZG, PoT y UTXO.

El tiempo del probador es `≥ restr / ops_campo` (Halo2 hace Ω(n) operaciones de campo para n
filas; `halo2` Book, «Proving system»). La **ventana crítica** `W*` es la mayor `W` que cierra a
1 bloque/s con una tasa y un `M` dados.

## 6. Supuestos y límites

1. GHOSTDAG y su oráculo son GDR-v0.2; el modelo de coste del coloreo es el de la **definición**
   (par por candidato×azul). Una implementación incremental reduce constantes, no el orden en `W`.
2. El PoT y la inyección no se modelan; sus fallos (ATAQUE 1–2 de `research/dag-poas-auditoria.md`)
   se citan como supuestos, no se reabren.
3. La tasa de operaciones de campo es declarada, no medida en esta máquina.
4. No se fija `W`, `M` ni ninguna constante de producción.
