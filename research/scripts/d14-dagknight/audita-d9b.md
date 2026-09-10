# D9-B · Auditoría adversarial de D14B (DAGKNIGHT fiel) y D14C (sin comité)

**Rol:** D9 · Matemáticas y validación formal. **Mandato:** refutar, no validar.
**Fecha:** 2026-09-10. **Objeto:** `research/scripts/d14-dagknight/informe2.md` (D14B) y
`research/scripts/d14-sin-comite/informe.md` (D14C), con re-ejecución de sus scripts.
**Método:** lectura de fuente primaria local (paper, código de referencia, SPEC), re-ejecución de
los cuatro scripts de D14B y del script de D14C, y **control positivo propio** del fixture de
`rusty-kaspa@dagknight` (que ningún script del informe ejecuta). Se usó `git` **de solo lectura**
(`branch`, `ls-tree`, `show`, `log`) para comparar con la rama; no se hizo ninguna escritura de git
ni commit. Al re-ejecutar los scripts se reescribieron sus `salida_*.txt` con contenido
**byte-idéntico** al previo (verificado con `diff`).

---

## Bloque 1 · Control positivo de DAGKNIGHT (informe2, Puntos 0 y 1)

### A1 · La rama de referencia existe y el fixture es el real

```
AFIRMACIÓN:   informe2.md:22-29,49-52 — «`kaspanet/rusty-kaspa`, rama `dagknight` … el vector
              `consensus/umc_fixture.json`» y «`virtual_score = 4` … idénticos al oráculo
              `expected_score()` de `umc_voting.rs:274-277`».
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE (por D9; no por los scripts del informe)
DERIVACIÓN:   (a) `origin/dagknight` existe en `/home/katana/zeo/fuentes/rusty-kaspa`, tip
              `3353678ae69703b5fb603a335e7466a3c0604794` (2026-09-07).
              (b) `git show origin/dagknight:consensus/umc_fixture.json` tiene md5
              `41cf6d88eafa4079112bbc824bcf823f`, **idéntico** al `ref_umc_fixture.json` local
              (3092 B, diff vacío).
              (c) El oráculo `umc_voting.rs:274-277` devuelve `calc_work(0x207fffff) * 4`.
              (d) D9 ejecutó `d14k_ref.umc_voting` alimentado con el fixture (bloques 1..17, sp del
              fixture, virtual sp=11, blues=[11], reds=12..17): resultado `virtual_score=4`,
              rojos `12..17`, gris `8` (vía NCA=2), y `rank_dag` de la cadena pura 1..11 = 0.
              (e) D9 ejecutó además el pipeline completo `d14k_ref.rank_view` sobre el fixture:
              rank 0 con **dos** ganadores, el honesto {11} (score 4, blues 11..2+1) y el atacante
              {17} (score 2, blues 17..12+1).
ENTEROS:      k=0 → `deficit = isqrt(0) = 0`; sin truncamiento en juego. El fixture usa trabajo
              uniforme (`calc_work(0x207fffff)`), luego el cociente conteo/trabajo no se distingue.
ADVERSARIO:   El propio fixture contiene un subgrupo atacante que pasa la UMC al mismo rank 0: es
              una instancia del ataque de selección que D8c mide. El fixture no puede detectar la
              divergencia conteo↔trabajo (ver A5).
IMPACTO:      Si el fixture no fuera el real, el instrumento de D14B no estaría anclado a nada.
              Lo está.
CORRECCIÓN:   El informe dice «Esto es VERIFICADO contra código de referencia» como si su
              pipeline lo hubiera hecho. **Ningún script del repo carga `ref_umc_fixture.json`**
              (`grep` sobre `*.py` de `research/scripts/`: única mención, un comentario en
              `d14k_ref.py:9`). La validación existe, pero es de D9, no de la ruta de reproducción
              publicada. Añadir el test del fixture a `d14k_ref.py` o a `d14k_control2.py`.
```

### A2 · Citas del paper

