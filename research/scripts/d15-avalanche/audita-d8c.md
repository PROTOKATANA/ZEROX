# D8c — Auditoría adversarial de D15A (Snowball sobre espacio) y D14C (`informe3`)

**Fecha:** 2026-09-10 · **Rol:** D8 · Seguridad / auditoría adversarial (zx-d8-adversarial).
**Rondas auditadas:** `research/scripts/d15-avalanche/informe.md` (D15A) y
`research/scripts/d14-dagknight/informe3.md` (D14C).
**Alcance:** no se modificó ningún fichero del repositorio salvo este informe; no se ejecutó ningún
comando git **en ZEROX**. Se ejecutó un `git show` de solo lectura sobre el clon externo
`/home/katana/zeo/fuentes/rusty-kaspa` (rama `origin/dagknight`) para verificar el voto ponderado de
`umc_baseline.rs`; no escribió nada. Las dos sondas nuevas se corrieron sobre **copias** en
`/tmp/opencode/d8c/` (comandos en §7).

**Postura.** Asumo que cada conclusión es falsa hasta que el ataque falla. Etiquetas: CONFIRMADO
(reproducido o demostrado), SOSPECHA (mecanismo real, sin reproducir), DESCARTADO (ataque que no
funciona, con motivo). Cada hallazgo usa el formato obligatorio del rol.

**Resultado en una línea.** Ninguna de las dos vías muere entera, pero las dos quedan **condicionadas
a cosas que los informes no miden**: D15A por el split permanente sin slashing y por la frontera del
override; D14C por el instrumento sin pesos reales y por la cola de latencia que **supera** el
baseline. Lo que no sobrevive tal cual: «la latencia de D15A vale a α=0,33» (solo a ese α), «no es
comité» (solo en la variante que no compra nada), «máx 94,25 s < baseline» (falso en el peor caso),
«DAGKNIGHT REFUTADO» como titular y «pesos uniformes es una condición menor» (invalida el número
publicable).

---

## 0 · Tabla de conclusiones atacadas

| # | Conclusión | ¿Sobrevive? | Mejor ataque | Estado |
|---|---|---|---|---|
| D15-1 | El override compra latencia sin tocar la frontera | **No** como está escrita | d12 §G.2: un gadget vinculante a horizonte corto baja la frontera; aquí el voto ata `f < 1−q/k = 0,40` y el DAG aguanta 46,9 % a Δ=4 s | CONFIRMADO |
| D15-2 | No es un comité | **Solo en la variante A (asesora), que el informe refuta** | La única variante útil (B, override) hace del voto la decisión efectiva | CONFIRMADO |
| D15-3 | La ventana por `slot` anula la retención | **Sí para el conteo; no para el marco** | Supresión parcial de soluciones honestas sesga el marco del sampler, no la respuesta | SOSPECHA |
| D15-4 | Sesgo de respuesta (≥32,8 %) y supresión no matan | **Seguridad sí; viveza no** | Si el nodo cierra al recibir `q`, el adversario de baja latencia sobrerrepresenta; con conteo absoluto el voto se estanca | SOSPECHA |
| D15-5 | MTTF 10^1684 y seguridad a `f=0,33` | **Sí a `f=0,33`; el propio CTMC se estrella a `f≥0,36`** | Valle en 0,9998 y MTTF 10^98,9 rondas a `f=0,40` (`salida_ctmc.txt:31-33`) | CONFIRMADO (alcance) |
| D15-6 | Latencia 29-116 s si Δ≤4 s | **Solo a `f=0,33`** | A `f=0,40`: r90=25 → 204 s a Δ=4 s (`salida_agentes.txt:85`) | CONFIRMADO |
| D15-7 | Split permanente sin slashing (fallo nuevo) | **Sí, y es peor de lo que dice el informe** | Equivocación por lado de partición; no necesita `p0<0,746` | CONFIRMADO |
| D14-1 | «DAGKNIGHT REFUTADO» | **El cuerpo sí; el titular no** | El paper ya avisa de «D subestimado → aceptación prematura» (`dagknight.txt:347-351`) | CONFIRMADO (titular) |
| D14-2 | `retraso20` 12/12 es ataque real | **Sí** | Es el modelo del paper (atacante sin retardo, `dagknight.txt:321-325`); no es artefacto | CONFIRMADO |
| D14-3 | M2h es publicable | **Solo como regla de cliente; sin teorema** | Ganador adversario en 8/12 semillas de red sana (`salida_latencia2.txt:23`); el margen de ruina no cubre la carrera de clúster | SOSPECHA |
| D14-4 | Congelación ≤2/12 aceptable | **Matizada** | Red sana: `cong_h` 4-8/12; el ≤2/12 es en ataque y con 12 semillas | CONFIRMADO (matiz) |
| D14-5 | Precedencia 3-9/12 es problema de seguridad | **No para un pago** | La inclusión (que M2h sí garantiza) es lo que evita el doble gasto | CONFIRMADO (matiz) |
| D14-6 | M2h con `blue_work` variable | **No demostrado: la referencia pondera por trabajo y el instrumento no** | `umc_baseline.rs` vota `±work(B)`; `d14k_ref` usa conteos; ZEROX usa `Σ⌊2^128/(SR+1)⌋` | CONFIRMADO |
| D14-7 | Latencia máx < baseline en todas las semillas | **Falso en el peor caso** | R=40 tips, α=0,40, Δ=20: máx 168,5 s > 150 s (sonda propia); R=20 sp: 158,2 s > 150 s | CONFIRMADO |
| D14-8 | «2,5-4,3× mejor que 130,41 s» | **Comparación no homogénea** | El baseline no tiene ε; la curva real da ~0,25-1 de riesgo a 130 s | CONFIRMADO (omisión) |

