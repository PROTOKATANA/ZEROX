# REVISIÓN W06d6 — sincronización por registro de admisión, red (RI-3a), orden admitir→persistir→difundir (RI-3c)

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 04:50). **Ejecutor:** subagente Sonnet, único,
00:59–04:43. Evidencia: `resultados-W06d6/` (informe, progreso, horas, definiciones faltantes, parche,
`MIGRACION.sha256`); las ejecuciones reales se quedan en `deepseek/W06d6/run/`. **Veredicto: SUPERADO
PARCIALMENTE. Migrada.**

## Resultado

| Paso | Resultado |
|---|---|
| V0 | Base 795/0/5 |
| V1 | Mensajes `Peticion::Registro`/`Respuesta::Registro` y `longitud_registro` en el saludo: ida y vuelta, página llena/corta/fuera de rango/vacía, tope de bytes, par caído a mitad |
| V2 | RI-3a (tres) y RI-3c H1 con salida antes/después; inyección de fallo entre admitir y persistir (nada se difunde; reinicia bien); dial con reintento; padres extra y cola `Pendiente` |
| V3 | Tres procesos, `N_dev` real, cruzan el corte y convergen |
| V4 (nodo tardío) | **Superado en 2 repeticiones**: tras ≥ 500 bloques PoST alcanza el mismo slot en menos de 90 s (límite 15 min) y, tras el reposo, los cuatro tienen **la misma punta y el mismo `resumen_estado`**. Cierra V5 de W06d5 |
| V5 (partición PoST) | **No superado**, y **no se probó el escenario pedido**: A se aisló desde el génesis, así que cada lado cruzó el corte con su **propio terminal** (escenario E-6b). Destapó el hallazgo principal (abajo) |
| V6 (`zx-adversario`) | **Superado**: las entradas de E-7 rechazadas con su motivo, el objetivo no cae (tras corregir un génesis falso de la herramienta) |
| V7 | `fmt`, `clippy -D warnings`, **814/0/5**, guardianes |

## Hallazgo principal (verificado por el director en el código)

`zx-cadena` **congela el terminal** al admitir el primer bloque PoST y guarda un solo DAG con ese terminal como
raíz; el nodo solo crea el servicio PoT de verificación para ese terminal. No es FC-3 (TRN-09), rompe I-3 y
deja divididos para siempre a dos nodos que cruzan el corte con terminales distintos. **W06d7** lo corrige.

## Migración y reservas

- El parche no aplicaba porque el ejecutor añadió a su `ws.orig` los tests de reproducción (para demostrar que
  fallaban en la base). Comprobado que la raíz no había cambiado en esas rutas desde la base (`394cb6e`) y que
  `ws` difiere de la base en **exactamente** los 28 archivos de `MIGRACION.sha256`; migrada copiando esos 28
  archivos; **28/28 huellas** desde la raíz; `zx-node`, `zx-p2p` y los manifiestos idénticos a la zona.
- `Cargo.lock`: solo añade `tracing-subscriber` 0.3.23 (pedido en la decisión 3, en contradicción con «sin
  versiones nuevas» de la misma orden: error del director) y tres dependencias suyas, MIT o MIT/Apache; ninguna
  versión existente cambia. Lo usa solo `zx-adversario`.
- **Autodenuncia del ejecutor:** usó `python3` para tres sustituciones de texto en un archivo de código,
  contra la prohibición. El resultado se verificó después (suite y `clippy`); no afecta a ninguna evidencia.
  Queda registrado como incumplimiento.
- Sin test unitario aislado de «producir solo con garantía» (sigue probado solo con procesos reales).
- Suite conjunta con SL-4c (migrada en paralelo, crates distintos) **no ejecutada todavía**: la hará el paso 0
  de la siguiente orden de código.
