# Rescate de `deepseek/` — LEEME

## 1 · Qué es esto, de dónde viene y por qué existe

Este directorio, `P-ZRX/rescate-deepseek/`, conserva el material **único** que quedaba en
`deepseek/`, la zona de trabajo aislada del ejecutor externo DeepSeek, antes de que Katana
eliminara esa carpeta.

- **Origen:** `deepseek/` en la raíz del repositorio ZEROX.
- **Fecha del rescate:** 2026-09-21 (ver §7 para las marcas de `date` de apertura y cierre).
- **Por qué hacía falta:** `deepseek/` está declarada en `.gitignore` (línea 18: «Zona de trabajo
  aislada para el ejecutor externo (DeepSeek)… El directorio se borra al cerrar cada encargo»).
  Al estar ignorada, **git no la versiona ni la recupera**: lo que no se copiara antes del borrado
  se perdía de forma definitiva.
- **Naturaleza de esta operación:** es una operación de **archivo**, no de investigación. No se ha
  validado ningún resultado, no se ha emitido juicio sobre el contenido y no se ha cambiado ninguna
  cifra del repositorio.
- **Alcance:** solo se ha escrito dentro de `P-ZRX/rescate-deepseek/`. No se ha borrado ni
  modificado nada en `deepseek/`, `veritas/`, `SPEC.md`, `TAREAS.md`, `crates/`, `research/` ni en
  el resto de `P-ZRX/`. `deepseek/` sigue intacta para que la elimine Katana.

El material se copió con `cp -a` (se preservan fechas y permisos) y **copiando, nunca moviendo**.

## 2 · Qué NO se rescató, y por qué

| Origen en `deepseek/` | Situación | Motivo |
|---|---|---|
| `deepseek/P-2.1/historico-v1/` | Ya a salvo | Idéntico byte a byte a `P-ZRX/P-2.1/historico/v1/`; verificado con `diff -rq` sin diferencias (exit 0). |
| `deepseek/veritas/consenso/poda-post-v1/` | Migrado a `veritas/consenso/poda-post-v1/` | **No es una copia.** La versión migrada tiene `BITACORA.md` y `PROCEDENCIA.md` que la de `deepseek/` no tiene, y varios ficheros comunes difieren. De aquí solo se rescató su `PROGRESO.md`. |
| `deepseek/veritas/consenso/prueba-recursiva-v1/` | Migrado a `veritas/consenso/prueba-recursiva-v1/` | Mismo caso: la migrada tiene `BITACORA.md` y `PROCEDENCIA.md`; de aquí solo se rescató su `PROGRESO.md`. |
| `deepseek/veritas/seguridad/coste-rama-privada-v1/` | Migrado a `veritas/seguridad/coste-rama-privada-v1/` | Mismo caso: la migrada tiene `BITACORA.md` y `PROCEDENCIA.md`; de aquí solo se rescató su `PROGRESO.md`. |
| `deepseek/x.txt` | Prescindible | Es el bloque de prompt de especialista Julia que se repite en los `P-ZRX/*/PROMPT.md`. |

### ⚠️ Advertencia sobre los tres instrumentos migrados

La versión que **vale** de `poda-post-v1`, `prueba-recursiva-v1` y `coste-rama-privada-v1` es la de
`veritas/` (con `BITACORA.md` y `PROCEDENCIA.md`), **no la de `deepseek/`**. La de `deepseek/` no se
copió entera precisamente para no confundir ambas; lo único rescatado de esos tres directorios son
sus bitácoras `PROGRESO.md` (§4), que sí son material no migrado. **No se debe sobrescribir la
versión migrada con la de `deepseek/`.**

## 3 · Qué se rescató

| Origen (`deepseek/…`) | Destino (`P-ZRX/rescate-deepseek/…`) | Ficheros |
|---|---|---:|
| `deepseek/veritas/seguridad/coste-rama-privada-v2/` | `veritas/seguridad/coste-rama-privada-v2/` | 45 |
| `deepseek/veritas/seguridad/coste-rama-privada-v3/` | `veritas/seguridad/coste-rama-privada-v3/` | 46 |
| `deepseek/P-2.1/veritas/consenso/ancla-inyeccion-v1/` | `veritas/consenso/ancla-inyeccion-v1/` | 36 |
| `deepseek/ENCARGO-05-poda-post.md`, `ENCARGO-06-prueba-recursiva.md`, `ENCARGO-07-coste-rama-privada.md`, `ENCARGO-07v2-coste-rama-privada.md` y `ENCARGO-07v2-coste-rama-privada.sha256` | `encargos/` | 5 |
| `deepseek/P-2.1/resumen.txt` | `ancla-inyeccion-v1-resumen.txt` | 1 |
| `PROGRESO.md` de `poda-post-v1`, `prueba-recursiva-v1` y `coste-rama-privada-v1` | `progreso-instrumentos-migrados/PROGRESO-poda-post-v1.md`, `PROGRESO-prueba-recursiva-v1.md`, `PROGRESO-coste-rama-privada-v1.md` | 3 |
| **Total** | | **136** |

