# P-REGISTRO-SECTORES — evaluar un registro verificable para ZEROX

**Estado:** encargo de investigación y prototipo aislado; no es una regla de consenso.
**Fecha:** 2026-09-25.

## Ejecución por etapas

Este documento conserva el contrato global. El análisis y los encargos acotados
están en:

1. [`ANALISIS.md`](ANALISIS.md): hechos comprobados, inferencias y puertas de decisión.
2. [`ENCARGO-01-FORMATO-ALTA.md`](ENCARGO-01-FORMATO-ALTA.md): objeto comprometido,
   alta y vínculo de una solución con el sector activo.
3. [`ENCARGO-02-AUDITORIAS.md`](ENCARGO-02-AUDITORIAS.md): permanencia,
   regeneración y fallos honestos.
4. [`ENCARGO-03-DAG-GARANTIA.md`](ENCARGO-03-DAG-GARANTIA.md): semántica del DAG,
   elegibilidad, recompensa y garantía.
5. [`ENCARGO-04-FORMATO-ALTERNATIVO.md`](ENCARGO-04-FORMATO-ALTERNATIVO.md):
   investigar un formato nuevo y el coste de replotear.
6. [`ENCARGO-05-PRECOMMIT-POREP-AUDITORIAS.md`](ENCARGO-05-PRECOMMIT-POREP-AUDITORIAS.md):
   evaluar como conjunto precompromiso, PoRep y auditorías posteriores, incluida
   la transición desde el PoW temporal.

El orden de cierre es 01 → 02 → 03 → 05 → decisión. El 04 puede investigar
PoRep y un formato nuevo desde ahora, pero no proponer migración sin contrastar
01 y 02. El 05 cierra la evaluación conjunta; no sustituye las pruebas de
formato y costes de los anteriores. No activar ninguna regla ni modificar
`D-ZRX/SPEC.md` al ejecutar estos encargos de investigación. La copia
histórica de código está fuera del
árbol de trabajo actual; no restaurar miles de archivos eliminados como efecto
secundario de un prototipo.

## Objetivo

Determinar si registrar parcelas o sectores antes de que sean elegibles, demostrar qué
bytes comprometen y auditarlos después mejora la seguridad de ZEROX frente al
PoAS + PoT + DAG sin registro. Separar tres beneficios posibles:

1. Dificultar la creación oportunista de candidatos al conocer retos futuros.
2. Evaluar si una garantía económica puede vincularse a capacidad lógica
   comprometida y auditada bajo supuestos explícitos.
3. Detectar el abandono de una parcela después de producir y determinar qué
   consecuencia es justificable frente a fallos honestos de disco o red.

No dar por demostrado ninguno de ellos por el mero hecho de guardar un `SectorId`,
una raíz o una fecha de alta. Un registro no resuelve por sí solo el doble farmeo
de una rama no publicada, la censura de pruebas ni la finalidad de pagos.

## Punto de partida que no se debe perder

- La investigación histórica `P-ZRX/P-COBERTURA/investigacion/INFORME.md`
  (§§2–3 y 7) concluye, **para el formato PoAS examinado**, que el registro con
  edad y auditorías puede encarecer la regeneración, pero no acredita por sí
  mismo la preexistencia física de todos los bytes. Revisar su modelo y sus
  hipótesis antes de reutilizar una cifra o una conclusión.
- `P-ZRX/P-SEMBRADOR/investigacion/INFORME.md` y
  `DECISIONES-PENDIENTES.md` distinguen compromiso de sector completo,
  demostración de codificación, maduración y auditoría posterior. No volver a
  presentar `SectorId` o referencia histórica como prueba de antigüedad.
- `P-ZRX/P-CLAVE/investigacion/INFORME.md` advierte que un saldo pequeño por
  clave puede dejar mucha capacidad con poco valor confiscable. El vínculo
  garantía/capacidad requiere una medida de capacidad verificable.
- La propuesta actual `D-ZRX/SPEC.md` (C-BON-01…07, C-EVP, C-SLA y §9) registra
  **saldos por clave**, no sectores. Ninguna cifra ni regla de registro de este
  encargo se incorpora automáticamente a POS2T.

La copia histórica se encuentra en `/home/katana/zeo/.trash/zerox/`. Es
evidencia, no autoridad normativa. Si deja de estar disponible, consultar los
archivos versionados mediante `git show 9681061:<ruta>`.

## Preguntas que debe responder

### A. Qué se compromete y cuándo

1. Comparar, con codificación concreta, al menos: (i) identidad de sector y
   fecha; (ii) raíz de los bytes exactos de una parcela completa, versión,
   cardinalidad, clave y referencia histórica; (iii) prueba verificable de
   inicialización o codificación completa, si es factible. Indicar la propiedad
   **adicional** que aporta cada opción.
2. Fijar qué dato queda publicado antes de que pueda conocerse el reto relevante.
   Distinguir fecha de publicación de un compromiso de fecha de existencia de
   los bytes. Definir qué sucede si cambia el historial DAG por una reorganización.
3. Demostrar o refutar que una solución PoAS usada para producir pertenece al
   compromiso registrado y activo. Una apertura de una pieza no se debe llamar
   prueba de que el sector completo estuvo almacenado.
4. Examinar claves nuevas, varios sectores bajo una clave, duplicación de bytes
   o compromisos entre claves y sectores que caducan o se reemplazan.

### B. Seguridad frente a adversarios concretos

Para cada variante, dar un ataque óptimo conocido y el coste honesto/adversario
bajo el **mismo** horizonte, red y hardware. Incluir al menos:

