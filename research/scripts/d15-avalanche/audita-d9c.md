# Auditoría D9c — dos informes sin auditar: `d15-avalanche/informe.md` y `d14-dagknight/informe3.md`

**Auditor:** D9 · Matemáticas y validación formal (mandato de refutar).
**Fecha:** 2026-09-10 · **Fichero propio:** este. No se tocó ningún otro fichero; no se ejecutó git.
**Objeto:** intentar refutar cada número y cada cita decisiva de los dos informes. Prioridad del
encargo: bajar irreversibilidad, sin comités.

## 0 · Método y alcance

1. **Re-ejecución completa.** Los 4 scripts de `d15-avalanche/` y los 5 de `d14-dagknight/` que
   producen las tablas citadas se re-ejecutaron; **todas** las salidas (`salida_ctmc.txt`,
   `salida_agentes.txt`, `salida_muestreo.txt`, `salida_latencia.txt`, `salida_visible2.txt`,
   `salida_latencia2.txt`, `salida_mitigaciones_vis.txt`, `salida_d8_mitigacion.txt`,
   `salida_fixture_test.txt`) salieron **idénticas byte a byte** a las del informe (`diff` vacío).
   `AUDITA_SCRIPTS.py` da 0 sospechas en ambos directorios (4 y 24 scripts), como dicen los informes.
2. **Verificación independiente.** Se reimplementaron fuera del repo (`/tmp/opencode/`) el CTMC
   (hypergeom + recurrencia de primer paso con `mpmath` a 80 dígitos), las latencias, el sesgo de
   respuesta, la retención y la frontera `p0` (60 semillas nuevas, 20001-20060, fuera de las 20 del
   informe). No se importó el CTMC de D15A; sí se importó `simula()` de `snowball_agentes.py` para
   la rejilla fina de `p0` (el instrumento es el que se audita).
3. **Fuentes.** Paper de Avalanche en `research/scripts/d14-sin-comite/fuentes/avalanche-1906.08936.txt`
   (2239 líneas) y `research/fuentes/dagknight.txt` (100 387 B, **1702** líneas). `rusty-kaspa` en
   `/home/katana/zeo/fuentes/rusty-kaspa`, tip `origin/dagknight` =
   `3353678ae69703b5fb603a335e7466a3c0604794`, 1381 ficheros.
4. **No se compiló `rusty-kaspa`.** El test Rust del fixture existe y su valor esperado es
   `expected_score() = 4w`; el test Python (`d14k_fixture_test.py`) se ejecutó y **PASA**. No corrí
   `cargo test` (no hay `target/`; compilar el workspace es desproporcionado). Se dice abajo.

## 1 · Tabla de cifras

| Cifra | Informe | Recálculo D9c | Estado |
|---|---|---|---|
| `p_adv` k=50,q=30 | 7,80e-5 | 7,798141e-5 | OK |
| `p_hon` | 0,8849 | 0,884935 | OK |
| frontera valle | 0,7849 | 5259/6700 = 0,784925 | OK |
| log10 MTTF (rondas) | 1692,4 | 1692,40474 | OK |
| MTTF (años) | 10^1684,9 | 10^1684,906 | OK |
| `f_eff` retención T=4W | 0,663 | 0,663317 | OK |
| cruce T/W al 50 % | 2,030 | 2,0303 | OK |
| honestos online exigidos, q/k=0,60 | 32,8 % | 32,84 % | OK |
| latencias Δ=1/4/16/20 (k50q30, T=2Δ) | 29/116/464/580 | 29/116/464/580 | OK |
| cruce Δ (T=2Δ) | 4,5 s | 4,497 s | OK |
| cruce Δ (T=Δ) | 8,7 s | 8,694 s | OK |
| **frontera `p0`** | **0,746 (analítica)** | **~0,785-0,79 medido; valle CTMC 0,7849** | **REFUTADO** |
| **control k=10,q=8, f≥0,25 → rojo** | **20/20** | **0/20 (f=0,25-0,33); 5/20 (f=0,40)** | **REFUTADO** |
| resumen Δ=1, T=2Δ | 28-38 s | 27-39 s (tabla del propio informe) | corregido |
| resumen Δ=4, T=2Δ | 112-150 s | 108-156 s | corregido |
| resumen Δ=16, T=2Δ | 448-600 s | 432-624 s | corregido |
| resumen Δ=20, T=2Δ | 560-750 s | 540-780 s | corregido |
| resumen gossip Δ=1/4/16/20 | 14-19/56-75/224-300/280-375 | 14-20/56-80/224-320/280-400 | corregido |
| Δ=8, T=Δ | «empata» | 120 s < 130,41 s → **gana** | corregido |
| 0,206 s | «mediana» | «most common» = **moda** | corregido |
| MTTF 10^1684 | 10^1684 | 10^1684,9 | corregido |
| ataque `retraso20` vista real | 12/12 | 12/12 | OK |
| ataque `retraso20_sp` | 3-9/12 | cap0 3-9/12; cap_ref 2-8/12 | OK |
| M2h ε=1e-6 | 30,5-51,7 s | 30,49-51,68 s | OK |
| M2h ε=1e-12 | 55,7-61,7 s | 55,67-61,72 s | OK |
| M2h mín/máx | 15,19 / 94,25 s | 15,19 / 94,25 s | OK |
| baseline α=0,33 | 130,41 s | 130,41 (`salida_zerox2.txt:32`) | OK |
| suelo M2h | 30,3-64,1 s | 30,3-**67,2** s | corregido |
| congelación M1 | 0-6/12 | **0-4/12** | REFUTADO |
| `git grep risk` | 2 hits | 6 líneas | corregido |
| «risk» en el paper | 0 hits / sin definición | **6 apariciones `𝑟𝑖𝑠𝑘`; definición verbal :977-978** | REFUTADO |
| `dagknight.txt` | 1703 líneas | 1702 | corregido |
| ε implícito del baseline M=90 | no declarado | **2,09e-28** (fórmula del propio informe) | nuevo |

