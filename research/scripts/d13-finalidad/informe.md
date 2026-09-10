# Ronda 13 · Irreversibilidad: quórum de soluciones, capa P-040 y alternativas

**2026-09-10 · estado: oleada 1 completada y auditada.** Cuatro informes de agentes
(`f0a-clave-plot.md`, `f0b-anti-equivocacion.md`, `f1-p040-latencia.md`,
`f2-alternativas-latencia.md`), dos auditorías independientes (`audita-d9.md`, `audita-d8.md`) y el
instrumento del principal (`verifica_d13.py`, 45 comprobaciones). **Prioridad declarada por Katana:
bajar el tiempo de irreversibilidad lo más posible.** El cliente ligero es secundario (servidores
privados como plan B).

---

## 0 · Instrumentos y método

| Instrumento | Qué hizo | Resultado |
|---|---|---|
| `verifica_d13.py` (principal) | 45 comprobaciones numéricas contra los informes | Todos los PASS correctos; **defecto de cancelación** en `1-(1-p)^N` detectado por D9 y **corregido** con `expm1/log1p` |
| `audita-d9.md` (D9) | Recálculo con mpmath+scipy, re-ejecución de scripts, spot-check de citas | 5 REFUTADAS, 8 COTAS CORREGIDAS, 6 NO DEMOSTRADAS; verificó POA, binomiales, certificado, ploteo y las citas de `hotpow.txt`/FIP-0086/código |
| `audita-d8.md` (D8) | Ataque adversarial a las cuatro conclusiones | F0 sobrevive con alcance recortado; F1 sobrevive con etiqueta corregida; **F2 cae en su forma fuerte**; abre la vía DAGKNIGHT |
| `research/fuentes/fip-0086.md` | FIP-0086 descargado y verificado contra el original | Épocas de 30 s (:39), una instancia por época (:54, :704), `+2` (:183), `Δ=6 s`/`2Δ` (:713, :441), BLS12-381 G2/G1 + BDN (:918-920), <⅓ (:248) |

---

## 1 · Cifras verificadas (lo que se puede usar)

| Magnitud | Valor | Etiqueta |
|---|---|---|
| POA Def. 1 de HotPoW, Bitcoin `k=1` | 0,26424112 | VERIFICADO (mpmath+scipy) |
| POA Def. 1, `k=64` / equivocación libre | 1,2723673e-12 / **0,5166240** | VERIFICADO |
| Umbral de viveza `p ≥ (2/3)/(1−α)` | 66,667 / 88,889 / 95,238 / 99,503 % | DEMOSTRADO + verificado |
| `α` máx. del comité para riesgo anual 1e-6 / 1e-12 | **28,243 % / 27,049 %** | VERIFICADO |
| Parada por instancia a `α=0,33`, `K=4000` | 32,439 % → **340 999 paradas/año** | VERIFICADO |
| Umbral espacio-tiempo con honestos al 80 % | **28,5714 %** | DEMOSTRADO |
| Certificado Ed25519 `K=4000` | 4000·(64+2)+128 = **264 128 B** → **277,65 GB/año** a 30 s | VERIFICADO |
| Certificado BLS agregado `K=4000` | **724 B** → 0,761 GB/año | VERIFICADO |
| Gossip a `K=4000`/30 s | **2,04 TB/año** (1 voto de 484 B); 6,1–8,1 con 3–4 votos | PLAUSIBLE |
| Ploteo | 83,608 s/GiB CPU; 69,363 s/GiB GTX 1070; 64 GiB = **89,2 / 74,0 min** | VERIFICADO (`coste-ploteo-medido.md`) |
| Suelo estructural de confirmación | 100–134 s; `0,56·3k = 50,4 s` (el «60-75» era impreciso) | VERIFICADO / corregido |
| Latencias ajenas | Ethereum 12,8 min; Avalanche 1,35 s; DAGKNIGHT 1,2–12 s (`λ=3,75`, `α=0,2`); GHOSTDAG 70,4 % ≤10 s; Autonomys 100 bloques ≈ 600 s | VERIFICADO |

---

## 2 · F0 · El quórum de soluciones (P-043): muerto como gadget

