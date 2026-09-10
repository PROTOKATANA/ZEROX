# Auditoría de la ronda 14A — qué queda en pie y qué no

**D9b:** `audita-d9b.md` · **D8b:** `../d14-sin-comite/audita-d8b.md`

## Lo que D9b verificó (se puede usar)

- La rama `origin/dagknight` de `rusty-kaspa` y el fixture `ref_umc_fixture.json` son reales
  (md5 idéntico); el fixture da score=4, rojos 12..17, rank 0. Pero **ningún script lo carga**: la
  validación no es reproducible con la ruta publicada.
- Los cuatro scripts se re-ejecutan byte-idénticos. Latencias a `α=0,33`: **7,92 / 14,14 / 29,62 /
  55,67 s** de media (ε=0,05/1e-3/1e-6/1e-12), mínimos **3,29 / 8,67 / 15,19 / 36,22 s**; baseline
  **130,41 s**.
- `k_ref` no se infla a `Δ ≤ 20`; el ataque de selección de subgrupo sigue ahí (0-3/12 semillas con
  ganador honesto).

## Lo que D9b refutó o corrigió

| Afirmación | Corrección |
|---|---|
| «M_kMC = Alg. 1» | Alg. 1 es Order-DAG naïve; M_kMC es el recuadro `dagknight.txt:114-119` |
| «En ZEROX todos los bloques pesan 1» | ZEROX usa `blue_work` variable (`ancla-de-orden.md:157`); la medida con pesos reales queda sin demostrar |
| M3 a Δ=20: «123/144/127» y «máx k_hon 34» | **123,3 / 144,0 / 170,0 s**; máx `k_hon` **37** |
| Suelo ε=0,05: 7,6 s | **7,46 s** (`m/((1−α)λ)`); el 7,6 era media por registro |
| 14C cita el `k*` de 14A (4-17 s / 90-250 s) | Superado por 14B: suelo ≤55 s a Δ≤20 |

## Lo que D8b tumbó

1. **El «hueco de selección» está mal medido.** Su oráculo dispara en red sana (`instant`): 1/12 a
   α=0,10, 4/12 a α=0,25, 7/12 a α=0,40; a α=0,40 Δ=16, `instant` y `retraso20` dan idéntico 7/12.
   No distingue ataque de red pública.
2. **El 4-17 s no es publicable.** El control positivo sigue en LAGUNA (el paper no publica su regla
   de cliente); la fórmula `max(3k, m(α,ε))` es **independiente de Δ**, lo contrario de la
   responsividad que vende el paper; y la cota del paper a Δ=16-20 s (256-400 s) es **peor que el
   baseline**.
3. **La atribución al CAP es forzada.** El teorema es «adaptativo + finalidad con UNA regla»
   (`lewispye-roughgarden-cap.txt:759`); las reglas duales caen fuera (`cap-adaptividad-finalidad.txt:97-98`).
4. **Avalanche no es un comité** (muestreo abierto, Sybil pluggable); los 2.000 AVAX son despliegue.
   Su exclusión se sostiene por Sybil/peso, no por los motivos que da 14C.

## Lo que NO se tumbó

- La regla fiel **sí elimina la inflación del rank de la vista** (`k_view` 0-2,6); la medida es
  reproducible.
- El ataque real sigue: **retención + cadena privada** captura en **8-12/12 semillas** (rank del tip
  honesto 12-21 o `None` con el atacante en 0). Etiqueta **SOSPECHA**.
- «Sin comité no hay finalidad determinista rápida»: operativamente sobrevive.

## Estado publicable

Nada de esta ronda es todavía una cifra de consenso. Lo único firme: **el baseline mide 130,41 s a
α=0,33** y **la confirmación adaptativa baja de ahí solo si `Δ` es bajo y el ataque de retención se
cierra**; ambas cosas sin demostrar.
