# El reloj de PoT: ¿un ASIC 19× de AES? ¿ChaCha en vez de AES? — con fuente

**2026-09-08, noche.** Dos preguntas de Katana al elegir `ρ_max` (R-FIN-14 (f)): si un atacante sofisticado
puede construir un reloj AES 19× más rápido que el timekeeper, y si sustituir AES por (X)ChaCha20(-Poly1305)
mejoraría algo. Respuesta corta: **no y no.** Lo que sigue es el porqué, con las fuentes leídas hoy.

## 1 · Qué es una iteración del PoT, en el código

`subspace-proof-of-time` (`/home/katana/zeo/fuentes/subspace @ f8842d0`):

- `src/lib.rs:29-45`: `prove(seed, iterations)` → `aes::create(seed, seed.key(), iterations/8)`. La **clave es la
  semilla** y es pública.
- `src/aes.rs:36-49` (genérico): `cur_block = AES128_key(cur_block)` repetido `iterations` veces; cada 1/8 se guarda un
  checkpoint.
- `src/aes/x86_64.rs:22-33` (acelerado): cada iteración son **9 `_mm_aesenc_si128` + 1 `_mm_aesenclast_si128`,
  encadenados sobre el mismo registro**. Diez instrucciones dependientes; no hay nada que paralelizar dentro de una
  iteración.

Luego el tiempo por slot es exactamente `iteraciones × 10 × latencia(AESENC) / f_reloj`.

## 2 · La calibración de Autonomys es la latencia de la instrucción, no un número mágico

| Microarquitectura | Latencia `AESENC` (ciclos) | Fuente |
|---|---:|---|
| Alder Lake-P / Raptor Cove, Ice Lake, Zen 5 | 3 | uops.info, `AESENC_XMM_XMM` |
| Zen 4, Skylake | 4 | uops.info, `AESENC_XMM_XMM` |

Comprobación: `10 × 3 ciclos / 6,2 GHz = 4,84 ns` por iteración; `206 557 520 × 4,84 ns = 1,00 s`. Es literalmente el
*«About 1s on 6.2 GHz Raptor Lake CPU (14900KS)»* de `subspace-node/src/chain_spec.rs:128-130`. **El timekeeper de
Autonomys corre a la latencia de una unidad de hardware de AES a la frecuencia más alta que se vende.**

Residuo: el 9950X3D medido (`prove` 1,561 s a 200 032 000 it.) da 7,8 ns por iteración, ~40 ciclos a 5,2 GHz, más que
los 30 que darían 3 ciclos. Sin explicar (frecuencia real bajo carga, o latencia distinta a la tabulada). No cambia
la conclusión.

## 3 · ¿Un ASIC 19×? — no es cuestión de presupuesto, es de física

- Un 19× exige `4,84 ns / 19 = 255 ps` por iteración: **25 ps por ronda de AES**. Una ronda de AES es SubBytes
  (inversión en GF(2⁸), decenas de niveles lógicos), ShiftRows, MixColumns y AddRoundKey. Un solo nivel de puerta en
  los procesos punteros está en el orden de la decena de picosegundos. ESTIMACIÓN del principal, sin paper: el techo
  realista de un ASIC de latencia frente a un 14900KS es **~1,5-2,5×**, y viene de quitar la sobrecarga de pipeline y
  optimizar la S-box, no de un salto de escala.
- Lo mismo, dicho por quien lo estudió: Autonomys, página oficial de Proof-of-Time
  (`academy.autonomys.xyz/autonomys-network/consensus/proof-of-time`, leída 2026-09-08): *«AES fulfills our requirements
  of being iterative and non-parallelizable, and producing a short, random, verifiable output»*; *«Based on a
  Supranational study, we do not expect a significant speedup over the best AES implementation, even with an
  ASIC»*; y la contramedida estructural: la ventaja de un timekeeper más rápido *«is reset»* en cada inyección de
  entropía (~5 min). El estudio de Supranational en sí **no se ha leído** (no localizado): LAGUNA menor.
- El precedente de Chia (`proof-of-space-tiempo.md` §4): 3,1-3,8× con un ASIC **de grupos de clase**, una operación
  que ninguna CPU acelera. Con AES la CPU **ya es** el ASIC. Ese es el argumento entero.
- Un Estado no cambia la física de la S-box. Lo que un Estado sí tiene y otros no, en este diseño: **red** (subir
  `Δ_ef`: a 20 s la frontera cae a 32,4 %, 9a) y **eclipse** (no modelado, LAGUNA). Esas son sus palancas, no el reloj.

