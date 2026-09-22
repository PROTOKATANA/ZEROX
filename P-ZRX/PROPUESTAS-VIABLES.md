# Propuestas viables — tablero de avance hacia el SPEC

**Abierto:** 2026-09-21 · **Mantiene:** Claude · **Decide:** Katana · **Ejecutan:** los encargos de
`P-ZRX/`. Este fichero es el **tablero de trabajo**: qué propuestas siguen vivas, qué problema resuelve
cada una, en qué fase está y qué le falta **exactamente** para pasar a la siguiente.

**Sólo entran propuestas vivas.** Lo refutado con números no se lista aquí: está en
`P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §1 y en los informes de cada encargo, que es donde debe quedar
para que nadie lo reabra sin leer por qué cayó.

## Cómo se lee

| Fase | Significa |
|---:|---|
| **F0** | Idea con argumento. Nadie la ha comprobado |
| **F1** | Comprobada en su alcance: existe un informe **validado por Claude** que dice qué cierra y qué no |
| **F2** | Prototipada fuera del SPEC, con coste medido (bytes, CPU, estado por nodo) |
| **F3** | Redactada como regla y decidida por Katana → entra en `SPEC.md` |
| **F4** | Implementada y con tests |

**Regla de avance:** nada sube de fase sin que Claude lo valide, y **nada llega a F3 con un parámetro
inventado** (`AGENTS.md`: «una regla pendiente no se implementa inventando un número»).

---

## El tablero

| # | Propuesta | Problema que resuelve | Fase | Qué le falta para subir |
|---:|---|---|:---:|---|
| **1** | ~~Identidad de billete por pieza~~ **REBAJADA** (ver bitácora 2026-09-21) | El mismo que (7). **Pero `P-ZRX/P-IDENTIDAD/` midió que dentro de una historia las tres identidades particionan IGUAL**: un reto fija un solo s-bucket y cada pieza aporta a lo sumo un chunk en él (verificado en el código fijado), luego el beneficio se reduce a ramas con flujos divergentes y a ≈0,6 % de los casos con `pieces_in_sector = 1000` | **F1 (tope)** | **Nada la sube tal cual.** Rompe el invariante de no-equivocación de `C-FLU-12` (bajo A es teorema) y abre invalidación en cascada que `C-GD-10` no descarta (64,8 % de bloques no válidos con equivocación total, frente a 0,40 % con A). Solo volvería si se rediseña con esos dos costes resueltos |
| **2** | **Cablear las reglas de flujo** `C-FLU-13/14` | Multistream: `S` flujos simultáneos hundían el umbral a `1/(S+1)` | **F3→F4** | **Sólo código.** Decidido y redactado. Aviso: los instrumentos **declaran** el flujo en vez de derivarlo de `past(B)`, así que la regla está redactada pero **no validada** |
| **3** | **Controlador de rango anclado al flujo canónico** (P1–P3 para R-FIN-13′) | Una rama privada elige bloques escasos y pesados y multiplica su probabilidad de ganar con el mismo trabajo medio | **F2→F3** | **ENTREGADO y validado**: `P-ZRX/P-RANGO/propuesta/PROPUESTA-SPEC.md` con `C-RET-01…C-RET-11`. La clave es medir la ventana en **índices de slot absolutos**, no en bloques: una rama privada que produce poco **no ensancha** su ventana. Falta que Katana lo traslade al SPEC y fijar los valores (`W`, `G`, `Q`, `γ`, `SR_MIN/MAX`) |
| **4** | **Segundo VDF** (revelación retardada, R-FIN-14(h)) | Cualquier ventaja de reloj da ≈`L` slots de retos conocidos por adelantado, y permite manipular el ancla | **F1→F2** | Decidir `ρ_max`; derivar `PRESUP_NODO` con (h) dentro y tratar el vector de partición; reejecutar `P-ZRX/P-REVELACION/` |
| **5** | **Puente espacio → tasa** | **Ninguna cifra de umbral del repositorio significa lo que dice**: todos los instrumentos miden oportunidades por slot, no fracciones de disco | **F0** | Un encargo que lo derive de las reglas reales de PoAS. **Sin encargo escrito** |
| **6** | **Registro de parcelas con maduración** | Nada ata unos bytes a un momento: de ahí el sembrador y el alquiler por horas | **F0** | **Bloqueada**: no existe prueba de que un compromiso cubra todos los bytes de una parcela Autonomys. Requiere encargo criptográfico |
| **7** | **Castigo por doble firma + recompensa retenida, ligada a la CLAVE** (no al lote) | Una parcela farmea la rama pública y la privada a la vez y suma peso al atacante | **F1 (tope)** | **ENTREGADO 2026-09-22: NO disuade.** El atacante cruza la deriva comprando solo claves de saldo casi cero (67,5 % del espacio con la distribución declarada), **con soborno cero**, y las claves nuevas no se pueden encarecer. Queda como **mitigación parcial**, no como defensa del umbral. Desbloqueada el 2026-09-21: confiscar saldo retenido **no exige demostrar que la parcela existía entera**, así que **no depende de (6)** ni de la prueba de cobertura. Ya estaba en `P-ZRX/P-RNG/` ficha D («un lock asociado a la clave **o**, mejor, al compromiso de parcela»): la variante por clave es la que se puede construir hoy. Necesita (8) |
| **8** | **Firmante seguro en el productor** (persistir `oportunidad → pre_hash` **antes** de firmar, y negarse a firmar otra) | Un granjero honesto con **dos nodos o harvesters redundantes**, o que **reinicia perdiendo el estado**, produce bloques contradictorios sin mala fe. Hoy pierde trabajo (solo una copia cobra); con (1) perdería bloques y con (7) sería **castigado** | **F2→F3** | **ENTREGADO y validado**: prototipo en Rust, 27 tests, durabilidad probada matando el proceso. Coste **0,81 ms por bloque** (0,08 % del slot). Falta **decidir el punto de enganche: no hay productor de bloques en `crates/`** |
| **9** | **Compromiso causal temprano del ancla** (un bloque fija la inyección futura; los descendientes la heredan por la cadena de padres seleccionados; no se recalcula al fusionar) | **La única fuga que `P-ZRX/P-EQUIVOCACION/` dejó abierta**: dos ramas pueden derivar anclas distintas y con ellas retos distintos, y entonces el doble farmeo no deja evidencia | **F0** | **`P-ZRX/P-ANCLA-TEMPRANA/` escrito, sin lanzar**: intentar romperla antes que defenderla. Condición propuesta `L ≥ F + D`, **casi gratis bajo el perfil 1a**. **Reabre el área que Katana cerró el 2026-09-19/20**: solo lanzarlo si se está dispuesto a volver sobre eso |
| **10** | **Pools sin autoridad de firma** (el pool gestiona pagos y recibe parciales; el granjero conserva la firma y valida el contexto; una firma de parcial no vale como autorización de bloque) | **Capturar el servidor de un pool equivale hoy a capturar las firmas de todos sus granjeros**: es la vía barata para conseguir `β` prestado sin sobornar a nadie | **F1** | **ENTREGADO y validado. El agujero está CONFIRMADO**: hoy un operador hostil puede producir bloques para la rama que elija con el espacio de sus granjeros **y cobrar él la coinbase**, si su protocolo hace que el cliente firme un `pre_hash` que él compone. Ninguna regla lo impide. Cierra: arquitectura Chia-like + atar la coinbase a `sol.public_key` (D1) |

### Dependencias que conviene no olvidar

- ~~**(1) puede dejar a (7) en segundo plano.**~~ **RETIRADO el 2026-09-21**: `P-ZRX/P-IDENTIDAD/` midió que (1) no cierra el doble farmeo dentro de una historia, así que **(7) vuelve a ser la vía principal** y el prototipo es el que ya estaba previsto. Texto original: si cambiar la definición cierra el doble farmeo por
  construcción, el mecanismo de castigo deja de ser imprescindible. **Por eso (1) va antes que el
  prototipo.**
- **(6) y (7) comparten el registro.** Si se adopta (6), (7) sale casi gratis; si no, (7) necesita su
  propio estado.
- **(5) condiciona el *valor* de casi todo.** Sin él se puede decir «esto cierra tal conducta», pero no
  «esto sube el umbral en tanto».
- **(4) es independiente** de todo lo demás: sus cifras se miden en slots, no en fracción de espacio.

---

## Lo que NO es una propuesta pero pesa más que varias

| Hueco | Estado |
|---|---|
| **Red y eclipse** | Modelado en su día (ronda 11b), **sin integrar ni validar** para las reglas vigentes. Según el propio repositorio, **la palanca real de un adversario grande, por delante del reloj** |
| **`Δ` real** | Sin medir; **exige red funcionando**. De él dependen `L_suelo_slots`, el suelo de `F` y si una partición nace |
| **Prueba de cobertura completa** | No existe para el formato fijado. Bloquea (6) |
| **Distribución del saldo retenido** | Un granjero pequeño puede tener **saldo confiscable cero**, y el atacante reclutaría precisamente esas claves. La media no sirve: hace falta la **distribución** y a quién elegiría el atacante. Condiciona (7) |
| **`C-GD-10` no descarta puntas que violarían U2** | Hallado por `P-ZRX/P-IDENTIDAD/`: el productor descarta las puntas que romperían `C-GD-11`, pero **no** las que harían inválido su bloque por U2. Con la identidad vigente el efecto es 0,40 %; con una más gruesa, hasta 64,8 %. **Afecta a (1) y conviene mirarlo aunque (1) no se adopte** |
| **Nodo nuevo: arranque sucinto** | Puede validar desde el génesis; falta el arranque sucinto desde estado podado |
| **Verificador PoT** | **No existe**: `zx-core::wire_dag::verificar_justificacion_pot` devuelve `IntegracionPotPendiente` y `zx-p2p` lo propaga (`crates/zx-p2p/src/rele_compacto.rs:732-738`, `TAREAS.md`:221). Sin él, ninguna regla de flujo se puede validar de verdad |
| **El reloj principal** | Producir una línea de PoT ocupa un núcleo entero sin reparto, y la máquina de referencia no llega al slot de 1 s |

---

## Bitácora de cambios de fase

Una línea por movimiento. **Quien mueva una fila, la escribe aquí.**

| Fecha | # | De → a | Motivo y evidencia |
|---|---:|---|---|
| 2026-09-21 | 1 | — → F0 | Hallazgo de `P-ZRX/P-PRESTAMO/`, validado por Claude. Detalle en `P-ZRX/T-ZRX/MEJORA-IDENTIDAD-DE-BILLETE.md` |
| 2026-09-21 | 1 | F0 → **F1 (tope)** | `P-ZRX/P-IDENTIDAD/` **refuta la premisa**: `chunk` no es un grado de libertad independiente (un reto fija un s-bucket; una pieza aporta a lo sumo un chunk en él — verificado por Claude en `PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:33-39` y `…/subspace-farmer-components/src/sector.rs:582-608`). Dentro de una historia A, B y C particionan igual: 0 bloques honestos perdidos en 48 400. Beneficio ≈0,6 %; coste: invariante de `C-FLU-12` y cascada por `C-GD-10` |
| 2026-09-21 | 4 | F0 → F1 | `P-ZRX/P-REVELACION/` mide qué compra y qué no: quita el acantilado de `ρ=1`, **no anula** la ventana (factor 1,2–4,6 en la edad exigida) |
| 2026-09-21 | 7 | F0 → F1 | `P-ZRX/P-EQUIVOCACION/` mide la cobertura y los falsos positivos; `P-ZRX/P-PRESTAMO/` da la región `(ρ_ret, T_v)` |
| 2026-09-21 | 8 | — → F1 | Sale del análisis de Codex del 2026-09-21: el firmante seguro es **pieza autónoma**, no un detalle de (7). Especificado y con catálogo de falsos positivos en `P-ZRX/P-EQUIVOCACION/` |
| 2026-09-21 | 5 | — → F0 | Descubierto al auditar CRP-v0.2/0.3: el defecto D4 sigue abierto (`P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1) |

