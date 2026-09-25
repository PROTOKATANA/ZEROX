# PROGRESO — S01

Registro de la sesión (zona `deepseek/S01/`). Los tiempos con marca `date -Is` están en
`HORAS.log`; `HORAS.log` se abrió al final por un olvido del ejecutor y las marcas retroactivas se
rotulan como tales.

## Estado

- **Veredicto G1: SUPERADA**, con la separación de alcance de `ORDEN-S01` §7.
- Prototipo, oráculo, resultados crudos, informe, especificación, método y este progreso: completos.
- Integridad final de la entrada: cinco de seis OK; `D-ZRX/RFT-ZRX.md` cambió por un commit
  concurrente externo (ver `INFORME.md` §1.3). Clon de Autonomys intacto.

## Pasos

1. **Lectura de entradas (obligatoria).** `ORDEN-S01.md`, `LINEO.md`, `ENCARGO.md`, `ANALISIS.md`,
   `ENCARGO-01-FORMATO-ALTA.md`, `RFT-ZRX.md`, `fuentes-filecoin/INFORME.md` y `REVISION.md`;
   histórico `P-COBERTURA` §§2–3,7 y `P-SEMBRADOR` fase 1. Detectadas las faltas de definición de
   `INFORME.md` §1 (H_d `pub(crate)`, `CBID_RED_DEV` inexistente, regiones exactas, cambio
   concurrente de RFT-ZRX.md, `max_pieces_in_sector`).
2. **Preparación de la zona.** Clon `--no-hardlinks` de Autonomys a
   `deepseek/S01/autonomys-subspace` fijado en `f8842d019cdf…`; caché `.cargo-home` copiada de L01;
   `target` propio. Extracción solo-lectura de `farmer.rs`, `farmer_disco.rs` y `poas.rs` a
   `referencia/`.
3. **Prototipo.** `prototipo/` con `h_d.rs`, `merkle.rs`, `r2.rs`, `sector.rs`, `registro.rs` y el
   driver `bin/s01.rs`; `Cargo.toml` independiente (path deps al clon) y `Cargo.lock` propio.
   Compilado en `--release`, `--offline`, 8 hilos.
4. **Oráculo.** `oraculo-r2/` en Julia (solo CPU, `SHA` de stdlib), `Project.toml`/`Manifest.toml`,
   `run.jl`, `test/runtests.jl`, `julia-version.toml`.
5. **Corridas.** `s01 {2,3,4} 128 resultados`. En cada tamaño: ploteo real, R2, dump, búsqueda de
   soluciones, verificación PoAS real, aperturas positivas en 3 slots distintos, 15 negativos y
   medición de 1000 verificaciones.
6. **Oráculo vs Rust.** Coincidencia byte a byte de `digest_mapa`, `digest_meta`, `raiz_chunks` y
   R2 en los tres tamaños (12/12).
7. **Pruebas.** `cargo test`: 6/6. `julia test/runtests.jl`: 5/5. Repeticiones: 3 por tamaño.
8. **Informe y artefactos.** `INFORME.md`, `ESPECIFICACION-BYTES.md`, `METODO.md`, `PROGRESO.md`,
   `ENTORNO.txt`, `HORAS.log`, `resultados/` y `logs/`.

## Resultado en una línea

Una solución PoAS real verificada por el clon abre el mismo sector comprometido por R2: 32 B de
compromiso, 617–649 B de apertura, 4,5–4,7 µs de verificación (0,4 % sobre el PoAS real), 32–60 ms
de cómputo de R2 por sector de 2–4 MiB, y 15/15 negativos rechazados. R2 no demuestra que el ploteo
sea correcto, ni preexistencia, ni permanencia, ni ausencia de doble uso entre ramas.