Efecto sobre R-FIN-14 si aun así el reloj fuera más rápido: el steering crece como `√(ρ/ρ_max)` (5,1 % a `ρ = 3` con
`ρ_max = 1,5`; 4,1 % a `ρ = 3,85` con `ρ_max = 3`); P4 solo se anula a `ρ ≥ I/W_dec` (13 con `I = 600 s`, 19 con
`I = 851 s`); la frontera de flujo único no depende de `ρ` (solo se modeló el steering: LAGUNA para ráfagas).

**Lo que sí es real y no se arregla con `ρ_max`:** issue `autonomys/subspace#2141` (2023-10-20, *«A faster timekeeper
will outrun its competitors»*, **cerrada como *not planned***): un timekeeper más lento ve sus mensajes rechazados por
viejos, cada generación de hardware deja obsoletos a los demás, y *«We are not aware of a mechanism how this could be
mitigated»*. Es un problema de **centralización y vivacidad**, no de seguridad del ancla; entra en B7
(`timelord-redundancia-informe.md`), donde C-TIMELORD-03 ya pide redundancia operativa.

## 4 · ¿ChaCha20 / XChaCha20-Poly1305 en vez de AES?

Las dos fuentes que aportó Katana, leídas:

- `blog.vitalvas.com/post/2025/06/01/xchacha20-poly1305-vs-aes/`: compara **AEAD** (cifrado autenticado). Ventajas
  de XChaCha20-Poly1305: nonce de 24 bytes frente a 12 (*«After ~2^32 messages, collision probability becomes
  significant»* para AES-GCM), *«designed to be constant-time by default, while AES implementations vary in their
  side-channel resistance»*, clave de 256 bits. Rendimiento: AES-GCM ~6,4 GB/s **con AES-NI** frente a ~1,8 GB/s en
  software; XChaCha ~4,2 GB/s sin hardware. **No declara a ninguno «más seguro» en general** ni dice que AES-128 esté
  roto.
- `blog.dun.im/…/chacha20-poly1305-vs-aes-gcm…` (403 al descargar; resumen por búsqueda): ChaCha20-Poly1305 gana
  **en CPU sin aceleración de AES** (móviles, routers) y en software endurecido contra canales laterales; AES-GCM gana
  donde hay AES-NI.

Por qué nada de eso aplica al PoT:

1. **El PoT no cifra secretos.** La clave es la semilla y es pública; no hay nonce, no hay mensaje, no hay tag de
   autenticación. Las tres ventajas de ChaCha (nonce largo, constant-time, 256 bits) protegen cosas que aquí no
   existen. Poly1305 es un MAC: sobra entero. XChaCha es una extensión de nonce: sobra entera.
2. **Lo que el PoT necesita es lo contrario de lo que ChaCha ofrece.** Necesita una función iterativa sin atajo
   algebraico y con el **menor hueco posible entre la CPU de cualquiera y el mejor hardware imaginable**. AES tiene
   instrucción dedicada en x86 y ARM; ChaCha no la tiene en ninguna CPU de consumo. Con ChaCha el timekeeper honesto
   correría en software (una ronda ARX es una cadena dependiente de sumas, rotaciones y xor) y un ASIC de sumadores
   rápidos le sacaría una ventaja **mayor** que a AES. ESTIMACIÓN, sin medir: varias veces. Es exactamente el hueco que
   queremos cerrar, abierto a propósito.
3. **La fortaleza criptográfica no es el criterio.** Ni AES-128 ni ChaCha20 tienen ataques prácticos; para el PoT la
   hipótesis relevante es «no existe atajo para `f^N`», y está igual de estudiada (o de poco estudiada) en las dos.

**Conclusión:** se mantiene AES-128 tal como lo usa Autonomys. Cambiar la primitiva del reloj no compraría seguridad y
sí abriría el hueco CPU↔ASIC. Y cumple la regla 5 de `CLAUDE.md`: cripto auditada sin modificar.

## 5 · Lo que queda abierto

- Localizar y leer el estudio de Supranational citado por Autonomys (cota numérica del ASIC de AES). LAGUNA menor.
- El residuo del 9950X3D (40 ciclos por iteración en vez de 30).
- `ρ_max` sigue siendo decisión de Katana: 3× sin segundo VDF, o revelación retardada (R-FIN-14 (h)), que además es la
  palanca más fuerte para acortar `F` (`n_eval = 0 ⇒ F = F_carrera`).

Fuentes web consultadas el 2026-09-08: [Proof-of-Time, Autonomys Academy](https://academy.autonomys.xyz/autonomys-network/consensus/proof-of-time) ·
[issue #2141](https://github.com/autonomys/subspace/issues/2141) · [uops.info AESENC](https://uops.info/html-instr/AESENC_XMM_XMM.html) ·
[vitalvas, XChaCha20-Poly1305 vs AES](https://blog.vitalvas.com/post/2025/06/01/xchacha20-poly1305-vs-aes/).
