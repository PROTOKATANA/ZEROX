# DMS-v0.1 — contrato de Δ medida en simulación

**ID:** `DMS-v0.1` (propuesto aquí; «Δ medida en simulación», siguiendo el estilo DCM-v0.1 /
RCE-v0.1 del repo). **Fecha:** 2026-09-13. **Revisión del instrumento:** 2 (enmendado
2026-09-13, `ENMIENDA-R2.md`). **Estado:** **medición en simulación; no activado en
consenso.** Ninguna cifra de este instrumento es parámetro de producción ni regla: no se
adopta Δ, ancho de banda ni tamaño alguno de aquí.

## Qué mide

Δ_q(b): tiempo desde la creación del bloque b hasta que una fracción q ∈ {50, 90, 99, 100}
de los nodos (rango entero ⌈q·n/100⌉) lo ha recibido íntegro, en un modelo de inundación
honesta hop-by-hop sobre redes sintéticas (regular d=8 y G(n,p)), N ∈ {100, 1000, 10000},
latencias lognormales por arista (mediana 80 ms, p99 500 ms), cola serial por nodo,
t_tx = 8·tam/ancho, λ=1/s, T=600 s, 12 réplicas por combo. Además (r2): media de llegada por
bloque, media por nodo, Δ̄ ponderada por producción bajo reparto uniforme y bajo la hipótesis
H de concentración («10 % de los nodos, 50 % del espacio»; cuotas enteras 9/1; la cuota
gobierna el sorteo del creador y el peso del observador), ρ = λ·d·t_tx y régimen por combo.

## Qué NO mide (límites del contrato)

- No hay relé compacto (R-NET-01): el modelo reenvía el objeto completo a los 8 vecinos en
  serie; el SPEC exige cabecera + IDs cortos. Sesgo declarado, no corregido en r2.
- No hay validación antes de retransmitir (C-NET-12, C-NET-06): t_proc = 0 en el caso base
  (cota inferior); la sensibilidad t_proc = 0,1 s es una cota superior de una opción
  descartada en Q4. El coste real por salto sale de un banco en hardware.
- No hay canal de reenvío de transacciones ni mempool (la «segunda Δ» es v2a, Q5).
- No hay adversario, churn, pérdida de paquetes ni colas de recepción.
- No es el argumento de seguridad: ese es δ₀ medido (Q3). El provisional publicado aquí es
  Δ_99 en su p99, con su etiqueta obligatoria.
- Ninguna medida es MR (no existe red ZEROX).

## Variables

| Variable | Unidad | Estado |
|---|---|---|
| Δ_q | segundos | **MS** en este modelo; q ∈ {50, 90, 99, 100} |
| Δ̄ uniforme / Δ̄ espacio | segundos | **MS**; descriptivo de tamaño (padres típicos ≈ 1+λ·Δ̄, **D**). Δ̄ espacio usa la regla (i): con sorteo de creadores ∝ cuota es la media simple de las medias ponderadas por observador; el peso por creador (`delta_barra_peso_por_creador`) vale solo con sorteo uniforme |
| ancho de banda | bit/s | **E**: 100 Mbit/s referencia (Q1) y 59,67 sensibilidad; base r1 10 Mbit/s |
| tamaños de objeto | bytes | **D** del presupuesto Q2 (556+32p+128s; anuncio 812+6tx; bloque 812+350tx) |
| ρ = λ·d·t_tx | adimensional | **D**; régimen `estable` (ρ<1) / `saturado` (ρ≥1) |
| t_proc | segundos | 0 (**H**, cota inferior por C-NET-12) o 0,1 (**H**, opción descartada) |
| reparto de espacio | — | uniforme; concentración **H** sin datos reales |
| topología, N, latencia, λ, T | — | **H** de escenario, como en la r1 |

## Reglas del contrato

- La r1 no cambia: re-ejecutar barrido y sensibilidad produce `resumen.csv` idéntico byte a
  byte a la revisión 1, con cualquier número de hilos (verificado 8 y 24).
- Un combo con ρ ≥ 1 queda etiquetado `saturado`: sus cuantiles se guardan y se publican
  como evidencia de cola no estacionaria, **nunca como Δ**.
- Regla (i) de la ponderación: con el sorteo de creadores ∝ cuota, la Δ̄ de concentración es
  la media simple de las medias ponderadas por observador; aplicar además el peso del
  creador contaría la cuota dos veces y queda prohibido.
- Todo cálculo sale de `run.jl` con semilla, versión de Julia y entorno fijados (LINEO);
  tests con `--check-bounds=yes`; equivalencia referencia↔kernel bit a bit.
- **Ninguna cifra es parámetro de producción.**