- Ploteo parcial y descarte de candidatos fallidos («sembrador»).
- Regeneración al conocer el reto, con CPU/GPU y almacenamiento alquilado.
- Borrado después de ganar, conservación solo de sectores ganadores y respuesta
  a auditorías periódicas.
- Selección masiva de claves/sectores, división de capacidad y altas justo antes
  de la activación.
- Fallo de disco, desconexión, partición o censura que impida publicar una
  prueba honesta dentro del plazo.
- Uso de la misma capacidad en dos ramas del DAG, incluida una rama privada.

Clasificar cada resultado como **impide**, **encarece**, **detecta bajo supuestos**
o **no afecta**. No llamar «seguro» a un resultado que solo aumenta el coste.

### C. Auditoría y consecuencias

1. Diseñar retos futuros no elegibles por el productor a partir del pasado DAG
   validado. Especificar apertura, plazo, presupuesto de CPU/red y recuperación
   cuando falte contexto. Comprobar si el atacante puede anticipar el reto en
   una rama privada o regenerar antes del vencimiento.
2. Separar **pérdida de elegibilidad o recompensa futura** de **confiscación de
   stake**. No penalizar automáticamente una ausencia si una partición o censura
   honesta produce la misma observación; cuantificar los falsos positivos.
3. Si una recompensa se condiciona a pruebas posteriores, definir qué bloques
   del DAG generan obligación, cuándo empieza la madurez, cómo se aplican los
   efectos tras un cambio de cadena seleccionada y si el peso del bloque o la
   emisión se recalculan. Exigir conservación monetaria y undo exacto.
4. Analizar si el registro permite acotar garantía por capacidad activa sin
   convertir tokens en peso de producción: PoAS + PoT deben seguir determinando
   oportunidad y `blue_work`; el saldo solo debe cubrir obligaciones y faltas.

## Comparadores obligatorios

Evaluar en las mismas trazas y con el mismo criterio de fallo:

| Variante | Alcance que puede reivindicar |
|---|---|
| R0 · PoST actual sin registro | Línea base; no inventar una capacidad acreditada |
| R1 · Solo `SectorId`/fecha o raíz sin prueba completa | Contabilidad y fecha del compromiso, no preexistencia de bytes |
| R2 · Compromiso exacto + prueba de alta + maduración | Elegibilidad de una instancia demostrada según el alcance real de la prueba |
| R3 · R2 + auditorías futuras | Permanencia observada por muestras/plazos; medir regeneración y falsos positivos |
| R4 · Formato de parcela distinto, si R2/R3 no bastan | Rama de investigación separada; explicitar migración y coste de replotear |

El precedente de Filecoin es su combinación de
[precompromiso y Proof of Replication](https://spec.filecoin.io/systems/filecoin_mining/sector/adding_storage/)
con [WindowPoSt](https://spec.filecoin.io/algorithms/pos/post/). Describir qué
supuestos dependen de su sellado, registro de poder y plazos; no trasladar sus
garantías, parámetros ni su significado de «PoSt» al PoAS + PoT de ZEROX.

## Prototipo y mediciones

Preparar primero un prototipo **aislado de la ruta de consenso** con un oráculo
pequeño que compruebe compromisos, altas, auditorías, caducidad y reversión.
Usar parcelas y verificador PoAS reales cuando una conclusión dependa de su
formato; un simulador que solo acepta un `SectorId` no valida la cobertura.
Antes de medir, fijar adversario, evento de fallo, unidad, versión del modelo,
máquina y presupuesto. Seguir `V-ZRX/LINEO.md`: Julia en CPU y C++/CUDA en GPU
solo si el perfil justifica esta última; no crear auditorías Python.

Publicar al menos:

- Coste de registrar, demostrar, verificar y auditar por sector y por TiB;
  tamaño de estado, ancho de banda y trabajo por bloque/época.
- Tiempo de regeneración y coste de mantener bytes frente a cada plazo de reto,
  incluyendo sensibilidad al hardware adversario y a la aceleración futura.
- Espera de activación y capacidad honesta inactiva, en especial para un
  productor nuevo y uno doméstico; pérdidas por fallos y particiones.
- Reducción del éxito o aumento del coste de cada ataque de la sección B;
  efectos sobre entrada, concentración y participación.

No fijar una duración, depósito, frecuencia de auditoría o tasa aceptable por
intuición. Si falta un límite adversarial o la prueba no cubre el sector entero,
registrar el veredicto como **condicional o inconcluso**.

## Entregables y criterio de cierre

Entregar `INFORME.md`, `MODELO.md`, `METODO.md`,
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` y `DECISIONES-PENDIENTES.md`, más el
prototipo, pruebas y resultados reproducibles si se hacen mediciones. El informe
debe contener una matriz **variante × ataque × propiedad demostrada × coste
honesto × coste adversario × evidencia** y terminar en una de estas decisiones:

1. **Descartar:** la mejora verificable no compensa el coste o no hay prueba.
2. **Seguir investigando:** identificar exactamente la medición o primitiva que falta.
3. **Proponer ratificación:** solo con formato, semántica DAG, límites, parámetros,
   riesgo aceptable y pruebas suficientes para una revisión independiente.

Este encargo no modifica `D-ZRX/SPEC.md`, no activa slashing por ausencia de
auditoría y no declara resuelto el doble farmeo privado. Una propuesta de regla
de consenso, si la evidencia la sostiene, será un paso posterior y explícito.