```
AFIRMACIÓN:   informe2.md:56-93 — fig. 3 (`dagknight.txt:182-197`), Alg. 3/5/6, tie-breaking
              `:823-840`, `:996-999` (riesgo local), `:1007` (cota optimista), `:1021-1027`
              (pesimista), `:1064-1065` («will appear online»).
CLASIFICACIÓN: RESPALDADO POR FUENTE
DERIVACIÓN:   `dagknight.txt` (latin-1) verificado línea a línea:
              · :182-197 — fig. 3: D=2 k=4 t=12; D=1 k=1 t=6; D=0.1 k=0 t=1.2; λ=3.75, α=0.2,
                ε=0.05. Correcto.
              · :669 Alg. 3 (Calculate-Rank), :733 Alg. 5 (K-Colouring), :770 Alg. 6 (UMC-Voting).
              · :823-840 — §2.6.4 tie-breaking. Correcto.
              · :996-999 — «evaluating the function risk … by the client locally». Correcto.
              · :1007 — cota optimista; :1021-1027 — pesimista exponencial; :1064-1065 —
                implementación «made available online». Correcto.
ENTEROS:      no aplica (citas).
ADVERSARIO:   La rama existe pero **no contiene la regla de cliente ni la simulación**:
              `git grep` en `origin/dagknight` sobre `consensus/src/processes/dagknight/` y
              `consensus/benches/` no encuentra ninguna función de riesgo/confirmación ni
              simulación de tiempos (solo dos comentarios de tests con la palabra «simulate»,
              `manager.rs:680,941`). La conclusión de LAGUNA para los tiempos 1,2/6/12 s se
              sostiene.
IMPACTO:      ninguno; refuerza la LAGUNA declarada.
CORRECCIÓN:   «M_kMC» **no es el Alg. 1 del paper**. Alg. 1 (`:501-511`) es *Naïve ordering
              algorithm* (Order-DAG); M_kMC es el recuadro «KNIGHT Optimization: Minimal k
              Majority Cluster» (`:114-119`) y la definición de rank (`:548-550`). El script
              `d14k_control2.py:9` etiqueta «M_kMC fiel (Alg. 1…)»: cita errónea, resultado
              correcto.
```

### A3 · La validación del fixture no está en la ruta de reproducción

```
AFIRMACIÓN:   informe2.md:49-52, 240-253 — el control «valida el instrumento contra el vector de
              la implementación de referencia» y `AUDITA_SCRIPTS.py` da 0 sospechas.
CLASIFICACIÓN: REFUTADO (como propiedad del pipeline; el resultado es correcto, ver A1)
DERIVACIÓN:   `grep -rn "ref_umc_fixture" research/scripts/**/*.py` → solo `d14k_ref.py:9`
              (comentario). `AUDITA_SCRIPTS.py` re-ejecutado: 16 scripts, 0 sospechas (correcto),
              pero ese auditor no ejecuta fixtures: no puede validar el instrumento.
ENTEROS:      no aplica.
ADVERSARIO:   Un revisor que siga la sección «Reproducción» (informe2.md:229-236) obtiene las
              tablas, pero no el control contra el que se dice validado.
IMPACTO:      Reproducibilidad, no consenso. El instrumento sí queda validado por D9 (A1).
CORRECCIÓN:   Añadir un `d14k_fixture_test.py` que cargue el JSON y exija score=4, rojos 12..17,
              rank 0, y documentarlo en la sección de reproducción.
```

### A4 · Rank del protocolo en el control

```
AFIRMACIÓN:   informe2.md:81-83 — «medias 0,08-0,92 (honesta) y 0,08-1,00 (completa)».
CLASIFICACIÓN: REFUTADO
DERIVACIÓN:   `salida_control2.txt` §C, medias por (D,T): honesta = [0.08, 0.00, 0.17, 0.08,
              0.75, 0.17, 0.42, 0.58, 0.92, 1.58, 0.83, 1.17] → rango **0,00-1,58**; completa =
              [0.25, 0.00, 0.17, 0.00, 0.58, 0.42, 0.25, 0.25, 0.67, 1.00, 0.08, 0.33] → rango
              **0,00-1,00**. El 0,08-0,92 sale de mezclar solo la columna T=1,2.
ENTEROS:      no aplica.
ADVERSARIO:   ninguno; la conclusión cualitativa (rank ≪ 30) aguanta.
IMPACTO:      bajo (cifra, no conclusión).
CORRECCIÓN:   0,00-1,58 (honesta) y 0,00-1,00 (completa).
```

### A5 · «En ZEROX todos los bloques pesan 1»

