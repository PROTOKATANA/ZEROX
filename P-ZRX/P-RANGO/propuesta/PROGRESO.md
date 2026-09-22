# PROGRESO — P-RANGO

## 0 · Antes de empezar: una lectura del encargo que conviene corregir

**Lo digo antes de nada, como pide el encargo.** El encargo §1 redacta **P2** como «anclar el
conjunto de referencia del retarget al **flujo canónico**, no al pasado privado». Leído al pie de la
letra —«que el controlador mire la cadena honesta»— **contradice a `C-HDR-06`**, que exige que el
rango esperado sea función **exclusiva** de `past(B)`: para una rama privada, `past(B)` **es** el
pasado privado, y un verificador no puede leer bloques que no están en él. No es un detalle de
redacción: si se trasladara literalmente, abriría una regla incumplible.

Lo que P2 **sí** puede exigir por regla son tres cosas operativas, y son las que he redactado:
ventana en índices de slot **absolutos**, conjunto de referencia **exactamente** el pagable de
`R-FIN-13′`, y flujo **derivado** y nunca declarado. Lo que P2 no puede cerrar por regla es P3
(`ρ` acotado), y eso queda `<<PENDIENTE>>` con criterio, no maquillado. El argumento completo está en
`PROPUESTA-SPEC.md` §0.2 y en `INFORME.md` §2.

**Segunda observación, menor:** el encargo §2 pide que «los redondeos» vayan como símbolos. Un
**modo** de redondeo no es un valor: es una decisión de diseño, y el §3.4 del propio encargo exige
que la redacción diga qué se hace con el residuo de paridad. He fijado el modo (entero más cercano,
empates al cociente par) y la paridad (rejilla par); los **valores** (`SR_MIN`, `SR_MAX`, `W_slots`,
…) siguen siendo símbolos. Y `SR_MIN ≥ 2` no es un número elegido: es el borde del dominio que
`C-GD-01` ya declara (`SR = 0` da `w = 2^128`, fuera de `u128`).

---

## 1 · Comprobaciones de ENTRADA (antes de tocar nada)

Ejecutadas desde la raíz `/home/katana/zeo/ZEROX`.

