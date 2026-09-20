# regla-flujo-v1 — la regla de flujo del PoT (perfil 1a, `L ≥ F`)

**Esto NO es un instrumento de cálculo: es una PROPUESTA de texto normativo.** No tiene
`Project.toml`, `run.jl` ni `resultados/`, y por eso no sigue la estructura de `veritas/LINEO.md`
§1: no hay nada que ejecutar. Vive en `veritas/` porque es la evidencia sobre la que se edita el
SPEC, y `PROCEDENCIA.md` es su testimonio de validación.

| Archivo | Qué es |
|---|---|
| `PROPUESTA-SPEC.md` | `C-FLU-01…18`, `C-FLU-20…23` y `C-FIN-01`, con sus demostraciones y sus etiquetas de afirmación (2 039 líneas, seis revisiones) |
| `DECISIONES-PENDIENTES.md` | D-F1…D-F10, con sus opciones, su coste y la decisión de Katana. **Ninguna queda abierta** |
| `PROCEDENCIA.md` | Testimonio del validador. **No se edita** |
| `PROGRESO.md` | Bitácora del agente. Rutas históricas; véase su nota de migración |
| `ENTRADA/` | Copia congelada del encargo, el prompt y las tres adendas, con `ENTRADA.sha256` |
| `HUELLAS.sha256` | Huellas de todo lo anterior, con rutas desde la raíz del repositorio |

## Procedencia y migración

Redactada por un **agente Claude independiente** en `P-FLUJO/propuesta/` según
`P-FLUJO/ENCARGO.md` y sus adendas 1, 2 y 3, validada por Claude (validador) el 2026-09-20 y
migrada aquí el mismo día por `P-CIERRE/ENCARGO.md` §1.1. El original en `P-FLUJO/` queda intacto.
**La migración no cambió ningún archivo de esta carpeta** salvo la nota de migración de
`PROGRESO.md` y este `LEEME.md`.

## Dos cosas que hay que leer antes que el resto

1. **`C-FLU-19` no existe.** La regla de finalidad se llamó `C-FLU-19` hasta la revisión 5, y
   `D-F7 = B` la sacó de la familia: es **`C-FIN-01`**. El hueco en la numeración `C-FLU` es
   deliberado y **no se reutiliza** (`TAREAS.md` §4.2).
2. **La historia de la refutación.** El agente refutó la afirmación central del encargo y, tras una
   objeción del validador, refutó también su propia conclusión (c) —que la ventana de adopción
   fuese vacía—, sobre la que Katana había decidido DF-2. Está contada en las revisiones 4 y 5 de
   `PROPUESTA-SPEC.md` y en `PROCEDENCIA.md`. **Ningún texto derivado debe decir «las particiones
   se curan» ni «no tienen cura»: depende de cómo nació.**

## Comprobaciones

```bash
# desde la raíz del repositorio
LC_ALL=C sha256sum -c veritas/consenso/regla-flujo-v1/HUELLAS.sha256
LC_ALL=C sha256sum -c veritas/consenso/regla-flujo-v1/ENTRADA/ENTRADA.sha256
```

## Lo que esta propuesta NO cierra

Veintiún puntos al final de `PROPUESTA-SPEC.md`. Los que más pesan: la `Δ` es simulada, no medida
en red; la vía **A2** (rama privada que desplaza el ancla dentro del corte) **no está medida**; la
**tercera rendija** que abre el presupuesto de `C-FLU-23` **no está medida** y está parcialmente
bajo control del atacante; y la reconciliación de `C-FIN-01` con el código que hoy se detiene, con
`COINBASE_MATURITY` y con el techo de archivado queda **fuera por alcance decidido**.
