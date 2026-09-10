# Ronda 15A — Avalanche/Snowball sobre peso de espacio: ¿finalidad rápida sin comité?

**Lee primero:** `research/scripts/METODO-AGENTES.md`. **Restricción vinculante de Katana
(2026-09-10):** sin comités de decisión; descentralización y seguridad. **Prioridad:** bajar el
tiempo de irreversibilidad lo más posible. El cliente ligero es secundario.

**Punto de partida (auditado).** D8b estableció que Avalanche **no es un comité**: su muestreo es
abierto y el Sybil-resistance es *pluggable* (`arXiv:1906.08936:271-273, :318-319`). Los 2.000 AVAX
son requisito de despliegue, no del protocolo. La ronda 14C lo excluyó por el motivo equivocado.
Queda como el único candidato no-comité con latencia sub-segundo en la literatura (1,35 s medidos).

**Preguntas que decide la ronda.**
1. **¿De dónde se muestrea sin registro?** El espacio no tiene censo. Opciones a evaluar:
   (a) los productores de bloque recientes (sus firmas de recompensa dan claves con evidencia de
   espacio); (b) la red P2P (Sybil-abordable); (c) los bloques/soluciones recientes del DAG;
   (d) pruebas de almacenamiento archivado (KZG). Para cada una: ¿es un comité fijo disfrazado?
   ¿resiste Sybil? ¿cuánta evidencia de espacio da por muestra?
2. **Peso sin tabla.** ¿Cómo se pondera el espacio sin una tabla de poder? ¿Por soluciones en una
   ventana (trabajo reciente) o por almacenamiento archivado (más caro de falsificar)?
3. **Seguridad y viveza de Snowball/Snowman** con `α=0,33` y `Δ` sin medir: umbral de sondeo,
   metastabilidad, ataques dirigidos al muestreo, retardo de red. Fuente: Snowball
   (`arXiv:1906.08936`), docs de Avalanche, y literatura de ataques (si la hay).
4. **Latencia en ZEROX:** modelo de rondas de sondeo con `λ=1`, `Δ ∈ {1,4,16,20}`; ¿cuánto tarda
   la irreversibilidad probabilística y con qué ε? ¿Y el gossip que exige?
5. **Composición:** ¿sustituye al fork choice de GHOSTDAG o es una capa encima? ¿Qué mensaje nuevo
   exige y a qué coste? ¿Convive con R-FIN-7 y `C-REORG-07`?
6. **¿Cae bajo la prohibición de comité?** Responde explícitamente con la definición de Katana.

**Fuentes.** El paper de Snowball y docs de Avalanche pueden estar en
`research/scripts/d14-sin-comite/fuentes/`; si no, usa webfetch (`arXiv:1906.08936`,
`docs.avax.network`). Kaspa y el DAG: `research/dag-poas-ancla-de-orden.md` (no editar),
`research/fuentes/phantom-ghostdag.txt`.

**Entregable:** `research/scripts/d15-avalanche/informe.md` en español, con tabla (latencia,
¿comité?, ¿dinero?, Sybil, supuestos, coste, fuente), etiquetas DEMOSTRADO/VERIFICADO/PLAUSIBLE/
REFUTADO/LAGUNA, `## Veredicto` y `## Errores propios`. Si no se puede muestrear sin comité ni
Sybil sin dinero, dilo con la prueba y cierra la vía.
