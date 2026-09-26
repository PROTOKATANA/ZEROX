# ORDEN-T04 — Oráculo del estado en el DAG PoST (Julia)

## 1. Identidad y contexto

- **ID:** T04. **Estado:** redactada 2026-09-26; se lanza tras T01-B. **Director:** Claude.
  **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04/`.
- **Objetivo único:** implementar en Julia (CPU) un oráculo de referencia del contrato
  `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md` (aplicación al fusionar, descarte silencioso, cobro de
  azules y `rojo_k`, garantía evaluada sobre `Estado(past(B))`), apoyado en el oráculo GHOSTDAG
  antiguo GDR-v0.2 (revalidado) y en las reglas por bloque del oráculo T01, y exportar vectores para
  el diferencial Rust (W06a).
- **Pregunta falsable:** «ED-1…ED-6 producen, para toda historia DAG pequeña de la rejilla, estados
  que conservan el valor, aplican cada bloque una sola vez, no dependen del orden de llegada, se
  deshacen exactamente y, con `k = 0` y sin fusiones, coinciden con T01.» Se refuta con un
  contraejemplo reproducible o una contradicción del contrato que obligue a elegir.
- **Desbloquea:** IPA B-11; W06a (estado DAG en el nodo, diferencial contra estos vectores).

## 2. Autoridad y entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`;
`P-ZRX/P-TRANSICION/CONTRATO-v0.md` (incluidas «Ratificaciones v0.1»); `P-ZRX/P-DAG/DECISIONES-W05.md`.
Código de referencia (solo lectura): el oráculo T01 en `P-ZRX/P-TRANSICION/T01/` (tras T01-B) y el
oráculo GHOSTDAG antiguo `git -C /home/katana/zeo/ZEROX show 9681061:veritas/consenso/ghostdag-rank-v1/<f>`
(`src/{modelo,referencia}.jl`, `CONTRATO.md`, `MODELO.md`, `fixtures/kaspa/*`); vectores ya en el
workspace: `testdata/ghostdag-rank-v1/{corpus-rust.txt,kaspa-rust.txt}`.
Entrada congelada: `P-ZRX/P-DAG/ENTRADA-T04.sha256`, al empezar y como último paso.

## 3. Decisiones ya tomadas por el director

1. **Orden DAG:** copia a tu zona `src/modelo.jl` y `src/referencia.jl` de GDR-v0.2 (sin cambios de
   lógica; solo la raíz pasa a ser el terminal, D-P07) y **revalídalos** reproduciendo exactamente
   `testdata/ghostdag-rank-v1/corpus-rust.txt` y los fixtures `kaspa`. Si no los reproduces, **para**.
2. **Reglas por bloque:** usa el módulo de T01 como dependencia de **solo lectura**
   (`Pkg.develop(path = …/T01)` con el Manifest en tu zona, o `include`; declara cuál). No modifiques
   T01. Implementa en T04 `aplicar_fusion` con la tabla de §3 del contrato DAG: invalidan el bloque la
   forma, los padres (D-P08), la coinbase (posición, unicidad, clave) y la garantía del productor sobre
   `Estado(past(B))`; se **descartan** las transacciones y operaciones de garantía que no validan
   (ED-4…ED-6); la coinbase PoST acredita `mín(declarado, subsidio + tarifas aceptadas)`; los
   `rojo_U3` son inertes; el punto de aplicación es el slot del bloque de cadena que fusiona.
3. **Estado del pasado** exactamente como ED-2; **virtual** como ED-3 con reorganización y undo
   exacto. Fase PoW como en T01 (ED-1).
4. **Interfaces:** solo las por defecto (CUT-HWΦ, FC-3, SEC-0). Parámetros de la rejilla: un
   subconjunto pequeño de la rejilla de T01 (declárelo) y `k ∈ {0, 1, 3}`.
5. **`merge_depth`**: la red dev rechaza como inválida la fusión de un bloque más profundo que
   `F_slots` (contrato DAG §5).

Si una regla admite dos lecturas incompatibles, **antes de editar** regístrala como
`AMBIGUEDAD-n` en `PROGRESO.md`; aplica la más restrictiva solo si no altera otra regla; si la
altera, **para**.

## 4. Verificación

- Casos dirigidos (cada uno con su resultado esperado construido a mano): doble gasto entre dos
  bloques fusionados (gana el primero en orden `C-GD-05`, el otro se descarta); coinbase PoST
  recortada al descartar una tarifa; depósito fusionado que habilita a un productor posterior;
  bloque PoST cuyo productor solo tiene garantía en una rama no fusionada (inválido); `rojo_U3` inerte;
  bloque aplicado una sola vez aunque lo alcancen dos cadenas; reorganización que cambia la cadena
  seleccionada y recalcula estados; bloque de transición con dos hermanos PoST en el mismo slot.
- Propiedades IE-1…IE-6 sobre historias DAG aleatorias pequeñas (≤ 14 bloques PoST, ≤ 3 padres),
  `StableRNG` por réplica, semilla `0x5a5a`, ≥ 200 réplicas por punto; IE-3 con todas las
  permutaciones de llegada si hay ≤ 7 bloques PoST y 200 aleatorias si hay más; IE-5 comparando con
  T01 en historias sin fusiones.
- Exporta vectores a `T04/resultados/vectores-estado-dag-v0.txt` (formato de T01-B ampliado con
  `padres=[…]` y, por bloque aplicado, `DESC tx=<índice> motivo=<Err>` para cada transacción
  descartada) con su `sha256`; relectura independiente como en T01-B.
- **Prohibido Python.** Presupuesto: **3 h, 1 hilo (4 para la rejilla si el perfil lo justifica),
  8 GiB, 2 GiB de disco**.

## 5. Entregables y límites

Proyecto Julia según LINEO §1 en `T04/`, `resultados/`, `INFORME.md` (veredicto; casos; invariantes;
ambigüedades; «Lo que este oráculo NO demuestra»: criptografía, PoT/PoAS, red, latencia, parámetros),
`METODO.md`, `PROGRESO.md`, `HORAS.log`. Resumen final ≤ 40 líneas. DeepSeek `deepseek-flash`,
esfuerzo `high`; LINEO antes del código; nada fuera de `T04/`; sin commit ni push; sin secretos;
ningún `Ok` ficticio.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04 && cd /home/katana/zeo/ZEROX/P-ZRX/P-DAG/T04 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden T04. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-DAG/ORDEN-T04.md y cúmplelo. Antes de escribir código, lee íntegros /home/katana/zeo/ZEROX/V-ZRX/LINEO.md y /home/katana/zeo/ZEROX/P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../T04-dsh.stdout 2> ../T04-dsh.stderr )
