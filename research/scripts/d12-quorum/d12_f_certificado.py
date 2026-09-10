#!/usr/bin/env python3
"""
d12_f_certificado.py — PUNTO F. El coste real del certificado de quorum de soluciones.

TODAS las cifras de tamano salen del codigo de Autonomys (`/home/katana/zeo/fuentes/subspace`
@ f8842d0), no de memoria:

  crates/subspace-core-primitives/src/solutions.rs:254-274   struct Solution
    public_key        PublicKey        32 B   (lib.rs:210  pub const SIZE: usize = 32)
    reward_address    RewardAddress    32 B   (AccountId32 en el runtime)
    sector_index      SectorIndex       2 B   (sectors.rs:25  pub type SectorIndex = u16)
    history_size      HistorySize       8 B   (segments.rs:274  NonZeroU64)
    piece_offset      PieceOffset       2 B   (pieces.rs:229  u16)
    record_commitment RecordCommitment 48 B   (pieces.rs:801  pub const SIZE: usize = 48)
    record_witness    RecordWitness    48 B   (pieces.rs:937  pub const SIZE: usize = 48)
    chunk             ScalarBytes      32 B   (lib.rs:258  pub const FULL_BYTES: usize = 32)
    chunk_witness     ChunkWitness     48 B   (solutions.rs:241 pub const SIZE: usize = 48)
    proof_of_space    PosProof        160 B   (pos.rs:103-105  K=20 -> SIZE = K*8)
                                     -----
                                      412 B

  Y el hecho que decide el punto: `verify_solution`
  (crates/subspace-verification/src/lib.rs:228-272) NO toma ninguna referencia al valor votado.
  El reto es `global_randomness.derive_global_challenge(slot)`, funcion del PoT y del SLOT.
  La atadura al bloque la hace una FIRMA APARTE (`check_reward_signature`, lib.rs:107-117;
  en ZEROX, `C-HDR-03/04` con Ed25519). Consecuencia: una solucion puede firmar cuantos
  valores quiera. Ver la seccion de equivocacion al final.

Comparacion contra `research/dag-poas-capa-finalidad.md` §4.B (F3: 724 B con BLS y K=4 000).
"""
import numpy as np

SEG_ANO = 365 * 24 * 3600

# --- tamanos, del codigo -----------------------------------------------------------------
SOL = {"public_key": 32, "reward_address": 32, "sector_index": 2, "history_size": 8,
       "piece_offset": 2, "record_commitment": 48, "record_witness": 48, "chunk": 32,
       "chunk_witness": 48, "proof_of_space": 160}
B_SOLUCION = sum(SOL.values())
B_SOLUCION_SIN_PREMIO = B_SOLUCION - SOL["reward_address"]
B_REF = 32          # hash del valor votado
B_SLOT = 8          # LE64(slot), R-FIN-14(b)
B_FIRMA_ED = 64     # Ed25519, C-HDR-04
B_FIRMA_BLS = 48    # BLS12-381 G1 comprimida
B_CLAVE_BLS = 48
B_CABECERA = 683    # dag-poas-ancla-de-orden.md §6: ~683 B con ~4 padres -> 21,5 GB/ano

COBERTURA = {}


def cuenta(r):
    COBERTURA[r] = COBERTURA.get(r, 0) + 1


def bytes_voto(agregado=False, con_premio=False):
    """Un voto autoportante de PoAS."""
    s = B_SOLUCION if con_premio else B_SOLUCION_SIN_PREMIO
    if agregado:
        cuenta("voto_bls")
        # con agregacion BLS: la firma desaparece del voto (una sola agregada por certificado)
        # pero la clave BLS del votante NO: no hay registro contra el que indexar un mapa de bits
        return s + B_REF + B_SLOT + B_CLAVE_BLS
    cuenta("voto_ed")
    return s + B_REF + B_SLOT + B_FIRMA_ED


def cert_v1(k):
    """Variante 1: el voto ES el bloque. Certificado autoportante = k cabeceras."""
    cuenta("cert_v1")
    return k * B_CABECERA


def cert_v2(k, agregado=False, con_premio=False):
    """Variante 2: voto aparte (la de HotPoW). Certificado = k votos (+ firma agregada)."""
    cuenta("cert_v2_bls" if agregado else "cert_v2_ed")
    base = 32 + k * bytes_voto(agregado, con_premio)   # 32 B: referencia comun
    return base + (B_FIRMA_BLS if agregado else 0)