---

## 1 · D15A — Snowball sobre peso de espacio

### H-D15-1 · Split permanente por partición + equivocación gratis (el mejor ataque)

```
HALLAZGO:     El override vinculante convierte una partición en dos finalidades permanentes y
              contradictorias, sin que el adversario tenga que ganar ningún voto.
SEVERIDAD:    split
ESTADO:       CONFIRMADO
ESCENARIO:    Partición que dura más que d (la profundidad del checkpoint). Lado A con h_A del
              espacio honesto, lado B con h_B, adversario con f=0,33 presente en los dos (sus
              nodos cruzan la partición). Cada lado vota su propio checkpoint. El adversario
              responde a cada lado con la mayoría local (equivocación). Con k=50, q=30, q/k=0,60:
              · lado A (h_A=0,40): p = 0,40+0,33 = 0,73 → P(chit ≥30) = 0,985 por ronda;
              · lado B (h_B=0,27): p = 0,27+0,33 = 0,60 → P(chit ≥30) = 0,561 por ronda
                (11 chits: mediana 18 rondas, p90 23).
              Ambos lados alcanzan confianza β1=11 y finalizan checkpoints distintos. Al curar la
              partición, R-FIN-18 («MUST NOT reorganizar por debajo») impide a cada lado seguir al
              otro; no hay slashing; «finalidad = max(voto, R-FIN-7)» no ordena dos checkpoints a la
              misma profundidad. Split permanente.
              El informe reconoce el mecanismo (`informe.md:345-350`) pero lo condiciona a
              «dos lados con p0<0,746» (`:347-349`); la equivocación por lado es más barata: no hay
              que invertir a nadie, basta con no contradecir a cada mayoría local.
UBICACIÓN:    `informe.md:336-343` (composición), `:345-350` (fallo nuevo), `:251-256` (p0).
PRECONDICIÓN: partición de red > d; 33 % del espacio; cero dinero (la equivocación no se castiga).
MITIGACIÓN:   slashing (prohibido por la restricción de dinero), o votar solo checkpoints en el
              pasado común con d mayor que la partición máxima esperada (no acotable a priori), o
              hacer el voto no vinculante (posición A, que no compra latencia). Sin dinero, no hay
              mitigación a la vista. La vía B no es publicable así.
```

**Nota de consistencia.** La §6 del informe dice «No hay contradicción formal» (`informe.md:343`)
y once líneas después describe el nodo «congelado en la mentira para siempre» (`:348-350`). Las dos
frases no pueden ser verdaderas a la vez: si el voto puede finalizar algo que R-FIN-7 no habría
finalizado, R-FIN-18 **sí** está mal escrita (es la pregunta 3 del encargo de P-040,
`dag-poas-capa-finalidad.md:328-329`).

### H-D15-2 · El override no tiene cálculo de frontera

