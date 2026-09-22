# PROGRESO — investigación P-SEMBRADOR

## Entrada

Fecha:

```text
2026-09-20T12:06:23+02:00
```

Presupuesto declarado antes de calcular: máximo 8 hilos de CPU, 16 GiB de RAM, 2 GiB de disco y corridas de minutos. Si una corrida agota ese presupuesto, se detiene y el resultado queda `inconcluso`. No se ejecutará Python.

Comprobación de entrada, ejecutada desde `/home/katana/zeo/ZEROX`:

```text
$ LC_ALL=C sha256sum -c P-SEMBRADOR/ENTRADA.sha256
P-SEMBRADOR/PROMPT.md: OK
```

Estado de entrada:

```text
$ git -C /home/katana/zeo/ZEROX status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? P-SEMBRADOR/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

Los cambios anteriores ya existían al comenzar. Esta investigación escribe exclusivamente dentro de `P-SEMBRADOR/investigacion/`.

## Objeción inicial solicitada por el encargo

La sospecha de que `history_size` o `altura_ploteo` antiguos no demuestran por sí solos la antigüedad física de una parcela es **plausible, pero no verificada todavía** al abrir la investigación. C-EXP-01…06 vinculan la referencia histórica con la validez/caducidad del sector, pero el texto leído no aporta un compromiso del sector publicado antes del reto. La conclusión se condiciona a comprobar en la fuente fijada de Autonomys si el verificador exige algún vínculo temporal externo al contenido de la solución.

No se detectó aún una contradicción demostrada en la descripción del ataque del §2. Sí se tratarán como hipótesis por verificar el ploteo parcial, la independencia de los intentos y el traslado de las cifras históricas a la primitiva real.

## Trabajo en curso

- Lectura completa de `README.md`, `MIGRACION.md`, `research/README.md` y `veritas/LINEO.md`.
- Lectura de las secciones aplicables de `SPEC.md`, `P-2.1/SINTESIS.md`, `P-POT/propuesta/PROPUESTA-SPEC.md` y `P-FLUJO/propuesta/PROPUESTA-SPEC.md`.
- Revisión separada de la fuente Rust de Autonomys, del modelo matemático Julia y de las candidatas de diseño.

## Salida

### Hallazgos cerrados

- **[Demostrado por inspección de dependencias]** La solución aceptada depende de un registro/pieza, no de la existencia del sector completo. El consenso no recibe `SectorContentsMap`, checksum ni un compromiso temporal previo.
- **[Verificado en fuente]** `history_size` y `altura_ploteo` determinan referencia histórica, mapeo y caducidad; no demuestran cuándo se calcularon o almacenaron los bytes. La sospecha inicial queda confirmada.
- **[No determinado]** El benchmark histórico de sector completo no mide el kernel dirigido mínimo. Los márgenes económicos heredados no se adoptan.
- **[Derivado y verificado por instrumento]** Para `w` retos conocidos y espacio efectivo `H=N_h/λ`, `q=1-(1-1/H)^w` es la probabilidad de un candidato no vacío, `μ=w/H` son las soluciones esperadas y `M=coste/(recompensa_efectiva·μ)` es el margen. El resultado cambia con `ρ` y `L`.
- **[Propuesta propia]** A1+C1 —compromiso/certificado completo anterior al reto y edad superior a una cota del adelanto— es el cambio mínimo capaz de eliminar condicionalmente la adaptación. Sin registro/acumulador y prueba completa, ZEROX sólo puede mitigar o tarifar el sembrador.
- **[No determinado]** La fórmula final del adelanto debe rehacerse con `pot_output=salida(slot+D)`; no se fijó ningún parámetro de consenso.

### Instrumento y verificación

Se creó `P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/` con proyecto y manifest de Julia, versión fijada, referencia `BigFloat`, kernel, validación, tests, benchmark, barrido, hipótesis e informe reproducible. No se creó ni ejecutó Python.

Comprobación independiente final:

```text
$ env JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 ./veritas/julia.sh --project=P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1 --threads=1,0 -e 'using Pkg; Pkg.test()'
validación de entradas: 5/5
bordes y significado económico: 17/17
sensibilidad exigida a rho y L: 8/8
monotonías del modelo: 5/5
oráculo BigFloat: 5/5
scripts parseables: 2/2
SembradorV1 tests passed (42/42)
```

Artefactos medidos por el instrumento: JET `No errors detected`; `@code_warntype` devuelve `ResultadoMargen{Float64}`; kernel de 100.000 filas con mediana 1,484472 ms, 0 bytes y 0 asignaciones calientes; barrido adimensional de 96 filas. Son medidas del evaluador matemático, no del ploteo.

### Comprobación final del encargo

Ejecutada desde `/home/katana/zeo/ZEROX` después de terminar los entregables:

```text
$ LC_ALL=C sha256sum -c P-SEMBRADOR/ENTRADA.sha256
P-SEMBRADOR/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? P-SEMBRADOR/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date --iso-8601=seconds
2026-09-20T12:35:20+02:00
```

Los cambios previos fuera de `P-SEMBRADOR/investigacion/` permanecen sin tocar. Esta ejecución escribió únicamente dentro de la zona autorizada.
