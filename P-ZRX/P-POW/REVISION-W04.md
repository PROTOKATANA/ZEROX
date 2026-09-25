# Revisión del director — W04 (2026-09-26)

**Veredicto: SUPERADO y migrado a la raíz** (01:56). DeepSeek, 01:37–01:54.

Revisado por el director: `validar_cabecera_pow` aplica, en orden, rama activa de la red, `prev_hash`,
altura, `bits` = `codificar_con(target_esperado, parametros.limites)`, `hash_pow < target` estricto
(U256 big-endian), `ts > ts_padre` y FTL — con los **límites de la red** (`ctx.parametros.limites`).
`LIMITES_AMPLIOS` (constante no pedida por la orden, que acepta cualquier target) solo se usa en tests
y para derivar el máximo dev; **no** en verificación. Riesgo anotado: no debe usarse nunca como límite
de una red. Derivados antiguos reproducidos exactamente (`K`, `NK`, `ST_CAP`, `T_FLOOR`, `FTL`).
`Cargo.lock`: solo se añade `zx-consensus`. Base de DeepSeek idéntica a la raíz; `MIGRACION.sha256`
(70 archivos) verificado en la raíz.

Valores congelados: perfil dev `T = 2`, `N = 20`, `bits_iniciales = 0x1e7fffff`
(`0x7fffff·2^216`), `HASH_GENESIS_DEV = c72fdb3b…050c2d59`. Minado dev (perfil `test`, sin
optimizar): 40/40 bloques válidos, media 136 733 intentos/bloque (≈ 2^17, lo esperado del target
inicial), 124,8 s de pared: **no** es medida de rendimiento.

**No demuestra:** seguridad del PoW, idoneidad de los parámetros dev, algoritmo de producción
(A-12), validación de cuerpo ni fin del PoW (W03).