```
HALLAZGO:     El informe no calcula qué le hace el override a la frontera del DAG; el precedente
              d12 §G.2 dice que un gadget vinculante a horizonte corto la baja.
SEVERIDAD:    seguridad / documental
ESTADO:       CONFIRMADO (la omisión); SOSPECHA en el número exacto (el modelo de seguridad del
              voto no es el del certificado de d12).
ESCENARIO:    La posición B solo compra si el voto progresa: f < 1−q/k = 0,40 con q/k=0,60
              (`informe.md:197-207`). La frontera de flujo único del DAG es 46,9 % a Δ=4 s
              (`dag-poas-ancla-de-orden.md:156`), y cae a 38,3 % (Δ=16) y 32,4 % (Δ=20). En el
              intervalo 40-46,9 % —justo donde el override gana latencia, Δ≤4— el DAG aguanta y el
              voto se atasca: el override reduce el sobre operativo. Además el propio CTMC del
              informe da valle en 0,9998 de los honestos a f=0,40 (`salida_ctmc.txt:33`), o sea
              margen cero. d12 §G.2 midió el patrón: 44,69 % → 32,98 % a d+W=988 s y **sin frontera**
              a 143 s (`d12-quorum/informe.md:668-690, :856`). El informe no hace el cálculo análogo
              ni argumenta por qué no aplica.
UBICACIÓN:    `informe.md:197-207, :288-316, :328-343`.
PRECONDICIÓN: f ∈ [0,40; 0,469] con Δ≤4 s.
MITIGACIÓN:   publicar el umbral efectivo min(frontera DAG, 1−q/k, umbral de p0) y aceptar por
              escrito que el override no puede operar por encima de 0,40.
```

### H-D15-3 · La tabla de latencia es solo para `f=0,33`

```
HALLAZGO:     La latencia publicable (29-116 s) se mide solo a f=0,33; a f=0,40 —el α que usa D14
              en su rejilla— la ganancia se reduce a Δ≲2 s.
SEVERIDAD:    documental
ESTADO:       CONFIRMADO (medido con el instrumento del propio informe).
ESCENARIO:    `salida_agentes.txt:85`: a f=0,40, k=50, q=30, r90=25 rondas (frente a 14 a f=0,33).
              Con T=2Δ: Δ=1 → 54 s; Δ=2 → 104 s; Δ=4 → 204 s > 130,41 s. A f=0,45 el simulador da
              20/20 semillas rojas (`:86`), y a f=0,40 el CTMC da MTTF 10^98,9 y valle 0,9998
              (`salida_ctmc.txt:33`). La tabla del informe (`informe.md:295-301`) solo tiene f=0,33.
UBICACIÓN:    `informe.md:290-316`; `salida_agentes.txt:76-87`; `salida_ctmc.txt:25-33`.
PRECONDICIÓN: ninguna.
MITIGACIÓN:   recalcular la tabla a f=0,40 o declarar el 33 % como límite vinculante del diseño.
```

### H-D15-4 · «No es comité» se sostiene solo en la variante que no compra nada

```
HALLAZGO:     La respuesta de Q6/Q7 (no es comité) es correcta para la posición A (señal asesora)
              y discutible en la posición B (override vinculante), que es la única que el propio
              informe considera útil.
SEVERIDAD:    menor (decisión de alcance, no bug)
ESTADO:       CONFIRMADO (tensión interna)
ESCENARIO:    El informe descarta A como REFUTADO («no baja la irreversibilidad»,
              `informe.md:335`) y vende B («compra latencia», `:336`). Pero B es exactamente
              «el nodo MUST NOT reorganizar por debajo» (`:338-343`): el voto pasa a ser la
              decisión efectiva. Que cada nodo valide localmente su contador no lo distingue de un
              certificado BFT, donde cada nodo también valida localmente. La membresía de facto es
              el conjunto rodante de soluciones de la ventana, finito y público por decisión
              (`:376-378`). Bajo la definición estricta el informe tiene razón; bajo la restricción
              de Katana («sin comités de decisión»), la carga de la prueba está en la variante B,
              no en A.
UBICACIÓN:    `informe.md:98-105, :328-343, :358-378`; `ENCARGO.md:4-5`.
PRECONDICIÓN: ninguna.
MITIGACIÓN:   responder a Katana con la distinción A/B explícita: «no es comité como señal; es un
              comité muestreado de facto como override».
```

### H-D15-5 · Sesgos de respuesta y de marco