```
AFIRMACIÓN:   `d14k_ref.py:26-27` — «en ZEROX y en el control del paper todos los bloques pesan 1
              (work = 1) … el modelo usa conteos»; heredado en la regla «fiel» de informe2.
CLASIFICACIÓN: REFUTADO para ZEROX
DERIVACIÓN:   La implementación de referencia es **ponderada por trabajo**:
              `umc_baseline.rs:75` (`deficit = k.isqrt() * work(CG)`), `:142-144`
              (`score = Σ votos − red_work + deficit`), `:161-163`
              (`virtual_score = signed_blue_work + deficit − red_work`). El diseño de ZEROX usa
              peso variable por bloque: `research/dag-poas-ancla-de-orden.md:157` —
              `blue_work = Σ⌊2^128/(SR+1)⌋` sobre azules. El simulador `r8c_gd.py:258` usa
              `work = 1 por bloque`, y el fixture usa `calc_work` constante: **ninguno de los dos
              puede detectar la diferencia**.
ENTEROS:      `isqrt(k)·w(CG)` vs `isqrt(k)`: con `w(CG)` variable el déficit cambia; el redondeo
              de `⌊2^128/(SR+1)⌋` no es el problema, lo es el cociente entre pesos.
ADVERSARIO:   Un atacante que concentre bloques de `SR` bajo (más trabajo por bloque) puede
              alterar qué subgrupo gana la UMC y qué tip es VSP. Con conteos, esa palanca no
              existe.
IMPACTO:      La medida `k_ref` «VERIFICADA» lo está **solo en la dimensión estructural** (rank +
              UMC + grises). Bajo los pesos reales de ZEROX (SR variable) **no está demostrada**;
              la latencia de 7,92 s y el suelo de 3-55 s podrían moverse.
CORRECCIÓN:   O (a) re-medir `d14k_ref` con `work = ⌊2^128/(SR+1)⌋` y SR variable, o (b) declarar
              en el cuerpo del informe la simplificación de trabajo uniforme (hoy solo está en el
              docstring del script) y degradar la etiqueta de la medida a
              PLAUSIBLE, NO DEMOSTRADO para ZEROX.
```

---

## Bloque 2 · Latencia (informe2, Punto 3)

```
AFIRMACIÓN:   informe2.md:122-135 — α=0,33: ε=0,05 → 7,92/3,29 s; 1e-3 → 14,14/8,67;
              1e-6 → 29,62/15,19; 1e-12 → 55,67/36,22; baseline 130,4 s; ≥12 semillas.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE
DERIVACIÓN:   Re-ejecutados `d14k_control2.py`, `d14k_zerox2.py`, `d14k_d8b.py` y `d14k_d8c.py`
              (32 núcleos; 1,4 s / 1,3 s / 39 s / 3 s). Las cuatro salidas son **byte-idénticas**
              a las guardadas (`diff` vacío). `salida_zerox2.txt` §D y §E: α=0,33 da exactamente
              7.92/3.29, 14.14/8.67, 29.62/15.19, 55.67/36.22 y baseline 130.41 s.
              `SEMILLAS` = 12 semillas (11,23,37,41,59,67,73,89,97,101,113,127).
ENTEROS:      `m(α,ε) = ⌈ln ε / ln(α/(1−α))⌉` con flotantes; α=0,33 exacto en la lista; sin
              truncamiento entero crítico.
ADVERSARIO:   El margen `M = max(3k_ref, m)` y «tiempo hasta el M-ésimo honesto tras B*» es una
              **adaptación propia**, no la regla de cliente del paper (LAGUNA, A2). El propio
              informe la etiqueta como adaptación (informe2.md:137-139): correcto.
IMPACTO:      Las cifras de latencia no son DAGKNIGHT certificado; son una cota de trabajo propia.
              El informe lo dice; el número que responde a Katana (3,29/7,92 s) queda como
              «adaptación sobre GHOSTDAG/rank fiel», con el ataque de selección abierto (A9).
CORRECCIÓN:   La columna «suelo M/((1−α)λ)» imprime 7,6 s, pero `m=5` y `(1−α)=0,67` dan
              5/0,67 = **7,46 s**; el 7,6 es la media de los suelos por registro
              `max(3k_ref, m)/((1−α)λ)` (con semillas de k_ref=2). Etiqueta imprecisa, cifra
              correcta.
```

---

## Bloque 3 · Umbral de Δ, manipulaciones y selección (informe2, Punto 4)

### A6 · `k_ref` no se infla en Δ ≤ 20

