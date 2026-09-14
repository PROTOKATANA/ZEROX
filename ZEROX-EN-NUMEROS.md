# ZEROX en números

**Referencia del proyecto · revisión del 11 de septiembre de 2026**

PoSpace-Time —PoAS + PoT— con DAG, transferencias transparentes y capa blindada prevista.
**Sin staking ni comités de decisión. Cortex es una aplicación.**

| Diseño de referencia | Economía recalibrada | Implementación |
|:---:|:---:|:---:|
| **1 bloque/s · 1 s/slot** | **14,90116119 ZZK** de recompensa base inicial | **Migración en curso** |
| Ritmos nominales, pendientes de validación en red | Cola nominal de **0,26666666 ZZK/bloque** | Todavía no hay un nodo PoST + DAG completo |

> **Lectura esencial.** Las constantes económicas están en el código. Las esperas, fronteras de ataque y tasas de transacciones de la investigación necesitan sus hipótesis: no son prestaciones certificadas del nodo. El SPEC actual tampoco garantiza irreversibilidad global a las 3,33 horas. [Estado de migración][migracion] · [SPEC, §§7–13][spec]

[Parámetros](#parametros) · [Moneda y tarifas](#moneda) · [Capacidad y almacenamiento](#capacidad) · [PoT y criptografía](#criptografia) · [Código](#codigo) · [Pendientes](#pendientes) · [Cambios y trazabilidad](#trazabilidad)

### Cómo leer los estados

| Estado | Significado |
|---|---|
| **E · elegido** | Constante o referencia explícita del SPEC; se indica si es provisional. No implica integración. |
| **M · medido** | Observación de una ejecución o inventario. **M histórica** identifica resultados conservados, sin repetirlos en esta revisión. |
| **D · derivado** | Resultado de una fórmula y de los supuestos indicados. **D histórica** conserva el cálculo de su informe original. |
| **P · pendiente** | Falta definición, decisión, medición, prueba o integración; se especifica cuál. |

**Convenciones de esta hoja:** un año de cálculo son 365 días, es decir, 31 536 000 s; GB y TB son decimales. El peso de consenso no es el tamaño serializado. Una tasa media no es una cota temporal. Para constantes y conversiones contables no aplica un adversario: el criterio es concordancia entre fórmula, SPEC y Rust. Para seguridad, el modelo y el evento de fallo deben acompañar al número.

**Corte de fuentes:** rama `rediseno/v1-spec-first`, HEAD `7b783d469fbae5722a0ae014b5e212ed6999eb2b`, **con cambios locales**. Esta hoja revisa el contenido del workspace, incluido lo aún no comprometido. Prevalecen [SPEC][spec] y [la ficha de finalidad, revisión 2][modelo]; los informes de [research][investigacion] conservan evidencia de versiones anteriores. No se utiliza el vault externo como autoridad.

---

<a id="parametros"></a>
## Parámetros y confirmación

El perfil de estudio **A″ / T1** usa GHOSTDAG con las enmiendas U2/U3″, R-FIN-8′, R-FIN-12, R-FIN-13′ y R-FIN-14. Su integración y la prueba de seguridad de pagos siguen abiertas. [SPEC, §§7 y 11][spec] · [Modelo T1, §§1 y 3][modelo]

| Magnitud | Referencia actual | Estado y condición |
|---|---|---|
| Recurso de consenso | Espacio archivado PoAS, familia Autonomys, y PoT secuencial | **E** · no es PoW ni participación monetaria. |
| Orden | DAG GHOSTDAG con peso propio por rango | **E / P** · portado, ejecución y conflictos pendientes. |
| `λ_obj`, producción de bloques | **1 bloque/s** | **E** · objetivo medio del perfil; no tasa observada. |
| `τ_nom`, duración nominal del slot | **1 s/slot** | **E** · no asegura que cualquier procesador produzca ese trabajo en un segundo físico. |
| `k`, parámetro de GHOSTDAG | **30** | **E** · referencia de estudio. El residuo `k=25` está corregido; falta calibración de lanzamiento. |
| Padres / mergeset | **15 padres / 180 bloques**, a `k=30` | **E** · referencia Kaspa `c338d495`; shuffle de candidatos, no de la decisión del verificador. |
| `α`, fracción adversaria de espacio | **0,33** operativo declarado | **E** · referencia de investigación, no umbral certificado de la implementación. |
| `Δ`, retardo efectivo de red | **Sin medir** | **P** · red ZEROX con DAG, pruebas, carga, colas y adversario de red. Los 4/16/20 s son escenarios. |
| `S_max_slots`, salto desde el padre seleccionado | **150 slots** | **E** · equivale nominalmente a 150 s; no limita por sí mismo la retención física ni `Δ`. Se admite igualdad de slot entre padre e hijo. |
| `F`, restricción temporal R-FIN-7 | **2 h, provisional** | **E / P** · diseño de protección local; integración y acuerdo bajo particiones pendientes. |
| `I`, época; `L`, rezago de inyección; `ρ_max`, ventaja del reloj adversario | **Sin valores finales** | **P** · `I=851 s`, `L=1 h` y `ρ_max=3` son candidatos de informes, no configuración de producción. |
| Espera de aceptación de un pago | **Sin tabla validada para T1** | **P** · fijar observador, inicio/reinicio de espera, riesgo aceptable, red y evento de fallo. |

Fuentes de todas las filas: [SPEC, §7.3][spec], [modelo, §§3 y 6][modelo] y [ancla, enmiendas de §2][ancla].

### Qué dicen realmente los números de finalidad

La referencia **R0 · `carrera-nominal-tiempo-fijo-v1`** modela dos procesos Poisson independientes, tasas constantes, pesos iguales y ventaja inicial adversaria `3k=90`. Con `λ=1/s`, `α=0,33` y pérdida honesta `δ=0`, el evento es que el atacante consiga **adelanto estricto en algún instante desde la aceptación a tiempo fijo, incluido ese instante**. En R0, α reparte las tasas de eventos; su correspondencia con fracción de espacio efectivo necesita justificación para T1. No se ejecutan transacciones, PoT, red ni retarget dentro de esa función. [Modelo, §§3.1 y 4][modelo]

| Espera fija en R0 | Resultado publicado | Qué permite afirmar |
|---:|---:|---|
| **600 s · 10 min** | **1,516 × 10⁻⁶** | **D histórica** · riesgo de la carrera nominal descrita. |
| **1 800 s · 30 min** | **7,071 × 10⁻³⁶** | **D histórica** · mismo escenario y evento. |
| **1 800 s · 30 min**, cambiando a `α=0,40` | **1,148 × 10⁻¹⁰** | **D histórica** · otro adversario; no intercambiable con la fila anterior. |

Procedencia: [ronda 10c, §C.1][r10c], [salida de ronda 12][r12salida] y [SPEC, §13][spec]. Son resultados leídos, **sin nueva validación numérica en esta revisión**. El criterio para publicar una garantía de pago es justificar la transferencia **R0 → T1**, incluida la política de aceptación; sigue pendiente. Un resultado diminuto o un cero por redondeo no demuestra riesgo nulo.

**Confirmación adaptativa:** los **8–56 s** de D14 no son una garantía vigente. D16 cuestiona la adaptación ensayada, pero cambia un tiempo de parada por su media, y su peor caso procede de una traza cuya conformidad con las reglas destino no está acreditada. Tampoco se ha demostrado que `k_ref` sustituya al `k` de la cota original. La línea sigue necesitando investigación; no corresponde publicar que toda la familia DAGKNIGHT quedó refutada. [SPEC, §13][spec] · [límites de D14–D16][migracion]

**Madurez, reorg y finalidad son magnitudes distintas.** Los **12 000 bloques** de madurez y el máximo heredado de **11 999 bloques** de reorg pertenecen a la implementación transitoria. Convertirlos a unas **3,33 h** con la tasa nominal no proporciona un plazo determinista ni acuerdo entre nodos aislados. `C-REORG-07` y R-FIN-7 no se presentan como dos reglas simultáneamente activas. [SPEC, §§8 y 12–13][spec]

---

<a id="moneda"></a>
## Moneda y tarifas

**Modelo contable E1:** constantes actuales de Rust y SPEC; calendario nominal a `λ=1 bloque/s`, sin penalización de subsidio y con emisión íntegra. La aplicación y el contador de emisión sobre el DAG aún necesitan integración. [SPEC, §8][spec] · [emisión Rust][emision]

| Magnitud | Valor de referencia | Estado / definición |
|---|---:|---|
| Unidad atómica | **1 brek = 10⁻⁸ ZZK** | **E** · los importes se codifican en brek. |
| Techo blando `SOFT_CAP` | **1 000 000 000 ZZK** | **E** · no es un máximo del suministro. |
| Límite total de suministro | **No existe** | **E** · la cola nominal no se apaga. |
| Premine / reserva de fundador / impuesto de desarrollo | **Ninguno** | **E** · coinbase de génesis de valor cero. |
| Desplazamiento `SHIFT` | **26** | **E** · recalibración conservada. |
| Recompensa base inicial | **1 490 116 119 brek = 14,90116119 ZZK** | **D** · `SOFT_CAP_brek >> 26`; el génesis paga cero. |
| Cola nominal `TAIL_EMISSION` | **26 666 666 brek = 0,26666666 ZZK/bloque** | **E** · se aplica antes de penalizar; no es un mínimo cobrado por bloque. |
| Cola anual nominal | **8 409 599,78976 ZZK/año** | **D** · `26 666 666 × 31 536 000 / 10⁸`. |
| Emisión anual / techo blando | **≈ 0,84096 %** | **D** · porcentaje respecto a 1 000 M ZZK. Respecto al suministro creciente, el porcentaje disminuye. |
| Entrada en cola / cruce del techo blando | **≈ años 8,56 / 10,69** | **D histórica** · calendario del modelo E1, no fechas garantizadas. |
| Madurez de coinbase | **12 000 bloques** | **E** · unidad heredada; semántica DAG pendiente. |
| Caducidad del checkpoint frágil | **63 072 000 bloques** | **E** · conversión nominal de dos años; bootstrap y calendario DAG pendientes. |

La recalibración de emisión está resuelta en las constantes. Se retiran como problemas activos el cruce a los **30,9 días** y el **100,92 % anual**: eran resultados de ejecutar a un bloque por segundo las constantes antiguas `SHIFT=19` y cola de `32 ZZK`. Los **10,15 → 10,69 años** y el **≈5,3 %** de cambio de calendario pertenecen a la comparación histórica sin penalización. [Recalibración, §§1–3][recalibracion]

### Política de tarifa mínima

| Constante | Valor | Estado / alcance |
|---|---:|---|
| `REF_WEIGHT` | **384 000** unidades de peso | **E** · referencia para calcular la tarifa. |
| `TARIFA_SUELO` | **54 359 brek/unidad de peso** | **E** · suelo absoluto independiente de la caída de recompensa. |
| `FEE_MASK` | **10 000 brek** | **E** · redondeo de la tarifa hacia arriba. |
| Tolerancia de admisión | **2 %**, mediante resta entera | **E** · `mínima − mínima/50`. |
| Tx hipotética de peso **350** | **0,1903 ZZK** cotizados; **0,186494 ZZK** admitidos al suelo | **D** · corrige el redondeo «0,19 ZZK». |
| Tx P2K de dos entradas y dos salidas, peso **307** | **0,1669 ZZK** cotizados; **0,163562 ZZK** admitidos al suelo | **D** · firmas de 64 B por entrada. |

Derivación: `mínima(w) = ceil(w × 54 359 / 10 000) × 10 000` brek; después se aplica el colchón entero. Con las constantes actuales domina el suelo: `base≤base_inicial` y `Mlt≥ZONA_LIBRE`. Modificar la política puede cambiar la tarifa. A lanzamiento, la expresión cruda vale **57 220**, y `57 220 − floor(57 220/20) = 54 359`; el comentario del SPEC que identifica directamente el suelo con la expresión cruda es impreciso. [SPEC, §§5.5 y 6.5][spec] · [tarifa Rust][tarifas]

Esta es **política de mempool y retransmisión**, no una causa de invalidez de bloque. El suelo elimina la caída automática de la tarifa con la recompensa y con la mediana; **su resistencia adversarial completa sigue sin auditarse**. Los costes históricos de spam no son una prueba de coste neto para un productor que puede recuperar tarifas. [SPEC, §§5.5 y 17][spec]

---

<a id="capacidad"></a>
## Capacidad, tamaños y almacenamiento

### Lo fijado en la capa de capacidad

| Magnitud | Valor | Estado / alcance |
|---|---:|---|
| `ZONA_LIBRE` | **100 000** unidades de peso/bloque | **E** · suelo de la mediana, no «transacciones gratis». |
| `N_LARGO` | **21 600 bloques** | **E** · ventana de capacidad; **6 h nominales** a λ1. |
| `N_CORTO` | **1 000 bloques** | **E** · ventana de ráfaga; **16 min 40 s nominales** a λ1. |
| `FACTOR_SURGE` | **50** | **E** · acota la mediana efectiva respecto a `Mlt`. |
| `MAX_TX_WEIGHT` | **100 000** unidades de peso | **E** · tope absoluto de C-WGT-11. |
| Objetivo del marketplace | **1 280 pagos/s = 110 592 000 pagos/día** | **E / D** · objetivo de diseño; no benchmark ni demanda observada. |

Fuente y criterio: [SPEC, §6.5][spec] y [peso Rust][peso]; concordancia de constantes y fórmulas. El adversario y la política de cola se estudian por separado.

**No hay un único techo de tx/s.** El límite de bloque es `2·M(H)`. Con `Mlt=100 000`, en arranque `M=100 000` y el límite es **200 000** unidades; si la mediana corta alcanza el máximo de ráfaga, el límite llega a **10 000 000** unidades. `Mlt` puede crecer, así que esa última cifra tampoco es un máximo global. La coinbase consume parte del peso disponible. [C-WGT-01 y C-WGT-07..09][spec]

**Ejemplo exacto de empaquetado:** con una coinbase sin entradas ni testigos y una sola salida PubKey (**56 unidades**), caben **325 transacciones P2K de dos entradas y dos salidas** bajo 100 000 unidades: `floor((100 000−56)/307)=325`. Es **D**, capacidad por peso con ese contenido concreto; no rendimiento medido del nodo ni tamaño de archivo. [C-WGT-01..02][spec]

| Cifra de la hoja anterior | Lectura validable hoy |
|---|---|
| **285 tx/s libres de penalización** | **D**, aproximación `100 000/350` a λ1, antes de reservar coinbase. El denominador es una tx hipotética de peso 350; no una medición del nodo. |
| **28 571 tx/s de techo** | **D**, aproximación `10 000 000/350` para el estado de ráfaga descrito. Se retira la afirmación de techo global y cola eterna por encima. |
| **25:02 ± 39 s** para absorber 1 280 tx/s | **D histórica** · conversión de un resultado por bloques del modelo con peso 350 y cadena madura. No es intervalo garantizado ni ensayo del nodo. |
| **1 s** hasta inclusión | Objetivo relacionado con λ1; **P** como latencia real de pagos, que incluye propagación, validación, selección y cola. |

El instrumento introduce un **escalón sostenido de 448 000 unidades de demanda por bloque**, con `Mlt=100 000` fija y ventana corta madura de 1 000. El resultado publicado es **1 502 bloques** hasta tener cola vacía **y subsidio íntegro**; el SPEC conserva **≈423 000 tx** de cola máxima. La conversión a **25:02**, con desviación típica **≈39 s**, supone esos bloques a tasa Poisson λ1. Introducir demanda fija por bloque no equivale a simular llegadas constantes por segundo cuando los intervalos varían. No se traslada el resultado a peso 307 sin repetir el escenario. [SPEC, §6.5][spec] · [instrumento histórico, función `reaccion`][rafaga]

### Qué ocupa cada cosa

| Objeto | Valor | Estado / corrección |
|---|---:|---|
| Cabecera implementada | **92 B** | **M** · formato lineal heredado; es una deuda de migración. |
| Base de cabecera PoAS descrita | **556 B** | **E** · C-HDR-01; **no** es la cabecera DAG definitiva. |
| Cabecera DAG definitiva | **Pendiente** | **P** · padres, compromisos y justificación PoT aún sin formato completo. |
| Transparente P2K, 2 entradas / 2 salidas | **307 unidades de peso** | **D** · C-WGT-02; tamaño wire/disco distinto y pendiente de medir para el destino. |
| `Action` Orchard | **820 B**, sin prueba ni firma de autorización | **D histórica** · formato upstream estudiado, no coste total de una acción blindada. |
| Prueba Orchard estudiada, con `n` acciones | **2 720 + 2 272·n B** | **D histórica** · a ello se suman acciones, firmas y campos comunes. |
| Checkpoints PoT del ensayo | **128 B/slot = 8 × 16 B** | **M histórica / D** · payload, sin tráfico auxiliar ni encapsulado. |

Fuentes: [SPEC, §§6 y 9][spec], [cabecera Rust][cabecera], [formato Orchard][orchard], [prototipo PoT][pot]. La transacción histórica solo Orchard ocupaba **2 851 + 3 156·n B**, en el rango documentado **1≤n≤27**; para dos acciones, **9 163 B**. No se adopta como formato final del pool mientras §9 siga pendiente.

### Escenario doméstico: presupuesto, no requisito de lanzamiento

**Modelo B350:** 350 bytes almacenados y transmitidos por transacción, año de 365 días, conservación íntegra, sin poda ni sobrecoste de índices/UTXO/cabeceras/pruebas. Equipo supuesto: **8 núcleos, 50 Mbps de subida y SSD de 4 TB**. El adversario no interviene en estas conversiones; son cuentas de volumen. [Palancas de rendimiento][palancas] · [instrumento de presupuesto][presupuesto]

| Cuenta | Resultado aproximado | Fórmula / límite de interpretación |
|---|---:|---|
| SSD de 4 TB repartido entre 5 años | **72 tx/s** | `4·10¹² / (5·31 536 000·350)`; presupuesto bruto, no límite de consenso. |
| Subida íntegra a 8 pares | **2 232 tx/s** | `50·10⁶ / (8 bits/B · 8 pares · 350 B/tx)`; sin overhead. |
| 1 280 tx/s sostenidas | **14,13 TB/año** | `1 280·350·31 536 000`; llena 4 TB en **≈3,4 meses** bajo B350. |
| Objetivo / presupuesto redondeado de disco | **≈17,8×** | `1 280/72`; mismo escenario B350. |
| 200 000 pares, una liquidación diaria por par | **≈2,315 tx/s** | Escenario aportado en la hoja original: `200 000/86 400`; ahorro ideal **≈553×** respecto a 1 280 pagos/s. |

Los canales son una vía de diseño **pendiente de implementación**. Esa cuenta omite aperturas, cierres, disputas, liquidez y otras transacciones. Tampoco demuestra que un PC con SSD pueda ejercer todos los roles: producir PoT tiene otro presupuesto de hardware.

<details>
<summary><strong>Estimaciones de crecimiento que ya no deben presentarse como medidas</strong></summary>

| Valor anterior | Resultado de la revisión |
|---|---|
| **21,5 GB/año de cabeceras** | Procede de una estimación de **≈683 B/cabecera**, con unos cuatro padres, a λ1. No deriva de 556 B. El formato DAG pendiente impide fijar su crecimiento anual. [Ancla, §6][ancla] |
| **4,0 GB/año de PoT** | `128·31 536 000 = 4 036 608 000 B/año`, **D** de payload a un slot/s. No incluye almacenamiento, flujos extra, metadatos ni política de poda. |
| **3 154 GB/año como suelo adversarial** | `100 000·31 536 000 = 3 153 600 000 000` unidades de peso/año si se llena esa zona. Convertirlas a bytes exige equiparar peso y tamaño físico, igualdad que el protocolo no establece. No es un mínimo inevitable ni «gratis» para cualquier atacante. |
| **2,40 GB sin finalizar; 1,44 GB con F2h** | Estimaciones heredadas `11 999·2 439·82` y `7 200·2 439·82 B`. La segunda sustituye duración por conteo medio; ninguna es una cota de RAM para el DAG. [Recalibración, §3 bis][recalibracion] |
| **757 MB → 0,5 MB** de ventana | Estimación `N·24 B`: de 31 536 000 a 21 600 muestras. No es una medida de memoria residente de la estructura Rust. [SPEC, §6.5][spec] |
| **31,5 M salidas coinbase/año** | λ1 da **31 536 000 bloques/año de media**. Una coinbase por bloque no fija una única salida ni el número de UTXO sin gastar. [C-EMIT-03][spec] |
| **0,6 MB/año** de PoT podado | Proyección de una propuesta de poda/checkpoints; no hay integración que la respalde. [Informe de problemas, §34][problemas] |
| **6,6 MB/año** para cliente ligero con comité | Retirado del diseño autorizado junto con esa capa. No queda como solución pendiente de aprobar. [Capa histórica de finalidad][comite] |

</details>

---

<a id="criptografia"></a>
## Proof of Time y criptografía

### Medidas de PoT conservadas

**Ensayo H1:** Ryzen 9 9950X3D, código Autonomys de referencia, **200 032 000 iteraciones/slot** y **ocho checkpoints**. Se conserva el banco histórico; no se ha repetido aquí. [Ancla, «Coste del PoT, MEDIDO»][ancla] · [modelo, §3][modelo]

| Operación | Resultado | Estado / criterio |
|---|---:|---|
| Verificación de un slot | **96,1 ms/slot** | **M histórica** · ensayo citado de 100 muestras. No incluye todo el nodo. |
| Producción de un slot | **1,561 s/slot** | **M histórica** · excede el objetivo físico de 1 s con esa carga en esa máquina. |
| Carga de verificación a un slot/s | **≈9,61 % de un núcleo** | **D** · `96,1/1 000`; sin otros trabajos ni flujos. |
| Producción / verificación | **≈16,2×** | **D** · cociente de esos tiempos; no cota universal anti-DoS. |
| Referencia upstream de iteraciones | **206 557 520** | **M por lectura** · génesis Autonomys `f8842d0`, distinto del ensayo; no valor final ZEROX. |
| `W_dec`, ventana de elección del ancla | **45 s, máximo observado** | **M histórica** · búsqueda limitada de ronda 9c; **no cota universal**. |
| `ρ_max`, ventaja admisible del reloj | **Pendiente** | **P** · **1,5–2,5×** es estimación sin estudio localizado; **3×** es un candidato. |

No se mantiene la afirmación «un ASIC AES de **19×** es físicamente imposible»: los **25 ps/ronda** de aquella estimación no constituyen una demostración de imposibilidad. Los **3,1–3,8×** citados para Chia corresponden a otra primitiva —grupos de clase— y no miden un ASIC de AES. [PoT y hardware, §§1–3][aes]

### Primitivas y grado de integración

| Pieza | Referencia validada | Estado actual |
|---|---|---|
| Claves / firmas transparentes | **Ed25519: clave pública de 32 B, firma de 64 B**; `ed25519-zebra = 4.2.0` | **E / M** · verificadores reutilizables; dirección con payload de clave pública, codificada **bech32m**. |
| Hash de consenso | **SHA3-256**, crate `sha3 = 0.12.0` | **E / M** · prefijos de **16 B**; la etiqueta raíz incorpora el identificador binario de rama. BLAKE2b no es este mecanismo. |
| Reloj | **AES-128 encadenado** | **E / M** · prototipo Rust separado, todavía sin integrar en `zx-node`. |
| Pruebas de espacio | Testigos KZG sobre **BLS12-381**, **dos** en la base PoAS | **E / P** · diseño y código upstream; no verificador integrado en el nodo ZEROX. |
| Pool blindado | Orchard / Halo2, curva **Pallas** | **E / P** · `orchard = 0.15.5`, `halo2_proofs = 0.3.5` declarados, sin consumidor en el workspace actual. |

Fuentes: [SPEC, §§2–3, 6–7 y 9][spec], [Cargo.toml][cargo], [Cargo.lock][lock] y [migración][migracion]. `orchard`, `halo2_proofs` y `blake2b_simd` figuran en las dependencias declaradas del workspace, pero no en su grafo resuelto actual. Adoptar primitivas existentes no acredita la seguridad de su composición ni completa la capa blindada.

Se retiran del panel de prestaciones **47,5 µs como cota de firma Ed25519** y **84 211 tx/s de CPU**: la investigación conserva la constante y su extrapolación, pero no un banco reproducible que respalde esa cota. Asimismo, **646 µs de KZG** no se confirma: [el banco del coste por salto][costesalto] mide **584 µs por `kzg.verify`** (mediana de dos lotes; 583–586 µs en cuatro configuraciones de compilación) y **1,19 ms** por la solución PoAS completa, con prueba de espacio y dos testigos, en un Ryzen 9 9950X3D.

---

<a id="codigo"></a>
## Código y comprobaciones

**Medido el 11 de septiembre de 2026**, con las features predeterminadas y el toolchain fijado `nightly-2026-05-03`. `rustc 1.97.0-nightly (20de910db 2026-05-02)`; Cargo `1.97.0-nightly (4f9b52075 2026-05-01)`.

| Comprobación / inventario | Resultado actual | Criterio y alcance |
|---|---:|---|
| Tests del workspace | **438 pasan · 1 falla · 4 ignorados** | **M** · 443 registrados, 439 ejecutados. Los ignorados no cuentan como aprobados. |
| Fallo de `spec_numeros` | **92 B ≠ 556 B** | **M** · `el_spec_dice_el_tamano_real_de_la_cabecera`; discrepancia conservada, no escondida. |
| `cargo check` / formato | **Correctos** | **M** · compilación y `cargo fmt --check`. |
| Clippy | **0 avisos** | **M** · workspace, todos los targets, `-D warnings`. |
| Guardianes locales | **4 correctos** | **M** · alcance, citas, versiones exactas y frontera de crates. Citas o excepciones declaradas no prueban implementación correcta. |
| Crates del workspace | **10** | **M** · `cargo metadata`; cuatro esqueletos: RPC, wallet, lightwalletd y scanner. Mempool ya contiene lógica. |
| SPEC | **2 488 líneas · 169 identificadores de regla** | **M** · reglas reconocidas por el patrón de `ci/citas-spec.sh`; incluye reglas de red/proceso, no 169 pruebas de consenso. |
| Historia alcanzable desde HEAD | **270 commits** | **M** · `git rev-list --count HEAD`; no significa 270 commits exclusivos ni acredita «sin publicar». |
| Prototipo PoT, fuera del workspace | **2 tests pasan; 32 vectores diferenciales** | **M** · un test unitario y uno diferencial; ejecución desde una copia idéntica aislada. No se suman al workspace. |

Los tests de red pasaron al repetirse con permiso para abrir sockets/mDNS fuera del sandbox. No se ejecutó RocksDB opcional ni un benchmark nuevo. El prototipo no puede probarse directamente con su `--manifest-path` original porque aún falta resolver su pertenencia/exclusión del workspace: **empaquetado pendiente**, aunque sus tests aislados pasen.

<details>
<summary><strong>Desglose de tests y comandos reproducibles</strong></summary>

| Target con tests | Pasan | Fallan | Ignorados |
|---|---:|---:|---:|
| `zx_consensus` | 138 | 0 | 0 |
| `reorg_differential` | 4 | 0 | 0 |
| `spec_numeros` | 6 | 1 | 0 |
| `wire_peso_differential` | 8 | 0 | 0 |
| `zx_core` | 104 | 0 | 0 |
| `cavp_sha3_256` | 4 | 0 | 0 |
| `zx_mempool` | 25 | 0 | 0 |
| `zx_node` | 51 | 0 | 0 |
| `sincronizacion` | 7 | 0 | 0 |
| `tres_nodos` | 3 | 0 | 4 |
| `zx_p2p` | 57 | 0 | 0 |
| `dos_nodos` | 6 | 0 | 0 |
| `zx_storage` | 25 | 0 | 0 |
| **Total workspace** | **438** | **1** | **4** |

El resto de targets y los doc-tests no registraron tests con las features usadas.

```bash
cargo fmt --all -- --check
cargo check --offline --locked -j 2 --workspace
cargo test --offline --locked -j 2 --workspace --no-fail-fast
cargo clippy --offline --locked -j 2 --workspace --all-targets -- -D warnings
bash ci/citas-spec.sh
bash ci/alcance-consenso.sh
bash ci/dependencias-exactas.sh
CARGO_NET_OFFLINE=true bash ci/frontera-crates.sh
```

Inventario, con el mismo patrón de identificadores que el guardián:

```bash
wc -l SPEC.md
rg -o --pcre2 '^\*\*\K[A-Z]+-[A-Z]+-[0-9]+[a-z]?' SPEC.md | sort -u | wc -l
cargo metadata --offline --locked --no-deps --format-version 1 | jq '.workspace_members | length'
git rev-list --count HEAD
sha256sum SPEC.md
```

Logs de esta sesión, temporales: `/tmp/zerox-metricas-cargo-test-unsandboxed.log`, `/tmp/zerox-metricas-cargo-check.log`, `/tmp/zerox-metricas-cargo-clippy.log` y `/tmp/zerox-metricas-pot-isolated-test.log`. Este desglose permanece en la hoja aunque se limpie `/tmp`.

El ensayo aislado de PoT usó una copia sin modificar en `/tmp/zerox-metricas-pot.8j6V4Q`:

```bash
cargo +nightly-2026-05-03 test --offline --locked -j 2 \
  --manifest-path /tmp/zerox-metricas-pot.8j6V4Q/Cargo.toml
```

Para repetirlo tras limpiar `/tmp`, preparar de nuevo una copia íntegra de `prototipos/pot-estable/` fuera del workspace. Esta operación no resuelve su empaquetado original.

</details>

El éxito de estas comprobaciones se refiere al código presente. No prueba implementación de PoST + DAG ni verificación integral de pagos. En particular, la validación transparente de importes, la autorización y la comprobación de cuerpo aún deben ensamblarse en el nodo; el pool blindado tampoco está integrado. [Modelo, §5][modelo] · [README][readme]

---

<a id="pendientes"></a>
## Pendientes que siguen activos

Esta lista sustituye al recuento antiguo de «58 problemas». Agrupa trabajo vivo y conserva los identificadores de aquella hoja entre paréntesis; **no son reglas C-XXX ni se renumeran**. Un cierre documental se retira de esta lista cuando corresponde, sin fingir que el nodo ya lo implementa.

| Trabajo pendiente | Qué falta para cerrarlo | Referencia |
|---|---|---|
| **Cabecera, prueba y nodo DAG** | Formato de padres y PoT; validación conjunta PoAS/KZG/sello/reto; orden, estado, génesis y sincronización. | [SPEC, §§6–7, 11, 15 y 17][spec] |
| **Identidad pagable y retarget** (17, 18, 22, 47, 49, 50) | Resolver copias paralelas no azules potencialmente `rojo_k`; contexto de deduplicación, representante, pago, ejecución y retarget; fusiones tardías. **Laguna de especificación, no doble pago demostrado.** | [Modelo, §6.2][modelo] |
| **Peso y convergencia** (36, 37, 50, 51) | Dominio y desbordamiento del peso `floor(2^128/(SR+1))`, controlador y prueba del orden/composición. `SR=0` da `2^128`, fuera de u128. | [SPEC, §§7.2 y 11][spec] |
| **Red real, eclipse y DoS** (01, 02, 11, 14, 35, 44, 45, 52, 56) | Medir Δ con carga y adversario; validar sensores y selección de padres; contabilizar slots/pruebas pendientes y calibrar lanzamiento. | [SPEC, §§16–17][spec] |
| **Calendario PoT y ancla** (06, 07, 13, 38, 40, 41, 42, 43, 51, 53, 54) | I/L/ρ, actualización de iteraciones, bootstrap, disponibilidad del ancla, deadline y borde de igualdad. La notación de slots ya está consolidada. | [SPEC, §7.3][spec]; [modelo, §6.1][modelo] |
| **Relojes y disponibilidad** (03, 12, 15, 29, 32, 55) | Redundancia y recuperación probadas, producción bajo particiones y reconciliación. Ningún timeout de standby está adoptado como garantía. | [Modelo, §§3 y 6][modelo]; [redundancia][timelord] |
| **Aceptación de pagos y confirmación adaptativa** (05, 16, 31, 36, 37, 57) | Definir evento y ε, observabilidad, reinicios y frescura; justificar R0→T1 y comparar alternativas bajo el mismo adversario y criterio. | [SPEC, §13][spec] |
| **Ataques de espacio, ancla e incentivos** (07, 08, 09, 14, 39, 40, 41, 46, 47, 48) | Compresión/ploteo, precios fechados, soborno, retención y ataques combinados; incentivo a fusionar rojos. | [Informe de problemas][problemas]; [modelo][modelo] |
| **Poda y consulta ligera** (28, 34) | Diseño y pruebas de estado podable/disponibilidad. La ausencia de cliente ligero implementado no demuestra imposibilidad de toda solución sin comité. | [SPEC, §§15.1 y 17][spec]; [migración][migracion] |
| **Privacidad, capacidad y aplicaciones** | Integrar Orchard; auditar suelo de tarifa y peso blindado; cerrar vida de sectores/activaciones/timelocks y desarrollar canales si se adoptan. | [SPEC, §§5.5, 7.5, 9 y 17][spec] |

**Fuera de los pendientes:** volver a decidir si hay staking o comités; ambos están excluidos. El «segundo candado» de R-FIN-14(h) permanece como alternativa de investigación, no como componente activo cuya ausencia constituya una avería. No se asignan nuevos valores a I, L, ρ, F, k o Δ en esta revisión.

---

<a id="trazabilidad"></a>
## Qué cambió y cómo comprobarlo

| Antes | Referencia corregida |
|---|---|
| Finalidad «categórica» a 2 h o riesgo cero a 3,33 h | Restricción local propuesta y límite lineal heredado, respectivamente; acuerdo global pendiente. |
| 100–134 s como mínimo universal | Una conversión de conteo a tiempo medio no demuestra imposibilidad de confirmar antes. |
| A/DAGKNIGHT «refutada» como familia | Adaptación concreta cuestionada; transferencia y comparación homogénea pendientes. |
| Copias y cadena parásita completamente cerradas | La unicidad azul no resuelve por sí sola la unicidad de las identidades pagables. |
| 556 B de cabecera DAG; 820 B por acción blindada completa | Base PoAS lineal y Action sin prueba/firma; ambos se estaban presentando con un alcance incorrecto. |
| 437/439 tests, 11 crates y 5 vacíos | 438/439 ejecutados pasan; cuatro ignorados aparte; 10 crates y cuatro esqueletos. |
| Tabla de `k` frente a Δ «sin terminar por cuota» | Hay informe y resultados de ronda 11a. Sigue pendiente elegir/calibrar el valor de lanzamiento. |
| Unidades de época y DoS todavía definidas como bloques/hashes | El SPEC ya separa slots y segundos, corrige el contador de épocas y exige presupuestar pruebas. Quedan contratos y calibración. |

### Cierres retirados de la lista de trabajo

La recalibración monetaria y la elección de ventanas ya están reflejadas en constantes. También se han corregido documentalmente `k=25`, la monotonía estricta de slot, U3′-filtro, el contador de épocas `c·j` y la reutilización de métricas del retarget que solo contaba azules. El presupuesto y shuffle de padres tienen algoritmo de referencia; la regla vulnerable de revelación tardía se retiró. Los comités y el staking están fuera del alcance. [SPEC, §§7.2–7.3, 13 y 16.1][spec] · [modelo, §6][modelo]

Los defectos específicos resueltos dejan de figurar como problemas sin contramedida. Su integración, cuando falta, queda agrupada en el trabajo del nodo. Las cifras de ataques anteriores se conservan únicamente en el registro siguiente para explicar por qué ya no aparecen en el panel.

<details>
<summary><strong>Revisión de las cifras históricas de seguridad</strong></summary>

**Criterio común:** ninguna fila acredita seguridad de T1. Se identifica el escenario del informe leído; si faltan conformidad de trazas, composición o definición del evento, el resultado no se acepta como garantía del destino. No se han reejecutado esos instrumentos.

| Cifra anterior | Resultado de la validación documental y procedencia |
|---|---|
| **44,6 % / 35,1 %; colchón 2,1 puntos** | **D histórica**: 44,57 % / 35,08 % y 2,08 puntos frente a α0,33. D10c §C.2 usa F2h, I851 s, `δ=0` o el descuento pesimista D8 y frontera en `union10=10⁻¹⁰` durante diez años. I y el traslado al controlador actual no están cerrados. [R10c][r10c] |
| **38,3 % a Δ16 s / 32,4 % a Δ20 s** | **D histórica** de D9a: F=19 080 s e I=4 200 s, mismo umbral histórico `union10=10⁻¹⁰`. No son «la misma frontera a F2h». El control de D11a reproduce 38,3337 % / 32,3788 %. [D9a, §5.5][r9a]; [D11a, §A.3][r11a] |
| **Techo Δ22,7 s; publicar 40 % si Δ<8 s; F1h si Δ<15 s** | Conclusiones/candidatos condicionados de los modelos históricos. **P** como decisiones o cotas de la red destino; no se obtiene aprobación de producción midiendo un único percentil. [D10b][r10b]; [SPEC, §§7.3 y 13][spec] |
| **4,3 × 10⁻¹⁰ a 600 s** | **D histórica superada**: α0,25, tasa ≈1,364/s y pérdida ≈0,267 a k30 del retarget antiguo. No se mezcla con R0 α0,33/λ1/δ0. [D16, corrección D9, punto 1][r16] |
| **100–134 s; mejora a 60–75 s** | La primera usa `3k/((1−α)λ)`, **tiempo medio** para un conteo honesto, no mínimo absoluto. Reducir la ventaja usando una medida tampoco acredita la segunda espera. Se retiran ambas como garantías. [R10c, §C][r10c]; [modelo, §4][modelo] |
| **8–56 s adaptativos; 29,9 s con ε=10⁻⁶** | **D/M históricas**, no latencias seguras acreditadas. D14 observa un tiempo de parada; D16 lo convierte a tiempo medio y evalúa otra carrera. [D14][r14]; [SPEC, §13][spec] |
| **0,2564; error 2,56 × 10⁵; ganancias 3,05×/2,05× y 1,66×/1,39×** | Cifras presentes en D16 y su corrección. Las ganancias se refieren respectivamente a ε10⁻⁶/10⁻¹² y a elecciones distintas de `k_ref`; el peor caso procede de `retro500` sin comprobar S_max. No son riesgo exacto ni descarte general de la política adaptativa. [D16][r16]; [límites de evidencia][migracion] |
| **Captura 12/12 con Δ≥16 s** | **M histórica mal generalizada**: hay 12/12 en escenarios a Δ16; a Δ20 también aparecen 8/12 y 7/12. La métrica no ejecuta doble gasto y hay pendientes de conformidad del generador. [D14][r14]; [migración][migracion] |
| **Menú de anclas m=2,54 «con retención»** | **M histórica mal atribuida**: el informe identifica 2,54 **sin retención**; 2,82–2,96 proceden de instrumentos con retención cuestionada. La clausura de publicación se corrigió en ronda 9c, sin revalidar retrospectivamente todos los menús. `m` no es la ventaja 90 de R0. [Problemas, §41][problemas] |
| **45 s con ≤10 candidatos** | **M histórica** de búsqueda limitada, 12 semillas y horizonte de 1 000 s; no cota para cualquier estrategia. Resolución y cobertura siguen abiertas. [Ronda 9c, §C][r9c] |
| **Eclipse: 100 % rojos; banda 60–150 s** | **M histórica** en variantes concretas de D11b, con λ1, Δ4, k30 y víctima de fracción 0,05. La condición de rojo no demuestra por sí sola pérdida de toda recompensa bajo R-FIN-8′. No extrapolar a todos los eclipses. [D11b, §A][r11b] |
| **Sensor 30 s; cero falsas alarmas en 140 días; detecta en 25–134 s** | 30 s es propuesta; los ceros observados son **1,2·10⁷ s simulados por ventana**, no tasa de falsas alarmas nula. 25–134 s son **medianas de escenarios distintos**, no cotas; con α0,33 y ventana de 30 s, el p99 registrado es **583 s**. [D11b, §§B.7 y C.2–C.3][r11b] |
| **Standby en ≈3 s** | **P** · propuesta `G≈3` slots, sin integración ni prueba de recuperación ZEROX. Múltiples productores del mismo flujo no necesitan comité de decisión. [Redundancia][timelord]; [problemas, §3][problemas] |
| **S_max20 invalida 71–77 %; 150 es la única elección segura** | Porcentajes de casos de granjero retrasado; no prueban unicidad de una configuración segura. S_max150 es la referencia nominal conservada. [Problemas, §10][problemas]; [SPEC, §7.3][spec] |
| **Particiones <F con ≥9 % de espacio** | Condición histórica de la propuesta, no garantía integrada de disponibilidad, ausencia de huecos o acuerdo global. PoT, reglas de ancla y recuperación requieren su propio contrato. [Ancla, R-FIN-7][ancla]; [SPEC, §13][spec] |
| **Steering ÷279; ráfagas 0,46 / <0,08 puntos** | Resultados de modelos/estrategias concretos; el primero depende de la opción (h), y el segundo no cubre retención selectiva con oráculo. No son cotas del adversario completo. [Problemas, §§6 y 9][problemas] |
| **Margen del sembrador 1,9× → 3,6× al reducir L/F** | **D histórica**, con precios y velocidad de ploteo supuestos. D10c distingue ρ, L y F y corrige sus columnas (h); ni L1h ni esos márgenes son configuración o seguridad garantizadas. La sensibilidad ±50 % no es una prueba universal. [R10c, §§A, E y F][r10c] |
| **Segundo candado: diez → tres líneas; 0,15–0,81 núcleos; «81 % más»** | **D histórica** de configuraciones alternativas, no coste del núcleo adoptado. En L2h/I851, el registro da **0,813 núcleos adicionales** y factor de verificación **1+L/I≈9,46**: «81 % más» confunde fracción de núcleo con incremento relativo. [D10a, salida B.2][r10apot]; [problemas, §4][problemas] |
| **DoS: ventajas 16× / 32×** | Cocientes de trabajo en el modelo histórico de prefijo falso y verificación secuencial/aleatoria; no presupuesto completo del nodo ni garantía para cualquier entrada. [D10a, B.2.b][r10apot] |
| **Parásita: rentabilidad 1,55→0,99; retarget ×1,45→×1,005; reversiones cero** | **M históricas** de estrategias ensayadas. El resultado cero no es imposibilidad. La laguna vigente de identidades pagables impide declarar resuelta toda la composición parásita+copias. [Catálogo, A2][catalogo]; [modelo, §6.2][modelo] |
| **Un billete, quince recompensas; 14–21 bloques honestos excluidos** | Antecedentes de duplicación y selección de padres. U3″ resuelve unicidad azul; presupuesto/shuffle corrige la selección de referencia. Ni ello prueba unicidad pagable ni la integración del productor ZEROX. [Problemas, §§18 y 20][problemas]; [modelo, §§3.0 y 6.2][modelo] |
| **Publicación parcial: daño 0,31→0,10** | Comparación de estrategias del experimento histórico, sin trasladarla a una refutación universal ni al caso conjunto con retardo alto. [Problemas, §§23 y 44][problemas] |
| **Unidades: hasta ×5,8; lema BDK: 1,2 puntos** | Cifras de interpretaciones históricas. La notación de índices se ha consolidado; la transferencia del lema y la pinza no se demuestra cambiando unidades. [Problemas, §§43 y 51][problemas]; [modelo, §6][modelo] |
| **Empalme conteo/peso: <0,4 puntos** | **Certificación retirada**: las ventanas y el argumento anteriores no certifican el controlador R-FIN-13′ ni una cota uniforme bajo ataque. No queda «cerrable en una página». [Empalme, rectificación inicial][empalme]; [SPEC, §7.2][spec] |
| **Fusionador al 100 % duplica la parásita; 5 % inocuo** | Lo primero es resultado histórico; lo segundo, candidato sin validar. No hay un porcentaje adoptado aquí. [Problemas, §48][problemas] |
| **≈89 % encendidos; quórum ambiguo ≈0,52; parada al 33 %** | Pertenecen a instancias históricas de comité/quórum. La exclusión vigente viene del alcance elegido, no de convertir sus resultados en un teorema contra todo BFT o cualquier finalidad rápida. [Ronda 13][r13]; [SPEC, §13][spec] |

</details>

<details>
<summary><strong>Destino de los 58 identificadores de la hoja anterior</strong></summary>

**Esta es trazabilidad, no otra lista de tareas.** «Cierre documental» identifica la premisa resuelta; la integración restante aparece agrupada arriba. Los números se mantienen como identificadores históricos de la hoja.

| ID | Asunto | Estado de esta revisión |
|---:|---|---|
| 01 | Retraso adversarial de red | Pendiente; medir/modelar Δ y validar mitigaciones. |
| 02 | Eclipse | Pendiente; sensores y diversidad sin verificación integrada. |
| 03 | Timekeeper único | Pendiente operativo; varios productores son posibles, falta recuperación integrada. |
| 04 | Partición sin hardware para el segundo candado | Retirado del núcleo activo; depende de la alternativa (h). |
| 05 | Carrera de bloques | R0 histórico definido; seguridad del pago T1 pendiente. |
| 06 | Steering | Pendiente; depende de ρ, calendario y anclas. |
| 07 | Soborno de ancla | Pendiente, agrupado con 40. |
| 08 | Sembrador rápido | Pendiente; parámetros y costes del adversario sin cerrar. |
| 09 | Ráfagas con adelanto | Experimento específico conservado; retención selectiva pendiente. |
| 10 | Censura por S_max | Referencia 150 slots elegida; retirado el alegato de «única elección segura». |
| 11 | DoS del reloj | Pendiente de integración/calibración, agrupado con 52. |
| 12 | Particiones | Pendiente de disponibilidad, recuperación y acuerdo. |
| 13 | Recalibración de reloj | Contador documental corregido; regla N(s), calendario y arranque pendientes. |
| 14 | Residuo de parásita | Pendiente de composición e instrumentación válida. |
| 15 | Tolerancia igual a F | Garantía no acreditada; separar F y L. |
| 16 | Umbral 33 % / frontera 44,6 % | Declaración y experimento separados; calibración pendiente. |
| 17 | Parásita económica | Cierre general insuficiente por unicidad pagable pendiente. |
| 18 | Copias | Unicidad azul identificada; unicidad pagable pendiente. |
| 19 | Timewarp por timestamp | Cerrado documentalmente ese mecanismo; retarget completo sigue pendiente. |
| 20 | Griefing de mergeset | Mitigación en algoritmo de referencia; portado y cobertura pendientes. |
| 21 | Grinding del desempate por hash | Cerrado documentalmente ese desempate; integración del orden pendiente. |
| 22 | Parásito racional ajeno | Resultado histórico; no cierre de toda la economía destino. |
| 23 | Publicación parcial | No mejora en el experimento estudiado; retirado como problema separado. |
| 24 | Revelaciones falsas | Alternativa (h), retirada del inventario activo del núcleo. |
| 25 | Revelación tardía predecible | Regla vulnerable retirada; cierre documental de esa alternativa. |
| 26 | Todo honesto conoce victorias futuras | Premisa refutada en el submodelo secuencial; retirada como problema. |
| 27 | AES 19× imposible | Afirmación de imposibilidad retirada; hardware pendiente en 38. |
| 28 | Cliente ligero | Pendiente secundario; no imposibilidad universal demostrada. |
| 29 | PoT no sucinto | Coste del kernel identificado; integración y presupuesto pendientes. |
| 30 | Umbral estructural <50 % | Retirada la afirmación universal; prueba de seguridad sigue pendiente. |
| 31 | Suelo universal 100–134 s | Afirmación retirada; política de aceptación por demostrar. |
| 32 | Centralización del reloj | Pendiente operativo y de hardware. |
| 33 | Coinbases anuales | Magnitud nominal, retirada como defecto independiente; calendario/estado pendientes. |
| 34 | Poda | Pendiente de diseño, disponibilidad e integración. |
| 35 | Δ real | Pendiente de medición en red destino. |
| 36 | Convergencia del orden | Pendiente crítico; sin etiqueta infundada de «riesgo bajo». |
| 37 | Ventaja inicial | Pendiente justificar su aplicación a T1, no solo medirla. |
| 38 | Ventaja ASIC AES | Pendiente de cota/evidencia localizada y hardware de referencia. |
| 39 | Compresión de parcelas | Pendiente de modelo y coste de regeneración. |
| 40 | BDK/soborno en espacio | Pendiente de modelo económico compuesto. |
| 41 | Menú y retención | Clausura de publicación corregida en un instrumento; menús anteriores no revalidados. |
| 42 | Resolución de W_dec | Pendiente de cobertura/cota más allá de la búsqueda finita. |
| 43 | Unidades de la pinza | Notación cerrada documentalmente; demostración BDK pendiente. |
| 44 | Retardo alto y parásita | Pendiente bajo un presupuesto adversario coherente. |
| 45 | Más de quince puntas | Pendiente de cobertura con el algoritmo completo de padres. |
| 46 | Precios supuestos | Pendiente; no publicar margen económico como garantía actual. |
| 47 | Parásita y copias | Pendiente reforzado por la laguna de identidad pagable. |
| 48 | Incentivo de fusión | Pendiente; 5 % no es decisión ni resultado validado. |
| 49 | Fusiones fuera de ventana | Pendiente, separado de deduplicación. |
| 50 | Conteo frente a peso | Pendiente; retirada la certificación antigua de error. |
| 51 | BDK en índices | Pendiente de prueba; notación común no basta. |
| 52 | DoS contado como hashes | Premisa heredada corregida en C-NET-03/04; presupuesto PoT pendiente. |
| 53 | Separar L de F | Pendiente de adopción/calibración; L1h es candidato. |
| 54 | ρ y segundo candado | Pendiente conjunto; (h) es alternativa. |
| 55 | F de producción | Pendiente; F2h sigue provisional. |
| 56 | k con margen | Informe 11a disponible; elección final pendiente. |
| 57 | Cierre de P-038 | Propuesta sin completar; pendientes actuales en SPEC §17. |
| 58 | Comité de finalidad | Descartado por alcance; confirmación adaptativa se trata aparte. |

Fuentes: [informe de problemas, apartados homónimos][problemas], [ancla y enmiendas][ancla], [SPEC, §§7, 11–13, 16.1 y 17][spec] y [modelo, §§6–7][modelo]. Los cierres 53–58 de la hoja no sustituyen ese registro local.

</details>

<details>
<summary><strong>Decisiones y alternativas: qué sigue teniendo vigencia</strong></summary>

| Tema de la hoja anterior | Tratamiento actual |
|---|---|
| P-038 abierta / P-041 cerrada / P-042 abierta / P-043 cerrada | Se conserva la referencia histórica; el estado utilizable se expresa por trabajo en SPEC §17. Las constantes de P-041 están aplicadas; DAG, rendimiento, aplicaciones y aceptación no están completos; los comités están excluidos. No se consulta DECISIONES del vault para resolver estados. |
| A + C | C sigue siendo política elegida por el comercio. La confirmación adaptativa requiere prueba y comparación válida; «baseline + C» no convierte la tabla histórica en garantía lista para usar. |
| Suelo y ventana de 6 h | Constantes elegidas. El descenso nominal de recompensa de **≈56×** ya no arrastra la tarifa bajo el suelo; no equivale a haber completado la auditoría adversarial. |
| Ventana anual, 180/90/30 días, cubos y tarifa con otra mediana | Alternativas históricas no adoptadas. **5,5 años de recuperación** corresponde al modelo de ventana anual; no es un problema activo de N_LARGO21 600. [SPEC, §§5.5 y 6.5][spec] |
| Muestreo de una altura de cada 120 | Retirado: el experimento señalaba una palanca **120×** al conocerse qué alturas cuentan. No es la política vigente. [Recalibración, §5][recalibracion] |
| N_CORTO de 100/300/500/998/999/3 000/12 000 | Barridos históricos, no decisiones pendientes. **1 000** está elegido; las **5 h** y las frecuencias de captura pertenecen a esos escenarios. «Nunca al 33–40 %» no es una garantía matemática de probabilidad cero. [SPEC, §6.5][spec] |
| Zona libre de 200 000/448 000; antispam 4×/20× más barato | Alternativas anteriores al suelo. Los factores salen de tarifa proporcional a `1/Mf²`; con suelo absoluto fijo no se generalizan a toda mediana/configuración. Se conserva **100 000**. [Recalibración, §4][recalibracion]; [SPEC, §5.5][spec] |
| Más de 72 tx/s, más bloques, Sealevel, todo el marketplace en cadena | 72 es un presupuesto hipotético de disco, no una prohibición de consenso. Las proyecciones de CPU/red no bastan para declarar inútil toda optimización ni viable el objetivo completo. |
| Dominios, agregación, Erlay y canales | Líneas históricas de trabajo. No hay cifras de ahorro ni integración acreditadas aquí. Una arquitectura de dominios que requiera staking no se adopta por citar Autonomys. |
| ChaCha/XChaCha, «VDF aleatorizado», segundo candado | Se mantiene el PoT AES de referencia; alternativas y argumentos históricos en [hardware][aes] y R-FIN-14. No se eleva la frase «no existe esa categoría» a un teorema ni se presenta (h) como núcleo activo. |
| PoW+PoS, Decred/Peercoin y reparto 60/30/10→1/89/10 | Fuera del alcance elegido. Los porcentajes comparativos se retiran de esta referencia: no justifican parámetros de ZEROX ni aportan una medición comparable. |

</details>

<details>
<summary><strong>Comparación externa: correcciones a la tabla anterior</strong></summary>

Fuentes públicas primarias consultadas el **11 de septiembre de 2026**. No se conserva una clasificación por «tx/s reales»: mezclaba observaciones sin ventana/fecha, techos teóricos y objetivos de un nodo aún sin implementar. Ninguna de estas filas compara seguridad a igual ε y adversario.

| Red / cifra anterior | Qué puede respaldarse |
|---|---|
| Bitcoin: **≈7 tx/s; ≈60 min; ASIC para participar** | 7 tx/s no está acreditado como medición actual homogénea. La guía describe **seis confirmaciones y aproximadamente una hora** como convención de aceptación, con riesgo residual; operar un nodo verificador y minar son roles distintos. [Guía de pagos](https://developer.bitcoin.org/devguide/payment_processing.html), [nodos y bloques](https://developer.bitcoin.org/devguide/block_chain.html?highlight=consensus). |
| Cardano: **0,41 tx/s; minutos–horas** | Se retira 0,41: falta dataset, ventana y definición comparable. La documentación distingue confirmación de cadena, de transacción y umbral de aceptación según riesgo; no ofrece ese número como capacidad fija. [Cardano Docs](https://docs.cardano.org/about-cardano/learn/chain-confirmation-versus-transaction-confirmation). |
| Solana: **1 000–4 000 tx/s; 384 GB; 34 000 USD/año** | No se acredita ese rango como medición con filtro de votos y ventana común. Agave recomienda **256 GB o más** para validador y registra hasta **1,1 SOL/día** en votos; convertirlo a USD requiere precio y fecha. RPC distingue `processed`, `confirmed` y `finalized`: «segundos» no especifica cuál. [Requisitos Agave](https://docs.anza.xyz/operations/requirements), [niveles de confirmación](https://solana.com/docs/rpc). |
| Filecoin F3: **decenas de segundos** | Es la expectativa descrita para operación normal de F3, con GossiPBFT y certificados ponderados por potencia; no una cota incondicional ni una medición de ZEROX. [FIP-0086, resumen y modelo adversarial](https://github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0086.md). |
| ZEROX: **285 / 28 571 tx/s; 2 h / 8–56 s; PC+SSD, nada que comprar** | Sustituido por las tablas de esta hoja: capacidad hipotética, seguridad pendiente y roles con costes distintos. No hay un benchmark de nodo PoST + DAG que permita compararlo de ese modo. |

</details>

### Alcance de esta revisión y mantenimiento

Se contrastaron constantes, fórmulas, reglas, código, informes y salidas conservadas; se ejecutaron las comprobaciones de código indicadas. **No se ejecutaron auditorías Python ni nuevas simulaciones o benchmarks matemáticos.** «D/M histórica» significa procedencia revisada, no recálculo certificado. Los valores que no se pueden acreditar se corrigen de alcance o se retiran, sin sustituirlos por cifras inventadas.

La huella del SPEC revisado es:

```text
SHA-256 SPEC.md
2d1d5453fcf79281c49cd9e19ea7f299819bba93465f93dceb84e95602c1b5de
```

Si cambian el SPEC, las constantes, el formato, las features o el modelo, revisar las filas afectadas y fechar de nuevo sus comprobaciones. Hay comentarios históricos residuales en fuentes —por ejemplo, 350 B frente a peso 307 o una «ventana anual» frente a la constante 21 600—: esta hoja sigue la fórmula/regla y declara la discrepancia. Cambiar documentación no equivale a cerrar la migración.

### Fuentes de referencia

[SPEC][spec] · [Migración][migracion] · [Modelo de finalidad, revisión 2][modelo] · [Índice de investigación][investigacion] · [Proceso de auditoría Veritas][lineo]

[spec]: SPEC.md
[readme]: README.md
[migracion]: MIGRACION.md
[modelo]: veritas/finalidad/baseline-30m/MODELO.md
[investigacion]: research/README.md
[lineo]: veritas/LINEO.md
[ancla]: research/dag-poas-ancla-de-orden.md
[r10c]: research/scripts/d9-ronda10c/informe.md
[r9a]: research/scripts/d9-ronda9a/informe.md
[r9c]: research/scripts/d9-ronda9c/informe.md
[r10b]: research/scripts/d9-ronda10b/informe.md
[r10apot]: research/scripts/d8-ronda10a/salida_b2.txt
[r11a]: research/scripts/d9-ronda11a/informe.md
[r11b]: research/scripts/d8-ronda11b/informe.md
[r13]: research/scripts/d13-finalidad/informe.md
[r14]: research/scripts/d14-dagknight/informe3.md
[r16]: research/scripts/d16-gate/informe.md
[catalogo]: research/dag-poas-catalogo-problemas-ataques.md
[empalme]: research/dag-poas-empalme-peso.md
[r12salida]: research/scripts/d12-quorum/salida_b.txt
[recalibracion]: research/recalibrado-constantes-lambda1.md
[palancas]: research/dag-poas-palancas-rendimiento.md
[rafaga]: research/scripts/rendimiento/verif_n_corto_exacto.py
[presupuesto]: research/scripts/finalidad-espacio/verif_rendimiento.py
[problemas]: research/dag-poas-informe-52-problemas.md
[comite]: research/dag-poas-capa-finalidad.md
[aes]: research/pot-aes-asic-chacha.md
[timelord]: research/timelord-redundancia-informe.md
[pot]: prototipos/pot-estable/LEEME.md
[orchard]: research/orchard-bundle.md
[costesalto]: veritas/rendimiento/coste-salto-v1/resultados/RESUMEN.md
[emision]: crates/zx-consensus/src/emision.rs
[peso]: crates/zx-consensus/src/peso.rs
[tarifas]: crates/zx-mempool/src/tarifa.rs
[cabecera]: crates/zx-core/src/preimage/block.rs
[cargo]: Cargo.toml
[lock]: Cargo.lock
