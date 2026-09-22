# PROGRESO — P-EQUIVOCACION

Bitácora de la sesión. Zona de escritura: `P-ZRX/P-EQUIVOCACION/investigacion/` (única).
Fuentes de solo lectura: `PROMPT.md`, `CANDIDATA.md`, `ENTRADA.sha256` y todo el resto del repositorio.

## 0 · Presupuesto declarado antes de ejecutar (LINEO §7 y bloque §8, punto 11)

Esta auditoría es **análisis de reglas escritas** + **un enumerador exhaustivo pequeño en Julia con
aritmética entera exacta**. No hay Monte Carlo masivo ni GPU.

| Recurso | Declaración | Usado de verdad |
|---|---|---|
| Hilos | **máximo 4** (hay otros encargos en la máquina; el tope conjunto de LINEO es 24). Se midió 1…4 y se conservó 4. | 4 |
| RAM | **máximo 4 GiB** | < 1 GiB |
| Disco temporal | **máximo 200 MiB**, todo dentro de `resultados/` | < 1 MiB |
| Tiempo | corridas de minutos; ninguna corrida individual > 5 min de pared | ninguna > 12 s |
| Lenguaje | Julia 1.13.0 en CPU vía `./veritas/julia.sh`. **Nada de Python.** | sí |
| Si se agota | checkpoint en `resultados/` y estado **inconcluso**; nunca un timeout como evidencia de falsedad | no se agotó |

## 1 · Estado inicial (obligatorio, §5 del encargo)

```
$ LC_ALL=C sha256sum -c P-ZRX/P-EQUIVOCACION/ENTRADA.sha256
P-ZRX/P-EQUIVOCACION/PROMPT.md: OK
P-ZRX/P-EQUIVOCACION/CANDIDATA.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ git rev-parse HEAD
49c6ffa7a29a2237fb19c341d1d9fb79755f15a1

$ date
lun 21 sep 2026 16:47:49 CEST

$ uptime
 16:47:49  up 13 days 13:17,  0 users,  carga promedio: 3,05, 1,79, 0,89
```

`D ZEROX-EN-NUMEROS.md` y las cuatro entradas `??` **preexisten** a esta sesión (son trabajo de
Katana/Claude y de encargos anteriores). No se tocan. La carga media no es 0: hay otros encargos;
de ahí el tope declarado de 4 hilos.

## 2 · Qué se ejecutó de este directorio, y qué no

El directorio contiene **tres archivos, ninguno ejecutable**: `PROMPT.md` (el encargo),
`CANDIDATA.md` (la solución candidata, congelada) y `ENTRADA.sha256` (sus huellas). «Ejecutar los
archivos» se interpretó como **ejecutar el encargo de `PROMPT.md`**: producir los entregables de su
§7 en `investigacion/`, con el enumerador Julia de
`investigacion/veritas/consenso/equivocacion-v1/`. `PROMPT.md`, `CANDIDATA.md` y `ENTRADA.sha256` son
de solo lectura y **no** se modificaron (huellas verdes al empezar y al terminar, §5).

## 3 · Avisos ANTES de empezar (§8 del encargo: «si algo te parece equivocado, dilo antes»)

Ninguno de estos avisos cambió el plan; se dejan escritos para que Claude y Katana los lean antes que
el informe. Los tres son **de redacción del encargo o de las fuentes que cita**, no del método.

1. **`S_max_slots` no acota «un bloque publicado más de `S_max` después de su slot».** La regla
   escrita es `slot(B) − slot(sp(B)) ≤ S_max` (C-GD-04) y `pot_bundle_count == slot(B) − slot(sp(B)) ≤ 150`
   (C-HDR-07), es decir la distancia al **padre seleccionado**, no a un reloj de publicación. No hay
   en el SPEC ninguna regla que mida el retraso de *publicación* contra el slot del bloque: el
   timestamp no gobierna esto (§7.4, C-TS-01). Importa para la Parte B: el plazo del firmante seguro
   se deriva de `slot(B) − slot(sp(B)) ≤ S_max`, no de una noción de «publicación tardía» que el SPEC
   no define. Resuelto en `FALSOS-POSITIVOS.md` §3.2.