```bash
LC_ALL=C sha256sum -c P-ZRX/P-RANGO/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

```text
=== 1. sha256sum -c ===
P-ZRX/P-RANGO/PROMPT.md: OK
exit=0
=== 2. git status --short ===
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
exit=0
=== 3. date ===
mar 22 sep 2026 17:13:59 CEST
```

```text
uptime (entrada): 17:13:59  up 14 days 13:43,  0 users,  carga promedio: 1,45, 1,18, 1,12
```

`PROMPT.md` verifica contra `ENTRADA.sha256` (sin editar). El estado de git es el mismo que al
salir: **no se ha modificado ningún archivo rastreado** ni nada fuera de `P-ZRX/P-RANGO/propuesta/`.

---

## 2 · Bitácora

1. **Lectura íntegra de las fuentes obligatorias** (encargo §6). Todas abiertas enteras, no por
   línea citada:
   - `AGENTS.md`, `README.md`, `MIGRACION.md`, `research/README.md`.
   - `SPEC.md`: §6.1 (`C-HDR-01`…`C-HDR-08`, con `C-HDR-06` completo), §7.1.3–§7.1.5
     (`C-FLU-01`…`C-FLU-14`, `C-FLU-20`, `C-FLU-21`), §7.2 (rango, unicidad pagable, `C-ORD-01`…
     `C-ORD-03`), §7.3 (parámetros y límites), §11 (`C-GD-01`…`C-GD-11`), §12 (`C-REORG-06`,
     `C-REORG-07`, `C-FIN-01`), §12.1 (`C-CHK-01`…`C-CHK-07`), §17.
   - `TAREAS.md` §2.3 **entero** y §2.9 entero (además de §2.1 para el contexto de cierre).
   - `veritas/seguridad/coste-rama-privada-v1/PROPUESTA.md` **entera** e `INFORME.md` §3 (y §1–§9).
   - `P-ZRX/P-CRP1/auditoria/CIFRAS.md` (las cifras recalculadas).
   - `veritas/consenso/puerta-cobertura-v1/PROCEDENCIA.md` §3 y `MODELO.md` §1 (el residuo de
     paridad y el predicado de aceptación).
   - `veritas/consenso/retarget-causal-endogeno-v1/`: `CONTRATO.md`, `MODELO.md`, `INFORME.md`,
     `ENMIENDA-Z0.md`, `src/controlador.jl`.
   - `veritas/consenso/ventana-retarget-causal-v1/`: `CONTRATO.md`, `INFORME.md`.
   - `research/dag-poas-ancla-de-orden.md`: `R-FIN-6`…`R-FIN-14` (incluidas `R-FIN-8′` y
     `R-FIN-13′` completas).
   - `crates/zx-consensus/src/bloque_dag.rs` (`ContextoRangoDag`, `CandidatoSinRango`, la prueba
     `compile_fail` de circularidad) y `crates/zx-consensus/src/dificultad.rs` (LWMA-1: **es de otra
     cosa**, no se copia).
   - `P-ZRX/P-POT/propuesta/PROPUESTA-SPEC.md` y `DECISIONES-PENDIENTES.md`;
     `P-ZRX/P-FLUJO/propuesta/PROPUESTA-SPEC.md` (forma y encabezados).
   - `veritas/LINEO.md` **entero** (obligatorio: se ha escrito y ejecutado un instrumento Julia).

2. **Corrección de lectura de P2**, escrita en §0 de este archivo y en `PROPUESTA-SPEC.md` §0.2.

3. **Instrumento `RNG-v0.1`** en `P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1/`, estructura de
   LINEO §1. Comprueba, exacto y sin coma flotante: `A(SR)` contra un oráculo por enumeración en
   círculos de 256 y 1024 puntos; la identidad de la tasa por producto y por forma cerrada; el
   residuo de paridad con la rejilla par y con `SR` impar; el dominio (`SR = 0` fuera de `u128`); la
   anchura (`u256` basta sin precondición, `u128` no); el kernel del controlador
   (`UInt128` comprobado) contra una referencia `BigInt`; Z0; activación y `MissedUpdate`; y la cota
   de deriva por cohorte. Lo que **no** mide: seguridad, estabilidad ni ramas privadas (encargo §4:
   no repetir CRP-v0.1).

4. **Redacción de los entregables.** Reglas `C-RET-01`…`C-RET-11` con `MUST`/`MUST NOT`, de dónde
   sale cada una y qué la refuta; las tres propiedades P1/P2/P3 y los cinco pendientes de
   `TAREAS.md` §2.3 trazados a regla en `PROPUESTA-SPEC.md` §2.

5. **Presupuesto** (encargo §4 y LINEO §11): máximo **4 hilos**, **4 GiB** de RAM, **1 GiB** de
   disco temporal, **30 min** de pared. Uso observado: muy por debajo; sin timeout, sin
   `inconcluso`. Todo el cálculo es aritmética exacta sobre pocos miles de casos.

6. **Zona de escritura.** Solo `P-ZRX/P-RANGO/propuesta/`. `PROMPT.md` y `ENTRADA.sha256` intactos
   (verificado). No se ha tocado `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`,
   `research/`, `veritas/` ni el resto de `P-ZRX/`.

**Nota de reproducibilidad del entorno Julia.** El depósito de Julia (`~/.julia`) está fuera de la
zona de escritura permitida, así que la resolución de dependencias se hizo con un depósito local
temporal (`.depot`) que se ha **eliminado** al terminar. Los comandos publicados en el `INFORME.md`
del instrumento funcionan con el depósito por defecto en **solo lectura** (verificado tras
eliminarlo: `run.jl` y `test/runtests.jl` vuelven a pasar).

---

## 3 · Comprobaciones de SALIDA (después de escribir todo)

```bash
LC_ALL=C sha256sum -c P-ZRX/P-RANGO/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

```text
=== 1. sha256sum -c ===
P-ZRX/P-RANGO/PROMPT.md: OK
exit=0
=== 2. git status --short ===
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
exit=0
=== 3. date ===
mar 22 sep 2026 17:27:51 CEST
```

```text
uptime (salida): 17:27:51  up 14 days 13:57,  0 users,  carga promedio: 2,32, 2,89, 2,35
```

El estado de git es **idéntico** al de entrada. `PROMPT.md` sigue verificando. Las tres
comprobaciones se ejecutaron **después de congelar** los demás entregables (incluidos
`PROPUESTA-SPEC.md`, `DECISIONES-PENDIENTES.md`, `INFORME.md` y todos los artefactos de `RNG-v0.1`);
este mismo archivo es la bitácora que las registra. Tamaño total de la zona de trabajo:
**196 KB, 23 archivos**, todos bajo `P-ZRX/P-RANGO/propuesta/`.

---

## 4 · Entregables

| Archivo | Qué es |
|---|---|
| `P-ZRX/P-RANGO/propuesta/PROPUESTA-SPEC.md` | el entregable principal: `C-RET-01`…`C-RET-11`, con `<<PENDIENTE>>` declarados, de dónde sale cada regla y qué la refuta, y la trazabilidad P1/P2/P3 + los cinco pendientes |
| `P-ZRX/P-RANGO/propuesta/DECISIONES-PENDIENTES.md` | las siete decisiones del encargo §3, con lo que gana/paga/cierra cada opción y cuáles quedan abiertas |
| `P-ZRX/P-RANGO/propuesta/INFORME.md` | por qué cierra la compra de varianza y qué deja abierto; termina con «Lo que esta propuesta NO resuelve» |
| `P-ZRX/P-RANGO/propuesta/veritas/consenso/rango-v1/` | instrumento `RNG-v0.1` (Julia CPU, LINEO §1) con `Project.toml`, `Manifest.toml`, `src/`, `test/`, `bench/`, `run.jl`, `resultados/` e `INFORME.md` |
| `P-ZRX/P-RANGO/propuesta/PROGRESO.md` | este archivo |
