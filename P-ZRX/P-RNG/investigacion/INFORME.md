No existe hoy un mecanismo conocido que dé a ZEROX un coste irrecuperable comparable al de PoW para todas las ramas sin violar sus valores; la opción viable es encarecer ataques concretos con compromiso previo, edad y recompensas propias condicionadas a permanencia, manteniendo PoT como coste temporal.

# P-RNG — El recurso no se gasta

## Resultado, alcance y etiquetas

**[Propuesta propia, no decisión de Katana.]** No buscaría una constante mágica de caducidad ni una
«prueba de desgaste» física. Recomiendo estudiar **B+H**, donde H aplica la idea D de garantía solo
a recompensas propias:

1. compromiso previo verificable de la parcela completa y activación con edad;
2. una parte de las recompensas ya ganadas que permanezca condicionada a pruebas futuras de esa
   parcela; y
3. altas/renovaciones agrupadas para que el coste fijo no expulse al granjero doméstico.

Esa combinación pone precio al **alquiler corto**, al **sembrador** y a abandonar el almacenamiento.
No vuelve exclusivo el espacio entre ramas, no elimina el *grinding* privado y no hace que un atacante
dispuesto a perder el doble gasto tema perder recompensas pequeñas. Es una defensa por ataque, no un
equivalente universal de la energía de PoW.

Etiquetas usadas: **[demostrado]** es una consecuencia lógica bajo supuestos explícitos;
**[verificado en fuente]** procede de una fuente abierta; **[medido]** conserva el alcance del
instrumento citado; **[derivado]** es álgebra simbólica; **[estimado]**, **[propuesto]** y
**[no determinado]** tienen su significado literal. No se hizo una simulación ni un cálculo numérico
nuevo.

## 1. La métrica: conservar `C_irr`, pero no esconder la contingencia

### 1.1 Variables y adversario

Sea, para cada sistema, `R_h` la cantidad de su recurso honesto y
`R_a=αR_h/(1−α)` la cantidad que debe añadir el atacante para terminar con cuota `α`. Para espacio
escribo `R=B`:

- `B_h` [bytes] el recurso honesto activo;
- `α∈(0,1)` la fracción de influencia del atacante después de añadir su recurso;
- `B_a = α B_h/(1−α)` [bytes] cuando influencia y bytes son proporcionales;
- `T` [s o slots, siempre indicado] la duración del ataque;
- `a(t)` [slots] la edad demostrada del recurso;
- `q_f` [adimensional] la probabilidad, bajo el modelo declarado, de que una conducta genere una
  prueba incluida y ejecutada antes de liberar la garantía;
- `D_f` [moneda] la pérdida máxima ejecutable mediante esa prueba.

**[Derivado.]** La influencia-tiempo es

```text
I(α,T) = ∫₀ᵀ α_efectiva(t) dt;       si α_efectiva es constante, I = αT.
```

Descompongo el coste del atacante en:

```text
C_irr(α,T) = C_inevitable(α,T) + q_f · D_f(α,T)
c_irr(α,T) = C_irr(α,T) / I(α,T)
C_certeza(α,T) = C_inevitable(α,T).
```

`C_inevitable` incluye alquiler pagado, energía consumida, escrituras/desgaste ya causados y coste de
oportunidad no recuperable durante `T`. No incluye el precio íntegro de hardware que se conserva ni
una fianza que se devuelve. `q_f·D_f` se informa aparte: poner `q_f=1` sin una prueba de fraude corta,
observable e incluible sería inventar seguridad.

Formalmente, para una estrategia y el conjunto de desenlaces admisibles, `C_inevitable` es el ínfimo
del coste privado sobre esos desenlaces; `C_irr` es el coste esperado cuando se añade la pérdida
contingente. El principal de una fianza se informa como **capital en riesgo**, no como pérdida; solo
su financiación/liquidez entra siempre en `C_inevitable`.

Para decidir si un mecanismo **pone precio al ataque**, hace falta además el contrafactual, con la
misma capacidad, horizonte y escenario:

```text
ΔC_irr^ataque = C_irr(estrategia atacante) − C_irr(mejor uso honesto del mismo recurso).
```

**[Derivado.]** Caducidad, operación o una quema uniforme pueden elevar el coste bruto y dejar
`ΔC_irr^ataque≈0`; en ese caso son mantenimiento del recurso, no seguridad específica. Se informan
ambos. Tampoco se netean recompensas dentro del coste físico: el resultado económico neto va aparte
como `N = C_privado − ingresos`.

**[Corrección al encargo.]** Esta separación es necesaria: la electricidad de un hash ya ejecutado se
pierde con certeza; una fianza solo se pierde si la infracción entra en el conjunto demostrable. El
coste hundido de preparar una parcela tampoco es el precio de comprar el disco: es la energía,
depreciación y oportunidad que no se recuperan aunque la parcela o el disco se revendan.

