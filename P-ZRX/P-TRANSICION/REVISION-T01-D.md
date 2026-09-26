# Revisión del director — T01-D (2026-09-26)

**Veredicto: SUPERADO.** DeepSeek, 03:03–03:27. F-15 (nonce por clave de garantía) en el oráculo:
`ErrNonce`, `Garantia.nonce_siguiente`, `Tx.nonce`, comprobación antes que el resto de reglas, undo.
Vectores v0.1: base 2 055 casos (`0faec4a3…aa5527`) y negativos 3 939 (1 915 de T01-C + 2 024
`ErrNonce`: repetición de retiro 404, de liberación 180, nonce saltado 608, viejo 608, dos iguales en
un bloque 224); relectura 0 discrepancias; `run.jl --replicas 50`: 0 fallos. Siete lecturas
declaradas, aceptadas (entre ellas: el nonce se comprueba antes que la fase; una clave sin registro
empieza en 0; desbordamiento del nonce ⇒ `ErrDesbordamiento`).