```
AFIRMACIÓN:   informe2.md:155-162 — suelos 3,3/6,7/13,3/23,3/30,0 (α=0,10), 4,0/8,0/12,0/32,0/
              40,0 (α=0,25), 5,0/5,0/10,0/20,0/55,0 (α=0,40) a Δ=1/4/8/16/20; todos < baseline.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE (para las 6 estrategias probadas)
DERIVACIÓN:   `salida_d8b.txt` §C coincide cifra a cifra; máximos individuales de `k_ref`:
              9 (α=0,10), 10 (α=0,25), 11 (α=0,40) a Δ=20 → suelos 30,0/40,0/55,0 s.
              `k_mkmc` ≤ 55,0 s. La inflación 27-50 del `k*` crudo de 14A no reaparece.
ENTEROS:      no aplica.
ADVERSARIO:   Solo 6 estrategias (instant, retraso20/60, burst300, parasita5, retro500) y
              Δ ≤ 20. No es una demostración general de no-inflación; el propio informe lo
              acota (informe2.md:185-187).
IMPACTO:      La conclusión «no hay umbral de Δ dentro de lo probado» es correcta **en el dominio
              probado**. La selección de subgrupo sigue abierta (A9).
CORRECCIÓN:   ninguna.
```

### A7 · M3 (mayoría honesta + cobertura ≥ 50 %): umbral y cifras

```
AFIRMACIÓN:   informe2.md:177-178 — «`k_hon` 12-27 (máx 34); suelo medio 123/144/127 s a Δ=20
              (α=0,10/0,25/0,40) → el umbral de Δ baja a 16».
CLASIFICACIÓN: REFUTADO (cifras) / la dirección del resultado se sostiene
DERIVACIÓN:   Recalculado desde `salida_d8b_crudo.txt`:
              · Δ=16: max k_hon = 22/21/26 → suelos **73,3/84,0/130,0 s** (< 100/120/150): M3
                **sí conserva ganancia a Δ=16**.
              · Δ=20: max k_hon = **37/36/34** → suelos **123,3/144,0/170,0 s** (> baseline):
                M3 muere a Δ=20. El «127» del informe es el suelo medio de *retraso60* α=0,40
                (§D), no el peor caso; y «máx 34» ignora el 37 y el 36.
ENTEROS:      `k_hon` es entero; `suelo = 3k/((1−α)λ)` exacto.
ADVERSARIO:   `k_hon = None` (M3 no encuentra ningún k en [k_ref, 40] con el criterio) en
              **55/72** registros a α=0,10 Δ=16 y **43/72** a Δ=20 (α=0,10); 39/27 a α=0,25;
              22/21 a α=0,40. El script excluye los `None` del máximo (`max(...)` sobre no-None):
              cuando M3 **no puede aplicarse**, el ataque no queda cubierto y el suelo impreso es
              optimista. La conclusión «M3 no es mitigación» se refuerza, pero el «suelo 123/144/
              170» es una **cota inferior** del daño, no un techo.
IMPACTO:      La recomendación (descartar M3) no cambia; las cifras publicadas deben corregirse.
CORRECCIÓN:   Δ=20 → **123,3/144,0/170,0 s**; «máx k_hon = 37»; y declarar los `None`.
```

### A8 · M1 «no arregla la selección»

```
AFIRMACIÓN:   informe2.md:176 — «M1 tope de k … No hace falta … no arregla la selección».
CLASIFICACIÓN: PLAUSIBLE, NO DEMOSTRADO
DERIVACIÓN:   `d14k_d8b.py` documenta en su docstring (líneas 12-13) que M1 debe medir «si el
              cluster a k_cap sigue siendo mayoritariamente honesto», pero `_tarea` **no calcula
              esa fracción** (solo k_ref, k_mkmc, hon_frac del ganador a k_ref, k_chain, k_hon).
              La tabla §D imprime los k_cap, no su honestidad. La afirmación «no arregla la
              selección» no se sigue de la salida.
ENTEROS:      no aplica.
ADVERSARIO:   Con `retro500` α=0,40 Δ=20 la media de k_ref es 7,8 (máx 11) y el tope K=4 la
              dejaría en 0,7: el tope cambia mucho la medida y su efecto sobre la selección es
              justamente lo no medido.
IMPACTO:      Una de las cuatro mitigaciones queda sin veredicto real.
CORRECCIÓN:   Medir `hon_frac` del cluster con `k_cap = min(k_ref,K)` para K=4/8/16, o retirar la
              afirmación.
```

### A9 · Ataque de selección de subgrupo

