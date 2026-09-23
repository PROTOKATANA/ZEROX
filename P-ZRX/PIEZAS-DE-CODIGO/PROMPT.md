Trabajas en el repositorio ZEROX, en /home/katana/zeo/ZEROX. **Lee `AGENTS.md` entero antes de dar la primera orden.** Responde en español.

# ENCARGO 0.0.1 — la primera versión que arranca y se puede medir

---

## REPARTO DE PAPELES — léelo antes que nada

**Tú eres el agente X: el líder. NO escribes el código — lo diriges.** Tu trabajo tiene cuatro
partes, y las cuatro son tuyas:

1. **Planificar.** Convertir la lista de 17 piezas (§3) en una **hoja de ruta**: orden real,
   dependencias, y qué se puede hacer en paralelo.
2. **Ordenar.** Para cada pieza, escribir a **DeepSeek** instrucciones **detalladas**: qué crate, qué
   módulo, qué funciones con qué firmas, contra qué API, qué casos de error, qué tests, qué regla del
   SPEC va citada, y **qué NO debe tocar**.
3. **Validar.** Leer lo que DeepSeek devuelve y comprobar que es correcto. **Abriendo el código, no
   fiándote de su resumen.**
4. **Corregir.** Si no está bien, devolvérselo con la corrección concreta. **No lo arregles tú en
   silencio:** la corrección es información, y si la escondes se repetirá.

**DeepSeek ejecuta.** Escribe el código siguiendo tus instrucciones. **No decide arquitectura, no
elige entre opciones y no inventa números.** Si tus instrucciones son vagas, el código será vago: la
calidad de su salida es responsabilidad de la precisión de tu orden.

**Katana decide.** Las decisiones de §4 son suyas — ni tuyas ni de DeepSeek.

> **Una orden a DeepSeek NO es «implementa el verificador PoAS».** Es el desglose: qué crate, qué
> módulo nuevo, qué función pública con qué firma, contra qué API del clon fijado, qué hace en cada
> caso de error, qué test la cubre y qué regla del SPEC va en su doc comment. Si tú no lo has
> desglosado, no lo has planificado.

**Qué comprobar al validar cada entrega de DeepSeek**, además del criterio de hecho de §6:

- **Compila**, y `cargo clippy -D warnings` y `cargo fmt --check` pasan.
- **Ningún verificador sustituido por aceptación.** Es lo que `AGENTS.md` prohíbe expresamente, y es
  el fallo más fácil de colar: un `Ok(())` donde debería haber un error explícito.
- **Los tests no son tautológicos.** Un test que comprueba una definición consigo misma no prueba
  nada. En la serie de investigación de este repositorio han aparecido cuatro.
- **Las citas al SPEC son por ID y dicen lo que la regla dice de verdad.** Ábrelas una a una.
- **No ha tocado lo que no debía** (§8), y `git status` lo confirma.

**La casilla la marcas tú, y responde de la calidad — no del esfuerzo.** Si DeepSeek entrega algo que
no cumple, no la marques: anótalo en `PROGRESO-0.0.1.md` y devuélvelo.

---

## 0 · Qué es la 0.0.1, y qué NO es

**Objetivo:** un nodo que **arranca desde génesis, produce bloques DAG válidos, los propaga, los
valida y los ordena**, de forma que se puedan **medir cifras reales** que hoy no existen.

**La 0.0.1 tiene éxito si permite medir esto:**

- **`Δ` real en red** — hoy solo hay simulación (`DMS-v0.1`). De ella cuelgan `L_suelo_slots`, el
  suelo de `F` y si una partición llega a nacer.
- **Tasa de bloques, padres típicos, tamaño de mergeset** con GHOSTDAG ejecutándose de verdad.
- **Coste de validación por salto** en la ruta real.
- **El puente espacio → tasa**, que hoy está bloqueado: `P-ZRX/P-PUENTE-ESPACIO-TASA/` no pudo
  cuantificar el umbral y sus **cinco razones son todas código que no existe**.

**Lo que la 0.0.1 NO incluye, y no se escribe:**

- Transacciones de usuario, wallet, RPC, scanner, lightwalletd. **Solo coinbase.**
- La capa blindada (Orchard/Halo2). Las dependencias están en `Cargo.toml` y ningún crate las usa:
  **déjalo así.**
- Poda (requisito de mainnet, no de beta).
- Las 21 reglas `C-FLU` completas. Se arranca con **un solo flujo**; el derivador de contexto de
  flujo queda fuera.
- El controlador de rango completo. Arranca con rango fijo declarado.