```
HALLAZGO:     El argumento «q absoluto de k identidades» protege contra la supresión de respuestas
              pero no contra dos sesgos que el informe no modela: (i) el cierre de ronda al recibir
              q respuestas premia al respondedor rápido (el adversario puede serlo); (ii) el marco
              es «soluciones conocidas en la ventana», y suprimir parcialmente soluciones honestas
              antes de muestrear sesga el marco, no la respuesta.
SEVERIDAD:    DoS/viveza (seguridad si el sesgo supera 1−q/k)
ESTADO:       SOSPECHA (no reproducido; el instrumento del informe no modela el marco parcial).
ESCENARIO:    (i) El informe exige que responda el 32,8 % de los honestos «muestreados»
              (`informe.md:264`; `salida_muestreo.txt:34-45`), pero si el nodo cierra al recibir q,
              el conjunto contado son los primeros respondedores; con el adversario co-ubicado y
              granjeros domésticos lentos, la fracción contada sube sin Sybil.
              (ii) `salida_muestreo.txt:47-58` demuestra que con conteo absoluto el adversario no
              fabrica q rojos. Cierto si el marco es completo. Si el sampler construye el marco con
              lo que recibe, un eclipse parcial (o supresión selectiva) reduce la cuota honesta del
              marco y el ataque vuelve. El informe etiqueta el eclipse completo como LAGUNA
              (`informe.md:268, :406`), pero no el sesgo parcial de marco.
UBICACIÓN:    `informe.md:81-88, :258-274, :318-324`; `salida_muestreo.txt:34-58`.
PRECONDICIÓN: control de red parcial sobre el sampler o sobre el gossip de soluciones honestas.
MITIGACIÓN:   ronda con deadline fijo (no cerrar al llegar a q) y muestreo desde el marco completo
              verificado por `slot`; medir la sensibilidad al marco incompleto.
```

### H-D15-6 · La ventana por `slot` y la retención: el conteo es invariante, el marco no

```
HALLAZGO:     «La retención no crea credenciales» es correcto para el conteo de soluciones de la
              ventana (`f_eff = f`), pero el adversario elige cuándo revelar sus soluciones y el
              sampler solo muestrea lo que conoce; el límite superior del sesgo es Δ/W (con W=3600 s
              y Δ=20 s, 0,6 %), no cero.
SEVERIDAD:    menor (con W≥3600 s)
ESTADO:       CONFIRMADO como cota; SOSPECHA de explotación.
ESCENARIO:    El informe calcula bien el ataque por publicación (`informe.md:125-137`;
              `salida_muestreo.txt:5-32`) y lo refuta indexando por `slot`. Pero la ventana del
              sampler es lo recibido: la cola de Δ segundos está incompleta para todos y el
              adversario puede completarla antes (conoce el reto y puede publicar al instante). El
              sesgo es Δ/W: despreciable con W=3600 s, no con W=60 s. El informe exige W≥3600 s por
              varianza (`salida_muestreo.txt:60-75`), así que la cota es consistente; falta decirlo.
UBICACIÓN:    `informe.md:53-61, :125-137`; `salida_muestreo.txt:5-32, :60-75`.
PRECONDICIÓN: W corto (< 600 s).
MITIGACIÓN:   fijar W≥3600 s como parte de la regla, no como recomendación.
```

### H-D15-7 · La comparación de la MTTF a `n=50000`

El informe avisa de que en Slush la frontera salta a 1 con `n=50000` (`informe.md:230-234`;
`salida_ctmc.txt:35-42`) y de que Snowball con confianza no tiene ese problema. La aserción es
plausible pero **no está medida**: el simulador de agentes usa `n=3000` (`snowball_agentes.py:26`).
No encontré en la ronda un barrido de `n` con Snowball. **SOSPECHA** (menor): si el contador no
desacopla el crecimiento de `n`, la MTTF publicada no es la de la ventana real (W·λ ≈ 3600
soluciones, no 3000). Mitigación: correr `snowball_agentes.py` con `n_total ∈ {3000, 10000, 50000}`.

---

## 2 · D14C — `informe3.md`

### H-D14-1 · El instrumento no es fiel con pesos variables (bloquea el número publicable)