2. **La infracción estrecha de `CANDIDATA.md` y la regla de copias de `SPEC.md` §7.2 se contradicen
   en un caso que el propio SPEC usa como vector.** §7.2 dice que, tras un reorg, «un billete
   consumido en una historia abandonada **vuelve a estar disponible** en la rama que prevalece», y lo
   respalda con `fixture_reorg_libera_billete`: «el mismo billete gana en dos ramas competidoras y,
   tras el reorg, lo consume el bloque de la rama prevalente». Ese vector es, literalmente, la
   infracción estrecha (mismo `TicketId` y slot, dos `pre_hash`, dos sellos válidos; los dos bloques
   existen). Hoy el doble uso entre ramas **no** es fraude. Si la infracción estrecha entra, ese
   fixture pasa de ser el ejemplo de corrección de §7.2 a ser el ejemplo de un delito. Va desarrollado
   en `FALSOS-POSITIVOS.md` FP7 y en `DEFINICION-PROPUESTA.md` §5, con tres salidas y una
   recomendación.

3. **«Las anclas de las inyecciones activas son anteriores a la bifurcación» es demostrable; «luego
   comparten flujo» no se sigue.** Es el resultado principal de este trabajo (`PROPOSICIONES.md` P2,
   P3 y P4): la primera mitad es un **teorema**; la segunda es **falsa en general** y su contraejemplo
   es la carrera A2 que `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` §0.4 ya etiqueta
   «probabilístico, no demostrado y NO medido». No es un error del encargo: es la respuesta. Se avisa
   aquí porque el §0 del encargo pide explícitamente no confirmar la hipótesis por deferencia.

Nada de lo anterior impidió ejecutar el encargo. No se detectó ningún defecto de método en el
`PROMPT.md`.

## 4 · Bitácora

| # | Fecha/hora | Hecho | Artefacto |
|---|---|---|---|
| 1 | 16:47 | Reconocimiento y huellas. Lectura íntegra de `veritas/LINEO.md` y `CANDIDATA.md`. Lectura de `SPEC.md` §6.1–§6.2, §7.1–§7.5, §11, §12, §17; IDV (IDENTIDAD, CONTRATO-VALIDACION, INFORME, DISPONIBILIDAD); `regla-flujo-v1/PROPUESTA-SPEC.md` §0.4/§2; `coste-rama-privada-v1/INFORME.md` §6; `P-2.1/SINTESIS.md`; `research/README.md`; `crates/zx-core/tests/ed25519_no_unicidad.rs`. | `PROGRESO.md` |
| 2 | 16:50 | Estructura del enumerador y `Project.toml`. `Pkg.instantiate()` **no se puede** ejecutar: el registro de Julia vive fuera de la zona de escritura (`EROFS`). Se usa el `Manifest.toml` de `veritas/plantilla/` (obligatorio según LINEO §1) y se verifica que carga. | `equivocacion-v1/` |
| 3 | 16:55 | `modelo.jl`, `referencia.jl`, `rapido.jl`, `espectro.jl`, `validacion.jl`, `rejilla.jl`. | código |
| 4 | 16:56 | **Fallo real detectado por el contraste**: el anticono del oráculo comprobaba sólo una de las dos condiciones de incomparabilidad y discrepaba del kernel en DAGs aleatorios. Corregido en las tres implementaciones (`H5` de `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`). | código |
| 5 | 16:57 | **Segundo fallo real**: el universo de soluciones compartía los valores de `chunk` entre piezas e invertía el signo de la comparación entre identidades (`H9`). Corregido. | código |
| 6 | 16:58 | Rejilla de la hipótesis y contraste. 480 configuraciones, todas dentro de la ventana; 54 sin escape con `κ_flujo = 1.0000`; 418/418 y 36/36 para el criterio `P5`. | `resultados/kappa-flujo.csv`, `resultados/contraste.txt` |
| 7 | 17:00 | Tabla de κ por identidad y por régimen, con el escenario `misma-parcela` que discrimina `C-GD-07` de IDV-01. | `resultados/kappa-identidad.csv` |
| 8 | 17:02 | Microbenchmarks y escalado 1/2/4 hilos, con resultado idéntico. | `resultados/benchmark.txt`, `resultados/escalado.txt`, `resultados/ENTORNO.txt` |
| 9 | 17:05 | Suite de tests: **567/567**. | `test/runtests.jl` |
| 10 | 17:06 | Entregables escritos. | ver §6 |
| 11 | 17:10 | **Repaso contra el encargo**: faltaban dos exigencias explícitas. (a) §2.3, «las otras fugas», una por una — añadidas a `INFORME.md` §3.3 y como `P10`; de las siete, dos **no** son fugas (slots alternos, parcelas preparadas), una es la fuga central (retos distintos = A2), dos quedan fuera del alcance de cualquier identidad (rama nunca revelada, censura) y una es económica. (b) Parte C, la pregunta literal «¿bastan firma, solución PoAS y reto del slot?» — respondida en tabla en `DEFINICION-PROPUESTA.md` §4.1. Además: `propiedad_H1` renombrada a `propiedad_P2` (coherencia con `PROPOSICIONES.md`), nueva limitación de alcance en `DEFINICION-PROPUESTA.md` §2 y **D14** en `DECISIONES-PENDIENTES.md`. | `INFORME.md`, `PROPOSICIONES.md`, `DEFINICION-PROPUESTA.md`, `DECISIONES-PENDIENTES.md` |
| 12 | 17:11 | Reejecución completa tras los cambios: **567/567** tests, los cuatro modos de `run.jl`, benchmark y escalado 1/2/4 hilos con `κ_flujo` global idéntico. | `resultados/` |

