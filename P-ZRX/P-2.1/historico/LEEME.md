# Histórico de versiones del encargo P-2.1

| Versión | Estado | Para qué sirve |
|---|---|---|
| **v1** (`v1/`) | **Ejecutada.** Corrida terminada el 2026-09-18 ~20:33 en `deepseek/P-2.1/veritas/consenso/ancla-inyeccion-v1/` | Es la entrada congelada contra la que se valida esa corrida. **Huellas en `v1/HUELLAS.sha256`, verificadas.** Midió el ancla equivocada (posición `N` de la cadena, el ancla nº 2 descartada en D9-c), en unidades de posición y no de slot, y solo en red honesta |
| **v2** | **Nunca lanzada, no conservada** | Escrita y sustituida el mismo día, antes de ejecutarse, tras barrer la investigación previa con ocho revisores. No tiene valor probatorio. Sus defectos están listados en `../ENCARGO.md` §2 y en `../CONTEXTO.md` |
| **v3** | **Vigente** (`../ENCARGO.md`) | La que se lanza |

**Nota sobre el 2026-09-18, 20:41:** el ejecutor de la v1 movió este directorio desde `P-2.1/` a
`deepseek/P-2.1/historico-v1/` mientras cerraba su corrida. Se recuperó íntegro (huellas OK) y se
devolvió aquí. Por eso el encargo v3 declara `P-2.1/ENCARGO.md`, `PROMPT.md`, `CONTEXTO.md`,
`ENTRADA.sha256` e `historico/` **de solo lectura**, y exige comprobar `ENTRADA.sha256` al empezar y
al terminar.