```
HALLAZGO:     La implementación de referencia de DAGKNIGHT pondera los votos por trabajo; el
              instrumento de D14C vota por conteos. ZEROX usa blue_work variable. El fixture no
              distingue ambos porque tiene work uniforme (0,1,2,…).
SEVERIDAD:    medición / seguridad
ESTADO:       CONFIRMADO
ESCENARIO:    `rusty-kaspa@dagknight:consensus/src/processes/dagknight/umc_baseline.rs:23-25`:
              «vote(B) = sign(Σ vote(blue ∈ future(B)) − red_work(future(B)) + deficit) · work(B)»;
              `:143-146` multiplica por `blue_work`; `:159-161` suma votos y `red_work` ponderados;
              `:73-75` el déficit es `sqrt(k)·work(CG)`. `d14k_ref.py:143-163` usa `votes[B] = 1`,
              `rw = count`, `deficit = isqrt(k)`. El propio docstring lo declara
              (`d14k_ref.py:26-27`). El informe lo lista como condición 2 (`informe3.md:222-224`),
              pero es más grave que una condición: el fixture (`ref_umc_fixture.json`) no puede
              validar la diferencia porque todos los bloques valen 1.
              Sonda propia (`/tmp/opencode/d8c/d14/test_pesos.py`, 6 semillas, escalando el
              `blue_work` del atacante ×2/×4/×8 en el orden exterior): `k_conf` medio de `retraso20`
              sube 4,5→8,5 (α=0,33, Δ=16) y 5,0→9,0 (α=0,40, Δ=16); `cap_ref` sigue 0/6. Es una
              sonda **parcial** (la coloración de la zona sigue usando conteos), pero muestra que la
              latencia publicable crecería con pesos reales.
UBICACIÓN:    `informe3.md:220-228`; `d14k_ref.py:26-27, 143-163`; `ref_umc_fixture.json`.
PRECONDICIÓN: ninguna (carencia del instrumento).
MITIGACIÓN:   portar el voto ponderado por `work` (y el déficit ponderado) y re-medir la rejilla
              entera; el fixture actual no sirve de control para ese port.
```

### H-D14-2 · La cola de latencia de M2h supera el baseline

```
HALLAZGO:     «Máxima: 94,25 s (por debajo del baseline en todas las semillas medidas)»
              (informe3.md:213) es falso como afirmación general. En la peor celda del propio D8
              (α=0,40, Δ=20, sp, R=20) la máxima es 158,2 s > 150,0 s del baseline a α=0,40
              (`salida_d8_mitigacion.txt:18, :25`). Mi barrido de R (sonda propia,
              `test_retencion.py`, 12 semillas) encuentra 168,5 s con R=40 y política `tips` a
              α=0,40, Δ=20 (k_conf máx 30). El atacante infla k_conf y, con M=max(3k,m), la
              latencia se va: 3·30/0,6 = 150 s solo por k.
SEVERIDAD:    DoS/viveza (documental en el titular)
ESTADO:       CONFIRMADO (medido)
ESCENARIO:    El atacante no captura (cap_ref=0/12) pero **sí** puede hacer que un cliente tarde
              más que el baseline en confirmar. El informe mide media y máximo en la rejilla α=0,33
              (`informe3.md:200-214`) y no cruza el máximo del D8 (α=0,40) con el baseline α=0,40.
UBICACIÓN:    `informe3.md:175-189, :213`; `salida_d8_mitigacion.txt:9-25`.
PRECONDICIÓN: α=0,40, R≈20-40 s, política `tips`/`sp`.
MITIGACIÓN:   publicar la cola (p99) y no solo la media; acotar `k_conf` (tope) o penalizar el
              clúster por encima de un umbral; más semillas.
```

### H-D14-3 · El baseline 130,41 s no tiene ε: la comparación no es homogénea

```
HALLAZGO:     M2h se mide con ε=1e-6/1e-12, pero el baseline es «tiempo hasta 90 honestos»
              (`d14k_zerox2.py:116`), sin nivel de seguridad asociado. La curva de riesgo del
              propio proyecto da ~2,5e-1 a 300 s y 1,5e-6 a 600 s (α=0,33, δ=0)
              (`d13-finalidad/f2-alternativas-latencia.md:37, :54`), luego a 130 s el riesgo del
              baseline está entre 0,25 y 1, no en 1e-6.
SEVERIDAD:    documental
ESTADO:       CONFIRMADO (omisión)
ESCENARIO:    «2,5-4,3× mejor» (informe3.md:211-214) compara una confirmación a ε=1e-6 con un
              baseline cuyo ε no se declara. Según qué ε se fije, la mejora puede ser mucho mayor
              (600-1800 s para 1e-6/1e-36) o la comparación puede favorecer a M2h por partida doble.
              El número no es publicable sin fijar el ε del baseline.
UBICACIÓN:    `informe3.md:200-214`; `d14k_zerox2.py:116`; `f2-alternativas-latencia.md:37`.
PRECONDICIÓN: ninguna.
MITIGACIÓN:   comparar a igual ε (p. ej., tiempo del baseline para 1e-6 según la curva de 10c).
```

