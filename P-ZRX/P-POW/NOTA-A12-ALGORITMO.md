# Nota A-12 — elección del algoritmo PoW de arranque

**Estado:** investigación de fuentes, **sin medición**. **Fecha:** 2026-09-26. **Firma:** Claude
(director, `AUTO-ZRX.md`). Alimenta `D-ZRX/IPA-ZRX.md` A-12, A-10, A-02. **No decide.**

## 1. Qué tiene que hacer el PoW en este diseño

Según `P-ZRX/P-TRANSICION/CONTRATO-v0.md` (D-T03, TRN-04), el trabajo PoW **no** da poder tras el
corte. Solo sirve para: (a) emitir sin premine; (b) ordenar la fase inicial por mayor trabajo; y
(c) poner un **umbral absoluto** `W_min` a quien quiera fabricar otro prefijo (otra distribución)
válido. Por tanto la propiedad que importa es el **coste absoluto de producir `W_min` de trabajo**
para un adversario con dinero, y cuánto de ese trabajo puede **alquilar o desviar** de otras redes,
no la «justicia» nominal del algoritmo. **[derivación]**

Observación clave **[derivación]**: en el arranque, el hash honesto de ZEROX es pequeño. Si el
algoritmo es el mismo que el de una red grande existente, el adversario puede desviar o alquilar
una fracción de esa red y rehacer el prefijo a bajo coste. El precedente documentado es Ethereum
Classic: ECIP-1049 (estado *Withdrawn*) cita ataques de doble gasto con hash «rented or came from
other chains» **[fuente]**.

## 2. Candidatos y hechos comprobados

| Candidato | Hechos comprobados | Indicios **sin verificar** | Coste de adopción en ZEROX |
|---|---|---|---|
| **SHA3-256** (heredado) | FIPS 202; verificador y preimagen en `archivo/crates/zx-core` (`preimage/block.rs`, `target.rs`); oráculo independiente NIST CAVP (`testdata/nist-cavp/`). ECIP-1049 lo proponía para ETC como algoritmo propio frente al hash mercenario **[fuente]** | Eficiente en GPU/FPGA; favorable a ASIC (documentos de la industria: blanco técnico de ePIC Blockchain para ETC); mercado de hash «Keccak» en NiceHash (existe la URL `nicehash.com/algorithm/keccak`, contenido no verificado) | Bajo: el verificador existe; hay que re-derivar preimagen y target (IPA A-11, A-13) |
| **RandomX** (Monero) | Optimizado para CPU de propósito general; modo rápido 2080 MiB, modo ligero 256 MiB «expected to be used only for proof verification»; cuatro auditorías 2019 (Trail of Bits, X41 D-SEC, Kudelski, QuarksLab) sin vulnerabilidades críticas; licencia BSD-3-Clause (repositorio `tevador/RandomX`, consultado 2026-09-26) **[fuente]** | Red de Monero muy grande con la misma primitiva ⇒ gran hash desviable; variantes con parámetros propios (p. ej. forks RandomL, RandomSFX) cambian el mercado, no el hardware; red de bots | Medio: dependencia C++ auditada; verificación con 256 MiB por nodo; nuevo verificador y vectores |
| **Memoria-dura GPU** (familia Ethash/KawPow) | ECIP-1049: «Ethash ASICs currently easily available on the market» **[fuente]** | Mercado de alquiler de GPU amplio | Alto y con el peor perfil de alquiler |

## 3. La bifurcación que tendrá que decidir Katana (cuando haya datos de A-10)

- **Accesibilidad doméstica** (favorece RandomX o similar: cualquier CPU mina) frente a
  **sencillez y verificabilidad** (favorece SHA3-256: primitiva estándar, verificador y vectores ya
  escritos, verificación barata), sabiendo que **ninguno** evita que un adversario con dinero
  compre o alquile el trabajo del prefijo: solo cambia el precio y quién puede competir.
- Un algoritmo **propio** (parámetros distintos de cualquier red grande) reduce el hash desviable
  de un día para otro, pero no la capacidad de un adversario que fabrique o alquile hardware.

**Qué falta antes de preguntar** (IPA A-10): hash honesto plausible al arranque, coste de alquiler
por algoritmo con fuente fechada, y coste absoluto de producir `W_min` para varios `W_min`.
Sin esos números, cualquier recomendación sería intuición.

## 4. Fuentes

- EIP/ECIP: ECIP-1049, https://ecips.ethereumclassic.org/ECIPs/ecip-1049 (consultada 2026-09-26).
- RandomX: https://github.com/tevador/RandomX (README; consultado 2026-09-26); OSTIF,
  https://ostif.org/four-audits-of-randomx-for-monero-and-arweave-have-been-completed-results/.
- FIPS 202 (SHA-3). Vectores CAVP en `archivo/testdata/nist-cavp/` (sha256 en
  `R-ZRX/MAPA-RESCATE.md`).
- Decred DCP-0012 (concentración del PoW), vía `R-ZRX/LEGADO/stake/MAPA.md` §1.4.