**Sobrevive la refutación.** Los cuatro ataques de D8 fallan: fragmentar la identidad es gratis
(`identity.rs:117-132`), U2/U3″ y el nullifier son locales a la rama (`ancla-de-orden.md:206-211`;
`f0b:181-189`), y «voto = bloque» es profundidad de confirmación (`f0b:237-255`, DEMOSTRADO).

**La formulación correcta:** no existe anti-equivocación que restaure `2k` **sin pagar uno de cuatro
precios** (D9, corrección del titular de F0b): segundo recurso, registro global, castigo ex-post
sobre activo escaso, o voto = bloque. La variante (e) —puzzle fresco por voto— **sí** restaura la
Def. 1, pero **es HotPoW**, es decir, reintroducir el Proof of Work que ZEROX abandonó el 5-sep.
El castigo de espacio es evadible: el atacante fragmenta en granjas de un sector y solo pierde los
`k` sectores infractores (≈64 GiB, 1,9 % de su cuota en una red de 10 TiB), o cero si los abandona.

**Consecuencia:** la vía quórum de P-043 se cierra con prueba. Lo que **no** cae es P-040: es una
capa BFT y su argumento de seguridad tolera equivocadores hasta ⅓ (D8, alcance recortado).

---

## 3 · F1 · P-040 (F3-style): la latencia real, corregida

**El «~30 s» era un hard-code** heredado de la época de 30 s de Filecoin, no una derivación. El
modelo correcto, con el `+2` de arranque (`fip-0086.md:183`) relativo al último finalizado:

- La instancia que puede incluir un bloque arranca en la época siguiente: espera **0–30 s** (media
  15 s), no 30–60 s. Latencia = `espera + T_cons`.
- `T_cons` = 3–4 entregas BFT: 3–6 s con `Δ=1 s`, **18–54 s con `Δ=6 s`** (el valor inicial del
  FIP). Media ≈ `c/2 + T_cons` = **33–39 s** con `Δ=6 s` y `c=30 s`.
- **El «3-7 s» de F1 es el ínfimo del núcleo BFT, no el suelo de la irreversibilidad** (D9 §3.3,
  REFUTADO como suelo). El FIP admite finalización sub-época (`:938`), pero solo para bloques que
  caen justo antes del arranque de una instancia. **La palanca para bajar la latencia es la
  cadencia.**

**Bajo ataque (`α=0,33`):** la capa se para en el **32,4 %** de instancias (`m=1`), **68,6 %** con
el `m=2,955` medido (**66,9 %** con el `m=2,822` del diseño vivo) y **100 %** con la cota
`m=151`. El «41 %» del paper es `K=1000`/`m=1` (corrección D9). Fallback: R-FIN-7 con `F=2 h`; la
cadena sigue. **Seguridad vs viveza:** el certificado nunca retrocede, pero la irreversibilidad de
30 s se rompe justo cuando importa.

**Requisitos:** BLS12-381 con BDN/PoP (el `blst` ya está por KZG, pero el esquema de agregación
resistente a rogue-key no está en R-FIN-17/20); `p` (encendido honesto) solo afecta a la viveza;
`Δ` sin medir; el comité es público y targeteable (D8).

**Etiqueta:** PLAUSIBLE como mejora del caso normal, **no garantía** al umbral publicado. No escribir
R-FIN-15..22 en el SPEC antes de medir `p` y `Δ` y de decidir la cadencia.

---

## 4 · F2 · Alternativas: la forma fuerte del veredicto cae (D8)

«Por debajo de 30 s solo hay comités y todos exigen dinero o conjunto conocido» es **falso**:

| Mecanismo | ¿Dinero? | ¿Comité? | Latencia | Viabilidad en ZEROX |
|---|---|---|---|---|
| **DAGKNIGHT** | No | No | 1,2–12 s en su simulación; **~12–20 s estimado** a `λ=1`, `α=0,33` | Media: sustituye R-FIN-6; confirmación **por cliente** (`D`), no certificado |
| **Prism** | No (PoW) | No | ∝ `D`, error `exp(-CD)` | Baja-media: rediseña la regla de orden |
| **Algorand BA\*** | No en el protocolo | Sí (peso) | 1 bloque / segundos | Media-alta como motor: sortición **secreta por paso**, ataca la targetabilidad |
| **Simplex** | No | Sí (PKI) | 3 rondas good-case | Media-alta: más simple que GossiPBFT |
| **Cordial Miners** | No | Sí (`n` mineros) | 3 rondas | Media como motor BFT |
| **Mysticeti-C / Shoal++** | No en el núcleo | Sí (validadores) | 3 rondas / 4,5 intercambios | Baja: exigen DAG por validador |
| **VDF anclado al PoT** | No | No | Suelo `I ≥ ρ_max·W_dec ≈ 112,5 s` | Baja para latencia; red determinista si el timelord se profesionaliza |

