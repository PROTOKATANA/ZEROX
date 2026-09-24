# Ajuste de la corrección A2 · prueba acotada

La corrección `CORRECCION-A2-CONTEXTO-DAG-Y-PERMANENCIA.md` mantiene sus dos cambios obligatorios: `dag()` debe devolver `&InstantaneaPrimerHijoDagDev`, y `ContextoRangoNoDisponible.es_permanente()` debe ser `false`. **No construyas un fixture completo de cabecera firmada y PoAS dentro de `error.rs` para probar la puerta A3.** Esa prueba opcional exigiría duplicar utilidades extensas del test de A3 y ampliar innecesariamente el archivo de errores. Su clasificación ya está en la rama existente de `cabecera_conjunta`: solo `RangoIncorrecto` va a `Invalida`; las demás variantes van a `Pendiente`. Anota ese límite en tu entrega; el test de puerta completo corresponderá a la futura integración A3, donde habrá un bloque firmado real.

Pruebas suficientes para esta corrección, dentro de los archivos ya permitidos:

- `comprobar_padres_contextual(&cabecera, contexto.dag())` pasa con `{G}` y rechaza padre ajeno.
- `ContextoRangoNoDisponible.es_permanente()` es `false`; un error de consenso permanente ya existente sigue siendo `true` para mostrar que no se anuló la clasificación general.
- `RangoSolucionValidado::validar` con un candidato cuyo slot no sea el guardado devuelve `ContextoRangoNoDisponible`, nunca `RangoIncorrecto` ni `Ok`; el candidato con mismo slot y rango declarado incorrecto sigue dando `RangoIncorrecto`.

Corrige además la frase del tiempo de test. Ejecuta solo los gates obligatorios de la orden; no compiles ni midas `--release`, no repitas un gate ya verde por curiosidad y no edites otros archivos. No hagas commit ni push.
