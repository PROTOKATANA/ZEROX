# VRC-v0.1 — contrato estructural de ventana y retarget causal

Fecha: 2026-09-11. Estado: **candidato de evaluación, no activado en consenso**.
No fija `W_adm`, `W`, `G`, rango inicial, límites ni fórmula económica del retarget.

## Variables y unidades

| Variable | Definición | Unidad/estado | Fuente |
|---|---|---|---|
| `s_B` | slot PoT original | `UInt64`, derivado | SPEC §7; CBE-09 |
| `s_C` | slot del contexto de incorporación | `UInt64`, derivado | CBE-06/09 |
| `W_adm` | anchura deslizante de L0 | slots, pendiente | CBE-06 |
| `J_j=[u_j,u_j+W)` | cohorte del controlador | slots, `W>0`, pendiente | este candidato |
| `G` | gracia causal; `c_j=u_j+W+G` | slots, pendiente | este candidato |
| `EventId` | `(context_id, block_id)` | identificador canónico del modelo | este candidato |
| `N_j` | snapshot de EventId contado al cierre | adjudicaciones, derivado | R-FIN-13′/CBE-11 |

`origin=0` es una elección estructural del instrumento para evitar eventos sin cohorte, no
un nuevo parámetro adoptado. Los context IDs son opacos: nunca se ordenan numéricamente.

## Reglas ensayadas

- DA0: todo bloque nuevo pendiente suspende el lote, aunque fuese perdedor o tardío.
- P0 elige el menor rank elegible por identidad; P1 prefiere azul dentro del lote y luego rank.
- Azul y `rojo_k` participan; `rojo_U3` no. Una identidad conserva un único slot original.
- L0 es literalmente CBE-06: `max(0,s_C-W_adm) <= s_B <= s_C`.
- LG es **nuevo y sólo comparador**: `s_B∈J_j` y `s_C<c_j`. En `c_j` se cierra primero
  y se incorpora después, por lo que no existe empate dependiente de llegada.
- Mientras su cohorte no esté sellada, el evento ganador paga, cuenta y ejecuta como una unidad,
  incluso con subsidio/comisiones cero. LG excluye después del corte; L0 puro conserva abajo el
  contraejemplo donde un pago posterior ya no puede entrar en el snapshot sellado sin retroactividad.
  Un cuerpo que su política clasifica como tardío queda validado y visto, pero no crea evento.
- Antes de `c_j` el controlador permanece en Bootstrap. Un candidato DA0 pendiente produce
  `ControllerPending`, nunca un conteo cero. Desde `c_j`, la ventana se sella una sola vez.
- Reconsultar una ventana sellada devuelve su snapshot inmutable. Una salida del controlador
  sólo podrá activar después; no existe fórmula de rango en VRC-v0.1.
- Undo exige el contexto exacto y revierte eventos, índices, bloques y sellos creados por ese
  contexto. Dos contextos con igual slot siguen siendo distintos.

## Hallazgo discreto sobre L0

L0 puro puede pagar después de que la cohorte del slot original ya se haya sellado. El fixture
`l0_postcierre_diverge` conserva el pago y el snapshot anterior, mostrando
`counted_ids != payable_ids`; no redefine L0 ni retroactualiza el retarget.

Para slots enteros, si el último slot de `J_j` es `u_j+W-1`, una incorporación L0 oportuna
llega como máximo en `u_j+W-1+W_adm`. La condición

```text
G >= W_adm
```

es suficiente para que llegue estrictamente antes de `c_j=u_j+W+G`. No se afirma necesidad
universal ni se elige valor alguno.

## Adversario y criterios

El futuro modelo económico debe incluir retención/liberación selectiva, copias y pruebas PoS
alternativas, elección de padres/fusiones, saturación del nodo, `Delta`, particiones y DA0.
VRC acepta estructuralmente si referencia/kernel coinciden, P0/P1 no dependen de llegada,
Pending no se vuelve cero, cierres son causales e inmutables y undo es exacto. Falla cualquier
violación. Esto no acredita ausencia de sesgo: la producción retenida no es observable on-chain.
