# Encargo 05 — ¿Existe una poda para ZEROX? Auditoría del análogo PoST a los niveles de PoW

**Ejecutor:** DeepSeek, en la zona aislada `deepseek/`.
**Diseñado por:** Claude (Opus 5), 2026-09-17, bajo decisión de Katana del 2026-09-17.
**Categoría Veritas propuesta:** `consenso` (dominante); `almacenamiento` secundaria.
**Ruta de trabajo:** `deepseek/veritas/consenso/poda-post-v1/`.
**Destino final, si se valida:** `veritas/consenso/poda-post-v1/`.

---

## 0 · Lo primero, y no es una formalidad

**Lee íntegro `veritas/LINEO.md` antes de escribir una línea de código.** Es obligatorio por
`AGENTS.md` y por C-SPEC-03. El bloque del §8 de LINEO («Prompt obligatorio para agentes Veritas»)
te aplica entero y no se repite aquí: cúmplelo como si estuviera copiado.

Lee también, en este orden:

1. `research/dag-poas-auditoria.md` — **ATAQUE 7** (§ «La poda y la IBD de rusty-kaspa son PoW») y
   §0.2 («Lo que rusty-kaspa asume de PoW»). Es el origen de este encargo.
2. `SPEC.md` §11 completo (C-GD-01…C-GD-11, C-ORD-01…C-ORD-04) y §6.1–§6.2 (cabecera DAG).
3. `SPEC.md` §17, fila **Poda (*pruning*)**.
4. `TAREAS.md` §2.4, subsección «Pruning».
5. `veritas/consenso/ghostdag-rank-v1/` — **es tu modelo de instrumento**: CONTRATO, MÉTODO,
   DERIVACIONES, HUELLAS. No lo reimplementes: si necesitas GHOSTDAG, se reutiliza.

---

## 1 · El problema, dicho sin adornos

Toda la poda de rusty-kaspa cuelga de **`calc_level_from_pow`** (`consensus/pow/src/lib.rs:72-75`):
el «nivel» de un bloque son los **ceros iniciales de su hash de PoW**. De ahí salen
`parents_by_level` (`header.rs:141`), `check_indirect_parents` (`post_pow_validation.rs:55-77`),
`level_work` (`difficulty.rs:223-231`) y toda `pruning_proof/` (`build.rs:145-195`).

**ZEROX no tiene PoW.** Sin niveles no hay prueba de poda; sin poda, *reachability* crece
`O(#cabeceras × mergeset_limit)` sin cota — **≈31,5 M cabeceras/año**. La auditoría lo marcó
**CONFIRMADO (laguna)**, gravedad media, y ahí lleva desde entonces.

**Tu pregunta:** ¿existe en PoST un análogo a los niveles de PoW que sostenga una prueba de poda
verificable, y bajo qué supuestos?

### Hipótesis de partida — NO es una regla, y no la adoptes

`research/dag-poas-auditoria.md` apunta un análogo natural:

> `solution_distance ≤ SR/2^L` ocurre con probabilidad `2^{-(L-1)}`

y lo etiqueta explícitamente **«es investigación, no adopción»**. Katana ha ordenado auditarlo
**sin adoptarlo**. Tu trabajo es **ponerlo a prueba**, no construir encima de él. Un informe que dé
por buena la hipótesis y solo ajuste constantes es un informe rechazado.

---

## 2 · Tres problemas que NO se resuelven juntos

Katana ha ordenado separarlos. Mezclarlos es el fallo más probable de este encargo, porque la
literatura de Kaspa los trata como uno solo.

| # | Problema | Quién lo sufre |
|---|---|---|
| **1** | **Poda local**: qué puede descartar un nodo que **ya validó toda la historia** | nodo veterano, disco |
| **2** | **Prueba de poda e IBD sin confianza**: cómo arranca un nodo **nuevo** sin bajarse y validar todo, y sin confiar en nadie | nodo nuevo |
| **3** | **Disponibilidad histórica**: quién conserva lo podado y bajo qué garantía (nodos archivales) | la red |