### 1.2 Instancias comparables

| Sistema | `C_inevitable(α,T)` como función | `q_f·D_f` | Qué sigue reutilizable |
|---|---|---|---|
| PoW | `p_e·η_hash·H_a·T + alquiler_hw(H_a,T) + desgaste_hw`, con `H_a=αH_h/(1−α)` | normalmente 0 | ASIC/hardware; **no** los hashes ya hechos. Para `S` ramas, `ΣH_i≤H_a` |
| PoS | operación + financiación/oportunidad de la fianza durante `T` | `q_f·min(fianza, penalización)` | la moneda si no hay prueba; claves antiguas sin fianza pueden tener `D_f=0` |
| Chia | alquiler de `B_a` + energía de VDF/auditoría + parte no amortizada de ploteo | no hay una confiscación general del plot | el plot durante años y el mismo plot frente a retos de ramas; el Green Paper reconoce el *double dipping* con factor 1,47 bajo sus parámetros |
| Filecoin | sellado único por réplica + WindowPoSt + energía/escrituras | pledge y recompensas no consolidadas sujetos a fallos | hardware y, tras cumplir, colateral; la réplica está ligada a sector/cadena |
| ZEROX hoy | fórmula de abajo: alquiler + PoT por flujo + resembrados que realmente caigan dentro de `T` | 0 como regla general | disco, sector vigente y sector usado a la vez en varios flujos |

Con precios y tecnologías siempre versionados, la misma tabla se escribe:

```text
PoW:
  C_certeza = p_e·ε_hash·H_a·T + alquiler_hash(H_a,T) + depreciación_realizada

PoS:
  C_certeza = operación(T) + tasa_financiación·Stake_a·T
  C_contingente = q_f·min(Stake_a, slash_máximo)

Chia:
  C_certeza = 1_nuevo·κ_plot·B_a + alquiler_plot(B_a,T)
              + p_e·E_VDF(T) + operación_y_desgaste(B_a,T)

Filecoin:
  C_certeza = 1_nuevo·κ_sell·B_a + operación_WindowPoSt(B_a,T)
              + tasa_financiación·pledge_a·T
  C_contingente = q_f·(pledge_confiscable + recompensa_no_consolidada)

SpaceMint:
  C_certeza = 1_nuevo·κ_init·B_a + operación(B_a,T)
  C_contingente = q_misma_prueba·recompensa_inmadura
```

`1_nuevo` vale uno solo cuando el ataque necesita crear capacidad nueva. Si alquila capacidad ya
preparada vale cero y aparece el alquiler; no se cuentan a la vez el coste histórico íntegro del
propietario y la renta pagada por el atacante. En PoS/Filecoin el principal bloqueado no es pérdida
cierta. En SpaceMint `q_misma_prueba=0` para retos distintos o una rama privada que no publica la
evidencia incriminatoria.