```
AFIRMACIÓN:   informe2.md:164-170,198 — «con retraso20/retraso60, Δ≥16, α≥0,25, no hay ningún
              ganador honesto en 0-3/12»; con parásita5/retro500 hay ganador honesto 12/12 y el
              tie-breaking lo elige 12/12.
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE
DERIVACIÓN:   `salida_d8c.txt` (re-ejecutado, idéntico): retraso20/60 con Δ≥16 y α≥0,25 dan
              ganador honesto en 1/12, 1/12 (α=0,25 Δ=16), 1/12, 3/12 (α=0,25 Δ=20), 0/12, 1/12
              (α=0,40 Δ=16), 0/12, 1/12 (α=0,40 Δ=20) → **0-3/12**. parásita5/retro500: 12/12 y
              12/12 seleccionado honesto.
ENTEROS:      no aplica.
ADVERSARIO:   El tie-breaking de D8c es un **proxy** de Alg. 4 (F a `g(k)=isqrt(k)`, umbral
              `> k_ref`, una sola k′), no el Alg. 4 completo (k′ ∈ [⌊k/2⌋,k]): el informe lo
              etiqueta «proxy» (informe2.md:179). La afirmación «impotente sin ganador honesto»
              no depende del proxy.
IMPACTO:      El hueco de seguridad queda establecido: el rank solo no basta a Δ≥16.
CORRECCIÓN:   Precisión de redacción: en 9-12 de 12 semillas **no hay** ganador honesto; «no hay
              ninguno en 0-3/12» se lee mal.
```

---

## Bloque 4 · D14C (sin comité)

### A10 · Prism 7,1-28,9 h a D = 4 s

```
AFIRMACIÓN:   informe.md:87,200-205 — c1(0,25)≈6 404 → 7,12 h; c1(0,33)≈26 044 → 28,94 h con
              D=4 s (Teorema 4.8).
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE
DERIVACIÓN:   Recalculado con la fórmula del Teorema 4.8 (`prism-1810.08092.txt:1351-1358`):
              c1(0,25)=6404.052 → 25 616,2 s = 7,116 h; c1(0,33)=26 044,261 → 104 177,0 s =
              28,938 h. `calcula_numeros.py` re-ejecutado: salida **idéntica** a
              `salida_numeros.txt`. Ojo: en `:1258` el paper define otra c1 (2808, list
              confirmation); el script usa correctamente la de 4.8 (5400).
ENTEROS:      logaritmos en flotante; sin truncamiento.
ADVERSARIO:   Es la cota `c1·D`; el término `c2·(Bv/C)·ln(1/ε)` no está acotado porque `Bv/C` no
              está fijado en ZEROX (el informe lo dice). El doble gasto crece y supera a la
              cadena más larga cerca de β=0,5: la cita del informe (:1413-1425) apunta a la
              descripción del ataque; la frase exacta está en `:1442-1445` y `:3683`.
IMPACTO:      ninguna cifra que corregir.
CORRECCIÓN:   cita recomendada: `:1437-1445` y `:3683`.
```

### A11 · Avalanche, SPECTRE, CAP, C-CHK y exclusiones

