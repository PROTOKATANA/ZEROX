# Ronda 10a (D8, adversarial) — Romper la revelación retardada por VDF, R-FIN-14 (h)

**Lee primero:** `research/scripts/METODO-AGENTES.md` (obligatorio). Luego, en este orden:
`research/dag-poas-bitacora-2026-09-08.md` §0, §2, §11 · `research/dag-poas-ancla-de-orden.md` §2 (R-FIN-1, 1a, 2, 3, 4,
5, 9, 13, 14 — NO editar) · `research/scripts/d9-ronda9c/informe.md` §E (E.1-E.5) y §F ·
`research/dag-poas-ancla-de-orden-auditoria-8c.md` · `research/pot-aes-asic-chacha.md` ·
`research/dag-poas-ancla-de-finalidad.md` §10 (por qué la ronda 7 la descartó) · `research/timelord-redundancia-informe.md`.
Código: `subspace/crates/subspace-core-primitives/src/pot.rs` (`seed_with_entropy`), `sp-consensus-subspace/src/lib.rs`
(inyección), `subspace-proof-of-time/src/{lib.rs,aes.rs,aes/x86_64.rs}`, `sc-proof-of-time/src/source/gossip.rs`.
Precedente: la *infused challenge chain* de Chia en `PDF/chia-blockchain/chia/consensus/` (cómo se deriva, quién la calcula,
cómo se verifica, qué pasa si falta). Cita fichero y línea.

**Contexto en dos frases.** Con R-FIN-14 el reto de cada slot sale de una cadena AES secuencial; un atacante con reloj
`ρ > 1` puede evaluar `n_eval = ρ·W_dec` slots de cada candidato a ancla (steering). La opción (h) propone
`entropía_j = VDF(chunk(I_j) ‖ salida(I_j), L·iter)` revelada en `t_j = slot(I_j) + L`, de modo que evaluar un candidato
exija calcular un VDF de `L` slots dentro de la ventana `W_dec ≤ 45 s` ⇒ steering 0 salvo `ρ ≥ L/W_dec` (80 con `L = 1 h`).
Números medidos: `prove` 1,561 s/slot y `verify` 96,1 ms/slot en un 9950X3D; `AESENC` 3 ciclos a 6,2 GHz = 1,00 s/slot
en el 14900KS de referencia. Constantes: `S_max = 150 s`, `W_dec ≤ 45 s`, `F = 2 h` provisional (`L = F`),
`I ∈ {300, 851} s`, `k = 30`, `λ = 1/s`, `τ = 1 s`.

## Puntos, en orden

**A · La regla, escrita del todo antes de atacarla.** Fija la definición operativa de (h) con las decisiones que 9c dejó
sin escribir: (1) quién calcula el VDF de revelación (timekeeper) y **cuándo empieza** — ¿un VDF por candidato desde que
aparece, o solo el del ancla decidida tras `W_dec`? (si tras `W_dec`, el timekeeper honesto dispone de `L − W_dec` para
`L·iter`: escribe la condición); (2) cómo se publica (gossip como `PotCheckpoints`, justificación en bloque) y quién
verifica qué; (3) **qué pasa si en `t_j` no hay entropía** (timekeeper lento, caído o particionado) — regla explícita;
(4) cómo se compone con R-FIN-3/4/5 (flujo por partición: dos flujos, dos VDF) y con R-FIN-9 (recalibración de
iteraciones). Entrega el texto de la regla candidata en tu informe, con etiqueta. NO la escribas en la propuesta.

**B · Ataques, cada uno con número o con REFUTADO/LAGUNA.**
1. **Reloj rápido:** ¿es correcta la cota `ρ ≥ L/W_dec`? ¿Puede el atacante elegir candidato **sin** conocer
   `entropía_X` (correlaciones entre `chunk`, `salida(I_j)` y la época; reutilizar VDF de candidatos anteriores; retener
   candidatos y arrancar su VDF antes de publicarlos)? Con `m ≤ 1 + λ·S_max` candidatos, ¿cuántos VDF en paralelo
   necesita y qué compra? Modelo cerrado + simulación si procede (`d9-ronda9c/r9c_lib.py`, `r9c_e1_contraataques.py`).
2. **DoS de verificación:** el atacante publica revelaciones falsas para candidatos; coste honesto `L × 96,1 ms`
   (paralelizable por checkpoints) frente a coste del atacante `L × prove`. Cuantifica con `L ∈ {1 h, 2 h}` y di si la
   asimetría 16× basta o hace falta regla (p. ej. solo se verifica la revelación del ancla de la cadena seleccionada).
3. **Vivacidad:** el timekeeper debe sostener `L/I` cadenas de `L·iter` más la principal. Con `(I, F) ∈ {(851 s, 2 h),
   (300 s, 2 h), (851 s, 1 h)}`: cadenas en vuelo, núcleos de clase 14900KS necesarios, y qué ocurre si el timekeeper
   real va a 1,56 s/slot (esta máquina). Relación con `autonomys/subspace#2141` (el timekeeper más rápido deja obsoletos
   a los demás): ¿empeora?
4. **Partición y `S_max`:** dos lados, dos flujos, dos VDF; al reunirse, R-FIN-5/7. ¿Introduce (h) un vector nuevo
   (p. ej. un lado sin timekeeper con revelación queda muerto aunque tenga espacio)?
5. **Carrera de bloques:** demuestra o refuta que (h) no cambia la frontera de flujo único (instrumento:
   `research/scripts/verif_frontera_vs_F.py`, que reutiliza `d9-ronda9a/r9a_a3_frontera.py`).
6. **El adelanto `L(1 − 1/ρ)` en la cadena común** (con `ρ > 1` el atacante conoce los retos antes que los honestos aunque
   no pueda hacer steering): ¿qué compra? Ráfagas planificadas, retención selectiva. Es la LAGUNA «ráfagas» de 9c; acótala.

**C · Coste, con número:** tabla `(I, F)` → VDF en vuelo, núcleos del timekeeper, fracción de núcleo de verificación por
nodo, bytes por época en justificación, latencia añadida.

**D · Veredicto:** ¿puede (h) ser núcleo del diseño? Etiqueta por punto. Si hay un ataque real, la contramedida más barata.