Los tres instrumentos únicos suman **127** ficheros (45 + 46 + 36). El resto hasta 136 son los 5
encargos, el resumen de cierre y las 3 bitácoras.

## 4 · Estado de cada pieza

> Aviso general: esta sección **describe** lo que dicen los propios ficheros y `TAREAS.md`; no
> valida nada ni juzga el contenido.

### CRP-v0.2 — `veritas/seguridad/coste-rama-privada-v2/`

- Se corresponde con **CRP-v0.2**, generado por el ejecutor DeepSeek bajo
  `encargos/ENCARGO-07v2-coste-rama-privada.md`.
- Su `INFORME.md` declara en la cabecera: **«Sustituye la evidencia protocolaria de CRP-v0.1»
  (baseline idealizado útil; veredicto protocolario inconcluso)**. Su resumen ejecutivo concluye
  que hay frontera medida para los escenarios ensayados, **pero el umbral protocolario global es
  inconcluso** porque flujo PoT conjunto, controlador del SPEC, PoT AES, `C-GD-11` y finalidad
  siguen pendientes.
- **Estado según `TAREAS.md` §2.9 (e) punto 15: `NO` está validada ni migrada. Sigue sin validar.**
- Ruta de destino prevista (solo tras validación independiente), según el propio encargo:
  `veritas/seguridad/coste-rama-privada-v2/`.

### CRP-v0.3 — `veritas/seguridad/coste-rama-privada-v3/`

- Su `INFORME.md` declara en la cabecera: **`CRP-v0.3`, derivada de `CRP-v0.2` (que `no` se
  cierra)**. `PROCEDENCIA.md` §2 lo repite: «CRP-v0.2 **no se cierra**. CRP-v0.3 es un instrumento
  separado… que incorpora las correcciones pedidas por el usuario (12 puntos)».
- Su resumen ejecutivo concluye que la frontera está medida para los escenarios ensayados y que el
  **umbral protocolario global sigue inconcluso** por reglas pendientes.
- **Estado según `TAREAS.md` §2.9 (e) punto 15: `NO` está validada ni migrada. Sigue sin validar.**
- Tal como pide ese punto de `TAREAS.md`, queda constancia expresa de que **§2.1 y `SPEC.md` §17
  citan CRP-v0.1**, no estas versiones posteriores.

### ANCLA-v0.1 — `veritas/consenso/ancla-inyeccion-v1/`

- Instrumento **ANCLA-v0.1** (consenso), cerrado por el ejecutor DeepSeek. En
  `P-ZRX/P-2.1/veritas/consenso/` solo está **v2** (`ancla-inyeccion-v2/`), por lo que v1 no existía
  en ningún otro sitio del repositorio.
- Su `INFORME.md` se declara «instrumento de estudio (MS)» que **no activa nada ni fija
  constantes**, y su `PROGRESO.md` cierra con la suite en 131/131, `HUELLAS.sha256` verificado
  (45 rutas) y `git status` idéntico al de apertura.
- El resumen de cierre `ancla-inyeccion-v1-resumen.txt` recoge las cifras de `D_min` (`D_min(10⁻³)=1`,
  `D_min(10⁻⁶)=3` medidos; `D_min(10⁻⁹)=4` estimado, no medido) y el mapa (ρ,F), con sus
  limitaciones declaradas (partición/eclipse no modelados; `D_max = I` y `F ≥ I` son interpretación
  del ejecutor, no del encargo).

### Encargos — `encargos/`

- `ENCARGO-05-poda-post.md`, `ENCARGO-06-prueba-recursiva.md`, `ENCARGO-07-coste-rama-privada.md`
  y `ENCARGO-07v2-coste-rama-privada.md` son las entradas congeladas de los tres instrumentos
  migrados y de CRP-v0.2/v0.3. No existían en otro sitio.