---

## Dónde está cada cosa

- **Mapa de amenazas y soluciones:** `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md`
- **La candidata de registro y castigo, entera:** `P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md`
- **La mejora de identidad, entera:** `P-ZRX/T-ZRX/MEJORA-IDENTIDAD-DE-BILLETE.md`
- **Plan y orden de los encargos:** `P-ZRX/T-ZRX/PLAN-ENCARGOS.md`
- **Qué se puede afirmar hoy del umbral, y con qué palabras:** `P-ZRX/P-CRP/auditoria/BASELINE.md`
| 2026-09-21 | 7 | — | **Desbloqueada**: ligar la retención a la **clave** en vez de al lote evita depender de (6) y de la prueba de cobertura (análisis de Codex; la variante ya estaba en `P-ZRX/P-RNG/` ficha D) |
| 2026-09-21 | 9 | — → F0 | Candidata nueva (Codex): compromiso causal temprano del ancla, contra la única fuga que dejó `P-ZRX/P-EQUIVOCACION/` |
| 2026-09-21 | 10 | — → F0 | Candidata nueva (Codex): pools sin autoridad de firma. **Vector que no estaba en el mapa** |
| 2026-09-22 | 3, 7, 8, 9, 10 | — | **Cinco encargos escritos** (sin lanzar): `P-ZRX/P-RANGO/`, `P-ZRX/P-CLAVE/`, `P-ZRX/P-FIRMANTE/`, `P-ZRX/P-ANCLA-TEMPRANA/`, `P-ZRX/P-POOLS/` |