---

# Parte I · D15A — Snowball sobre peso de espacio

## I.1 · Multiplicadores de latencia y cruces (Δ=1→29/15 s, etc.)

```
AFIRMACIÓN:   informe.md:62-67 y :290-316: latencia = d + r90·T, d = Δ, r90(k=50,q=30) = 14,
              T = 2Δ (consulta-respuesta) o T = Δ (gossip). Δ=1 → 29/15 s; Δ=4 → 116/60;
              Δ=8 → 232/120; Δ=16-20 → 464-780; cruce Δ<4,5 s (T=2Δ) y Δ<8,7 s (T=Δ).
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE (la aritmética) · PLAUSIBLE, NO DEMOSTRADO (T=Δ)
DERIVACIÓN:   Reproducción exacta de salida_latencia.txt. d + r90·2Δ y d + r90·Δ con d=Δ,
              r90=14: 1+28=29; 1+14=15; 4+112=116; 4+56=60; 8+224=232; 8+112=120;
              16+448=464; 16+224=240; 20+560=580; 20+280=300. Cruces: 130,41/(2·14+1)=4,497;
              130,41/(14+1)=8,694. Todos los valores de la tabla §5 son correctos para esos r90.
              T=2Δ es la ronda del paper (query + respuesta, Fig. 6). **T=Δ no sale del paper**:
              el paper solo define la ronda como consulta-respuesta; una respuesta por gossip sigue
              necesitando que la consulta llegue. T=Δ supone un flujo de voto de un solo sentido que
              el paper no especifica, y además la muestra deja de ser aleatoria dirigida.
              d=Δ como profundidad de alineación es una hipótesis de diseño, no un teorema del paper.
ENTEROS:      No aplica a la fórmula (reales). El `ceil` de m(α,ε) sí es entero y se trata en I.8/d14.
ADVERSARIO:   Un operador que planifique con T=Δ a Δ=8-9 s duplica la latencia real si el voto
              necesita ida y vuelta. No rompe consenso; rompe la promesa de irreversibilidad.
IMPACTO:      De rendimiento, no de seguridad. La conclusión «gana si Δ≲4-9 s» depende de T=Δ.
CORRECCIÓN:   Mantener la tabla T=2Δ como la del paper y etiquetar T=Δ como cota optimista.
              El veredicto de Δ=8 (abajo) también se corrige.
```

## I.2 · Veredicto Δ=8: «empata (T=Δ)»

```
AFIRMACIÓN:   informe.md:310: «Δ=8 → 232 s (T=2Δ) / 120 s (T=Δ): PIERDE (T=2Δ) / empata (T=Δ)».
CLASIFICACIÓN: REFUTADO
DERIVACIÓN:   120 s < 130,41 s. Con r90=14, T=Δ, el cruce es Δ<8,694, así que a Δ=8 **gana**
              (al filo). El propio informe da el cruce 8,7 s en :315 y en la tabla del veredicto
              escribe «Δ≤4 s … GANA» omitiendo el tramo 4<Δ<8,7 de gossip.
ENTEROS:      No aplica.
ADVERSARIO:   Nadie: es un error de lectura de tabla que infravalora la vía de gossip.
IMPACTO:      Nada material; la conclusión (Δ real sin medir) no cambia.
CORRECCIÓN:   Δ=8, T=Δ: «GANA (120 s)»; el resumen «pierde con Δ≥16» es correcto para T=2Δ.
```

## I.3 · Rangos del resumen ejecutivo

```
AFIRMACIÓN:   informe.md:64-66: Δ=1 → 28-38 s; Δ=4 → 112-150; Δ=16 → 448-600; Δ=20 → 560-750;
              gossip 14-19 / 56-75 / 224-300 / 280-375.
CLASIFICACIÓN: REFUTADO (rango) — conclusión intacta
DERIVACIÓN:   La tabla §5 del propio informe (:295-301) da, T=2Δ: Δ=1 → {33,29,37,27,39}=27-39;
              Δ=4 → {132,116,148,108,156}=108-156; Δ=16 → {528,464,592,432,624}=432-624;
              Δ=20 → {660,580,740,540,780}=540-780. T=Δ: {17,15,19,14,20}=14-20;
              {68,60,76,56,80}=56-80; {272,240,304,224,320}=224-320; {340,300,380,280,400}=280-400.
              Los rangos del resumen no coinciden con la tabla ni con subconjuntos evidentes de ella
              (p. ej. k=20/50q30/50q32 daría 29-37, no 28-38).
ENTEROS:      No aplica.
ADVERSARIO:   Nadie; es un resumen que no coincide con su propio artefacto.
IMPACTO:      Nada: el veredicto y los cruces usan r90=14 y son correctos.
CORRECCIÓN:   Usar los rangos de la tabla (columna izquierda de esta fila).
```