- `ENCARGO-07v2-coste-rama-privada.sha256` es el sidecar de huella de la entrada de v0.2/v0.3.
  Control de integridad realizado en el rescate: la huella rescatada coincide
  (`a8912ba5d8d48ae71685b3ea471d7166df74bebc4f17bd609c4182c1e8795c45`) y `ENTRADA.md` de v2 y v3 es
  byte a byte igual a ese encargo.

### Resumen de cierre — `ancla-inyeccion-v1-resumen.txt`

- `deepseek/P-2.1/resumen.txt`, renombrado al copiar. Es el cierre de ANCLA-v0.1 con las cifras de
  `D_min` y el mapa (ρ,F) citados arriba.

### Bitácoras de instrumentos migrados — `progreso-instrumentos-migrados/`

- `PROGRESO-poda-post-v1.md`, `PROGRESO-prueba-recursiva-v1.md` y
  `PROGRESO-coste-rama-privada-v1.md` son las bitácoras del **ejecutor**, no migradas.
- **No confundir con `BITACORA.md` de la versión migrada**, que es otra cosa, escrita después:
  fechas, presupuesto, defectos encontrados y cierres del ejecutor. Se conservan aquí como
  evidencia de procedencia.

## 5 · Qué habría que hacer para cerrar cada pieza

1. **CRP-v0.2 y CRP-v0.3.** Validarlas de forma independiente **o** declarar por qué no aplican
   (`TAREAS.md` §2.9 (e) punto 15). Mientras eso no ocurra, la evidencia central de §2.1 sigue
   citando CRP-v0.1 (`SPEC.md` §2.1 y §17) y hay una versión posterior sin revisar. Si alguna se
   acepta, migrarla a `veritas/seguridad/coste-rama-privada-v2/` (o `…-v3/`) —nunca a `P-ZRX/`—
   siguiendo `veritas/LINEO.md`; si se rechaza, dejar escrito el motivo. v0.3 exige además resolver
   su relación con v0.2, porque v0.2 «no se cierra».
2. **ANCLA-v0.1.** Decidir si es precursor superado por `ancla-inyeccion-v2/` o si su medición se
   conserva como evidencia. Si se acepta, migrarla a `veritas/consenso/ancla-inyeccion-v1/`
   siguiendo `veritas/LINEO.md`. Sus limitaciones declaradas (partición/eclipse no modelados;
   `D_min(10⁻⁹)` estimado; `D_max = I` y `F ≥ I` como interpretación del ejecutor) son las que un
   validador tendría que confirmar o acotar.
3. **Encargos y resumen.** No son instrumentos que se validen: se conservan como documentación de
   procedencia de los instrumentos. No requieren acción de cierre.
4. **Bitácoras `PROGRESO.md`.** Conservar como procedencia del ejecutor. Si en el futuro se migran
   los instrumentos correspondientes, decidir si estas bitácoras se incorporan junto a la versión
   migrada (la migrada ya tiene su propia `BITACORA.md`).

Ninguna de estas piezas se ha validado aquí: **CRP-v0.2 y CRP-v0.3 siguen sin validar y sin
migrar**, tal como estaban.

## 6 · Control de integridad del rescate

- **Recuento de control:** los tres instrumentos únicos suman **127** ficheros.
  `coste-rama-privada-v2` = 45, `coste-rama-privada-v3` = 46, `ancla-inyeccion-v1` = 36; 45+46+36 =
  127. Total rescatado: 136 ficheros.
- **`diff -rq` origen/destino:** sin diferencias (exit 0) en los tres instrumentos, en las 5 piezas
  de `encargos/`, en el resumen renombrado y en las 3 bitácoras renombradas.
- **Huellas:** la huella del `ENCARGO-07v2-coste-rama-privada.md` rescatado coincide con su sidecar;
  `ENTRADA.md` de v2 y de v3 es byte a byte igual al encargo.
- **Metadatos:** comprobado con `stat` que permisos y fechas de modificación se preservaron con
  `cp -a`.

## 7 · Registro de `date` y `git status` del rescate

**Al empezar** (`lun 21 sep 2026 11:01:32 CEST`):

```
$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

**Al terminar** (`lun 21 sep 2026 11:02:37 CEST`):

```
$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

El estado de `git` es **idéntico** al de apertura. `deepseek/` sigue intacta (239 ficheros, los
mismos que al empezar); lo único nuevo es este directorio `P-ZRX/rescate-deepseek/`.