**Si te encuentras ordenando algo de esa lista, has salido del alcance. Para y pregunta.**

## 1 · El estado real del código, para que no lo descubras tú

Verificado el 2026-09-23 leyendo el código, no los documentos:

- **La ruta activa es hoy una cadena LINEAL con PoW.** `crates/zx-node/src/sync.rs:309` verifica
  `comprobar_pow`; `cadena.rs` maneja `BlockHeader` de 92 B; el fork choice es el lineal.
- **El DAG + PoST está escrito AL LADO y no lo ejecuta nadie.** `zx-consensus` tiene 8 494 líneas
  —GHOSTDAG, cabecera DAG, PoT, rango, peso— y **`ghostdag.rs` no se referencia fuera de su crate**.
- **Nadie valida `SolucionPoas`.** Es un struct de datos (`zx-core/src/preimage/dag.rs`) que viaja en
  la cabecera y **ninguna función lo comprueba**: sin KZG, sin prueba de espacio.
- **`bloque_difundido` devuelve `Veredicto::Ignorar`** con un `TODO(sincronizador)`
  (`cadena.rs:725`): el nodo **no valida** lo que recibe.
- **El UTXO con datos de deshacer YA EXISTE y está probado** (`zx-storage/src/utxo.rs`, 644 líneas:
  `UndoData`, `aplicar_bloque`, `revertir_bloque`, `revertir_hasta_el_fork`, con test de que
  aplicar+deshacer es la identidad). **Nadie lo usa desde la cadena.**
- **`rele_compacto.rs` existe (1 266 líneas) y no está cableado.**
- **No existe ningún productor de bloques.** Ni esqueleto.
- `crates/zx-pot/` existe con el AES, pero `wire_dag::verificar_justificacion_pot` devuelve siempre
  `IntegracionPotPendiente`.

**Inventario completo y ordenado por dependencias:** `P-ZRX/T-ZRX/PIEZAS-DE-CODIGO.md`. **Ábrelo.**

## 2 · La decisión de arquitectura, que es la PRIMERA que hay que tomar

La ruta activa es PoW lineal heredado; el destino es PoST + DAG. **Antes de dar la primera orden a DeepSeek,
plantea esta decisión a Katana con el formato de §4** y espera respuesta:

- **(a) Refactorizar `Cadena` en marcha.**
- **(b) Escribir la ruta DAG al lado y conmutar.**

**Mi lectura, que no te vincula** (de Claude): (b), porque es lo que el repositorio ya viene haciendo
—`zx-consensus` tiene el DAG completo junto al lineal— y porque con (a) los tests existentes
protegen el comportamiento **viejo**. Pero decide Katana.

## 3 · LA LISTA — las piezas de la 0.0.1, con su check

**Mantén esta lista viva en `P-ZRX/PIEZAS-DE-CODIGO/PROGRESO-0.0.1.md`** (este `PROMPT.md` es de solo
lectura). Copia la tabla, marca cada casilla al completarla **y solo cuando cumpla su criterio de
hecho (§6)**. En cada entrega di **cuántas van de cuántas**.

### Bloque A · Verificación (sin esto nada de lo demás significa nada)

- [ ] **A1 · Verificador PoAS.** KZG sobre `record_commitment` y `record_witness`, verificación de
      prueba de espacio y cálculo de `solution_distance`. Vía realista: **integrar
      `subspace-verification`** del clon fijado (`PDF/autonomys-subspace`, `f8842d0`) enlazando por
      ruta a su **API pública**, sin copiar ni modificar su código. *(Grande. Bloquea todo.)*
- [ ] **A2 · Conectar `zx-pot` a `wire_dag`.** Sustituir `IntegracionPotPendiente` por verificación
      real, con el contrato de `C-POT-06` (tres estados, sin circularidad), `C-POT-07` (caché por
      clave contextual) y `C-POT-08` (orden de validación). *(Media.)*
- [ ] **A3 · Verificación conjunta de cabecera DAG.** `C-HDR-01…09`: layout, prefirma, sello,
      `pot_bundle_count`, codec único. Que un `DagBlockHeader` se pueda aceptar o rechazar con
      motivo. *(Media.)*

### Bloque B · Estado

- [ ] **B1 · Cablear el UTXO a la cadena.** Que `adoptar`/`extender` **apliquen** el bloque, guarden
      `UndoData` y **reviertan** en reorg. El código existe: úsalo, no lo reescribas. *(Media.)*
- [ ] **B2 · Persistir UTXO y undo en disco**, con el resto del almacén. *(Media.)*
- [ ] **B3 · `validar_bloque` en la ruta activa.** Que `bloque_difundido` deje de devolver
      `Ignorar`. *(Media.)*