## I.4 · «El 1,35 s es geo-replicado y a f≤0,20; a f=0,33 el paper no publica latencia»

```
AFIRMACIÓN:   informe.md:276-284: 1,35 s = mediana en 20 ciudades, n=2000 (:1253-1255);
              0,206 s típicos y 0,4 s máx en un solo emplazamiento (:1125-1130);
              a f=0,33 el paper no publica latencia medida.
CLASIFICACIÓN: RESPALDADO POR FUENTE (1,35 s; ausencia de f=0,33) · PLAUSIBLE, NO DEMOSTRADO (f≤0,20)
DERIVACIÓN:   Verificado en el texto: :1254 «the median transaction latency is 1.35 seconds, with a
              maximum latency of 4.25 seconds» en «Figure 19: … n=2000 in 20 cities». :1125-1130
              «most transactions are confirmed within approximately 0.3 seconds. The most common
              latencies are around 206 ms … maximum … around 0.4 seconds» (Fig. 15, mismo setup que
              throughput, n=2000). :1022-1023 fija k=10, α=0,8, β1=11, β2=150; :1279-1285 dice que
              esos parámetros garantizan 10^-9 «in the presence of 20% Byzantine nodes». La
              condición de viveza :598-599 es f < (k−α)/k = 0,20, luego la configuración desplegada
              **no puede** operar por encima de f=0,20 con viveza. Que las medidas se hicieran
              exactamente a f=0,20 no se afirma en el paper: es inferencia (razonable).
              No hay ninguna latencia publicada a f=0,33 (búsqueda en el texto: sin «33%», sin
              fracciones ≥1/3 en la evaluación).
ENTEROS:      No aplica.
ADVERSARIO:   Citar «1,35 s» como alcanzable a f=0,33 sería un error de diseño: a 20 % bizantino la
              propia configuración desplegada está en el borde de viveza.
IMPACTO:      Nada si se mantiene la etiqueta; el informe lo hace bien.
CORRECCIÓN:   Solo precisar que f≤0,20 es inferencia de :598-599, no una condición declarada de los
              experimentos de latencia.
```

## I.5 · «0,206 s es la mediana» en un solo emplazamiento

```
AFIRMACIÓN:   informe.md:279: «en un solo emplazamiento la mediana es 0,206 s y el máximo 0,4 s».
CLASIFICACIÓN: REFUTADO (cita)
DERIVACIÓN:   El texto :1126-1127 dice «The most common latencies are around 206 ms»: es la **moda**
              del histograma, no la mediana. La mediana de Fig. 15 no se publica como número; el
              texto solo dice «most transactions are confirmed within approximately 0.3 seconds».
              El máximo ~0,4 s sí está declarado.
ENTEROS:      No aplica.
ADVERSARIO:   Nadie; es una cita imprecisa.
IMPACTO:      Nada material.
CORRECCIÓN:   «0,206 s es la latencia más común (moda); el máximo ~0,4 s; el grueso <0,3 s».
```

## I.6 · MTTF 10^1684 años y frontera del valle 0,7849

```
AFIRMACIÓN:   informe.md:209-234: a k=50,q=30,f=0,33,n=10000, p_adv=7,80e-5, frontera del valle
              0,7849 (78,5 % de honestos; «hay que perder el 21,5 %»), log10 MTTF = 1692,4 rondas
              = 10^1684,9 años. Es «cota conservadora» porque Snowball amortigua con confianza.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE (el CTMC) · PLAUSIBLE, NO DEMOSTRADO (que sea cota de Snowball)
DERIVACIÓN:   Reimplementado desde cero: p_adv = 7,798141e-5; p_hon = 0,884935; frontera =
              5259/6700 = 0,784925; F_c = 1/µ_c y F_i = (1+λ_i·F_{i+1})/µ_i con mpmath a 80
              dígitos; E = ΣF_i; log10 E = 1692,40474; años = 1684,90563. Reproducidos también los
              demás renglones de la rejilla (k=20,q=12 → 81,6; k=100,q=65 → 6726,2) y la
              sensibilidad a n (n=50000 → frontera 1,0, log10 MTTF 8399,6).
              **La etiqueta «cota conservadora» no está demostrada.** Hay dos aproximaciones en
              direcciones opuestas: (i) Slush/Snowflake sin contadores flipea más que Snowball
              (paper §4.1: «rendering reversibility less likely over time»; «if the drifts ever
              revert, then reversibility analysis becomes identical to that of Snowflake» — no hay
              teorema de dominancia estricta); (ii) el MTTF mide el tiempo hasta que **todos** los
              honestos caen a rojo, que es un evento **más raro** que un fallo de decisión
              (dos nodos decidiendo distinto). (i) empuja la seguridad hacia arriba y (ii) hacia
              abajo; el neto no se demuestra. La evidencia real de Snowball es la simulación
              (0/20 mixtas a f=0,33), que es de horizonte finito y n=3000.
ENTEROS:      La recurrencia usa reales; el `ceil` no interviene aquí. Sin overflow/underflow: los
              estados i≤6700 y las colas hipergeométricas se evalúan en doble precisión con sf.
ADVERSARIO:   Un atacante de vista que aproveche el tramo entre «fallo de decisión» y «todos
              rojos» no queda cubierto por el número; el informe ya lo dice (eclipse = LAGUNA).
IMPACTO:      Si el 10^1684 se citara como garantía de decisión, sobreestimaría la seguridad.
CORRECCIÓN:   Etiquetar: «MTTF del modelo Slush hacia todo-rojo = 10^1684,9 años; no es una cota
              demostrada de la probabilidad de fallo de decisión de Snowball».
```