### H-D14-4 · «DAGKNIGHT REFUTADO» es demasiado fuerte como titular

```
HALLAZGO:     El ataque `retraso20` es exactamente el escenario que el paper describe como
              «subestimar D → aceptación prematura»; la regla de cliente del paper no existe
              (LAGUNA ya probada), y el teorema de convergencia del ordering no queda refutado por
              un cliente que fija D=16 y sufre retención 20.
SEVERIDAD:    documental
ESTADO:       CONFIRMADO
ESCENARIO:    El paper exige que el cliente fije D como cota de la latencia adversarial reciente
              (`dagknight.txt:34-35, :344-351`). El ataque usa R=20 > Δ=16: es el caso de D
              subestimado. Lo refutado es **usar el rank publicado como regla de cliente sin D**
              (que es lo que ZEROX tendría que hacer, porque la regla del paper no se publicó:
              `informe3.md:43-78`). El atacante omnisciente no es un artefacto: es el modelo del
              paper (`dagknight.txt:321-325`; `r8c_sim.py:3-11`). El veredicto del cuerpo
              («REFUTADO como vía publicable sin comité», `informe3.md:243`) es defendible; el
              titular de la tabla y del resumen no.
UBICACIÓN:    `informe3.md:12-16, :238-251`; `dagknight.txt:321-325, :344-351`.
PRECONDICIÓN: ninguna.
MITIGACIÓN:   titular «REFUTADO como regla de cliente D-agnóstica en ZEROX»; no «DAGKNIGHT
              REFUTADO».
```

### H-D14-5 · M2h sin teorema y con ganador adversario en red sana

```
HALLAZGO:     M2h es una regla de cliente propia (el informe lo dice) sin demostración de
              seguridad; el margen `m(α,ε)` es de ruina del jugador para una carrera de cadena, no
              para la carrera de clúster que M2h realmente resuelve. En red sana el ganador M2h ya
              es del atacante en 8/12 semillas a Δ=20.
SEVERIDAD:    seguridad
ESTADO:       SOSPECHA
ESCENARIO:    `salida_latencia2.txt:20-25`: en `instant` (red sana, α=0,33), Δ=16: gan_att 4/12,
              `cong_h` 4/12; Δ=20: gan_att 8/12, `cong_h` 8/12. Es decir: en 2/3 de las semillas de
              red sana, el clúster que confirma es de creador atacante, y en 2/3 el subgrupo del
              tip honesto no existe. El informe no reporta `gan_att` en el texto. La garantía
              «cubre la cadena honesta» se cumple (cap_ref 0/12), pero no hay argumento de que un
              clúster adversario que la cubre no pueda ser revertido después; el `m(α,ε)` que se usa
              como cota es la ruina de una carrera de bloques, no de una carrera de clústers.
              La fórmula de latencia usa además `k_conf` medido al final de la simulación (T=400)
              para calcular el tiempo tras B* (t=200) (`d14k_latencia2.py:107-115`): es un proxy,
              no la hora a la que la regla dispara.
UBICACIÓN:    `informe3.md:155-173, :220-228`; `salida_latencia2.txt:19-25`;
              `d14k_latencia2.py:107-115`.
PRECONDICIÓN: ninguna.
MITIGACIÓN:   demostrar (o al menos modelar) la carrera de clúster; reportar `gan_att` y `cong_h`;
              simular el cliente que decide en tiempo real, no con `k_conf` final.
```

### H-D14-6 · Congelación y precedencia: dos matices

- **Congelación.** El «≤2/12» del informe (`informe3.md:160-166`) es **en ataque**. En red sana el
  ganador M2h existe 12/12, pero el subgrupo del tip honesto falta 4-8/12 (`salida_latencia2.txt:20-25`).
  El número de 12 semillas da un intervalo ancho (2/12 = 17 % [2 %, 48 %] aprox.); no es una garantía.
- **Precedencia.** La métrica de la auditoría (tip honesto fuera del pasado del ganador) es más
  estricta que la necesidad de un comerciante: M2h garantiza que el tip honesto es **azul**
  (incluido en el orden); que no sea la espina de la cadena seleccionada no revierte una transacción
  ya ordenada. El 3-9/12 es un problema de la métrica, no del pago. El informe lo distingue
  (`informe3.md:166-173`), pero el veredicto de REFUTADO se apoya en la métrica estricta.