```
AFIRMACIÓN:   informe.md:46,85-86,91 — Avalanche 1,35 s y 2 000 AVAX; SPECTRE 21 s; CAP
              «No protocol is both adaptive and has finality» (`lewispye-roughgarden-cap.txt:759`);
              C-CHK es un firmante único que centraliza; exclusiones por comité.
CLASIFICACIÓN: RESPALDADO POR FUENTE / VERIFICADO
DERIVACIÓN:   · Avalanche 1,35 s: `avalanche-1906.08936.txt:24` (abstract: 3400 tps, 1.35 s) y
                `:1254` (mediana 1,35 s). **2 000 AVAX**: `docs.avax.network/docs/primary-network`
                (consultado 2026-09-10): «staking at least 2,000 AVAX».
              · SPECTRE 21 s: `phantom-ghostdag.txt:824-837` (λ=1/s, 2D=7 s, k=16, α≤0,25,
                ε=0,1 % → GHOSTDAG ~45 s, SPECTRE ~21 s). Correcto.
              · CAP: `lewispye-roughgarden-cap.txt:759` — «Theorem 4.1. No protocol is both
                adaptive and has finality». Literal. Definición de adaptativo en `:727`.
              · C-CHK: `SPEC.md` C-CHK-01 — «Existe un único checkpoint firmado en la vida de la
                cadena. Una vez emitido, la clave que lo firma se destruye». Firmante único:
                centraliza. Correcto.
              · Exclusiones: BFT fijo (comité+depósito), Algorand (sortición), Avalanche (muestra
                que decide; Sybil sin resolver, `:255-274`), Thunderella (acelerador+comité 3/4,
                `thunderella-2017-913.txt:155-180`), P-040/F3 (sorteo ponderado K=4 000,
                `dag-poas-capa-finalidad.md:71-72`), Filecoin F3 (QAP ≥2/3, `fip-0086.md:52-57`),
                C-CHK (firmante único). Todas correctas bajo la restricción de Katana.
              · Spacemesh: web (2026-09-10) confirma insolvencia de Unruly Technologies (filing
                abril-2025; postmortem 18-may-2025). El informe dice «may-2025»: un mes de
                desfase, sin impacto.
ENTEROS:      no aplica.
ADVERSARIO:   · La cita de Algorand en `informe.md:281` (`cap-adaptividad-finalidad.txt:32`) es
                incorrecta: la línea 32 dice que la cadena más larga es adaptativa. La
                justificación correcta es `lewispy-roughgarden-cap.txt:742-747` («BFT protocols
                such as Algorand … specifies committee sizes») o `cap-adaptividad-finalidad.txt:176-178`
                (su protocolo de checkpoint es «a slight modification of Algorand BA»).
              · `FINALIZATION_DEPTH_IN_SEGMENTS` está en `archiver.rs:90`, no `:82-88` (la cita
                del cuerpo es `:82-88`); `SLOT_PROBABILITY` está en `lib.rs:48`, no `:219-225`
                (esto último solo aparece en el texto impreso de `calcula_numeros.py:55`; el
                cuerpo del informe cita bien `:48`).
IMPACTO:      Errores de cita, no de cifra.
CORRECCIÓN:   corregir las tres referencias.
```

### A12 · Coherencia 14C ↔ 14B en DAGKNIGHT

```
AFIRMACIÓN:   informe.md:50-53,90 — «DAGKNIGHT … 4-17 s de media a ε=0,05, mínimo 0,36 s; pero
              el atacante puede inflar `k*` y devolver el suelo a 90-250 s».
CLASIFICACIÓN: REFUTADO como estado actual del conocimiento
DERIVACIÓN:   Esos números son de `informe.md` (14A) con el `k*` crudo. El propio 14B
              (`informe2.md:141-162`) muestra que con la regla fiel el atacante **no infla** en
              Δ≤20 (suelos 30/40/55 s) y que las latencias a ε=0,05 son 4,80-12,32 s de media
              (α=0,10-0,40) y mínimo 0,36 s. La «inflación 90-250 s» corresponde al criterio
              refutado.
ENTEROS:      no aplica.
ADVERSARIO:   El hueco real que sobrevive es **otro**: el ataque de selección de subgrupo
              (retraso20/60, Δ≥16, α≥0,25), no la inflación de k.
IMPACTO:      La recomendación de 14C («DAGKNIGHT completo … la única esperanza conocida de
              sobrevivir al ataque de inflación») queda desactualizada: la inflación se cerró en
              lo probado y se abrió la selección.
CORRECCIÓN:   En 14C, sustituir la fila DAGKNIGHT por la de 14B: latencia 4,8-12,3 s a ε=0,05
              (adaptación), suelo ≤55 s a Δ≤20, y el ataque abierto de selección a Δ≥16.
```

---

## Tabla de cifras