## I.7 · Frontera `p0 < 0,746` — REFUTADA

```
AFIRMACIÓN:   informe.md:77-80 y :236-256: «La frontera entre atractores está en ~74,6 % de los
              honestos = 50 % de la población total (analítica 0,5/(1−f), confirmada por agentes
              entre p0=0,7 y p0=0,8): si los honestos están menos alineados que eso, el adversario
              gana». §4.1 (:204-207) y §0 (:43-47): «con k=10, q=8 y f≥0,25, 20/20 semillas deciden
              rojo en salida_agentes.txt».
CLASIFICACIÓN: REFUTADO
DERIVACIÓN:   (a) Frontera. Con el propio instrumento y **60 semillas nuevas** (20001-20060),
              k=50,q=30,β1=11,α=0,33,n=3000: p0=0,7000 → 60/60 rojo; 0,7463 → **60/60 rojo**;
              0,7800 → 52/60; 0,7850 → 15/60; 0,7900 → 1/60; 0,8000 → 0/60. La separatriz está en
              **~0,785-0,79**, y coincide con el valle del CTMC (0,7849), no con 0,5/(1−f)=0,7463.
              El propio §4.2 dice 78,5 %; §4.3 se contradice. El 50 % de la población total solo
              dice dónde hay mayoría bruta; el valle de la cadena de nacimiento-muerte con
              coeficientes i y (c−i) está en i·H_rojo = (c−i)·H_azul, que es 52,6 % de la población
              (78,49 % de honestos). Un p0=0,76 (por encima de 0,746) da 60/60 rojo.
              (b) Control k=10,q=8. salida_agentes.txt: f=0,25 → 0/20 rojo; f=0,33 → 0/20;
              f=0,40 → 5/20 con rojo y 4/20 mixtas. El salto a 1 de la frontera del valle ocurre en
              **snowball_ctmc.py** (f=0,20 → 0,6565; f=0,25 → 1,0000), no en los agentes. «20/20
              deciden rojo» no existe en ninguna salida.
ENTEROS:      La frontera es (idx+1)/c con idx el último estado con µ_i≥λ_i; verificado 5259/6700.
              Los `ceil`/`int` de n_a=int(round(α·n)) no alteran la conclusión (3300/6700).
ADVERSARIO:   **Este error sí es explotable**: un despliegue que se creyera seguro con p0>0,746
              (p. ej. 0,76-0,78 tras una partición) sería capturado por el adversario en 52-60/60
              semillas. La defensa correcta (checkpoint a profundidad ≥Δ) sigue siendo válida, pero
              el umbral con el que se mide su eficacia debe ser ~0,79, no 0,746.
IMPACTO:      Captura de finalidad en el tramo [0,746; 0,785] de alineación honesta.
CORRECCIÓN:   Frontera medida ≈ 0,785-0,79 (CTMC 0,7849); usar `p0 ≳ 0,79` como condición
              operativa. El 0,746 de §4.3 y el «20/20» de §0/§4.1/§4.5/§10 deben borrarse.
```

## I.8 · Retención T=4W → f_eff=0,663

```
AFIRMACIÓN:   informe.md:129-137 y :258-269: f_eff = f·T/((1−f)W+f·T); con T=4W, f_eff=0,663;
              cruce del 50 % en T/W = (1−f)/f = 2,030.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE · DEMOSTRADO (ventana por slot invariante)
DERIVACIÓN:   0,33·4/(0,67+0,33·4) = 1,32/1,99 = 0,663317; (1−0,33)/0,33 = 2,0303. La ventana por
              slot no crea credenciales: cada solución cuenta una vez en su slot, f_eff=f. La
              fórmula de publicación es correcta para un atacante con backlog no acotado y ventana
              de publicación (la única pega, ya señalada por el informe: el atacante debe retener).
ENTEROS:      No aplica (reales).
ADVERSARIO:   Con ventana por publicación y T=4W el atacante cruza el 50 % sin espacio extra; el
              diseño debe indexar por slot de PoT (R-FIN-13). Correcto.
IMPACTO:      Nada; el informe acierta.
CORRECCIÓN:   No aplica.
```

## I.9 · Muestreo por slot ¿no es comité? ¿partir claves no cambia el total?

