# ADENDA 1 al encargo P-FLUJO — decisiones de Katana y actualización de la propuesta

**De:** Claude (diseñador y validador), 2026-09-20. **Solo lectura**, como el encargo. Regístrala en
`PROGRESO.md` al leerla. El `ENCARGO.md` no cambia; esta adenda **prevalece** en lo que dice.

## 0 · Tu refutación es correcta

La parte (a) de la afirmación central del encargo §2 era **falsa**, y el validador lo acepta: R-FIN-7
prohíbe un acto (reorganizar por debajo de `F`), no vuelve imposible el estado de dos mitades con cadenas
distintas. El perfil 1a se sostiene por **(P1)** ancla final antes de usarse —demostrado—, **(P2)** la
partición rara vez nace —medido en simulación— y **(P3)** si nace es permanente —demostrado—. Mantén esa
estructura: es la correcta.

## 1 · DECIDIDO por Katana (2026-09-20) — incorpóralo y retira la condicionalidad

| | Decisión |
|---|---|
| **Perfil 1a** | **Reconfirmado**, sabiendo que una partición de flujo, si nace, **no tiene cura en el protocolo**. Escríbelo así, sin suavizarlo: prevención, no recuperación |
| **Suelo de `L`** | **Sí.** `L` no queda atada a `F` a secas: `L_slots ≥ máx(F_slots, L_suelo_slots)`, combinado con la desigualdad de D-F4. `L_suelo_slots` es un **parámetro de consenso simbólico** (no le pongas valor): su criterio de calibración es la cola medida `G(d)` a un `ε` elegido y una cota de Δ **medida en red real**. Motivo: que bajar `F` en producción no deje `L` por debajo de lo medido. Cita como referencia, etiquetada `medido en simulación` / `estimado`: `L_mín(10⁻³)` = 119 / 1 198 / 1 682 slots con Δ = 4 / 10 / 16 s, y su extrapolación a 10⁻⁹ ≈ 360 / 3 600 / 5 000 (`P-2.1/SINTESIS.md`) |
| **D-F1** | **A:** entropía `= blake3(chunk(I_j) ‖ pot_output(I_j))`. Motivo adicional de Katana: no atar §2.1 a la identidad del billete (§2.2), que además puede cambiar si algún día se adopta un registro de parcelas contra el sembrador |
| **D-F6** | **A:** ampliar la cota de slot a **todos** los padres, `slot(P) ≤ slot(B)`, no estricta. Añade a la regla: **(i)** la consecuencia para la selección de padres (el productor no referencia puntas de slot mayor que el suyo; afecta a C-GD-10); **(ii)** que el coste para el productor honesto es **«estimado ≈ 0, a confirmar con ANCLA-v0.2 antes de pasar al SPEC»** —fracción de bloques honestos que referenciarían un padre de slot mayor, con Δ = 0,5 / 4 / 16 s—; **(iii)** que toca C-HDR-05 en §6.1 y una comprobación en `zx-core` |

## 2 · Sin decidir todavía: aplícalo como PROVISIONAL

Katana **no se ha pronunciado** sobre D-F2, D-F3, D-F4 y D-F5. Redacta la propuesta con la opción en la
que coinciden tu recomendación y la del validador, y **márcala «PROVISIONAL — pendiente de Katana»** en la
regla y en `DECISIONES-PENDIENTES.md`; no las des por decididas:

- **D-F2 → A** (`H_d` con etiqueta nueva de 16 bytes; hay que ampliar C-HASH-06).
- **D-F3 → C** (regla de finalidad **nueva en el SPEC**, en slots, con la semántica de R-FIN-7: la punta
  incompatible se **ignora**, el proceso no se detiene). Apóyate en que el propio SPEC ya declara
  `C-REORG-07` transitoria y a R-FIN-7 como la regla propuesta con «integración pendiente»
  (`SPEC.md:1891-1899` y `SPEC.md:2050-2054`). `F` como símbolo.
- **D-F4 → A** (desigualdad escrita de forma explícita).
- **D-F5 → no legislar ahora, estudio aparte**, más una **regla operativa mínima** que sí debes proponer:
  que el nodo **detecte que ha quedado fuera del flujo mayoritario y lo señale**, en vez de seguir
  funcionando en silencio. Es comportamiento de nodo, no validez de bloque: dilo.

## 3 · Dos declaraciones nuevas para «Lo que esta propuesta NO resuelve»

1. **El coste de 1a frente al sembrador.** Con `L ≥ F` no se puede bajar `L` para aliviar el ataque del
   sembrador (la mejora histórica «desatar `L` de `F`» queda cerrada), y la defensa por «maduración de la
   parcela» no funciona tal como estaba escrita: `history_size` y `altura_ploteo` **no demuestran
   antigüedad física**, y al atacante le basta una pieza, no un sector. Fuente:
   `P-SEMBRADOR/investigacion/INFORME.md` (**validación parcial** del validador: integridad, tests y las dos
   citas clave de la fuente de Autonomys comprobadas; el informe completo está sin leer). El margen real
   **no está medido**.
2. **La aritmética del adelanto está sin rehacer** tras fijar `pot_output` como salida futura (D-2 = A); tú
   mismo lo anotas en tu propuesta. Déjalo como pendiente explícito.

## 4 · Dos correcciones menores

- La cita `research/balizas-auditoria.md` no existe: el archivo es
  `research/dag-poas-balizas-auditoria.md` (la abreviatura venía de `P-2.1/SINTESIS.md`; error del
  validador). Ábrelo y cita la línea.
- Abre también la otra cita de segunda mano que declaraste (`…/pot.rs:176-187`) o mantenla marcada.

## 5 · Al terminar

Actualiza `PROPUESTA-SPEC.md`, `DECISIONES-PENDIENTES.md` (decididas / provisionales / abiertas) y
`PROGRESO.md` con las dos comprobaciones de siempre. No toques nada fuera de `P-FLUJO/propuesta/`.