### H-D14-7 · Δ variable y cadena parásita: no probadas

El informe condiciona todo a Δ fijo (16/20) y pesos uniformes (`informe3.md:220-228`). La cadena
parásita (que el catálogo del proyecto usa para bajar el umbral de orden a 37,1 %,
`dag-poas-ancla-de-orden.md:156`) no se combina con M2h; el simulador tiene `copias` y modos U3
(`r8c_sim.py:67-113`) pero la rejilla de mitigaciones no los barre. **LAGUNA**: con parásita y Δ
variable, `k_conf` y `cong` pueden subir; no hay medida. No pude cerrarlo en esta ronda.

---

## 3 · ¿Queda alguna vía sin comité? Las no exploradas

De las tres vías sin comité que dejó abiertas D8b/D13 (`d13-finalidad/audita-d8.md:263-292`):

1. **DAGKNIGHT sobre PoAS** — explorada y refutada por D14C (con los matices de §2).
2. **Algorand BA\* sobre la tabla de espacio** — comité (sorteo con peso); cae bajo la restricción de
   Katana. Descartada.
3. **Finalidad determinista anclada al PoT/VDF** — **la única vía sin comité que nadie ha
   desarrollado**. La idea: usar las inyecciones de entropía (R-FIN-14) como compromiso secuencial;
   un bloque incluido en el chunk inyectado no se puede reescribir sin repetir el VDF. Coste:
   (i) convierte al timelord en autoridad (hoy Katana lo opera, pero el diseño no lo usa como tal);
   (ii) suelo `I ≥ ρ_max·W_dec ≈ 112,5 s` con ρ_max=2,5 y W_dec=45 s (`audita-d8.md:284-289`),
   apenas por debajo de los 130,41 s y muy por encima de los 30 s de M2h; (iii) con ρ>1 se rompe.
   **Veredicto:** merece una ronda de encuadre **solo si Katana acepta al timelord como autoridad**;
   si no, no queda vía determinista sin comité.

Además, dos vías probabilistas que **no** son nuevos protocolos y que ningún informe ha convertido
en ronda:

4. **Regla de riesgo de cliente sobre GHOSTDAG** (la función `risk` que el paper de DAGKNIGHT no
   publica, `dagknight.txt:996-1007, :1064-1065`): calcular el riesgo de reorg desde el DAG observado
   y confirmar cuando `risk < ε`. No añade confianza, ni comité, ni mensajes; usa los instrumentos ya
   validados (`prev()`/`frontera` de d9/d12). Coste: probablemente **no baje** de 130 s con ε alto
   (la curva da 1,5e-6 a 600 s, `f2:37`), pero sustituye el 3k heurístico por una curva explícita y
   permite al comerciante elegir su ε. Es la ronda más barata y sin coste de confianza.
5. **«Sin conflicto visible» (vida débil, estilo SPECTRE)**: confirmar un pago cuando no se observa
   una transacción en conflicto en la ventana de retención; es la observación del propio paper
   (`dagknight.txt:364-370`). Coste: solo vale para pagos conmutativos, exige nodo completo en el
   comerciante, y la latencia es la retención adversarial R (el mismo `Δ` sin medir). No es
   finalidad, es seguridad de pago. Ronda corta.

**Recomendación (marcada).** Si Katana mantiene «el timelord no es autoridad», la única vía sin
comité que añade valor es la 4 (riesgo de cliente), y su valor probable es *documentar* el riesgo,
no bajar el suelo. Si acepta al timelord como autoridad, la 3 es la única que da finalidad
determinista, a ~112,5 s. No encontré ninguna otra vía sin comité que no esté ya refutada o
explorada.

---

## 4 · Ataques probados y descartados