**Lectura:** los BFT no «exigen dinero»; exigen **peso Sybil-resistente**, y el espacio lo da. El
problema real de todos es la **tabla** (targetabilidad, arranque, recuperación). DAGKNIGHT es el
único que ataca el suelo de 100–134 s **sin comité, sin dinero y sin confianza nueva**, a cambio de
ser probabilista y por cliente.

---

## 5 · Correcciones de esta ronda (D9)

| # | Afirmación | Corrección | Etiqueta |
|---|---|---|---|
| 1 | F1: «3-7 s es el suelo del protocolo» | Es el ínfimo del núcleo BFT; el suelo end-to-end es `c/2 + T_cons` de media | REFUTADO como suelo |
| 2 | F1: «F3 real: espera 30-60 s» | Espera 0–30 s (el `+2` es relativo al último finalizado) | COTA CORREGIDA |
| 3 | F1: «69,2 % con `m=2,955`» | 68,6 % exacto; 66,9 % con `m=2,822`; 69,2 % es `ceil(m)` | COTA CORREGIDA |
| 4 | F2: hereda el «41 %» | Es `K=1000`/`m=1`; el diseño para 32,4 / 68,6 / 100 % | REFUTADO el etiquetado |
| 5 | F2: stake de Avalanche «$1.689 M» | $1.680,7 M hoy; el 46,6 % es correcto | COTA CORREGIDA |
| 6 | F0b: «no existe anti-equivocación sin dinero» | Existe la variante (e), pero es reintroducir PoW; correcto es «sin pagar uno de cuatro precios» | TITULAR CORREGIDO |
| 7 | Gossip «~3,5 TB/año» | 2,04 TB (1 voto de 484 B); 6,1–8,1 (3–4 votos); no inflado, pero el tamaño de mensaje no está medido | PLAUSIBLE |
| 8 | «`0,56·3k` ⇒ 60-75 s» | `0,56·90 = 50,4 s`; el 60-75 venía de aplicarlo a 100-134 s | COTA IMPRECISA heredada |
| 9 | Propuesta `capa-finalidad.md:170`: fila «K=4000 = 237 728 B» | Es `K=3600`; para `K=4000` son 264 128 B / 277,65 GB | REFUTADO el etiquetado |
| 10 | `verifica_d13.py`: `1-(1-p)^N` | Inestable por cancelación; corregido con `expm1/log1p` | ERROR PROPIO del principal |

---

## 6 · Lo que abre esta ronda: dos vías para bajar la irreversibilidad

**Vía A · Confirmación adaptativa tipo DAGKNIGHT sobre el DAG de PoAS.** Único candidato sin
comité, sin dinero y sin confianza nueva. Ataca el suelo de 100–134 s. Estimación de orden a
`λ=1`, `α=0,33`: **~12–20 s** (D8 §5; no medido). Coste: sustituir R-FIN-6, re-derivar el suelo de
`3k`, la frontera de flujo único, R-FIN-7/`F`, y la convivencia con R-FIN-5 y R-FIN-14. Riesgo: la
confirmación es por cliente (`D`), no un certificado de protocolo.

**Vía B · Capa de comité con instancias continuas.** El FIP permite finalizar dentro de la época
(`:938`); el acoplamiento a 30 s es una elección de Filecoin, no una necesidad. Con instancias
cada 1–5 s y motores más simples (Simplex, BA\*, Cordial Miners) sobre la tabla derivada del
espacio, la latencia normal podría quedar en **~6–10 s**, manteniendo el umbral ⅓ y sin dinero.
Coste: diseñar la cadencia, la semilla por instancia y la renovación de la tabla; el comité sigue
siendo targeteable y la recuperación bajo ataque sigue siendo el punto débil.