### Bloque C · El DAG en la ruta activa

- [ ] **C1 · `zx-node`/`zx-storage` adoptan `DagBlockHeader`.** *Indicador objetivo:* el test
      `el_codigo_alcanza_la_base_poas_de_556` (`crates/zx-consensus/tests/spec_numeros.rs`) **deja de
      estar ignorado y pasa**. *(Grande.)*
- [ ] **C2 · GHOSTDAG sustituye a `fork_choice`.** `Cadena` deja de ser una **lista** y pasa a ser un
      **árbol de puntas**; alimentar `ContextoDag` desde el almacén. *(Grande.)*
- [ ] **C3 · Génesis DAG** con sus parámetros por red. *(Pequeña.)*

### Bloque D · Producción

- [ ] **D1 · Auditor de disco / plotter.** Plotear una parcela y auditarla por slot. Vía realista:
      integrar el de Autonomys. **No uses la ruta no paralela de `ab-proof-of-space`**: tiene un
      SIGSEGV reproducible (`P-ZRX/P-INTENTO/investigacion/mediciones/fallo-semilla.md`). *(Grande.)*
- [ ] **D2 · Productor de bloques.** Selección de padres (`C-GD-10`, con el barajado), ensamblado,
      coinbase, `pre_hash`, sello y publicación. *(Grande.)*
- [ ] **D3 · Firmante seguro.** Persistir `oportunidad → pre_hash` **antes** de firmar y negarse a
      firmar otra. Hay prototipo validado en `P-ZRX/P-FIRMANTE/` (0,81 ms/bloque) **fuera de
      `crates/`**: intégralo, no lo reinventes. *(Pequeña.)*

### Bloque E · Red

- [ ] **E1 · Cablear el relé compacto** y migrar a `/zerox/blocks/2`. **Trampa documentada:**
      `crates/zx-p2p/src/servicio.rs` despacha con `topico.contains("/blocks/")`, y `/blocks/2`
      también cumple esa condición — si cambias la versión sin cambiar el despacho, los anuncios se
      rechazan como basura **y se penaliza al par honesto que los propaga**. *(Media.)*
- [ ] **E2 · IBD sobre DAG.** El sincronizador actual pide cadenas lineales y comprueba PoW.
      *(Grande.)*

### Bloque F · Instrumentación — **es el objetivo de esta versión, no un extra**

- [ ] **F1 · Métricas de `Δ`**: sello de tiempo de emisión y de recepción por bloque y por nodo,
      exportables. Sin esto la 0.0.1 no sirve para lo que se escribe.
- [ ] **F2 · Métricas de DAG**: tasa de bloques, padres por bloque, tamaño de mergeset, azules y
      rojos, profundidad de reorg.
- [ ] **F3 · Métricas de coste**: tiempo de validación por bloque, desglosado por etapa.
- [ ] **F4 · Arranque reproducible de una red local** de N nodos con parcelas pequeñas, para poder
      repetir mediciones.

**17 piezas.** La 0.0.1 se da por válida cuando las 17 están marcadas **y** se cumple §7.

## 4 · Cómo pedir una decisión — FORMATO OBLIGATORIO

El SPEC está avanzado pero **tiene huecos y decisiones sin tomar**. Cuando te falte una decisión para
avanzar, **NO la inventes** (`AGENTS.md`: «una regla pendiente no se implementa inventando un
número»). Para, y plantéala así:

```text
DECISIÓN NECESARIA · <identificador corto>
Pieza bloqueada: <cuál de la lista>
Descripción: <qué hay que decidir y por qué aparece ahora>

Opción A · <nombre>
  Ventajas:    <qué se gana, concreto>
  Desventajas: <qué se paga, concreto>
  Descripción: <qué implica de verdad, no una etiqueta>

Opción B · <nombre>
  Ventajas:    ...
  Desventajas: ...
  Descripción: ...

Recomendación: <cuál y POR QUÉ>. Marcada como recomendación, no como decisión.
```

**Toda opción tiene un coste: dilo.** Si una decisión no bloquea nada, no la plantees — sigue y
anótala. Acumula las decisiones planteadas en `P-ZRX/PIEZAS-DE-CODIGO/DECISIONES-0.0.1.md`.

**Mientras esperas una decisión, trabaja en otra pieza que no dependa de ella.**

## 5 · Puedes lanzar una auditoría por tu cuenta si la necesitas

