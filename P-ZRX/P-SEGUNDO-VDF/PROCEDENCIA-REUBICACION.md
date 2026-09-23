# Procedencia de la propuesta de segundo VDF

El usuario pidió el 2026-09-23 mantener hipótesis, teorías e instrumentos del segundo VDF en `P-ZRX/P-SEGUNDO-VDF/` hasta validación. La auditoría Julia tenía dos copias idénticas sin seguimiento de Git; la copia de `veritas/seguridad/segundo-vdf-v1/` se retiró después de `diff -qr`, y queda únicamente `segundo-vdf-v1/` aquí.

Las salidas corregidas previas a este traslado se conservaron en `segundo-vdf-v1/resultados/pre-reubicacion-2026-09-23/`. Las salidas principales se regeneraron desde la nueva ubicación con semilla `0x5a5a`; `ENTORNO.txt` identifica la ruta nueva. Tests del proyecto aislado: 236/236 con un hilo y 237/237 con cuatro hilos. El benchmark anterior se conserva como medida del mismo código y también en el archivo previo a la reubicación.

El siguiente análisis estaba en la nota no normativa de `SPEC.md` §7.1.4. Se traslada a la propuesta como **antecedente de P-REVELACION, no conclusión validada por SDV-v1.1**:

> `P-ZRX/P-REVELACION/investigacion/INFORME.md` rehízo la aritmética del adelanto bajo su adversario y régimen declarados: el máximo de la ventana depende de `ρ`, el tope constante de `P-ADELANTO` es una envolvente y no el valor exacto para todo `ρ` finito, y la revelación retardada examinada reduce la ventana, no la anula. `ρ*` es el umbral del steering, no una prueba de que la ventana sea cero; `+D` resta exactamente `D`, y el bootstrap y la frontera honesta pertenecen a ese mismo modelo, no a una ley universal.

La nota también declaraba que no se adoptaba un segundo VDF ni la variante `(h)` sobre `C-FLU-12`: el beneficio bajo protocolo/red destino, `ρ_max`, `I`, `Lrev`, la edad `M` y los márgenes seguían pendientes. Esa condición **permanece**; la revisión SDV-v1.1 no la cerró.

`TAREAS.md` §2.9(c)(11) repetía la aritmética de P-REVELACION como antecedente. Se deja allí únicamente el estado de calibración pendiente; la comparación de modelos y el veredicto de segundo VDF viven en el [informe de la propuesta](segundo-vdf-v1/INFORME.md).

Las menciones históricas en `research/` y en otras propuestas `P-ZRX/` no se migraron: Git las identifica como evidencia anterior o trabajo distinto, no como la auditoría SDV-v1.1. Los cambios ajenos en archivos de raíz se conservaron.
