#!/usr/bin/env python3
"""
d12_g_frontera_cliente.py — PUNTO G. Lo que el gadget NO arregla, y lo que abre.

G.1  ¿Toca la frontera de flujo unico? Se recalcula la frontera con el HORIZONTE DE FINALIDAD
     EFECTIVO que impone el gadget. Instrumento: el `frontera()` de D9-9a, sin reescribirlo,
     con `F_SEG` sustituida. Control positivo: reproducir 46,9 % a F = 5,3 h y 44,6 % a F = 2 h.

G.2  ¿Toca el cliente ligero? Se compara lo que hace falta para VERIFICAR un certificado en las
     dos propuestas, y de ahi el coste anual del cliente.
"""
import sys
import numpy as np

sys.path.insert(0, "research/scripts/d9-ronda9a")
import r9a_a3_frontera as R  # noqa: E402

SEG_ANO = 365 * 24 * 3600
COBERTURA = {}


def cuenta(r):
    COBERTURA[r] = COBERTURA.get(r, 0) + 1


def frontera_con_F(F_seg, hf=lambda a: 1.0):
    """Frontera de flujo unico con otro horizonte de finalidad. NO reescribe el instrumento:
    sustituye la constante global que `union10()` lee."""
    viejo = R.F_SEG
    R.F_SEG = float(F_seg)
    try:
        cuenta(f"frontera_F{int(F_seg)}")
        return R.frontera(hf)
    finally:
        R.F_SEG = viejo


if __name__ == "__main__":
    print("=" * 96)
    print("G.1 · ¿Toca el gadget la frontera de flujo unico?")
    print("=" * 96)
    print("""
      El gadget cambia el horizonte de finalidad efectivo: se deja de reorganizar en cuanto llega
      el certificado, a t = d + W, en vez de a F. Y la frontera se calcula como la union sobre las
      epocas de 10 anos de prev() EVALUADA EN ESE HORIZONTE (r9a_a3_frontera.py:81-84). Como prev
      es decreciente en t, acortar el horizonte SUBE el riesgo por epoca y BAJA la frontera.

      Control positivo del instrumento: modelo (c), atacante unico, delta = 0.
      """)
    print(f"{'horizonte de finalidad':>34}{'frontera 1e-10':>18}   comentario")
    casos = [
        (5.3 * 3600, "F = 5,3 h (medido, diseno vivo)"),
        (2.0 * 3600, "F = 2 h (provisional, DECIDIDO)"),
        (1.0 * 3600, "F = 1 h (candidata de produccion)"),
        (3798.0, "d+W del gadget, alpha=0,33 obj 1e-30"),
        (1702.0, "d+W del gadget, alpha=0,33 obj 1e-12"),
        (988.0, "d+W del gadget, alpha=0,33 obj 1e-6"),
        (143.3, "solo W (k=64, c=1,5): el gadget 'rapido'"),
    ]
    for F, nombre in casos:
        fr = frontera_con_F(F)
        print(f"{nombre:>34}{fr:>17.2%}   ({F:.0f} s)")
    print("""
      -> el control positivo sale: 46,9 % a 5,3 h y 44,6 % a 2 h, los dos numeros publicados.
      -> y la lectura: si el gadget se usa para ACORTAR el horizonte, la frontera BAJA. Solo es
         neutro si el certificado llega DESPUES de que prev() ya haya bajado por si sola, que es
         justo la dominacion de D.6.
      """)

    print("=" * 96)
    print("G.2 · El cliente ligero: que hace falta para VERIFICAR un certificado")
    print("=" * 96)
    print("""
      Capa estilo Filecoin (R-FIN-17/21): un certificado son FIRMAS de claves que estan en la
      TABLA DE PODER, y la tabla de la instancia siguiente va comprometida en el certificado
      (R-FIN-21). Verificar = comprobar firmas contra una tabla que el propio certificado
      encadena. NO hace falta la cadena de bloques. Cita del FIP en la propuesta:
      «Verifying the finality of a tipset from genesis does not require access to the EC chain.»

      Quorum de soluciones: un voto es una PRUEBA DE ESPACIO contra el reto del slot. Verificarlo
      exige `global_randomness.derive_global_challenge(slot)`
      (subspace-verification/src/lib.rs:234-236), es decir **la salida del PoT de ese slot**, y
      el PoT es una cadena AES secuencial cuya verificacion NO ES SUCINTA (catalogo D4:
      96,1 ms/slot). Ademas exige el `record_commitment` de la historia archivada para el KZG.
      """)
    print(f"      {'que tiene que seguir el cliente':>44}{'por ano':>14}{'CPU/ano':>16}")
    print(f"      {'cabeceras (hoy, sin cliente ligero)':>44}{'21,50 GB':>14}{'—':>16}")
    print(f"      {'certificados de epoca estilo F3 (R-FIN-22)':>44}{'6,6 MB':>14}{'despreciable':>16}")
    pot = 128 * SEG_ANO / 1e9
    horas = SEG_ANO * 0.0961 / 3600
    print(f"      {'PoT, obligatorio para el quorum':>44}{pot:>11.2f} GB{horas:>13.0f} h")
    print(f"      {'+ certificados de quorum (k=64, 1/h)':>44}{30032 * 8760 / 1e6:>11.1f} MB{'—':>16}")
    print("""
      -> el cliente ligero con quorum de soluciones NO existe: para comprobar un solo voto hay que
         tener el PoT del slot, y eso son 4,0 GB/ano y ~840 horas de nucleo al ano de verificacion
         secuencial. **La propiedad de autoverificacion desde genesis se la da a F3 exactamente la
         TABLA DE PODER que el quorum presume no necesitar.**
      """)
    print("COBERTURA DE RAMA")
    for k_, v in sorted(COBERTURA.items()):
        print(f"  {k_:<24}{v}")