if __name__ == "__main__":
    print("=" * 104)
    print("F.1 · Tamano de un voto de PoAS, del codigo de Autonomys @ f8842d0")
    print("=" * 104)
    for campo, b in SOL.items():
        print(f"      {campo:<20}{b:>5} B")
    print(f"      {'TOTAL Solution':<20}{B_SOLUCION:>5} B     (sin reward_address: {B_SOLUCION_SIN_PREMIO} B)")
    print(f"\n      voto autoportante Ed25519 = solucion + ref(32) + slot(8) + firma(64) = "
          f"{bytes_voto(False, False)} B")
    print(f"      voto autoportante BLS agr. = solucion + ref(32) + slot(8) + clave BLS(48) = "
          f"{bytes_voto(True, False)} B")
    print("\n      CONTRASTE con HotPoW: alli un voto son 72 B (hotpow.txt:1049-1052: '256 bits para")
    print("      la referencia y la clave publica, y 64 bits para la solucion'). Una solucion de")
    print(f"      PoW son 8 B; una de ESPACIO son {B_SOLUCION_SIN_PREMIO} B. Factor {B_SOLUCION_SIN_PREMIO/8:.0f}x en la parte que manda.")

    print("\n" + "=" * 104)
    print("F.2 · Certificado y coste anual, a las cadencias razonables")
    print("=" * 104)
    print(f"\n{'variante':>34}{'k':>6}{'certificado':>14}" +
          "".join(f"{('cada ' + str(c) + ' s'):>16}" for c in (30, 64, 300, 3600)))
    filas = []
    for k in (16, 32, 64, 128, 256):
        for nombre, f in (("1 · voto = bloque (k cabeceras)", lambda k: cert_v1(k)),
                          ("2 · voto aparte, Ed25519", lambda k: cert_v2(k, False)),
                          ("2 · voto aparte, BLS agregada", lambda k: cert_v2(k, True))):
            b = f(k)
            anual = [b * SEG_ANO / c / 1e9 for c in (30, 64, 300, 3600)]
            filas.append((nombre, k, b, anual))
            print(f"{nombre:>34}{k:>6}{b:>12,} B".replace(",", " ") +
                  "".join(f"{x:>14.3f} GB" for x in anual))
    print(f"\n      Referencias: cabeceras del diseno 21,50 GB/ano; PoT 4,0 GB/ano;")
    print(f"      capa estilo Filecoin (dag-poas-capa-finalidad.md §4.B): 724 B cada 30 s = 0,76 GB/ano.")

    print("\n" + "=" * 104)
    print("F.3 · Lo que compra la agregacion BLS aqui, frente a lo que compra en F3")
    print("=" * 104)
    print(f"\n{'k':>6}{'Ed25519':>14}{'BLS agregada':>16}{'ahorro':>10}   |  F3 (K=4000): 237 728 B -> 724 B = 99,70 %")
    for k in (16, 32, 64, 128, 256, 1000, 4000):
        a = cert_v2(k, False)
        b = cert_v2(k, True)
        print(f"{k:>6}{a:>12,} B{b:>14,} B{(1 - b / a) * 100:>9.2f}%".replace(",", " "))
    print("\n      La agregacion solo comprime la FIRMA. En F3 el voto ES una firma, luego comprime")
    print("      el 99,7 %. Aqui el voto esta dominado por la prueba de espacio, que no se agrega:")
    print(f"      el ahorro es del orden del {100*(1-cert_v2(64,True)/cert_v2(64,False)):.0f} %. **La ventaja criptografica del gadget se cae:**")
    print("      ni evita BLS (ver F.5) ni lo aprovecha.")

    print("\n" + "=" * 104)
    print("F.4 · Trafico de gossip de la variante 2 (lambda_voto = k * lambda_bloque)")
    print("=" * 104)
    print(f"\n{'k':>6}{'votos/s':>10}{'kB/s':>10}{'TB/ano':>10}   (lambda_bloque = 1/s)")
    for k in (16, 32, 64, 128, 256):
        v = k * 1.0
        kbs = v * bytes_voto(False, False) / 1000
        print(f"{k:>6}{v:>10.0f}{kbs:>10.1f}{kbs * SEG_ANO / 1e9:>10.2f}")
    print("\n      Para comparar: la cadena entera son 21,5 GB/ano de cabeceras (0,0215 TB).")

    print("\n" + "=" * 104)
    print("F.5 · ¿Obliga a BLS12-381? — LA RESPUESTA ESTA EN EL CODIGO QUE YA ADOPTAMOS")
    print("=" * 104)
    print("""
      `verify_solution` (subspace-verification/src/lib.rs:264-272) llama a `kzg.verify(...)`
      para comprobar que el `chunk` pertenece al `record_commitment`. Ese KZG es
      `rust-kzg-blst` (Cargo.toml:113,180 y shared/subspace-kzg/Cargo.toml:24-27), es decir
      **`blst` de Supranational, C y ensamblador, sobre BLS12-381**, en la ruta de consenso de
      TODOS los nodos y para TODOS los bloques.

      R-FIN-14(c) del diseno vivo cita literalmente `subspace-verification/src/lib.rs:234-260`,
      que es esa misma funcion.

      Consecuencia para la comparacion: el 'coste' que `dag-poas-capa-finalidad.md` §5 presenta
      como bifurcacion de Katana —meter BLS12-381 y `blst` en la ruta de consenso— **ya esta
      pagado** si ZEROX adopta el PoAS de Autonomys con testigos KZG. No es una dependencia
      nueva de la capa de finalidad: es una dependencia del propio consenso.
      """)

    print("=" * 104)
    print("F.6 · CPU de verificacion por nodo")
    print("=" * 104)
    print("""
      Verificar UN voto = verificar UNA solucion = 1 prueba de espacio (tabla k=20) +
      1 apertura KZG (un emparejamiento sobre BLS12-381) + 1 firma. El coste lo domina el KZG.
      Medido en esta maquina con el propio banco de Autonomys (`cargo bench -p subspace-kzg`,
      funcion `verify`): ver `salida_bench_kzg.txt`.
      """)
    try:
        txt = open("research/scripts/d12-quorum/salida_bench_kzg.txt").read()
        import re
        m = re.findall(r"time:\s*\[([\d.]+)\s*(\w+)\s+([\d.]+)\s*(\w+)\s+([\d.]+)\s*(\w+)\]", txt)
        if m:
            lo, ul, med, um, hi, uh = m[-1]
            fac = {"ns": 1e-9, "µs": 1e-6, "us": 1e-6, "ms": 1e-3, "s": 1.0}
            t = float(med) * fac.get(um, 1e-3)
            print(f"      MEDIDO: kzg.verify = {med} {um}  (IC de Criterion: {lo} {ul} .. {hi} {uh})")
            print(f"\n      {'k':>6}{'ms por certificado':>22}{'% de un nucleo (cert/64 s)':>30}"
                  f"{'% de un nucleo (variante 2)':>30}")
            for k in (16, 32, 64, 128, 256):
                ms = k * t * 1000
                print(f"      {k:>6}{ms:>22.2f}{100 * (k * t) / 64:>30.4f}{100 * (k * t) / 1.0:>30.2f}")
            print("\n      (variante 2 = lambda_voto = k/s: hay que verificar k soluciones POR SEGUNDO,")
            print("       encima del 9,6 % de nucleo que ya cuesta el PoT a tau = 1 s.)")
        else:
            print("      LAGUNA: el banco aun no ha terminado; reejecutar este script al terminar.")
    except FileNotFoundError:
        print("      LAGUNA: falta salida_bench_kzg.txt")

    print("\n" + "=" * 104)
    print("F.7 · EQUIVOCACION GRATIS — lo que rompe la Definicion 1 del paper")
    print("=" * 104)
    print("""
      Definicion 1 de HotPoW (hotpow.txt:279-283): «cada evento asigna una capacidad de voto
      (ATV) a un agente. Cada ATV puede usarla el agente al que se le asigno para votar UNA VEZ
      por UN valor.» Toda la teoria de POA descansa en eso: dos quorums en conflicto exigen 2k
      ATVs. En HotPoW se cumple por construccion, porque el voto ES la solucion y la solucion
      contiene la referencia: `Hpow(r, p, s) <= tv` (hotpow.txt:437-441). Cambiar r obliga a
      resolver otro puzzle.

      En PoAS NO se cumple. `verify_solution` no ve r (lib.rs:228-272): el reto es
      `derive_global_challenge(slot)`, funcion del PoT y del slot. La atadura al valor la pone
      una firma aparte, y una clave firma cuantos mensajes quiera. Luego **una sola solucion
      puede votar por todos los valores en conflicto a la vez, a coste cero.**

      Consecuencia cuantitativa: dos quorums en conflicto ya no exigen 2k ATVs sino k, y
      POA pasa de P[Poisson(k) >= 2k] a P[Poisson(k) >= k]:
      """)
    from mpmath import mp, mpf, gammainc
    mp.dps = 60
    print(f"      {'k':>6}{'POA con Def.1 (2k)':>24}{'POA con equivocacion (k)':>28}")
    for k in (16, 32, 64, 128, 256):
        a = float(gammainc(2 * k, 0, mpf(k), regularized=True))
        b = float(gammainc(k, 0, mpf(k), regularized=True))
        print(f"      {k:>6}{a:>24.3e}{b:>28.4f}")
    print("""
      -> Sin regla anti-equivocacion el gadget NO tiene seguridad ninguna: la ambiguedad es
         ~0,5 para cualquier k. Y una regla anti-equivocacion exige castigo, o sea R-FIN-19 de
         la propuesta rival, o sea DINERO EN JUEGO. La ventaja anunciada 'sin dinero en juego'
         desaparece. La alternativa —que el voto sea un BLOQUE, donde U2/U3'' (R-FIN-11) ya da
         un voto por identidad de billete— es la variante 1, que es profundidad de confirmacion.
      """)
    print("COBERTURA DE RAMA")
    for k_, v in sorted(COBERTURA.items()):
        print(f"  {k_:<20}{v}")