| # | Afirmación | Valor del informe | Valor recalculado | Etiqueta |
|---|---|---|---|---|
| 1 | Rama `dagknight` existe; fixture real | existe | tip `3353678a` (2026-09-07); md5 fixture `41cf6d88…` idéntico | VERIFICADO COMPUTACIONALMENTE |
| 2 | Fixture da `virtual_score=4`, rojos 12..17, rank cadena=0 | 4 | 4; rojos 12..17; gris 8; rank 0 (D9, `umc_voting`+`rank_view`) | VERIFICADO COMPUTACIONALMENTE |
| 3 | El pipeline del informe valida el fixture | «VERIFICADO» | ningún `.py` carga el fixture | REFUTADO (como pipeline) |
| 4 | M_kMC medias con atacante revelado | 0,17/1,92/3,33 | 0,17/1,92/3,33 (D=0,1/1/2; T=1,2/6/12) | VERIFICADO COMPUTACIONALMENTE |
| 5 | Rango del paper 0/1/4 contenido en la distribución | sí | sí (0 en D=0,1; 1 en D=1; 4 en D=2) | RESPALDADO POR FUENTE |
| 6 | Tiempos 1,2/6/12 s del paper | no reproducidos | no reproducidos: falta regla de cliente y simulación (no están en el paper ni en la rama) | RESPALDADO POR FUENTE (LAGUNA) |
| 7 | Rank del protocolo (control) | medias 0,08-0,92 / 0,08-1,00 | **0,00-1,58** / **0,00-1,00** | REFUTADO (cifra) |
| 8 | «M_kMC = Alg. 1» | Alg. 1 | Alg. 1 es Order-DAG naïve; M_kMC es el recuadro `:114-119` | REFUTADO (cita) |
| 9 | «En ZEROX todos los bloques pesan 1» | work=1 | ZEROX: `blue_work=Σ⌊2^128/(SR+1)⌋` variable | REFUTADO; medida bajo peso real NO DEMOSTRADA |
| 10 | Latencia α=0,33, ε=0,05 | 7,92 / 3,29 s | 7,92 / 3,29 s | VERIFICADO COMPUTACIONALMENTE |
| 11 | ε=1e-3 / 1e-6 / 1e-12 | 14,14/8,67; 29,62/15,19; 55,67/36,22 | idénticos | VERIFICADO COMPUTACIONALMENTE |
| 12 | Baseline k=30, α=0,33 | 130,4 s | 130,41 s | VERIFICADO COMPUTACIONALMENTE |
| 13 | Suelo ε=0,05 α=0,33 | 7,6 s | 7,46 s (`m=5`); 7,6 es media de suelos por registro | COTA CORREGIDA (etiqueta) |
| 14 | k_ref no se infla, Δ≤20 | suelos 3,3-55 s | idénticos (6 estrategias, Δ≤20) | VERIFICADO COMPUTACIONALMENTE (dominio probado) |
| 15 | M3 suelos a Δ=20 | 123/144/**127** s | **123,3/144,0/170,0 s**; máx k_hon 37/36/34 | REFUTADO (cifra) |
| 16 | M3 umbral | «baja a 16» | conserva ganancia a Δ=16 (73,3/84,0/130,0); muere a Δ=20 | VERIFICADO (matiz de redacción) |
| 17 | M3 con `k_hon=None` | no se menciona | 21-55 de 72 registros sin mitigación viable a Δ≥16 | NO DEMOSTRADO (suelo optimista) |
| 18 | M1 no arregla la selección | afirmado | no medido por `d14k_d8b.py` | PLAUSIBLE, NO DEMOSTRADO |
| 19 | retraso20/60, Δ≥16, α≥0,25: ganador honesto | 0-3/12 | 0-3/12 (9-12/12 sin ganador honesto) | VERIFICADO COMPUTACIONALMENTE |
| 20 | parásita5/retro500: 12/12 honesto y elegido | 12/12 | 12/12 y 12/12 | VERIFICADO COMPUTACIONALMENTE |
| 21 | Prism a D=4 s | 7,12 h / 28,94 h | 6404,05→7,116 h; 26044,26→28,938 h | VERIFICADO COMPUTACIONALMENTE |
| 22 | Avalanche | 1,35 s; 2 000 AVAX | abstract `:24`/`:1254`; docs AVAX live | RESPALDADO POR FUENTE |
| 23 | SPECTRE | 21 s | `phantom-ghostdag.txt:824-837` | RESPALDADO POR FUENTE |
| 24 | CAP | `:759` | literal verificado | RESPALDADO POR FUENTE |
| 25 | C-CHK centraliza | firmante único | SPEC C-CHK-01 lo confirma | VERIFICADO |
| 26 | Exclusiones por comité | correctas | correctas; 3 citas de línea erradas | RESPALDADO POR FUENTE (citas a corregir) |
| 27 | 14C cita DAGKNIGHT 4-17 s / inflación 90-250 s | actual | superado por 14B: 4,8-12,3 s; suelo ≤55 s; hueco = selección | REFUTADO como estado actual |

---

## Cierre D9

```
REFUTADAS:
  R1. «Medias del rank del protocolo 0,08-0,92 (honesta) / 0,08-1,00 (completa)» → 0,00-1,58 y
      0,00-1,00. Impacto: cifra, no conclusión.
  R2. «M3 suelo medio 123/144/127 a Δ=20» → 123,3/144,0/170,0; «máx k_hon 34» → 37.
      Impacto: la mitigación M3 sigue descartada, pero con daño mayor del publicado.
  R3. «Alg. 1 = M_kMC» → Alg. 1 es Order-DAG naïve; M_kMC es el recuadro de optimización
      (:114-119) y la definición de rank (:548-550). Impacto: cita.
  R4. «En ZEROX todos los bloques pesan 1» → ZEROX usa blue_work variable
      (research/dag-poas-ancla-de-orden.md:157) y la referencia pondera por trabajo
      (umc_baseline.rs:75,142-144,161-163). Impacto: la medida k_ref de ZEROX queda
      NO DEMOSTRADA bajo sus pesos reales; la latencia de 7,92 s podría moverse.
  R5. «El control valida el instrumento contra el fixture» → ningún script lo ejecuta (solo un
      comentario). El resultado es correcto y lo verifiqué yo (score=4, rojos 12..17, rank 0).
      Impacto: reproducibilidad.
  R6. 14C: «DAGKNIGHT 4-17 s / inflación de k* a 90-250 s» → superado por 14B (regla fiel: suelo
      ≤55 s a Δ≤20; hueco real = selección de subgrupo). Impacto: recomendación de 14C a
      actualizar.

NO DEMOSTRADAS:
  N1. La regla «fiel» con pesos reales de ZEROX (SR variable): conteos ≠ trabajo.
  N2. M1 (tope de k): su efecto sobre la selección no se midió; el script no calcula la
      honestidad del cluster topado.
  N3. El «suelo M3» ignora los `k_hon=None` (21-55 de 72 registros a Δ≥16): es cota inferior
      optimista, no suelo.
  N4. No-inflación general de k_ref: solo 6 estrategias y Δ≤20.
  N5. La rama `origin/dagknight` local está en 2026-09-07; sin `fetch` (prohibido git de
      escritura) no puedo confirmar el tip remoto del 2026-09-10 que dice el informe. El fixture
      local es idéntico al de la rama local, no necesariamente al remoto de hoy.

COTAS CORREGIDAS:
  · M3, Δ=20: 123,3 / 144,0 / 170,0 s (no 123/144/127). Máx k_hon 37/36/34 (no 34).
  · Rank del control: honesta 0,00-1,58; completa 0,00-1,00.
  · Suelo ε=0,05 α=0,33: m/((1−α)λ) = 7,46 s; el 7,6 impreso es la media por registro.
  · 14C: FINALIZATION_DEPTH_IN_SEGMENTS en archiver.rs:90 (no 82-88);
    SLOT_PROBABILITY en lib.rs:48 (no 219-225 en el texto del script);
    Algorand: citar lewispye-roughgarden-cap.txt:742-747, no cap-adaptividad:32.

LO QUE NO PUDE VERIFICAR:
  · Tip remoto de `dagknight` a 2026-09-10 (sin fetch; solo refs locales).
  · La regla de cliente del paper y su simulación: no existen públicamente (LAGUNA que el
    informe ya declara).
  · El impacto cuantitativo de los pesos SR variables sobre k_ref (requiere re-medir).
  · «1,35 s» como finalidad general de Avalanche: es la latencia mediana de *su* despliegue de
    2 000 nodos (`:1254`), no una cota universal.
  · Fecha exacta de la insolvencia de Spacemesh: web dice abril-2025 (filing) y 18-may-2025
    (postmortem); el informe dice «may-2025».
```

**Veredicto de conjunto.** El control positivo de D14B resiste: la rama existe, el fixture es
real y la regla fiel reproduce `virtual_score=4` con rojos 12..17 (verificado por D9, no por los
scripts). Las cifras de latencia, el suelo de `k_ref` y el ataque de selección se reproducen
byte a byte. Lo que no resiste es la etiqueta de «fiel» para ZEROX con pesos variables, la
validación del fixture como parte del pipeline, tres cifras concretas (rank del control, M3 y
`k_hon`) y la vigencia de los números de DAGKNIGHT en D14C. D14C, en lo demás, se apoya en
fuentes primarias correctamente citadas (con tres líneas mal puestas) y sus números aritméticos
(Prism, CAP, AVAX, Filecoin, Chia, Autonomys) son exactos.