## 5 · Estado final (obligatorio, §5 del encargo)

```
$ LC_ALL=C sha256sum -c P-ZRX/P-EQUIVOCACION/ENTRADA.sha256
P-ZRX/P-EQUIVOCACION/PROMPT.md: OK
P-ZRX/P-EQUIVOCACION/CANDIDATA.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ git rev-parse HEAD
49c6ffa7a29a2237fb19c341d1d9fb79755f15a1

$ date
lun 21 sep 2026 17:11:22 CEST

$ uptime
 17:11:22  up 13 days 13:40,  0 users,  carga promedio: 1,15, 1,06, 1,25
```

**Idéntico al inicial salvo la carga media.** Ni un fichero fuera de
`P-ZRX/P-EQUIVOCACION/investigacion/` se creó, modificó ni movió; `PROMPT.md`, `CANDIDATA.md` y
`ENTRADA.sha256` siguen con sus huellas originales. No hubo `push`, ni publicación, ni mensajes
externos.

## 6 · Entregables (§7 del encargo)

| Entregable | Ruta |
|---|---|
| Informe (primera línea = la respuesta) | `investigacion/INFORME.md` |
| Proposiciones con premisas, demostración o contraejemplo y etiqueta | `investigacion/PROPOSICIONES.md` |
| Catálogo de falsos positivos y firmante seguro | `investigacion/FALSOS-POSITIVOS.md` |
| Propuesta de infracción, identidad y evidencia mínima | `investigacion/DEFINICION-PROPUESTA.md` |
| Pendientes | `investigacion/DECISIONES-PENDIENTES.md` |
| Progreso y huellas | `investigacion/PROGRESO.md` |
| Supuestos que codifica el código | `investigacion/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` |
| Enumerador | `investigacion/veritas/consenso/equivocacion-v1/` |

## 7 · Cierre: lo que este encargo deja abierto

Los diez puntos de «Lo que esta investigación NO resuelve» (`INFORME.md` §8) y la tabla de
`DECISIONES-PENDIENTES.md`. El que más puede mover el resultado es **D1** (el valor de `C-GD-11`):
si el *bounded merge depth* acaba siendo estrecho, el contraejemplo de `P4` puede ser inalcanzable en
el consenso destino aunque siga siendo un enunciado verdadero. El segundo es **D3** (la asimetría de
la carrera dentro de `V_j`), que es un argumento derivado del texto de `C-FLU-04` y **no medido**.