```
AFIRMACIÓN:   informe.md:53-61, :98-105, :358-378: muestrear soluciones de una ventana por slot no
              es comité (definición estricta) y partir el espacio entre claves no cambia el total.
CLASIFICACIÓN: PLAUSIBLE, NO DEMOSTRADO (comité: decisión de alcance) · DEMOSTRADO (Sybil de claves)
DERIVACIÓN:   (a) «No es comité» no es un teorema: el informe mismo reconoce que bajo la definición
              amplia («cualquier subconjunto muestreado cuyos votos deciden») sí lo es, y que la
              recomendación B es un **override vinculante** («MUST NOT reorganizar por debajo»)
              decidido por una muestra. Eso es exactamente lo que la definición amplia prohíbe. La
              elección estricta es de Katana, no un resultado.
              (b) Partir claves: si cada solución pesa 1 y el número esperado de soluciones es
              ∝ espacio (mismo `solution_range` global), la linealidad de la esperanza da que el
              peso agregado es invariante al reparto entre claves. Verificado el respaldo en
              `research/dag-poas-capa-finalidad.md:47-56` («partir el espacio entre identidades
              cuesta lo mismo que no partirlo»). Queda como LAGUNA del propio informe la varianza
              y la correlación entre claves del mismo dueño.
ENTEROS:      No aplica (esperanzas). El peso por clave es entero (nº de soluciones) y la suma se
              conserva exactamente.
ADVERSARIO:   Un atacante no gana peso partiendo claves, pero puede alterar la **varianza** de la
              muestra (muchas claves con 0-1 soluciones). El informe lo declara LAGUNA.
IMPACTO:      Si Katana adopta la definición amplia, la vía muere por alcance, no por matemáticas.
CORRECCIÓN:   Escribir explícitamente en el SPEC que la definición de comité adoptada es la
              estricta y que la muestra es un conjunto público y acotado por decisión.
```

## I.10 · Resto de cifras de D15A

```
AFIRMACIÓN:   sesgo de respuesta 32,8 % (q/k=0,60) y 40,3 % (q/k=0,55) (:264); supresión no puede
              fabricar q rojos (:265); voto embebido 4,1e-4 vs muestreo 2,5e-45 a β=11 (:269);
              coste gossip ~100 MB/s a n=10000,k=50 (:319); citas del paper :24,:242-254,:271-273,
              :288-294,:318-319,:345,:456,:598-599,:623,:667-730,:1125-1130,:1254,:1279-1285,
              :2173-2240; subspace sectors.rs:45-65, plotting.rs:108-126, archiver.rs:73,473.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE / RESPALDADO POR FUENTE
DERIVACIÓN:   Reproducidos 0,3284 y 0,4030; 0,33k<0,60k para todo k; (0,33/0,67)^11=4,14e-4 y
              (7,798e-5/0,8849)^11=2,49e-45 (41 órdenes de diferencia); 2·50·100 B·10000/1 s =
              100 MB/s. Todas las citas del paper verificadas línea a línea. En `subspace` @
              `f8842d0`: `SectorId::new` = blake3(pk_hash‖sector_index‖history_size) (sectors.rs
              :44-65); `plotting.rs` recibe `piece_getter` (piezas de historia) y `Kzg`; `archiver.rs`
              usa `subspace_kzg::Kzg` (:73) y `recreate_genesis_segment` (:473). Los 2.000 AVAX
              siguen sin verificarse en local (docs externos) — el informe ya lo declara LAGUNA.
ENTEROS:      No aplica salvo el coste (bytes enteros) y el nº de rondas.
ADVERSARIO:   El modelo de ruina del voto embebido es heurístico (pasos ±1 con probabilidad
              f/(1−f), ignorando la probabilidad de «sin chit» 0,115). La conclusión cualitativa
              (el muestreo reduce la cola) no depende de la constante exacta.
IMPACTO:      Nada material.
CORRECCIÓN:   Etiquetar la tabla de β como modelo heurístico, no como probabilidad exacta.
```

---

# Parte II · D14C — cierre de DAGKNIGHT (`informe3.md`)

## II.1 · La búsqueda de la regla de cliente