| Ataque | Resultado |
|---|---|
| Ráfaga por publicación contra ventana por `slot` | **DESCARTADO**: `f_eff=f` invariante (`salida_muestreo.txt:5-32`) |
| Supresión de respuestas para fabricar `q` rojos con conteo absoluto | **DESCARTADO**: `f·k=0,33k < q=0,60k` (`salida_muestreo.txt:47-58`) |
| Sybil de claves para subir peso | **DESCARTADO**: partir el espacio no cambia el total (D9) |
| Invertir el voto con `p0≥0,8` | **DESCARTADO**: 0/20 rojo (`salida_agentes.txt:50-51`) |
| Voto embebido en cabecera como sustituto del muestreo | **DESCARTADO**: pierde la amplificación (p_adv 7,8e-5 → f=0,33) (`salida_muestreo.txt:73-88`) |
| D15: subir `n` a 50.000 y esperar que el CTMC sea la MTTF real | **NO CERRADO**: el CTMC da frontera 1,0 a n=50.000; Snowball afirma no tener el problema pero no lo mide (`salida_ctmc.txt:35-42`) |
| D14: M1/M3/M4/M5/R1/R1b contra el ataque | **DESCARTADOS por el informe** (congelan o no cierran; `salida_mitigaciones_vis.txt`) |
| D14: subir la retención R contra M2h | **NO captura** (`cap_ref=0`), pero **sí infla la cola** (H-D14-2) |
| D14: pesos del atacante ×2/×4/×8 contra M2h | **No capturó** en 6 semillas (sonda parcial), pero `k_conf` subió 4,5→8,5 (H-D14-1) |
| D14: `retraso20` es artefacto del modelo omnisciente | **DESCARTADO**: la omnisciencia del atacante es el modelo del paper (`dagknight.txt:321-325`) |
| D14: el fixture valida el voto ponderado | **DESCARTADO**: el fixture es uniforme (`ref_umc_fixture.json`) |
| D14: M2h es regla del paper | **DESCARTADO**: es regla propia del informe (`informe3.md:155-173`) |

## 5 · No pude analizar

- **Port completo del voto ponderado** de `umc_baseline.rs` a `d14k_ref`; mi sonda de pesos es
  parcial (solo el orden exterior, la coloración de zona sigue con conteos). Es el trabajo que
  cierra H-D14-1.
- **Simulación end-to-end del split** de H-D15-1: la demostración es aritmética + admisión del
  informe, no un mundo con partición y equivocación.
- **Δ real (E1)**: sigue sin medir; las dos vías dependen de él y ninguna ronda lo resuelve.
- **Eclipse y sesgo parcial de marco** (H-D15-5/6): el instrumento de D15A no modela el marco
  incompleto.
- **Cadena parásita combinada con M2h** y Δ variable (H-D14-7).
- **Distribución real de tamaños de granja** para la varianza del peso de D15A
  (`informe.md:185-187`).
- **Control positivo del paper de DAGKNIGHT** (1,2/6/12 s): laguna ya declarada
  (`informe3.md:43-78`), no reabierta aquí.

## 6 · Errores propios

1. **La sonda de pesos no es un port fiel**: escala `blue_work` después de construir el DAG; la
   coloración de la zona (`committed_coloring`/`virtual_coloring`) sigue con work=1. La conclusión
   de H-D14-1 (instrumento no fiel) se apoya en la lectura de la referencia, no en la sonda; la
   sonda solo muestra la dirección del efecto (k_conf sube). No la vendo como prueba.
2. **Solo 6 semillas** en la sonda de pesos y 12 en la de retención; los conteos `x/6` y `x/12`
   tienen intervalos anchos. Las conclusiones CONFIRMADO no dependen de ellos (salen de la
   referencia y del propio D8).
3. **No toqué el repo**; las sondas viven en `/tmp/opencode/d8c/`, así que no son reproducibles
   desde el repositorio sin copiarlas. Los comandos van abajo. Sí ejecuté un `git show` de solo
   lectura en el clon externo de `rusty-kaspa` (declarado en el alcance); ningún git en ZEROX.

## 7 · Reproducción

```
# Sonda de pesos (parcial): blue_work del atacante x1/x2/x4/x8 sobre M2h
cp -r research/scripts/d14-dagknight /tmp/opencode/d8c/d14
cp -r research/scripts/d9-ronda8c     /tmp/opencode/d8c/d9-ronda8c
python3 /tmp/opencode/d8c/d14/test_pesos.py

# Barrido de retencion R=5..60, alpha=0,40, Delta=20, tips y sp
python3 /tmp/opencode/d8c/d14/test_retencion.py

# CTMC a f=0,33..0,45 y p_adv hipergeometrico (modulo del propio informe)
cp -r research/scripts/d15-avalanche /tmp/opencode/d8c/d15
cd /tmp/opencode/d8c/d15 && python3 -c "import snowball_ctmc as S; ..."
```

Los dos scripts de sonda están escritos en `/tmp/opencode/d8c/d14/` y no forman parte del
repositorio; su lógica está descrita en H-D14-1 y H-D14-2 para poder rehacerla.