**Vía C (reserva) · Finalidad determinista anclada al VDF.** Suelo `≈112,5 s` con `ρ_max=2,5`;
exige dar autoridad al timelord. No sirve para latencia; sí como red de seguridad.

---

## Veredicto

| Punto | Conclusión | Etiqueta | Número |
|---|---|---|---|
| F0 · quórum (P-043) | Muerto como gadget sin dinero; el castigo de espacio es evadible | REFUTADO | POA 0,5166 con cualquier `k`; evasión ≈ 64 GiB o 0 |
| F0 · P-040 | No lo alcanza: tolera equivocadores hasta ⅓ | DEMOSTRADO | — |
| F1 · latencia normal | 0–30 s de espera + `T_cons`; media 33–39 s a `Δ=6 s` | VERIFICADO / corregido | `c/2 + T_cons` |
| F1 · bajo ataque | Se para 32,4 / 68,6 / 100 % según `m`; fallback 2 h | VERIFICADO | 340 999 paradas/año |
| F1 · garantía | Mejora del caso normal, no del umbral | PLAUSIBLE | `α ≤ 28,2 %` anual 1e-6 |
| F2 · alternativas | Cae «solo comités con dinero»: DAGKNIGHT/Prism sin ninguno | REFUTADO | 12–20 s estimado |
| Prioridad · vías | A (DAGKNIGHT) y B (instancias continuas) atacan la latencia; C es reserva | PLAUSIBLE | — |

## Errores propios

1. El instrumento del principal tenía el defecto de cancelación que señaló D9; corregido y
   re-ejecutado.
2. La oleada 1 se escribió sin auditar; el 3-7 s, el 41 % y el «no existe» de F0b eran titulares
   que D9/D8 corrigieron. Quedan registrados arriba.

## Lo que NO se pudo verificar

- `Δ` real de ZEROX (E1 del catálogo): sin `zx-node` con DAG en red.
- `p` real del granjero doméstico y `m` real (2,955 vs 2,822): discrepan entre fuentes.
- La estimación 12–20 s de DAGKNIGHT a `λ=1`, `α=0,33`: cuenta de orden, no simulación.
- El tamaño real del mensaje GossiPBFT (el gossip de 3,5 TB depende de él).

---

## 7 · Decisión de Katana (2026-09-10): sin comités de decisión

**Restricción nueva y vinculante: se descarta toda opción que implique un comité central que tome
decisiones.** Se busca descentralización y seguridad. Consecuencias inmediatas sobre esta ronda:

| Opción | Estado tras la restricción |
|---|---|
| **P-040 / capa estilo F3** (R-FIN-15..22) | **DESCARTADA**: es un comité derivado del espacio, aunque no haya dinero. Toda la ronda 14B (`d14-instancia/`) queda como documentación del coste, no como camino. |
| Motores BFT (GossiPBFT, Simplex, BA\*, Cordial Miners) | **DESCARTADOS**: todos deciden en comité. |
| **Quórum de soluciones** (P-043) | Ya muerto por d13 (equivocación + castigo de espacio evadible). Sin cambios. |
| **Confirmación adaptativa tipo DAGKNIGHT** (ronda 14A) | **ÚNICA VÍA VIVA** para bajar la irreversibilidad sin comité, sin dinero y sin confianza nueva. Probabilista y por cliente. |
| Baseline GHOSTDAG (R-FIN-7, 100–134 s) | Viva; es el suelo actual. |
| Avalanche / submuestreo sobre peso de espacio | Sin comité fijo, pero sin estudiar con fuente primaria; queda como pregunta abierta. |
| Prism (líderless, PoW) | Sin comité; adaptación a espacio sin estudiar. |
| Finalidad anclada al VDF | **En cuestión**: el timelord es un operador (ZEROX), y el suelo es ≈112,5 s; choca con descentralización salvo redundancia. |

**La consecuencia para la prioridad:** sin comité, el mínimo de irreversibilidad no lo da una capa
de finalidad determinista, sino la **regla de confirmación del propio DAG**. El resultado de 14A
(8–56 s a `α=0,33` para `ε=0,05…1e-12`, frente a 100–146 s del baseline) es, hoy, el mejor número
disponible; su punto débil está declarado (manipulación del `k*` con retención si `Δ ≥ 16 s`).
