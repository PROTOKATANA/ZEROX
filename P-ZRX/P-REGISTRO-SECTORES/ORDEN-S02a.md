# ORDEN-S02a — Encargo 02 de sectores, parte a: coste real de regenerar para contestar una auditoría sobre R2

## 1. Identidad y contexto

- **ID:** S02a. **Estado:** redactada 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
  Primera parte de `ENCARGO-02-AUDITORIAS.md` (IPA D-02), en la plantilla de `AUTO-ZRX.md` §6.
  Investigación aislada: nada entra en el workspace ni en el consenso.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/S02a/`.
- **Pregunta falsable:** «Para el formato PoAS actual con compromiso R2 (S01), el coste de contestar
  una apertura sin guardar el sector crece con los datos que se omiten de forma medible y con una
  cota inferior de latencia por apertura que no baja de `t_reg` por registro regenerado.» Se refuta
  si una estrategia que no guarda los chunks contesta aperturas en un tiempo indistinguible del de
  leerlas de disco con los recursos medidos. El resultado esperado **por RFT-04** es «encarece, no
  impide»: la orden mide **cuánto**.
- **Desbloquea:** S02b (modelo de auditorías, plazos y falsos positivos) y la decisión G2.

## 2. Autoridad y entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `ENCARGO-02-AUDITORIAS.md`, `ANALISIS.md` §§4–5;
`D-ZRX/RFT-ZRX.md` (RFT-03, RFT-04, RFT-06); el resultado de S01 en
`P-ZRX/P-REGISTRO-SECTORES/investigacion/01-formato-alta/` (`INFORME.md`,
`ESPECIFICACION-BYTES.md`, `REVISION.md`, `prototipo/`). Histórico (solo lectura, **cifras de otra
máquina y otra carga**): `P-ZRX/P-INTENTO/investigacion/INFORME.md` y
`research/coste-ploteo-medido.md` en `/home/katana/zeo/.trash/zerox/`.
Entrada congelada: `P-ZRX/P-REGISTRO-SECTORES/ENTRADA-S02a.sha256`, al empezar y como último paso.

## 3. Decisiones ya tomadas por el director

1. **Auditoría candidata A1** (solo para medir; no es regla): una apertura = hoja de R2 en una
   posición `chunk_location` uniforme + camino Merkle, exactamente como la apertura de S01.
2. **Estrategias del adversario que se miden** (todas contestan una apertura en la posición pedida):
   - **E-disco:** guarda el sector completo (línea base honesta): leer la hoja y recomponer el camino.
   - **E-árbol(L):** borra los chunks y guarda solo los nodos del árbol por encima del nivel `L`
     (tamaño `2^{profundidad−L} × 32 B`); para contestar, regenera las `2^L` hojas del subárbol de la
     posición pedida y recompone el camino. `L ∈ {0, 1, 2, …, profundidad}`.
   - **E-nada:** no guarda nada del sector (solo sus metadatos públicos y la historia); regenera
     todas las hojas y el árbol completo.
3. **Regeneración real**, con el plotter/codificador de Autonomys `f8842d0` que ya usa el prototipo de
   S01: regenerar una hoja exige obtener la pieza (se supone **gratuita y local**: la historia es
   pública; el coste de red no se mide aquí y se declara), generar la tabla de prueba de espacio del
   registro y codificar el chunk. Mide explícitamente cuántas tablas distintas exige un subárbol de
   `2^L` hojas (depende de cuántos `piece_offset` distintos hay en esas posiciones consecutivas) y
   no supongas que es `2^L`.
4. **Recursos:** CPU únicamente; 1, 2, 4, 8 y 16 hilos (LINEO §7: tope 24; aquí 16 por haber otras
   órdenes en la máquina). GPU **no** se mide (declararlo: `ab-proof-of-space-gpu` existe en el clon;
   su coste queda abierto).
5. **Tamaños:** los tres de S01 (2, 3, 4 piezas) y, si el presupuesto alcanza, uno mayor (16 piezas);
   parámetros de fixture declarados.

Si algo no se puede cumplir tal cual, **para** e infórmalo antes de improvisar.

## 4. Contrato de ejecución

Parte de una copia del `prototipo/` de S01 en tu zona (no modifiques la de `P-ZRX`); añade un binario
de medición. Clon de Autonomys y caché de cargo copiables de `deepseek/S01/`. `CARGO_HOME` y
`CARGO_TARGET_DIR` en tu zona. Perfil de compilación `release` para medir (declárelo).

## 5. Modelo de amenaza

Adversario con CPU abundante que borró el sector tras registrarlo y quiere seguir contestando
auditorías. Lo que **no** se mide y el informe debe decirlo: GPU, ASIC, coste de descargar piezas,
latencia de red, adversario que guarda solo una fracción aleatoria de hojas (queda para S02b como
modelo).

## 6. Plan de verificación y medición

- **Corrección antes de medir:** para cada estrategia, la apertura producida verifica contra R2 con el
  verificador de S01 (100 posiciones aleatorias por tamaño; 0 fallos). Una estrategia que no verifica
  no se mide.
- **Métricas** (LINEO §6–§7; calentar, mediana y p99 de ≥ 30 aperturas por punto; semilla por CLI):
  almacenamiento conservado (bytes); tiempo de pared por apertura; tiempo de CPU; número de tablas
  regeneradas por apertura; RAM máxima; escalado con hilos; `t_reg` = tiempo de regenerar una tabla y
  codificar un registro (mediana, 1 hilo y mejor configuración).
- **Tabla final:** `estrategia × L × tamaño × hilos → almacenamiento, tiempo por apertura (med, p99),
  tablas por apertura, RAM`, y la curva «almacenamiento conservado ↔ latencia por apertura».
- Registra hardware, `uptime` antes y después, versiones y comandos. **Prohibido Python.**

Presupuesto: **2 h de reloj, 16 hilos, 32 GiB, 40 GiB de disco**; si se agota, **inconcluso** con lo
medido.

## 7. Entregables y límites

En `deepseek/S02a/`: código de medición, `resultados/` crudos, `INFORME.md` (tabla y curva; qué
estrategias **encarecen** y cuánto en tiempo y núcleos por apertura; qué no se mide), `METODO.md`,
`PROGRESO.md`, `HORAS.log`. Resumen final ≤ 30 líneas. DeepSeek `deepseek-flash`, esfuerzo `high`;
LINEO antes del código; sin Python; nada fuera de la zona; sin commit ni push; sin secretos; ningún
`Ok` ficticio.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/S02a && cd /home/katana/zeo/ZEROX/deepseek/S02a && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden S02a. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-REGISTRO-SECTORES/ORDEN-S02a.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../S02a-dsh.stdout 2> ../S02a-dsh.stderr )
