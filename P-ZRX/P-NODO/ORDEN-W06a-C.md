# ORDEN-W06a-C — `zx-cadena` sin atajos del oráculo en la ruta de producción

- **ID:** W06a-C. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek. Se lanza tras
  migrar W06d1.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06aC/`.
- **Motivo (`REVISION-W06d1.md`, reservas 1 y 2):** `crates/zx-cadena/src/cadena.rs` fija
  `MAX_PADRES_ORACULO = 3` (línea 37: el límite del generador de T04) para todo bloque PoST, aunque
  `PERFIL-DEV-v0.md` §4 dice 15; y la identidad GHOSTDAG entra como `u64` y se construye con
  `IdentidadGhostdag::de_fixture` (líneas 62, 896–904). `zx-node` tuvo que truncar la tupla `C-GD-07` a
  8 bytes (no inyectivo) y limitar sus padres a 3.
- **Pregunta falsable:** «Con el máximo de padres como parámetro (15 en la red dev, 3 en el diferencial)
  y la identidad real de `C-GD-07`, el diferencial contra T04 v0.3 sigue en 0 discrepancias con su
  cobertura, y `zx-node` produce y verifica bloques con más de 3 padres e identidades reales.»

## Decisiones del director

1. `max_padres` pasa a ser parámetro de construcción de `Cadena` (sin valor por defecto oculto): el
   nodo usa el de `PERFIL-DEV-v0.md` (15); el arnés de T04 usa 3, declarado.
2. `BloqueCadena::Post` lleva una `IdentidadGhostdag` real (la tupla de `C-GD-07` que ya calcula
   `zx-dag`); `de_fixture` queda **solo** para el arnés diferencial. `zx-node` deja de truncar.
3. Tests: bloque con 15 padres admitido y con 16 rechazado; dos bloques cuyas identidades truncadas a
   8 bytes coincidirían pero las reales difieren se tratan como distintos (U2); `zx-node`: la
   integración de W06d1 con elección de hasta 15 padres.

## Verificación

`fmt --check`, `clippy -D warnings --locked`, `cargo test --workspace --all-features --locked` (todo lo
previo con su nombre; `diferencial_t04` 0 discrepancias y cobertura idéntica), `dependencias-exactas.sh`,
`frontera-crates.sh`; lock sin cambios. Patrón de entregables de las órdenes W (`cambios.patch`,
`MIGRACION.sha256` sobre el `ws/` **final**, `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log`). Cargo
desde `ws/` con `GIT_CEILING_DIRECTORIES`, `CARGO_HOME` y `CARGO_TARGET_DIR` en la zona. **Prohibido
Python.** Presupuesto: 1 h 30 min, 8 hilos. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO; nada
fuera de la zona; sin commit ni push; sin secretos. Entrada congelada `P-ZRX/P-NODO/ENTRADA-W06a-C.sha256`.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W06aC && cd /home/katana/zeo/ZEROX/deepseek/W06aC && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W06a-C. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-NODO/ORDEN-W06a-C.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W06aC-dsh.stdout 2> ../W06aC-dsh.stderr )
