# Modelo de simulación de Δ — `delta-medido-v1` (revisión 2)

## Objetivo

Medir el retardo de propagación Δ (creación → recepción por una fracción q de los nodos) de
objetos del presupuesto Q2 en una red sintética honesta, y entregar para Q3 las medias de
llegada por bloque y por nodo. No modela GHOSTDAG, PoAS, PoT, mempool ni el protocolo de red
ZEROX (que no existe: TAREAS 1.4). Todo resultado es **MS** sobre este modelo, no MR.

Red estática: grafo regular d=8 o G(n,p) p=8/(n−1), re-muestreado hasta conexión; latencia
lognormal por arista (mediana 80 ms, p99 500 ms), una muestra fija por corrida. Creación
Poisson λ=1/s en [0,T); creador uniforme (o muestreado por cuota de espacio en la hipótesis
de concentración). Propagación: **inundación hop-by-hop** — cada nodo reenvía el objeto
completo a todos sus vecinos una sola vez, al primer recibo, con **cola serial por nodo**
(d transmisiones consecutivas de t_tx = 8·tam/ancho). Procesado por salto t_proc (0 base;
0,1 s en sensibilidad). Δ_q(b) = instante en que ⌈q·n/100⌉ nodos lo han recibido − t_creación.

**Sesgos declarados (y no corregidos en r2):** el modelo reenvía el objeto completo a los 8
vecinos en serie y valida en 0 s; el SPEC exige relé compacto (R-NET-01) y validar antes de
retransmitir (C-NET-12, C-NET-06). No hay canal de reenvío de transacciones ni mempool: la
Δ del anuncio compacto en el techo es optimista salvo la regla de transporte de Q1. La cola
serial entrega las copias tempranas antes que un reparto justo (optimista para Δ_50). El
caso base t_proc=0 sólo vale como cota inferior. La r2 mide objetos de distinto tamaño con
el MISMO modelo de inundación y declara este sesgo; el relé compacto y el adversario son v2a
(TAREAS Q5).

## Hipótesis de reparto de espacio (Q3)

- **Uniforme:** cada nodo crea bloques con igual probabilidad y pesa igual como observador
  (la r1 entera y la rejilla r2). Δ̄ uniforme = media de las medias por bloque.
- **Concentración H (sin datos reales):** «el 10 % de los nodos tiene el 50 % del espacio».
  Cuotas enteras (9, 1) para los nodos 1..n÷10 y el resto: k·9 = (n−k)·1, mitad exacta en
  aritmética entera. La cuota gobierna **a la vez** quién crea cada bloque (sorteo ∝ cuota) y
  el peso de cada observador (media por bloque ponderada). **Regla (i):** con el sorteo ∝
  cuota, cada bloque representa una unidad de producción y la Δ̄ es la media SIMPLE de las
  medias ponderadas por observador; nunca se añade peso por creador (contaría la cuota dos
  veces). La variante con peso por creador (`delta_barra_peso_por_creador`) vale SOLO con
  sorteo uniforme. Declarado como H: no representa el reparto real de espacio de ZEROX, que
  sigue pendiente para δ₀; la hipótesis relevante (espacio correlacionado con la centralidad)
  queda como entrada del v2b.
- **Estadístico de tamaño, no de seguridad:** Δ̄ alimenta «padres típicos ≈ 1 + λ·Δ̄» (D,
  descriptivo). El provisional de seguridad es Δ_99 p99 (etiqueta de TAREAS Q3); el
  argumento de seguridad es δ₀ medido.

## Comparabilidad

- misma semilla maestra 0x5a5a y derivación splitmix64 por (combo, réplica), sin RNG
  compartido; IDs de combo r2 ≥ 1001 (los 1..11 son de la r1);
- dos motores (referencia lineal y kernel con heap) validados **bit a bit** sobre matrices
  de llegada y medias;
- reducción determinista por orden de réplica; percentiles sobre el pool por combo con rango
  entero ⌈q·m/100⌉;
- cada combo publica ρ = λ·d·t_tx y régimen: `estable` (ρ<1) o `saturado` (ρ≥1); **ningún
  combo saturado publica sus cuantiles como Δ** (son evidencia de cola no estacionaria).

## Criterio de terminación

Referencia y kernel idénticos en matrices de llegada y medias; invariantes (conexidad, no
llegar antes de crear, mínimo ≤ media por bloque ≤ Δ_100); tests con `--check-bounds=yes`;
rejilla r2 reproducible (dos ejecuciones idénticas salvo tiempo de pared); la r1 intacta
(barrido y sensibilidad byte a byte). Un combo con ρ≥1 queda etiquetado `saturado` y fuera
de toda tabla de Δ.