Fuentes primarias: el [Green Paper de Chia](https://docs.chia.net/files/ChiaGreenPaper_20241008.pdf)
explica que probar tras plotear es barato, el ataque de *replotting*, `1,47` y el uso de VDF frente a
historias sin coste (§§1.1, 1.8.3, 2.2–2.3); la [especificación de sellado de
Filecoin](https://spec.filecoin.io/systems/filecoin_mining/sector/sealing/) separa `CommD`, `CommR`,
PoRep y aleatoriedad de cadena; [WindowPoSt](https://github.com/filecoin-project/filecoin-docs/blob/main/storage-providers/filecoin-economics/storage-proving.md)
audita continuidad; y la [especificación de colateral](https://spec.filecoin.io/systems/filecoin_mining/miner_collaterals/)
combina pledge inicial y recompensas no consolidadas. Filecoin exige moneda inicial y por eso no es
trasladable entero a ZEROX.

Para ZEROX, sea `ℓ(s,h)=VIDA_MINIMA_BLOQUES+desplazamiento(s,h)` [bloques], `r` la vida residual al
inicio, `n_exp(T,r,ℓ)` el número de expiraciones durante el ataque, `c_p` [moneda/byte] el coste
irrecuperable medido de resembrar y `c_w` [moneda/byte] su desgaste:

```text
C_inevitable^Z(α,T)
 = alquiler(B_a,T)
 + energía_PoT(n_flujos,T)
 + B_a · n_exp(T,r,ℓ) · (c_p + c_w)
 + operación(B_a,T).
```

**[Demostrado respecto de las reglas escritas.]** Si `T<r`, el término de caducidad es cero. Además,
el productor puede moler `altura_ploteo` hacia la vida máxima; `SPEC.md:1907-1961` lo declara
expresamente. Por ello C-EXP es desgaste recurrente de largo plazo, no un precio garantizado para un
alquiler de horas. El PoT sí consume cómputo secuencial por flujo, pero no es proporcional a los bytes
y el mismo `B_a` se audita contra varios flujos.

## 2. Taxonomía: qué nace de que el recurso siga ahí

| Ataque | Evidencia abierta | Por qué comparte la raíz | Irrecuperable hoy | Recuperable/reutilizable hoy |
|---|---|---|---|---|
| Multistream / *double dipping* | `research/dag-poas-auditoria.md:352-359`; Chia Green Paper §2.2 | los mismos sectores responden a `S` retos | CPU/energía del PoT y lecturas de cada flujo | todos los bytes; cero espacio adicional. La construcción histórica da `Sα/(1−α+Sα)` bajo su regla aditiva; `P-2.1/SINTESIS.md:18-21` advierte que esa cifra no se traslada a C-FLU |
| Cobertura racional de flujos | `P-PUERTA/veritas/consenso/puerta-cobertura-v1/INFORME.md:232-260` | una granja puede auditar más de una lotería sin duplicar el plot | coste fijo de abrir/verificar/producir PoT y lecturas | parcela completa; el coste fijo vuelve la medida regresiva para granjas pequeñas |
| *Grinding* de ancla, contenido, sello o padres | `research/dag-poas-catalogo-problemas-ataques.md:19-30`; `SPEC.md:937-966` | evaluar candidatos privados o variar un bloque cuesta poco tras hallar billete | PoT adelantado, oportunidad de recompensas retenidas, CPU | parcela y candidatos no publicados; algunas vías están cerradas por desempate/distancia, no toda elección privada |
| Soborno del ancla | `research/dag-poas-catalogo-problemas-ataques.md:22`; `research/dag-poas-informe-52-problemas.md:278-298` | el sobornado no destruye su recurso al probar otra conducta | coinbase a la que renuncia si su bloque pierde; soborno pagado | espacio y clave; rentabilidad final está sin modelar |
| Historia alternativa / largo alcance | Chia Green Paper §2.3; `research/dag-poas-informe-52-problemas.md:204-242` | reusar parcelas no reconstruye su coste histórico | PoT secuencial de la rama, energía y renta durante `T` | sectores; lo frena PoT/finalidad, no desgaste del espacio |
| Alquiler corto de espacio | `research/dag-poas-informe-52-problemas.md:232-235` | la capacidad vuelve intacta al arrendador | renta, operación y PoT del intervalo | discos y, si se transfieren claves/plots válidos, parcelas; no hay mercado medido ni prueba de que el alquiler sea disponible |
| Doble firma / copia de billete | `SPEC.md:1701-1707` | una solución puede envolverse en varios bloques sin rehacer espacio | oportunidad de cobro: solo una copia pagable | sector; U2/U3″ limita peso/pago, no crea desgaste físico |
| Partición de flujo | `P-FLUJO/propuesta/PROPUESTA-SPEC.md:1147-1169` | ambos lados siguen explotando el mismo tipo de capacidad | PoT/operación en cada lado y recompensas perdidas | parcelas; la propuesta declara que, si nace, no hay cura protocolaria |

**[Alcance vigente.]** C-FLU-13/14 propuestos buscan cerrar la suma multistream mediante validez
absoluta y prohibición de referencias cruzadas; el precio es que los flujos no se fusionan. Por
tanto, `1/(S+1)` no es el umbral del destino decidido. Además, la revisión 4 de
`P-FLUJO/propuesta/PROPUESTA-SPEC.md:130-205` retira la prueba de “ventana de adopción vacía”, pero
varias reglas posteriores (`:1167-1172,1249-1274`) conservan razonamientos de la versión anterior.
La decisión superior sigue siendo no añadir una regla de adopción; el texto de propuesta debe
sincronizarse antes de trasladarlo al SPEC.

**[Verificado en fuente.]** SpaceMint formuló en 2015 exactamente la familia “pruebas baratas ⇒
minar varias cadenas” y propuso compromiso previo más transacciones de penalización; su prueba de
infracción son dos bloques con la misma prueba. El propio paper limita la defensa: retos distintos
producen pruebas distintas y un doble gasto puede ser rentable aunque se pierdan recompensas
([SpaceMint, §§3.1, 3.3 y 4](https://eprint.iacr.org/2015/528.pdf)). Esto anticipa el límite de D.

## 3. Comparación ejecutiva de soluciones

| Familia | Veredicto | Ataques que encarece | No toca | Coste distributivo | Compatibilidad Autonomys/ZEROX |
|---|---|---|---|---|---|
| A. Caducidad más corta | **mitiga ×N**, condicionado a medir `c_p,c_w` | alquiler que cruza expiración; persistencia larga | multistream durante vida, grinding corto, soborno | regresiva: el doméstico paga las mismas escrituras por byte y suele tener menos amortización | alta en formato, baja en calendario DAG; C-EXP ya existe |
| B. Antigüedad demostrada | **pone precio** a entrada súbita si hay compromiso completo previo | alquiler por horas, sembrador, capacidad relámpago | multistream de capacidad ya madura; adversario preposicionado | espera de entrada; el estado fijo por parcela perjudica más al pequeño si no se agrupa | media-baja: alta/acumulador y apertura nuevos; no basta `altura_ploteo` |
| C. Sellado costoso/secuencial | **mitiga ×N**; solo pone precio por rama si el sello es de rama | sembrador y, si se liga a ancestry, historia alternativa | multistream si el sello es reutilizable | riesgo alto de GPU/ASIC y energía de alta | baja: cambia parcela/prueba; precedente Filecoin, no sustitución directa |
| D. Fianza de recompensas propias | **pone precio contingente** a fraudes demostrables | infracción objetiva aún por definir; abandono si se condiciona el pago | retos distintos, claves desechables sin saldo, doble gasto mayor que la fianza | progresiva al principio; no exige comprar moneda; retrasa liquidez | media: exige locks/estado y calendario DAG; puede aprovechar madurez, que hoy solo retrasa gasto |
| E. Exclusividad física | **no sirve** con clave/sector actual | ninguna de forma general | toda reutilización entre ramas | una parcela ligada a rama obliga a replotear por bifurcación | incompatible salvo rediseño sustancial |
| F. Trabajo pequeño por bloque | **pone precio**, proporcional al trabajo fijado | todas las ramas, grinding y largo alcance | alquiler de espacio como tal | electricidad continua, pools/ASIC; si es pequeño acaba simbólico | baja-media: nuevo peso/prueba y análisis híbrido |
| G. Detección/identidad/cota `ρ` | **no sirve** como coste universal | observabilidad y algunos abusos | Sybil, `ρ>1` como acantilado, ataque no publicado | falsos positivos y coste fijo regresivo | superficialmente alta, seguridad baja |
| H. Activación periódica + permanencia de recompensa | **pone precio** a capacidad efímera; propuesta preferida junto a B | alquiler corto, sembrador, borrar ganador | multistream del mismo compromiso, atacante sin interés en cobrar | espera y disponibilidad; agrupación puede contener coste fijo | media-baja; patrón Spacemesh/Filecoin, usando PoT propio |
| I. Quemar una fracción fija de toda recompensa | **no sirve** como defensa | reduce rentabilidad ordinaria | ataque externo a recompensas y reutilización de ramas | impuesto universal, no selectivo | alta, pero equivale a bajar emisión neta |

`N` nunca se fija aquí: es una razón medida entre el coste bajo reglas candidatas y el coste base,
comparados bajo el mismo ataque y riesgo.

## 4. Fichas por candidata

### A — Desgaste por caducidad

**Mecanismo [existente/propuesto].** C-EXP hace expirar cada sector y obliga a resembrarlo. Acortar su
vida eleva `n_exp(T,r,ℓ)`; cambiar solo `DISPERSION_BLOQUES` no garantiza la media porque el granjero
puede moler el desplazamiento.

**Ataques y `C_irr` [derivado].** Añade `ΔC_irr=B_a·Δn_exp·(c_p+c_w)`. Encarece únicamente ataques
que atraviesen expiraciones. No impide usar el sector en `S` ramas antes de caducar y no cobra al
alquiler con vida residual `r>T`. Veredicto: **mitiga ×N**, no “pone precio” universal.

Frente a cultivar honestamente los mismos bytes, ambos resembrarían: salvo que el ataque fuerce una
renovación adicional, `ΔC_irr^ataque≈0`. C-EXP crea coste bruto recurrente, no un castigo selectivo.

**Quién paga y coste sistémico [no determinado].** Atacante, doméstico y granja pagan por byte; la
granja amortiza GPU, lotes y sustituciones mejor, por lo que una vida corta es previsiblemente
regresiva. Aumenta energía de ploteo, escrituras, TBW de SSD, tráfico de historia y churn. Deben
medirse julios/TiB, bytes escritos/TiB, tiempo/TiB, distribución de `r` y fallos domésticos.

**Reaperturas/compatibilidad.** Conserva el formato Autonomys pero exige cerrar altura/calendario DAG,
finalidad y el grinding de `altura_ploteo`. Combina con B/H; no sustituye D ni PoT.

### B — Espacio ponderado por antigüedad demostrada

**Mecanismo [propuesto].** Una transacción registra antes del reto una raíz, versión, cardinalidad,
historia y dominio de codificación de la parcela completa. Tras edad `M`, su peso usa una función
`w(a)∈[0,1]`, monótona, sin fijarla aquí. La solución abre la pieza contra la raíz registrada.

**Ataques y `C_irr` [derivado].** Para capacidad atacante de edad `a`,

```text
α_efectiva(a) = α·w(a) / ((1−α)·w_h + α·w(a)).
```

Alquilar capacidad recién activada compra menos influencia; obtener `α_efectiva` exige más bytes o
esperar `M`, pagando preposición/alquiler. Encarece alquiler corto y sembrador. No afecta a espacio
maduro comprado/alquilado, ni impide que una raíz madura trabaje en varias ramas.

**Quién paga y coste sistémico.** El recién llegado doméstico espera igual que la granja, pero un
gran operador puede mantener inventario maduro: hay ventaja de incumbencia. La cadena paga altas,
bajas/acumulador y disponibilidad de testigos; el nodo paga estado y verificación. Bytes y CPU:
**[no determinados]** hasta diseñar acumulador y lote.

**Reaperturas/compatibilidad/evidencia.** Revoca “sin registro de sectores”, toca poda, solución y
posiblemente cabecera, aunque el alta puede vivir en una transacción. `P-SEMBRADOR/investigacion/INFORME.md:7-13,142-152`
demuestra que `history_size`/`altura_ploteo` no fechan los bytes y propone esta misma raíz. SpaceMint
registraba `(pk,γ)` antes de minar; Spacemesh incluye NIPoST en una ATX para la época siguiente
([protocolo](https://github.com/spacemeshos/protocol),
[NIPoST](https://github.com/spacemeshos/protocol/blob/master/nipost.md)). Hay que medir altas/s,
estado/TiB, prueba/solución, edad segura y concentración.

### C — Sellado costoso o secuencial por sector

**Mecanismo [propuesto].** Codificar cada sector en una réplica única ligada a un ticket previo y a
todos sus bytes mediante una ruta con coste verificable. Una prueba sucinta acredita el sellado.

**Ataques y `C_irr`.** Un sello reutilizable añade una sola vez `B_nuevo·c_sell`; encarece sembrador
y alta repentina, no multistream. Un sello ligado a cada ancestry añadiría aproximadamente
`Σ_ramas B_r·c_sell`, la propiedad buscada, pero obliga también al honesto a re-sellar ante una
bifurcación y hace incompatible la parcela persistente. Veredicto: **mitiga ×N** en su forma viable;
la forma exclusiva es **no viable hoy**.

**Quién paga/coste.** El pequeño carece de paralelismo y hardware dedicado; una función secuencial
puede igualar paralelismo pero no ventaja ASIC. Consume energía/escrituras al alta. Nodo/cadena pagan
prueba y compromiso. Todo tamaño y tiempo es **[no determinado]**.

**Reaperturas/compatibilidad/evidencia.** Cambia `proof_of_space`, parcela y migración. Filecoin hace
un PoRep intensivo con `CommD/CommR` y mezcla aleatoriedad de cadena para que una rama histórica tenga
que regenerar réplicas posteriores; también exige pledge comprado, que ZEROX rechaza. Debe medirse
ruta adversarial CPU/GPU/FPGA/ASIC, memoria, energía, prueba y regeneración.

### D — Fianza de recompensas propias

**Mecanismo [propuesto].** Una parte de coinbases ya ganadas queda en un lock asociado a la clave o,
mejor, al compromiso de parcela. Una prueba de fraude antes del desbloqueo quema o reasigna hasta
`D_f`. El participante nuevo no compra monedas: comienza sin fianza y la acumula al ganar.

**Ataques y `C_irr`.** Añade `q_f·min(D_f,V_bloqueado)`. Dos cabeceras firmadas pueden aportar una
prueba corta solo para una conducta que el protocolo prohíba inequívocamente. Hoy no puede declararse
fraude el mero uso del mismo billete en ramas competidoras: `SPEC.md:1302-1312` reconstruye el
contexto tras reorg y vuelve disponible el billete de la historia abandonada. No son prueba corta dos
retos distintos de flujos distintos; tampoco una rama privada nunca publicada. Claves nuevas evitan
deuda futura y un doble gasto mayor que `D_f` sigue siendo rentable. Veredicto: **pone precio
contingente** únicamente después de definir una infracción más estrecha, no desgaste cierto.

**Quién paga/coste.** Reduce liquidez de quien ya cobró, no el acceso inicial; puede ser menos
regresiva que hardware nuevo. El productor doméstico con red inestable necesita una conducta
demostrable, no una estadística. Nodo/cadena pagan locks, índice y prueba. `COINBASE_MATURITY=12 000`
(`SPEC.md:1499-1504,1609-1610`) solo impide gastar; no autoriza confiscar ni fija un plazo DAG.

**Reaperturas/compatibilidad/evidencia.** Cambia scripts/locks, emisión efectiva, reorg y vínculo de
la recompensa con el billete; no debe añadir la dirección a cabecera (C-HDR-08). SpaceMint retuvo
recompensas y penalizó la misma prueba en dos bloques sin depósito previo, pero reconoce que no
cubre retos distintos ni un doble gasto rentable. Filecoin usa recompensas no consolidadas, pero
además exige pledge inicial. Combina con B/H para que la clave desechable no borre toda continuidad.

### E — Exclusividad física del recurso

**Mecanismo examinado.** Hacer que los mismos bytes no puedan producir influencia en dos ramas.

**Ataques y `C_irr` [demostrado bajo la interfaz actual].** Exclusividad por clave o identidad no
funciona: dividir bytes entre identidades cuesta lo mismo y las identidades son gratis
(`research/dag-poas-balizas-auditoria.md:66-75`). Exclusividad por flujo ya fue descartada: para ligar
bytes a un flujo futuro hay que replotear al cambiar la inyección. Un compromiso previo prueba
existencia/edad, no impide leer los mismos bytes dos veces. Veredicto: **no sirve** sin una nueva
primitiva de recurso consumible o sellado de ancestry.

**Quién paga/coste/reaperturas.** El rediseño que sí la haría cierta cobra al honesto cada fork,
castiga red lenta y particiones, cambia parcela, reto, cabecera y migración. Choca directamente con
C-FLU y el carácter doméstico. No hay medición que justifique abrir esa ruta.

### F — Una pata de trabajo por bloque

**Mecanismo [propuesto para evaluar, no recomendado].** Cada bloque incluye PoW con trabajo objetivo
`W_b`; cada intento está ligado a una cabecera/ramificación concreta.

**Ataques y `C_irr` [derivado].** Añade

```text
ΔC_irr = p_e · e_hash · W_b · N_bloques_adversarios
```

y el presupuesto de hash se divide entre ramas. Es la única candidata examinada que reproduce
directamente la no reutilización de un hash. Encarece multistream, grinding e historia alternativa;
no evita alquilar espacio y no prueba disponibilidad archivística.

**Por qué no acabaría simbólica.** Solo hay dos casos: (i) el fork choice/validez exige una fracción
de trabajo suficiente para decidir ataques, y entonces deja de ser “pequeña”, consume energía y
favorece ASIC/pools; o (ii) es pequeña, y un atacante cuyo beneficio supera ese presupuesto la paga,
mientras la seguridad sigue descansando en PoAS/PoT. No hay una tercera garantía algebraica. Ese es
el mismo riesgo estructural por el que ZEROX descartó híbridos; no uso aquí cifras no verificadas de
Decred o Peercoin.

**Quién paga/coste/reaperturas.** Coste continuo para todos, no solo para el atacante; electricidad,
silicio especializado, pool centralization y nueva dificultad/peso/cabecera. Viola “conservar en lo
posible” la virtud energética. Veredicto: **pone precio**, pero no satisface conjuntamente §2.

### G — Lo que no basta

**Mecanismos.** Detección estadística, cuotas por identidad, penalizar mera rareza, o declarar una
cota de velocidad del reloj.

**Resultado.** Una estadística no demuestra doble firma ni fecha física y produce falsos positivos;
el Sybil derrota cuotas; el coste de abrir flujos no desaparece pero es fijo y por eso discrimina al
pequeño; y `ρ>1` abre el adelanto del sembrador como acantilado, no como degradación suave
(`P-SEMBRADOR/investigacion/INFORME.md:83-108`). Veredicto: **no sirve** como `C_irr`; solo sirve como
telemetría, límite DoS o supuesto explícito.

### H — Activación periódica y permanencia de recompensas propias

**Mecanismo [propuesto, combinación B+D].** Antes de una época, un lote registra su raíz completa.
Tras edad `M` entra con peso; cada recompensa del lote se libera por tramos solo si retos futuros,
impredecibles y cercanos a su fecha, demuestran que el compromiso sigue disponible. No hay depósito
comprado; la garantía máxima son recompensas de ese lote.

**Ataques y `C_irr`.** El alquiler corto debe cubrir espera + época + auditorías; borrar el ganador
arriesga `q_fD_f`; el sembrador ya no puede registrar después de ver el reto. No evita usar el lote
activo en varios flujos, ni castiga intentos fallidos nunca registrados, ni a quien sacrifica todas
las recompensas por un doble gasto. Veredicto: **pone precio** a capacidad efímera y **mitiga** el
resto.

**Quién paga/coste.** Espera, disponibilidad y posible pérdida por fallo doméstico; la granja tiene
mejor redundancia. Para no hacerlo regresivo: altas por lotes, coste de estado por byte y no por
identidad, tolerancia explícita a fallos, varios retos antes de perder y salida limpia. Nodo/cadena:
acumulador, expiración, retos y locks; todo **[no determinado]**.

**Reaperturas/compatibilidad/evidencia.** Es una migración de consenso: registro, poda, solución,
calendario DAG y coinbase. Puede conservar la codificación de piezas Autonomys y el PoT `blake3` como
fuente de retos, pero no su interfaz de sector sin registro. Spacemesh demuestra el patrón ATX/NIPoST;
Filecoin el patrón de continuidad y recompensa vestida. Ninguno demuestra adecuación a ZEROX.

### I — Quema fija de recompensa

**Mecanismo y resultado.** Quemar `β` de cada recompensa añade `β·recompensas_obtenidas`, no una
pérdida por atacar. Un atacante que no cobra tampoco la paga y el honesto sí. Es equivalente a bajar
la recompensa neta, puede reducir espacio honesto y no crea exclusividad. Veredicto: **no sirve**.

## 5. Qué reutilizar de P-SEMBRADOR y qué no duplicar

**[Verificado en fuente interna.]** P-SEMBRADOR ya demuestra que el verificador actual ve una pieza,
no el sector completo, y que ni `history_size` ni `altura_ploteo` acreditan cuándo se calcularon los
bytes (`P-SEMBRADOR/investigacion/INFORME.md:17-33,55-67`). Su A1+C1 es la base correcta de B: raíz
completa previa + prueba de que la raíz abarca la codificación. Su E es la base de H: pago sujeto a
permanencia. No repito su modelo de adelanto ni heredo sus cifras adimensionales como economía real.

Fuera del sembrador, A1+C1 también encarece alquiler recién llegado y catálogos adaptativos. No
resuelve multistream, soborno, grinding de bloques ya elegibles ni largo alcance de parcelas maduras.

## 6. Combinaciones y recomendación

| Combinación | Qué compra | Qué queda abierto |
|---|---|---|
| B + H | entrada no instantánea + continuidad + garantía de recompensas propias | multistream, grinding de participante maduro, doble gasto > garantía |
| A + B + H | lo anterior + coste recurrente de largo plazo | desgaste/energía honesta y alquiler dentro de vida residual |
| B + C + H | dificulta fabricar catálogo antes del reto y abandonar después | ASIC del sellado, complejidad criptográfica, multistream |
| D sola | prueba corta para una conducta estrecha | identidades nuevas, retos distintos y ataque no publicado |
| F + cualquier otra | coste por rama real | deja de respetar la prioridad energética si es material |

**[Propuesta propia.]** Construir primero un diseño fuera del SPEC de **B+H**, reutilizando el
prototipo A1+C1/E de P-SEMBRADOR: alta por lote, raíz exacta, edad simbólica `M`, apertura en la
solución y vesting condicionado a pruebas futuras. Mantener C-EXP con su calendario pendiente, no
acortarlo hasta medir desgaste. Rechazar por ahora C, E y F como migraciones desproporcionadas.

El criterio de avance no es “parece caro”, sino estas desigualdades, todas parametrizadas:

```text
edad M                  > ventana máxima de adaptación demostrada;
coste de alquiler útil  > beneficio del ataque bajo el mismo horizonte/riesgo;
garantía D_f            > beneficio demostrable de la conducta que realmente puede probarse;
coste doméstico/TiB     ≤ región de aceptación que Katana elija;
estado y verificación   ≤ presupuestos de nodo aún por fijar.
```

Si ninguna puede certificarse sin expulsar al pequeño, la decisión correcta es no adoptarlo y
mantener un catálogo explícito de tarifas por ataque.

## 7. Qué medir antes de decidir

1. Mercado real o experimento de alquiler: disponibilidad de parcelas ZEROX con claves, duración
   mínima, prima por lock y posibilidad de retirar capacidad; sin esto “alquiler barato” es una
   amenaza plausible, **no medida**.
2. Coste por TiB de resembrado Autonomys: energía, tiempo, RAM/VRAM, bytes escritos, TBW y rutas
   CPU/GPU adversariales; distribución doméstica y granja.
3. Prototipo de compromiso completo: bytes de alta, prueba por solución, estado/TiB, altas/s, poda,
   reorg y prueba de que todos los bytes quedan ligados.
4. Curvas `w(a)` sin fijar consenso: tiempo hasta influencia, ventaja de incumbencia, churn y
   capacidad de preposicionar inventario.
5. Pruebas de fraude DAG: tamaño y verificación de dos cabeceras + identidad de billete + evidencia
   de incompatibilidad; inclusión bajo partición y peor tiempo de ejecución.
6. Permanencia: frecuencia de retos, falsa pérdida por apagado/red/disco, plazo de regeneración,
   garantía acumulada y concentración por redundancia.
7. Comparación bajo el mismo `α,T`, beneficio externo y riesgo: base, B, B+H, A+B+H; informar
   `C_certeza`, `q_fD_f`, `c_irr` y `ΔC_irr^ataque`, no solo coste medio.

## 8. Fuentes verificadas y límites

- `SPEC.md:820-966,1270-1488,1495-1610,1655-1725,1907-1961,2020-2060,3021-3045`: formato,
  reto/flujo pendientes, madurez, GHOSTDAG, C-EXP y estado activo. La SPEC está en migración.
- `research/dag-poas-auditoria.md:247-277,343-359`: *double dipping* histórico y construcción
  multistream. Es evidencia histórica; C-FLU posterior cambia su aplicabilidad.
- `research/dag-poas-catalogo-problemas-ataques.md:15-30,68-99`: catálogo y etiquetas de aquella
  ronda, no parámetros heredables.
- `research/dag-poas-balizas-auditoria.md:66-89`: teorema local de identidad gratuita/exclusividad.
- `P-PUERTA/veritas/consenso/puerta-cobertura-v1/INFORME.md:232-285`: coste fijo/variable de
  cobertura; sus cifras de hardware conservan el alcance del instrumento.
- `P-2.1/SINTESIS.md:68-107` y `P-FLUJO/propuesta/PROPUESTA-SPEC.md:1147-1183`: decisiones de Katana
  y ausencia de una regla de adopción. La revisión 4 de P-FLUJO contiene residuos incompatibles
  sobre la ventana de adopción; no se trata como texto listo para SPEC.
- [Chia Green Paper](https://docs.chia.net/files/ChiaGreenPaper_20241008.pdf): PoSpace barato tras
  plotear, *replotting*, double dipping y PoT. El factor 1,47 pertenece a sus parámetros/modelo.
- [SpaceMint](https://eprint.iacr.org/2015/528.pdf): compromiso previo, *nothing at stake*, penalidad
  de la misma prueba y límites frente a retos distintos/doble gasto.
- [Filecoin sealing](https://spec.filecoin.io/systems/filecoin_mining/sector/sealing/),
  [storage proving](https://github.com/filecoin-project/filecoin-docs/blob/main/storage-providers/filecoin-economics/storage-proving.md)
  y [collateral](https://spec.filecoin.io/systems/filecoin_mining/miner_collaterals/): patrones
  PoRep/WindowPoSt/vesting; su pledge comprado viola la entrada sin moneda de ZEROX.
- [Spacemesh protocol](https://github.com/spacemeshos/protocol) y
  [NIPoST](https://github.com/spacemeshos/protocol/blob/master/nipost.md): inicialización,
  compromiso, ATX por época y continuidad. PoET/consenso no se copian.
- [Autonomys security](https://academy.autonomys.xyz/autonomys-network/consensus/security): declara
  que el ploteo bajo demanda se disuade económicamente, no una prueba de coste irrecuperable. El
  código fijado local fue la evidencia decisiva para la interfaz real.

## Lo que esta investigación NO resuelve

- **[No determinado.]** Si existe oferta económicamente relevante de alquiler de parcelas ZEROX y
  claves, ni su precio o plazo.
- **[No determinado.]** El coste real del resembrado y del intento dirigido mínimo; no se heredó
  ninguna cifra histórica.
- **[No determinado.]** Una prueba sucinta de parcela Autonomys completa ni un acumulador podable.
- **[No demostrado.]** Que una prueba corta pueda establecer incompatibilidad general entre dos
  bloques DAG/flujos; solo el mismo billete y campos firmados parece localmente comprobable.
- **[No determinado.]** `q_f`, garantía suficiente, edad, curva de peso, frecuencia de auditoría,
  tolerancia a fallos, bytes, CPU, energía y desgaste aceptables.
- **[No resuelto por diseño.]** Exclusividad física entre ramas para un recurso no consumible.
- **[No resuelto por esta investigación.]** La partición de flujo sin cura, finalidad cuantificada,
  selección de parámetros `F/I/L/L_suelo`, poda, integración PoAS/PoT ni la capa blindada.
- **[No decisión.]** Este informe no fija parámetros ni modifica C-EXP, cabecera, emisión o las
  propuestas C-POT/C-FLU; Katana debe decidir las bifurcaciones del documento adjunto.
