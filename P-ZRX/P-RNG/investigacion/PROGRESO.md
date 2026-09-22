# Progreso — P-RNG

## Apertura

Fecha:

```text
2026-09-20T14:15:20+02:00
```

Presupuesto declarado: investigación documental, sin simulación nueva; máximo 8 hilos CPU, 8 GiB de
RAM, 1 GiB de disco adicional y comandos individuales de minutos. No se ejecuta Python.

Observación previa sobre el encargo: la métrica propuesta `C_irr(α,T)` es útil, pero «pierde con
certeza» no permite comparar sin más el gasto inevitable de PoW con una fianza de PoS, cuya pérdida
es contingente a una conducta demostrable, detección, inclusión y ejecución. La investigación
conservará `C_irr`, descompuesta en coste inevitable y coste contingente, y separará además coste
hundido de depreciación/amortización de capital reutilizable.

Comprobación inicial, ejecutada desde `/home/katana/zeo/ZEROX`:

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-RNG/ENTRADA.sha256
P-ZRX/P-RNG/PROMPT.md: OK
P-ZRX/P-RNG/acro.txt: FAILED open or read
sha256sum: P-ZRX/P-RNG/acro.txt: No such file or directory
sha256sum: WARNING: 1 listed file could not be read
```

El fallo es de entrada: `acro.txt` no estaba presente. No se reconstruye ni se modifica porque el
encargo lo declara de solo lectura.

Estado inicial:

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
?? P-ZRX/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

Estos cambios preexistían a este trabajo y no se modificarán fuera de
`P-ZRX/P-RNG/investigacion/`.

## Trabajo

- Leídos por completo `README.md`, `MIGRACION.md`, `research/README.md` y `veritas/LINEO.md`.
- Leídas las secciones aplicables de `SPEC.md`: reglas de interpretación, cabecera/sello, prueba de
  espacio-tiempo, rango y unicidad pagable, GHOSTDAG, coinbase/madurez, reorganización, caducidad de
  sectores, confirmación, PoT de red y pendientes activos.
- La investigación documental está en curso; no se ha ejecutado ningún instrumento histórico de
  `research/scripts/`.

## Cierre

Fecha:

```text
2026-09-20T14:26:12+02:00
```

Trabajo terminado:

- Entregados `INFORME.md` y `DECISIONES-PENDIENTES.md`.
- Contrastadas de forma independiente la métrica matemática, la evidencia primaria externa y la
  evidencia interna/compatibilidad con ZEROX. El principal reabrió las fuentes incorporadas.
- No se fijaron parámetros de consenso, precios ni cifras económicas nuevas.
- No se creó ni ejecutó cálculo Julia, C++/CUDA o Python: las fórmulas son derivaciones simbólicas y
  las cifras citadas conservan la etiqueta y el alcance de sus fuentes.
- Validación documental: primera línea presente, sección final «Lo que esta investigación NO
  resuelve», tablas Markdown con número coherente de columnas, sin espacios finales y solo tres
  archivos escritos bajo `P-ZRX/P-RNG/investigacion/`.

Comprobación final, ejecutada desde `/home/katana/zeo/ZEROX`:

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-RNG/ENTRADA.sha256
P-ZRX/P-RNG/PROMPT.md: OK
P-ZRX/P-RNG/acro.txt: FAILED open or read
sha256sum: P-ZRX/P-RNG/acro.txt: No such file or directory
sha256sum: WARNING: 1 listed file could not be read
```

El fallo final es idéntico al inicial: falta la entrada de solo lectura `acro.txt`; `PROMPT.md`
permanece íntegro.

Estado final:

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
?? P-ZRX/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

El lanzador imprimió repetidamente `Error connecting to agent: Operation not permitted` antes de
comandos de shell; los comandos locales continuaron y devolvieron las salidas registradas. No se
usó ese agente externo como fuente ni se alteró el alcance de escritura.