**El (1) puede tener solución aunque el (2) no la tenga.** Un nodo que ya validó sabe que su estado
es correcto; puede tirar datos sin necesidad de convencer a nadie. El (2) es el difícil: exige un
objeto **verificable por un tercero**, y es exactamente lo que los niveles de PoW proporcionan en
Kaspa. Trátalos por separado en el informe, con veredicto propio cada uno. **Un «sí» en (1) no es
un «sí» en (2)**, y presentarlo como tal sería el error grave de este encargo.

---

## 3 · Alcance obligatorio

Los ocho puntos son de Katana. Ninguno es opcional; si alguno queda sin cubrir, se declara
**inconcluso** con su motivo, no se omite.

1. **`SR` variable.** El rango de solución no es constante: lo mueve el controlador de R-FIN-13′. Un
   umbral `SR/2^L` con `SR` variable **no define un nivel estable**. ¿Qué significa «nivel» cuando
   el umbral se mueve bajo los pies? ¿Se ancla `SR` al del bloque, al de la ventana, a un valor de
   referencia?
2. **Retarget.** Interacción con el controlador. Un atacante que influya en `SR` influye en los
   niveles: cuantifícalo.
3. **Múltiples soluciones.** Un billete puede dar varias soluciones ganadoras por s-bucket
   (`auditing.rs:237-270`, citado en la auditoría). ¿Multiplica eso las oportunidades de alcanzar un
   nivel alto? ¿A qué coste real de espacio?
4. **Retención.** Un adversario que retiene bloques de nivel alto y los publica cuando le conviene.
5. **Ramas privadas.** Construir en privado una rama con niveles altos y presentarla como prueba de
   poda. **Este es el ataque que mata a un esquema de poda mal diseñado**; trátalo como caso central,
   no como apéndice.
6. **Validación de `parents_by_level`.** Cómo se verifica que los padres declarados por nivel son
   los correctos — y **lee el §4 antes de asumir que ese campo existe en ZEROX**.
7. **Recomputación de `blue_work`.** Un nodo que arranca de una prueba de poda **no ha visto** el
   pasado: ¿puede recomputar o verificar `blue_work` (C-GD-02, `u256`) sin él? Recuerda el ATAQUE 8:
   bajo PoST, **afirmar un `blue_work` en la cabecera es gratis**, y solo un nodo completo lo
   comprueba. Si la prueba de poda se apoya en `blue_work` declarado, no prueba nada.
8. **Compromiso verificable del estado.** Qué objeto compromete el estado podado de forma que un
   tercero lo verifique (raíz de UTXO, acumulador, otra cosa), y qué cuesta producirlo y comprobarlo.

---

## 4 · La consecuencia que puede reabrir el SPEC — dilo pronto si la encuentras

La cabecera DAG de ZEROX quedó **cerrada en el SPEC el 2026-09-17** (§6.1–§6.2). Su estructura de
padres es **plana**:

```rust
// crates/zx-core/src/preimage/dag.rs:190
pub struct PadresDag { count: u8, seleccionado: BlockHash, extra: [BlockHash; MAX_PADRES_EXTRA] }
```

**No existe `parents_by_level`.** El layout `589 + 32·(P−1)` no tiene sitio para niveles.

Si tu auditoría concluye que una prueba de poda verificable **exige** padres por nivel en la
cabecera, entonces **§6.1 se reabre**, el layout cambia y el trabajo de cablear la cabecera DAG
(TAREAS §2.8) se hace sobre un formato que va a moverse.

**Eso no es razón para inclinar el resultado en ninguna dirección.** Es razón para **decirlo en
cuanto lo sepas**, no al final: es la conclusión con más consecuencias de todo el encargo y hay
trabajo esperando detrás. Escríbelo en `PROGRESO.md` el mismo día que lo determines.

---

## 5 · Prohibiciones explícitas

1. **No fijes parámetros.** Ni `L`, ni profundidad de poda, ni tamaños. Si el análisis pide un
   valor, entrégalo como **función de lo que aún no está decidido**, con su derivación.
2. **No uses `F = 2 h`.** Es provisional en investigación (`MIGRACION.md`), no un parámetro
   adoptado. Nada de lo tuyo puede depender de ese número.
3. **No adoptes la hipótesis** `solution_distance ≤ SR/2^L` como regla. Es lo que se audita.
4. **No propongas texto para `SPEC.md` ni lo edites.** El SPEC lo redacta Claude. Si tu resultado
   sugiere una regla, descríbela en `PROPUESTA.md` como propuesta, con sus supuestos y su alcance.
