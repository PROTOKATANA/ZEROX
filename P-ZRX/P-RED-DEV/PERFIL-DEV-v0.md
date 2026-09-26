# Perfil de la red dev de 0.0.1 (v0)

**Estado:** decisión del director para la red de **desarrollo**; **ningún valor es parámetro de
producción** ni sale de una medición de seguridad (`AUTO-ZRX.md` §3.7, D-P05). **Fecha:** 2026-09-26.
**Firma:** Claude. Los valores se eligen para que una red local de 3 nodos cruce el corte en minutos
y sea reproducible; los que dependen del hardware se **miden** antes de fijarse (marcados «por
medir»).

## 1. Identidad de red

`Red::Dev`, magia `db347847`, `CBID_RED_DEV = a8b466a7`, HRP `dzzk` (W02);
`HASH_GENESIS_DEV = c72fdb3b37e7571a82ec1e0e973e90d5e95e7ad9fc871772265b1994050c2d59` (W04).

## 2. Fase PoW (W04)

| Parámetro | Valor dev | Motivo |
|---|---|---|
| Algoritmo | SHA3-256 (`Sha3Dev`) tras `AlgoritmoPow` | Decisión de Katana (2026-09-26); A-12 abierto |
| `T` | 2 s | Fase PoW de ~1 min |
| `N` (ventana LWMA) | 20 | Respuesta rápida en pruebas |
| `bits_iniciales` / máximo | `0x1e7fffff` (≈ 2^239) | ~2^17 intentos esperados por bloque al inicio |

## 3. Transición (símbolos de `CONTRATO-v0.md` §1)

| Símbolo | Valor dev | Motivo |
|---|---|---|
| `H_dep` | 1 | Depósitos desde el primer bloque |
| `M_cb` | 5 bloques PoW | Madurez corta; ≥ 1 exigido |
| `M_dep` | 3 bloques PoW | — |
| `H_corte_min` | 30 | Cumple `H_corte_min ≥ máx(H_dep, 1 + M_cb) + M_dep = 9` con margen para que 3 nodos minen y depositen |
| `W_min` | `30 · trabajo(máximo dev)` | No liga salvo colapso de la dificultad; símbolo presente y comprobado |
| `q` (requisito por bloque) | 10 ZZK | Constante (IPA C-02 abierto) |
| `S_min` | `K_min · q` = 30 ZZK | — |
| `K_min` | 3 | Una clave por nodo de la red de prueba; **no** prueba operadores distintos |
| `M_res_slots` | 20 | — |
| `M_dep_slots` | 10 | — |
| `M_rec_slots` | 30 | — |
| `R_slots` | 60 | Cumple `R_slots > Q_corr + T_reporte + M_estab` solo formalmente: `C-SLA` inactivo |
| `F_slots` | 600 | ~10 min con slots de 1 s |
| `subsidio_pow(h)` | 50 ZZK constante | Sin curva de emisión (A-02 abierto) |
| `subsidio_post(s)` | 5 ZZK constante | — |
| Semilla del corte | S1 `blake3(block_hash(T))` (D-P09) | Marcador; A-07 abierto |

## 4. Fase PoST

| Parámetro | Valor dev | Motivo |
|---|---|---|
| Duración nominal del slot `τ` | 1 s | — |
| `N_dev` (iteraciones AES por slot) | **por medir** en W05b2: el valor que dé ≈ 1 s por slot en la máquina de referencia, y un valor pequeño para tests | D-P10 |
| `D` (retardo de autoría) | 0 | D-P10 |
| `SR_dev` (rango de solución) | **por medir** en W07: el que dé ≈ 1 bloque por slot en la red de 3 nodos con los sectores dev | D-P11 (sin controlador) |
| GHOSTDAG `k` | 10 | Holgura para bloques paralelos en la red local |
| Máximo de padres | 15 (antiguo) | Formato de cabecera sin cambios |
| Historia plotable | 1 segmento del génesis (D-P12) | `history_size = 1` toda la red dev |
| Sector dev | `FarmerProtocolInfo` de fixture (W05b1) | — |
| Sectores (Filecoin) | `SEC-0` | Mecanismo no activo en 0.0.1 |
| `C-EVP` / `C-SLA` | inactivos | IPA C-04, C-05 |

## 5. Bloqueo de activación accidental

Todo valor de este perfil vive detrás de `Red::Dev` o de un tipo de perfil dev; la red dev no
comparte génesis, magia ni `CBID` con ninguna otra. El nodo (W06) debe **negarse a arrancar** con
este perfil si la red configurada no es `Red::Dev`.
