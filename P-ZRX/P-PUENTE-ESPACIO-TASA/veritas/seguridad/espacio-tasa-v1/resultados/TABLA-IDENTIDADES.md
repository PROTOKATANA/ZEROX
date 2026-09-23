**Escenario 1** con `N` identidades que se reparten 1 TiB conservando **todos** los bytes
(`Σ bytes_i = T`, también `T mod N`). **Escenario 2** calculado **directamente desde `T`**.

*Hipótesis declarada:* `piezas_por_sector = 1000`, el **máximo** de `MAX_PIECES_IN_SECTOR`.
El formato admite sectores con **menos** piezas, así que las columnas `hip. 1000` **no** son
una exigencia del formato. `piezas_max_que_caben` da el mayor sector que sí cabe con ese
presupuesto. **La conclusión general «N identidades ⇒ cero espacio efectivo» está retirada.**

| `N` | Bytes por identidad | `Σ bytes_i = T` | Sectores esc. 1 (hip. 1000) | Sectores esc. 2 (desde `T`) | Perdidos | `perdidos ≤ N` | Sin sector (hip. 1000) | `piezas_max_que_caben` | ¿Cabe algún sector? |
|---:|---:|:---:|---:|---:|---:|:---:|---:|---:|:---:|
| 1 | 1099511627776 | sí | 1040 | 1040 | 0 | sí | 0 | 1000 | sí |
| 2 | 549755813888 | sí | 1040 | 1040 | 0 | sí | 0 | 1000 | sí |
| 3 | 366503875926 | sí | 1038 | 1040 | 2 | sí | 0 | 1000 | sí |
| 7 | 157073089683 | sí | 1036 | 1040 | 4 | sí | 0 | 1000 | sí |
| 10 | 109951162778 | sí | 1040 | 1040 | 0 | sí | 0 | 1000 | sí |
| 100 | 10995116278 | sí | 1000 | 1040 | 40 | sí | 0 | 1000 | sí |
| 520 | 2114445439 | sí | 1040 | 1040 | 0 | sí | 0 | 1000 | sí |
| 1039 | 1058240258 | sí | 1039 | 1040 | 1 | sí | 0 | 1000 | sí |
| 1040 | 1057222720 | sí | 1040 | 1040 | 0 | sí | 0 | 1000 | sí |
| 1041 | 1056207136 | sí | 0 | 1040 | 1040 | sí | 1041 | 999 | sí |
| 1042 | 1055193501 | sí | 0 | 1040 | 1040 | sí | 1042 | 998 | sí |
| 2000 | 549755814 | sí | 0 | 1040 | 1040 | sí | 2000 | 520 | sí |
| 10000 | 109951163 | sí | 0 | 1040 | 1040 | sí | 10000 | 104 | sí |

**La pérdida no es monótona en `N`**: con `N = 7` se pierden 4 sectores y con `N = 10`, 0.
Lo único afirmable es `Σ⌊bytes_i/s⌋ ≤ ⌊T/s⌋` y la cota `perdidos ≤ N`.

**Contraejemplo que retira la conclusión general.** Con `N = 1041` el presupuesto de cada
identidad (`1 056 207 136 B`) no admite un sector de **1000** piezas, pero **sí** uno de
**999** (`sector_size(999) = 1 055 839 168 B`), incluso sumando los `131 116 B` de metadata
externa: `1 055 970 284 ≤ 1 056 207 136`. Es decir, «cero espacio efectivo» es un enunciado
**condicionado a la hipótesis de 1000 piezas fijas**, no una propiedad del formato.