5. **Nada de Python.** Julia en CPU (C-SPEC-03, LINEO). C++/CUDA solo si el perfil justifica GPU, y
   con oráculo CPU estricto.
6. **No toques nada fuera de `deepseek/`.** Ni `crates/`, ni `SPEC.md`, ni `TAREAS.md`, ni
   `veritas/` fuera de tu copia de trabajo, ni `.git`. Comprueba con
   `git -C /home/katana/zeo/ZEROX status --short` al empezar y al terminar, y **registra ambas
   salidas** en `PROGRESO.md`.
7. **No declares horas trabajadas como evidencia.** Si registras tiempos, que sean de `date` y de
   los propios artefactos, no estimaciones.
8. **Una testnet sin poda no es una solución.** Katana lo ha dicho expresamente: la poda es
   **requisito para lanzar mainnet**. Puedes describir la operación provisional de una testnet con
   nodos archivales explícitos, pero **no cuenta como respuesta a la pregunta del encargo**, y el
   informe debe decirlo con esas palabras.

---

## 6 · Entregables

En `deepseek/veritas/consenso/poda-post-v1/`, con la estructura de LINEO §1 (créala con
`veritas/nueva-auditoria.sh` **copiando la plantilla a tu zona**, sin escribir en `veritas/`):

| Archivo | Contenido |
|---|---|
| `CONTRATO.md` | qué calcula el instrumento, qué **no** acredita, límites declarados, presupuesto de tiempo/RAM/disco **antes** de ejecutar (LINEO §7) |
| `MODELO.md` | el modelo matemático: definición de nivel bajo PoST, adversario, supuestos |
| `INFORME.md` | **veredicto separado para los tres problemas del §2**, con etiquetas `demostrado` / `medido` / `estimado` / `no demostrado` / `inconcluso` |
| `PROPUESTA.md` | si procede: qué regla podría escribirse, con supuestos y alcance. **Propuesta, no SPEC** |
| `PROGRESO.md` | bitácora: qué hiciste, cuándo, con qué comando, qué falló. Se migrará como `BITACORA.md` |
| `HUELLAS.sha256` | huellas de resultados y fuentes leídas |
| `src/`, `test/`, `bench/`, `run.jl`, `resultados/` | según LINEO §1 |

**Referencia y kernel.** LINEO §8.3–§8.5 es obligatorio: referencia transparente primero, kernel
después, y **validación del kernel contra la referencia**. Si reutilizas GHOSTDAG, el oráculo es
GDR-v0.2 (`veritas/consenso/ghostdag-rank-v1/`), no una reimplementación tuya.

---

## 7 · Criterio de terminación, y qué cuenta como éxito

Se aplica LINEO §10. Y además, lo específico de este encargo:

**Un «no existe» bien demostrado es un resultado excelente.** Si el análogo PoST no sostiene una
prueba de poda verificable, decirlo con la demostración delante vale más que cualquier esquema que
parezca funcionar y se caiga en el ataque de rama privada. Este proyecto ya ha pagado varias veces
el precio de un aviso escrito y un arreglo que no estaba.

**Lo que se rechaza:**

- dar la hipótesis por buena y limitarse a calibrar `L`;
- mezclar los tres problemas del §2 en un solo veredicto;
- un esquema que resista los ataques que tú elegiste y no los cinco que pide el §3;
- apoyarse en `blue_work` declarado en cabecera (ATAQUE 8: bajo PoST es gratis afirmarlo);
- una cifra sin semilla, réplica y presupuesto declarados.

**Si agotas el presupuesto:** para, conserva el checkpoint y reporta **inconcluso** con la entrada
mínima reproducible. Un timeout no es evidencia de falsedad, y decirlo a tiempo es parte del
trabajo.

---

## 8 · Qué pasa después

Tu informe **no se migra por el hecho de estar terminado**. Claude valida **reejecutando** —no
leyendo tus `resultados/`—, y solo entonces se migra a `veritas/consenso/poda-post-v1/` y se
commitea. Lo que deba sobrevivir vive en el instrumento, porque `deepseek/` se borra al cerrar el
encargo.

Si algo de este encargo te parece equivocado, **dilo antes de ejecutarlo**, no después.