---

## Estado de los encargos abiertos

| Encargo | Propuesta | Qué entrega | Hilos | ¿Lanzado? |
|---|:---:|---|---:|---|
| `P-ZRX/P-POOLS/` | 10 | **ENTREGADO 2026-09-22.** Agujero confirmado; 8 decisiones para Katana (D1: atar la coinbase a `sol.public_key`) | 4 | sí |
| `P-ZRX/P-FIRMANTE/` | 8 | **ENTREGADO 2026-09-22.** 0,81 ms/bloque; falta decidir el punto de enganche | — | sí |
| `P-ZRX/P-RANGO/` | 3 | **ENTREGADO 2026-09-22.** `C-RET-01…11` listas para que Katana las traslade | 4 | sí |
| `P-ZRX/P-CLAVE/` | 7 | **ENTREGADO 2026-09-22.** No disuade: grieta de las claves pobres + claves nuevas gratis | 8 | sí |
| `P-ZRX/P-ANCLA-TEMPRANA/` | 9 | Si el compromiso causal cierra la carrera del ancla, y qué reabre | 8 | no |

**Orden recomendado:** `P-POOLS` y `P-FIRMANTE` primero (ninguno depende de nada y el primero cubre un
vector recién descubierto), después `P-RANGO`, luego `P-CLAVE`. **`P-ANCLA-TEMPRANA` solo si Katana acepta
reabrir el área del ancla**, cerrada el 2026-09-19/20. Los cuatro primeros suman 16 hilos y caben a la vez.
| 2026-09-22 | 10 | F0 → **F1** | `P-ZRX/P-POOLS/` **confirma el agujero**: auditar no exige clave privada (`audit_sector_sync` toma la **pública**), el sello va bajo `sol.public_key` (`C-HDR-04`) pero **`C-HDR-08` deja la recompensa fuera de la cabecera** y `C-EMIT-03` solo acota el importe ⇒ quien construye el bloque elige quién cobra. Verificado por Claude en las tres fuentes |
| 2026-09-22 | 8 | F1 → **F2** | `P-ZRX/P-FIRMANTE/` entrega prototipo funcionando: 0,81 ms/bloque (0,08 % del slot), durabilidad probada con muerte del proceso. Halló y arregló un fallo real (`flock` heredado por `fork` ⇒ `O_CLOEXEC`) |
| 2026-09-22 | 3 | F1 → **F2** | `P-ZRX/P-RANGO/` entrega `C-RET-01…11`. **Corrigió el encargo de Claude**: «anclar al flujo canónico» leído al pie de la letra contradice `C-HDR-06` (el rango es función de `past(B)`, y un verificador no puede leer la cadena honesta). Lo redactó como ventana en **slots absolutos** |
| 2026-09-22 | 7 | F1→F2 → **F1 (tope)** | `P-ZRX/P-CLAVE/`: la retención por clave **no disuade al atacante que importa**. El `β_d` que cruza la deriva (0,34 con α=0,33) es menor que el espacio en claves de saldo casi cero (0,675) ⇒ soborno cero. Aguanta los cuatro exponentes de la rejilla (comprobado por Claude). Y las claves nuevas **no se pueden encarecer** sin registro ni moneda (teorema de identidades gratis) |
