# ─────────────────────────────────────────────────────────────────────────────
# coste.jl — defecto 5: ¿es expresable la cadena larga en la primitiva auditada?
#             y coste por nodo separado por tipo de recurso (encargo §4).
# ─────────────────────────────────────────────────────────────────────────────

"""
Hechos de la primitiva auditada `crates/zx-pot` (leída, no modificada):

- `pub fn prove(seed: PotSeed, iterations: NonZeroU32) -> Result<PotCheckpoints, PotError>`
- `pub fn verify(seed: PotSeed, iterations: NonZeroU32, checkpoints: &PotCheckpoints) -> Result<bool, PotError>`
- `PotSeed`/`PotOutput` = 16 B; `PotCheckpoints` = 8 × 16 B = 128 B, salida = el 8.º.
- La clave AES del tramo es `blake3(seed)[0..16)`, **derivada del argumento `seed` en
  cada llamada** (`tipos.rs`: `PotSeed::key`). `prove`/`verify` no aceptan clave.
- `prove` exige `N % 16 == 0` (8 checkpoints, `m = N/8` par).
- 32 vectores diferenciales del upstream `subspace-proof-of-time @ f8842d0` (0BSD).
- `aes::create` / `aes::verify_sequential` **sí** reciben clave explícita, pero son
  `pub(crate)` en un módulo privado.
"""
struct HechosPrimitiva
    iteraciones_max::UInt64      # u32::MAX
    bytes_checkpoint::Int        # 16
    n_checkpoints::Int           # 8
    bytes_bundle::Int            # 128
    vectores::Int                # 32
    clave_derivada_del_argumento::Bool
    clave_explicita_expuesta::Bool
end

const PRIMITIVA = HechosPrimitiva(UInt64(U32_MAX), 16, 8, 128, 32, true, false)

"""
Veredicto de segmentación de la cadena de revelación `T = Lrev·N(slot)`.

- `una_llamada`: `T ≤ u32::MAX` y `T % 16 == 0` ⇒ la primitiva **sí** expresa la
  cadena de clave única en una llamada.
- `segmentar_por_slots`: `false`. Encadenar `prove(salida_k, m)` **no** reproduce
  `AES128_chain^{Σm}(semilla)`: cada llamada redefine `K = blake3(argumento)[0..16)`,
  así que la concatenación es **otra clave y otra cadena**. Es exactamente lo que el
  encargo prohíbe hacer pasar por una medición.
- `via_correcta`: una API de segmentos de clave fija, enlaces de estado y vectores
  de equivalencia; exponer `aes::create`/`aes::verify_sequential` solo no basta,
  porque sus contadores por tramo también son `u32`. Coste `Pendiente`.
"""
function segmentacion_zxpot(Lrev::Real, N_slot::Real)
    T = Lrev * N_slot
    una = (T <= U32_MAX) && (T % 16 == 0)
    return (T = T,
            Lrev = Lrev,
            N_slot = N_slot,
            una_llamada = una,
            Lrev_max_una_llamada = Lrev_max_una_llamada(N_slot),
            factor_exceso_u32 = T / U32_MAX,
            segmentar_por_slots = false,
            reimplementa_aes = false,
            via_correcta = "API segmentada de clave fija + enlaces/checkpoints + equivalencia",
            estado = una ? :expresable : :pendiente)
end

"""
Tabla de coste por nodo, **separando recursos** (encargo §4):

- `lineas_timekeeper = ⌈L/I⌉ + 1`: líneas AES **secuenciales simultáneas** del productor.
  Medido: 25 líneas en un 9950X3D cuestan 1,7 % de degradación (1,509 s/slot);
  32 líneas, 9,4 %; 48, 43,3 %.
- `nucleos_verificador = verify·(1 + Lrev/I)`: fracción de núcleo de un nodo que
  verifica (con `verify = 96,1 ms/slot` medido).
- `prove_s_epoca`, `verify_s_epoca`: segundos por época.
- `lineas_capacidad = ⌈Lrev/I⌉`: capacidad para una semilla por
  época; incluye su latencia individual y excluye el PoT principal.
- `recuperacion_s`: ponerse al día verificando `F_slots` slots de un flujo rival.
"""
function tabla_coste(L::Real, Lrev::Real, I::Real, F_slots::Real;
                     c_v::Real = VERIFY_S_POR_SLOT, c_p::Real = PROVE_S_POR_SLOT)
    return (lineas_timekeeper = lineas_timekeeper(L, I),
            nucleos_cadena_principal = c_p,
            nucleos_verificador = c_v * (1 + Lrev / I),
            prove_s_epoca = c_p * (L + Lrev),
            verify_s_epoca = c_v * (L + Lrev),
            instantes_por_hora = instantes_por_hora(I),
            lineas_capacidad = lineas_revelacion_por_epoca(Lrev, I),
            recuperacion_s_1_nucleo = F_slots * c_v,
            recuperacion_s_16_nucleos = F_slots * c_v / 16)
end