**Autorizado por Katana.** Si para escribir una pieza necesitas **medir algo que no está medido**,
móntala y mídelo. No pidas permiso para eso. La auditoría la puedes hacer tú o dirigírsela a
DeepSeek como cualquier otra pieza — pero **el informe y sus etiquetas los firmas tú**.

**Cuándo sí:** cuando la falta de un dato **bloquea** una pieza o te obligaría a inventar un número.
Ejemplo real y pendiente: el **puente espacio → tasa**
(`P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1/`) llegó de bytes a candidatos por
slot y **no pudo cuantificar el umbral**, porque sus cinco dependencias eran **código que no
existía**. En cuanto ese código exista, esa medición **se puede completar** — y completarla es
trabajo legítimo de este encargo.

**Cuándo no:** por curiosidad, para confirmar algo ya medido, o para aplazar escribir código. **La
0.0.1 es código; las mediciones son medios, no el fin.** Si una auditoría se te alarga más de lo que
tardarías en la pieza que bloquea, dilo y decidimos.

**Antes de montar nada, comprueba si ya está medido.** Hay nueve encargos entregados en `P-ZRX/` e
instrumentos migrados en `veritas/`. Reinventar una medición existente es el desperdicio más caro de
este repositorio.

**Cómo hacerla — no es negociable** (`AGENTS.md` y `veritas/LINEO.md`):

- **Julia en CPU** con `./veritas/julia.sh`; **C++/CUDA** si el perfil justifica GPU. **Nada de
  Python.**
- Estructura de LINEO §1 en `veritas/<categoria>/<nombre>-vN/`, con `Project.toml`, `Manifest.toml`,
  `src/`, `test/`, `run.jl`, `resultados/` e `INFORME.md`. **Ésta es la única excepción a la
  prohibición de escribir en `veritas/` de §8.**
- **Referencia exacta antes que kernel rápido**, y el kernel validado contra ella.
- **Un test que compara una fórmula consigo misma no es un test.** En esta serie han aparecido
  cuatro: declara en una tabla qué rutas son independientes y cuáles no.
- **Etiqueta cada cifra**: `medido`, `derivado`, `estimado`, `demostrado`, `no determinado`. Y declara
  las hipótesis que gobiernan la conclusión en un fichero aparte.
- **Declara el presupuesto antes de ejecutar** (hilos, RAM, disco, tiempo) y **anota `uptime`**: la
  máquina tiene otro trabajo corriendo y compartirla contamina cualquier medición de tiempos. Si una
  cifra se midió con carga ajena, **etiquétala así**.

**Qué hacer con el resultado:**

- Anótalo en `PROGRESO-0.0.1.md`: qué mediste, por qué bloqueaba, y qué decidiste con el dato.
- **Si la medición contradice una cifra del SPEC o de un informe anterior, ESO ES UN HALLAZGO.**
  Repórtalo de inmediato y **no ajustes el código para que cuadre**. Ha pasado ya: una revisión del
  puente retiró una cota de seguridad que el repositorio daba por buena.
- Si el dato obliga a una decisión, plantéala con el formato de §4.

## 6 · Criterio de «hecho» por pieza

Una casilla se marca **solo** si cumple las cinco:

1. **Compila** y `cargo clippy -D warnings` y `cargo fmt --check` pasan.
2. **Tiene test** que falla si se rompe la pieza. No vale un test que compruebe una definición
   consigo misma.
3. **Cita su regla del SPEC por ID** (`C-HDR-03`, `C-GD-10`…), nunca por número de línea: las líneas
   se desplazan porque hay otro trabajo concurrente.
4. **Sale de `ci/reglas-sin-codigo.txt` o `ci/reglas-sin-cablear.txt`** si le corresponde, y
   `ci/citas-spec.sh` sigue en verde.
5. **No hay verificador sustituido por aceptación.** `AGENTS.md` lo prohíbe expresamente: si algo no
   se puede verificar todavía, **devuelve un error explícito** —como hace hoy
   `IntegracionPotPendiente`— y **nunca un `Ok` fabricado**.

## 7 · Cuándo se da por válida la 0.0.1

Las 17 casillas, más estas cinco comprobaciones de extremo a extremo:

- [ ] Una red local de **3 nodos** arranca desde génesis y produce bloques durante 30 minutos sin
      detenerse.
- [ ] Los tres convergen en la misma cadena seleccionada, y se puede **demostrar** que convergen (no
      solo observarlo).
- [ ] Un nodo que se cae y vuelve **se pone al día solo**. *(Hay tests ignorados exactamente para
      esto: `tres_nodos_en_linea_convergen`, `un_nodo_que_muere_vuelve_y_se_pone_al_dia_solo`,
      `varios_clientes_se_sincronizan_a_la_vez_del_mismo_servidor` — deben dejar de estar
      ignorados.)*