```
AFIRMACIÓN:   informe3.md:43-78: el paper no publica la regla (0 hits de «risk», sin definición);
              la rama `origin/dagknight` (1381 ficheros, 15 con dagknight/umc, `git grep client`
              → 1 hit en protocol.rs:73, `risk` → 2 hits ajenos, `confirmation` → solo la estándar
              de Kaspa, 60+ commits sin cliente/confirmación). Conclusión: LAGUNA.
CLASIFICACIÓN: RESPALDADO POR FUENTE / VERIFICADO COMPUTACIONALMENTE (la búsqueda) — con dos
              correcciones de cita
DERIVACIÓN:   Repetido en `/home/katana/zeo/fuentes/rusty-kaspa` sobre `origin/dagknight`:
              tip 3353678a…; 1381 ficheros; 15 nombres dagknight/umc; `git grep -i client` en
              `consensus/src/processes/dagknight/` = 1 hit exacto (protocol.rs:73, «blue score …
              also for client confirmation counting»); `git grep -i confirmation` = 80 líneas, todas
              RPC/wallet/proto/docs estándar (p. ej. `rpc/service/src/service.rs:430`), ninguna regla
              de cliente DAGKNIGHT; `git log --all` = **89** commits (el informe dice «60+»), ninguno
              de cliente. Búsqueda extra propia en **todos** los refs (`git for-each-ref`) de
              `fn risk|risk(|confirmation_risk|client_confirm`: **0** en todas las ramas.
              **Dos errores de cita:** (i) `git grep -i risk` da **6 líneas**, no 2
              (`pruning_proof/mod.rs:198`, `notify/src/subscription/single.rs:388`,
              `wallet/bip32/.../english.txt:227,1492`, `fee_estimation.ipynb` base64,
              `wasm/examples/.../storage.js:28`); el fondo (ninguna función `risk`) no cambia.
              (ii) **El paper sí usa `risk`**: 6 apariciones de `𝑟𝑖𝑠𝑘` (líneas 953, 955, 972, 977,
              998, 1000) y da una definición verbal en :977-978 («the probability that the ordering
              between b and any other block c changes between time t and t+r»). El «0 hits» es un
              artefacto de grep ASCII contra texto math-italic; el propio informe cita :996-999, que
              contiene `𝑟𝑖𝑠𝑘`. Lo que no existe es forma cerrada, pseudocódigo ni implementación.
ENTEROS:      No aplica.
ADVERSARIO:   La LAGUNA es real: sin regla de cliente no se puede reproducir el control 1,2/6/12 s
              ni medir la ganancia publicable de DAGKNIGHT.
IMPACTO:      El veredicto (LAGUNA de la regla de cliente) se mantiene; solo se corrige el conteo.
CORRECCIÓN:   «El paper define verbalmente `risk(b,t,r)` en :977-978 y lo usa 6 veces; no publica
              forma cerrada ni pseudocódigo. En la rama no hay `risk` en ninguna rama.»
```

## II.2 · Ataque de retención: `retraso20` 12/12 y `retraso20_sp` 3-9/12

```
AFIRMACIÓN:   informe3.md:100-134: vista real (entrega ≤T, cierre bajo ancestros): `retraso20`
              (tips) captura 12/12 a Δ=16 (α=0,25 y 0,40); `retraso20_sp` captura 3-9/12;
              `retraso60_sp` cae a 0/12; `instant` 0/12 (1/12 ruido en α=0,25 Δ=20).
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE · DEMOSTRADO (12/12 reproducido)
DERIVACIÓN:   `d14k_visible2.py` re-ejecutado: salida idéntica. Celdas de cap0 en vista real:
              retraso20 → {12,8,12,7}; retraso20_sp → {7,8,3,9}; retraso60_sp → {0,0,0,0};
              instant → {0,1,0,0}. La «vista real» (`recv(b)=max(llega(b),max recv(padres))`,
              cerrada bajo ancestros) es una corrección metodológica legítima sobre la «vista
              completa» de D8b, y el informe la documenta como error propio. La tabla de vista
              completa también reproduce ({8,8,5,5} retraso20; 5-11 sp).
ENTEROS:      T=400 s, T_TX=200 s; índices enteros; sin overflow. 12 semillas por celda.
ADVERSARIO:   El atacante real elegiría R≈Δ (20 s a Δ=16-20) y la política `tips`; con eso captura
              12/12. No hay mitigación del enunciado que lo cierre (ver II.4).
IMPACTO:      Alto: la regla de ordenación publicada queda capturada en la vista del cliente.
CORRECCIÓN:   No aplica.
```

## II.3 · M2h: latencia, congelación y métrica de precedencia

```
AFIRMACIÓN:   informe3.md:193-228: M2h a α=0,33, λ=1, T=400, 12 semillas: media 30,5-51,7 s
              (ε=1e-6) y 55,7-61,7 s (ε=1e-12); mínima 15,19 s; máxima 94,25 s; baseline 130,41 s;
              congelación ≤2/12; `cap_ref`=0/12; métrica D8b 3-9/12; suelo teórico 30,3-64,1 s.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE (medida) · PLAUSIBLE, NO DEMOSTRADO (la ganancia)
DERIVACIÓN:   `d14k_visible2.py` y `d14k_latencia2.py` re-ejecutados: idénticos. Medias ε=1e-6
              {30,49; 41,69; 37,92; 32,11; 47,67; 51,68}; ε=1e-12 {55,67…61,72}; mín 15,19; máx
              94,25; baseline `t_base`=130,41 (`salida_zerox2.txt:32`); cong 0-2/12; cap_ref 0/12.
              **Dos objeciones:**
              (1) **La comparación no es a igual ε.** El baseline usa M=3k=90 bloques; bajo la
              propia fórmula de ruina del informe, eso corresponde a
              (0,33/0,67)^90 = **2,09e-28**, mientras M2h se mide a ε=1e-6/1e-12. A igual ε=1e-6 el
              margen del baseline sería m=20 bloques ≈ 20/0,67 = 29,85 s, **el mismo** que M2h. La
              «ganancia 2,5-4,3×» es, por tanto, el cociente entre dos niveles de seguridad
              distintos (90 bloques vs 20-40), no una mejora de la regla a igual garantía. La lista
              de condiciones del informe (regla propia, pesos uniformes, vista real, métrica 3-9/12)
              **no incluye** este punto.
              (2) `k_conf` se mide en el DAG **final** a T=400 y luego se usa para calcular la
              latencia como si se conociera al confirmar; no es una simulación online de la regla.
              Es una simplificación declarable, no declarada.
              El «suelo teórico 30,3-64,1 s» es erróneo: la tabla D da 30,3-**67,2** s (Δ=20,
              retraso60_sp, ε=1e-12).
ENTEROS:      m = ceil(ln ε/ln(α/(1−α))) = 20 (ε=1e-6) y 40 (ε=1e-12) — verificado; M=max(3k,m)
              entero; `tiempo_a_M` usa el índice del M-ésimo honesto, sin off-by-one (verificado
              contra el crudo). El baseline 3·30=90 es la convención declarada de D14B.
ADVERSARIO:   Un operador que lea «30,5-51,7 s vs 130,41 s» como misma garantía baja la
              profundidad de confirmación ~22 órdenes de magnitud en ε. Ese es el riesgo real.
IMPACTO:      El número medido no cambia; **la conclusión de mejora a igual seguridad no está
              demostrada**. Con ε=1e-12 la ganancia medida es 2,1-2,3× y el baseline sigue en
              ε≈1e-28: tampoco es comparable.
CORRECCIÓN:   Publicar la latencia con su ε y añadir la fila del baseline a igual ε (≈29,9 s a
              1e-6; ≈59,7 s a 1e-12). Suelo M2h: 30,3-67,2 s.
```

## II.4 · ¿Ninguna de las seis mitigaciones cierra sin coste?

```
AFIRMACIÓN:   informe3.md:136-153: (a) M2 cierra y congela 1-12/12; (b) M3 no cierra (12|12);
              (c) la base ya está y el ataque la atraviesa; (d) M1 no cierra (12|12), cong 0-6/12;
              (e) M4 no cierra (7|6), cong 0-8/12; (f) M5 no cambia la selección (12|12), cong 0-9/12.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE — con una cota corregida
DERIVACIÓN:   `d14k_mitigaciones_vis.py` re-ejecutado: idéntico. Agregado sobre el crudo:
              M2_cadena cap0/cap_ref=0, cong 1-12 (en ataque hasta 12/12; en red sana 1-9/12);
              M3_cierre peor 12|12, cong 0-7; M4_mayoria peor 7|6, cong 0-8; M5_rank_hon peor 12|12,
              cong 0-9; M2h cap_ref 0, cong 0-2; R1 cong 12-12; R1b cap0 0-2, cong 0-9.
              **M1: la congelación máxima es 4/12, no 6/12** (M1_cap4 máx 4; cap8 máx 3; cap16 máx 1).
              La conclusión «ninguna cierra sin coste» se mantiene con las seis.
ENTEROS:      Conteos enteros sobre 12 semillas × 4 estrategias × 4 (α,Δ); sin redondeos.
ADVERSARIO:   M2 y R1 cierran la captura a cambio de congelar siempre (12/12): DoS de liveness
              permanente, peor que el ataque.
IMPACTO:      El veredicto no cambia; solo la cota de congelación de M1.
CORRECCIÓN:   (d) M1: congelación 0-**4**/12.
```

## II.5 · D8 de M2h con retención creciente

```
AFIRMACIÓN:   informe3.md:175-189: α=0,40, Δ=20, R∈{20..1000}: M2h `cap_ref`=0/12 en todas las R y
              ambas políticas; congelación 0-2/12; el atacante solo sube `k_conf` y latencia.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE
DERIVACIÓN:   `d14k_d8_mitigacion.py` re-ejecutado: idéntico. cap_ref=0 en las 12 filas; cong máx
              2/12 (tips R=60); k_conf y latencia coinciden con la tabla del informe (tips R=20:
              4,4 y 55,6 [35,9;70,4]; sp R=20: 12,7 y 72,9 [35,9;158,2]…). Baseline α=0,40:
              3·30/0,6 = 150,0 s. Correcto.
ENTEROS:      R y latencias en s; 12 semillas por celda.
ADVERSARIO:   El atacante conserva `gan_att` en 10/12 (tips R=20) pero no logra `cap_ref`: la
              distinción inclusión/precedencia es la que sostiene M2h.
IMPACTO:      Refuerza la única mitigación que sobrevive.
CORRECCIÓN:   No aplica.
```

## II.6 · Fixture de la rama (score=4, rojos 12..17, rank 0)

```
AFIRMACIÓN:   informe3.md:80-96: `ref_umc_fixture.json` (md5 41cf6d88…, idéntico a la rama);
              `d14k_fixture_test.py` PASA: rank_view(tips=[11,17])=0, umc_voting score=4 con rojos
              12..17 y gris 8 excluido, cadena pura 1..11 rank 0.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE
DERIVACIÓN:   `md5sum` del fixture local = `41cf6d88eafa4079112bbc824bcf823f` = `git show
              origin/dagknight:consensus/umc_fixture.json | md5sum`. El test Python se ejecutó:
              VEREDICTO PASA (exit 0), con exactamente esas salidas. El vector de la rama existe:
              `consensus/umc_fixture.json` (genesis=1, k=0, subgroup=[11], virtual sp=11,
              blues=[11], reds=[12..17]); el oráculo Rust `Fixture::expected_score()` en
              `umc_voting.rs` calcula 10w−6w=4w y `umc_baseline.rs:180` / `umc_cascade.rs:706`
              hacen `assert_eq!(result.virtual_score, fixture.expected_score())`.
              **Límite:** no compilé `rusty-kaspa` (sin `target/`), así que el `cargo test` de esos
              asserts no se ejecutó; sí verifiqué el valor esperado en el fuente y la réplica Python.
ENTEROS:      score=4 exacto; w = calc_work(0x207fffff); blues y rojos como conjuntos enteros.
ADVERSARIO:   Un fixture mal copiado anclaría mal todo el instrumento; el md5 lo descarta.
IMPACTO:      El instrumento queda anclado al vector de la implementación de referencia.
CORRECCIÓN:   No aplica.
```

---

# Cierre D9

```
REFUTADAS:
  R1 · d15 §4.3/:77-80/:204-207 — frontera p0=0,746. Medida real ~0,785-0,79 (60 semillas);
       valle CTMC 0,7849. Un p0=0,76 da 60/60 rojo. IMPACTO: captura de finalidad en el tramo
       [0,746; 0,785] si se usa el umbral erróneo como condición de seguridad.
  R2 · d15 §0/:43-47, §4.1/:204-207, §4.5, §10 — «k=10,q=8, f≥0,25 → 20/20 semillas rojo».
       Falso: 0/20 a f=0,25-0,33; 5/20 (y 4/20 mixtas) a f=0,40. El salto a 1 es del CTMC, no
       de los agentes. IMPACTO: el control positivo del instrumento no está demostrado como se
       afirma (el instrumento sí responde a f y q; la frontera del paper f<0,2 es del paper).
  R3 · d14 §2.2 — congelación de M1 «0-6/12». Real 0-4/12 (cap4 4, cap8 3, cap16 1). IMPACTO: nulo
       en la conclusión (M1 sigue sin cerrar), cota mal.
  R4 · d14 §1.1 — «la palabra risk no aparece ni una vez (0 hits)» y «no hay definición de la
       función». El paper usa 𝑟𝑖𝑠𝑘 6 veces (953, 955, 972, 977, 998, 1000) y la define
       verbalmente en :977-978. `git grep -i risk` en la rama da 6 líneas, no 2. IMPACTO: la
       LAGUNA (sin forma cerrada ni implementación) se mantiene; la cita es falsa.
  R5 · d15 §5 — «Δ=8, T=Δ: empata». 120 s < 130,41 s → gana. IMPACTO: nulo.
  R6 · d15 §1.2 — rangos del resumen (28-38, 112-150, …) no coinciden con la tabla del propio
       informe (27-39, 108-156, …). IMPACTO: nulo en el veredicto.

NO DEMOSTRADAS:
  N1 · d14 — la ganancia de latencia 2,5-4,3× frente al baseline **no está medida a igual ε**:
       el baseline (M=3k=90) implica ε≈2,1e-28 bajo la fórmula del propio informe; M2h usa
       ε=1e-6/1e-12. A igual ε=1e-6 el baseline sería ~29,9 s (M=20), igual que M2h. La medida es
       verificada; la mejora a igual garantía, no.
  N2 · d14 — la latencia de M2h usa `k_conf` del DAG final (T=400), no del instante de
       confirmación: no es una simulación online de la regla.
  N3 · d15 — T=Δ como tiempo de ronda (voto por gossip) no sale del paper, que solo define la
       ronda consulta-respuesta; sin ella la ganancia de gossip (Δ<8,7 s) no es citable.
  N4 · d15 — el MTTF 10^1684,9 como «cota conservadora» de Snowball: el CTMC es Slush/Snowflake
       hacia todo-rojo; Slush flipea más (favorable) pero todo-rojo es más raro que un fallo de
       decisión (desfavorable). El neto no está demostrado; la evidencia real es 0/20 mixtas a
       f=0,33 con n=3000 y horizonte finito.
  N5 · d15 — «no es comité» es decisión de alcance, no teorema; bajo la definición amplia la
       recomendación B (override vinculante por muestra) sí cae.
  N6 · d15 — la tabla de β del voto embebido (4,1e-4 vs 2,5e-45) es un modelo heurístico de ruina
       que ignora la masa «sin chit» (0,115); la conclusión cualitativa no depende de ello.
  N7 · d14 — el test Rust del fixture no se compiló (sin `target/`); solo se verificó el valor
       esperado en el fuente y la réplica Python.

COTAS CORREGIDAS:
  C1 · d15 p0: 0,746 → ~0,785-0,79 (medido), 0,7849 (valle CTMC).
  C2 · d15 control k=10,q=8: «20/20 rojo» → 0/20 (f=0,25-0,33), 5/20 (f=0,40); el salto a 1 es
       del CTMC a f=0,25.
  C3 · d15 rangos del resumen → los de la tabla §5 (27-39 / 108-156 / 432-624 / 540-780;
       14-20 / 56-80 / 224-320 / 280-400).
  C4 · d15 Δ=8 T=Δ: «empata» → gana (120 s).
  C5 · d15 MTTF: 10^1684 → 10^1684,9 (1692,40 rondas).
  C6 · d15 0,206 s: «mediana» → moda («most common»); máximo ~0,4 s correcto.
  C7 · d14 M1 congelación: 0-6/12 → 0-4/12.
  C8 · d14 suelo M2h: 30,3-64,1 s → 30,3-67,2 s.
  C9 · d14 `git grep risk`: 2 → 6 líneas; paper: 0 → 6 apariciones de `𝑟𝑖𝑠𝑘` (definición verbal
       :977-978).
  C10 · d14 `dagknight.txt`: 1703 → 1702 líneas (100 387 B correcto).
  C11 · d14 baseline M=90: ε implícito ≈ 2,09e-28 bajo la fórmula del informe (cifra nueva que
       faltaba para interpretar la comparación).
  C12 · d14 `git log --all` del módulo: «60+» → 89 commits.

LO QUE NO PUDE VERIFICAR:
  · El stake de 2.000 AVAX (docs.avax.network, externo) — el informe ya lo declara LAGUNA.
  · La regla de cliente del paper de DAGKNIGHT: no existe; no hay nada que verificar (LAGUNA real).
  · El control 1,2/6/12 s del paper (requiere la regla ausente y λ=3,75; no reproducible).
  · `cargo test` de `rusty-kaspa`: no compilé el workspace (sin `target/`); el fixture y el valor
    esperado se verificaron por md5 y lectura de fuente.
  · Δ real de ZEROX (E1), fracción honesta online y distribución de tamaño de granja: sin datos,
    como dicen ambos informes.
  · El ataque de eclipse fuera del modelo del paper: no evaluable aquí.
```
