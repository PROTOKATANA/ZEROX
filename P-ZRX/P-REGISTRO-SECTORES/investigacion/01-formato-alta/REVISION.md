# Revisión del director — S01 / encargo 01 de sectores (2026-09-26)

**Veredicto: G1 SUPERADA en su alcance exacto** (DeepSeek, 01:35–01:49).

**Qué queda demostrado:** una solución PoAS real, verificada con `verify_solution::<ChiaTable,_>`
de Autonomys `f8842d0`, abre el mismo sector completo que se comprometió con R2 (compromiso de 32 B
sobre todas las hojas `(s_bucket, piece_offset, codificado, chunk almacenado)` en orden físico, más
digests del mapa de contenidos y de los metadatos). Tres tamaños (2, 3, 4 piezas), 3 slots con
solución por tamaño, 15/15 negativos rechazados con su error, oráculo Julia independiente con 12/12
coincidencias byte a byte.

**Costes medidos (máquina de referencia, carga ajena posible, parámetros de fixture):** R2 32 B;
calcularlo tras plotear 32–60 ms para sectores de 2–4 MiB; apertura 617–649 B (camino de 16–17
niveles); verificar una apertura ~4,5 µs frente a ~1,25 ms del verificador PoAS (≈ 0,4 %). No son
cifras de producción: sectores de fixture de 2–4 MiB.

**Comprobado por el director en los datos crudos:** `RESULTADOS.tsv`, `ORACULO-CHECK.tsv` y
`negativos-P*.tsv`; `n_hojas = 32 768 × piezas` y longitudes de camino coherentes con el relleno.

**Lo que NO demuestra (y el informe lo dice):** que la raíz corresponda a un ploteo correcto (R3),
preexistencia (RFT-03), permanencia (RFT-04), uso exclusivo en una rama (RFT-06). R3 no se implementó
con la razón técnica de RFT-04: exige cambiar el objeto (encargos 04/05).

**Incidencias explicadas por el director:** la comprobación final de `ENTRADA-S01.sha256` falla en
`D-ZRX/RFT-ZRX.md` porque **el director** lo editó a las 01:40 (RFT-13) con S01 en marcha; el diff
solo añade RFT-13. «`CBID_RED_DEV` no existe»: S01 copió su base a las 01:35 y W02 se migró a las
01:36; se usó un CBID de prueba declarado.