- [ ] Un bloque con `SolucionPoas` inválida **se rechaza**, y se puede enseñar el rechazo.
- [ ] Las métricas de F1-F3 salen y son plausibles: **`Δ` medida comparable al orden de magnitud de
      la simulada (0,26-0,60 s)**. Si sale muy distinta, **es un hallazgo**: repórtalo, no lo ajustes.

## 8 · Zona de trabajo y convivencia — LEE ESTO DOS VECES

**DeepSeek escribe en `crates/` bajo tu dirección; tú escribes en `P-ZRX/PIEZAS-DE-CODIGO/`.** A
diferencia de los encargos de investigación, aquí **sí** se toca el código del proyecto — y la
responsabilidad de lo que entre es tuya, no suya.

> ⚠️ **HAY OTRO ENCARGO TRABAJANDO EN `crates/` AL MISMO TIEMPO** (el del verificador PoT y el
> cableado; ha creado `crates/zx-pot/`, `crates/zx-consensus/src/pot.rs`, `pot_rango.rs` y sus
> tests). **Antes de empezar, comprueba `git status` y pregunta a Katana si ese encargo sigue vivo.**
> Si lo está, **coordinaos o repartid bloques**: dos agentes editando los mismos ficheros se pisan y
> se pierde trabajo.

**No toques** `SPEC.md`, `research/`, `veritas/`, `PDF/` ni el resto de `P-ZRX/`. Si crees que el SPEC
está mal, **no lo edites**: plantéalo como decisión (§4).

Al empezar y al terminar, desde la raíz:

```bash
git -C /home/katana/zeo/ZEROX status --short
date
```

con las salidas en `PROGRESO-0.0.1.md`. **Hay 38 ficheros modificados sin commitear**: no los
revuelvas y **no hagas `git checkout`, `reset` ni `clean` de nada que no hayas escrito tú.**

## 9 · Disciplina de implementación (de `AGENTS.md`, que debes leer entero)

- **Preservar** código y vectores reutilizables de criptografía, transacciones, red y almacenamiento.
  **Adoptar primitivas auditadas; no reimplementarlas.**
- **La aritmética de consenso es entera y comprobada.** Nada de flotante en el camino de validez.
- **Mantener la frontera** entre tipos, consenso, red y estado.
- **No convertir esto en una migración ficticia:** no sustituir verificadores ausentes por aceptación
  incondicional, **ni quitar una comprobación útil solo para conseguir tests verdes**.
- **Documentar la ausencia de integración** donde la haya.
- Conservar identificadores estables de reglas; **no reutilizar los retirados**.

## 10 · Entregables

- `P-ZRX/PIEZAS-DE-CODIGO/HOJA-DE-RUTA.md` — tu plan: orden, dependencias, qué va en paralelo, y la
  **orden detallada** que le diste a DeepSeek para cada pieza (o su resumen fiel, si fue larga).
- `P-ZRX/PIEZAS-DE-CODIGO/PROGRESO-0.0.1.md` — la lista viva con sus checks, el recuento
  (**n de 17**), la bitácora con `date` y las comprobaciones de entrada y salida.
- `P-ZRX/PIEZAS-DE-CODIGO/DECISIONES-0.0.1.md` — toda decisión planteada, con su formato de §4 y la
  respuesta de Katana cuando llegue.
- `P-ZRX/PIEZAS-DE-CODIGO/INFORME-0.0.1.md` — al cerrar: qué quedó hecho, **qué NO**, qué mediciones
  salieron y **qué hallazgos inesperados** aparecieron.
- **Las auditorías que hayas montado** (§5), cada una en `veritas/<categoria>/<nombre>-vN/` con su
  `INFORME.md` y sus hipótesis declaradas.
- El código, en `crates/`.

## 11 · Reglas de validez

- **No inventes un número que el SPEC deja pendiente.** Plantea la decisión (§4).
- **No marques una casilla que no cumpla las cinco condiciones de §6.**
- **Di siempre cuántas piezas van de 17.**
- Si una pieza resulta **más grande de lo que la lista sugiere**, dilo en cuanto lo sepas: es
  información, no un fallo.
- Si descubres que el SPEC **se contradice** o que una regla no es implementable como está, **para y
  repórtalo**. Ha pasado antes y es un hallazgo valioso.
- **Si algo de este encargo te parece equivocado, dilo ANTES de empezar**, en tu primera respuesta y
  en `PROGRESO-0.0.1.md`.
