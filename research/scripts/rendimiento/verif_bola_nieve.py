#!/usr/bin/env python3
"""
verif_bola_nieve.py — el lazo de realimentacion entre Mlt y la tarifa, y como romperlo.

Mecanismo (SPEC C-WGT-04/05 y §5.5):
  - Mlt sube como mucho 1,7x cuando la mitad de la ventana son bloques a 1,7*Mlt
  - la tarifa minima va como base*REF_WEIGHT/Mf^2, y hoy Mf = Mlt
  => cada ronda: los bytes a llenar suben 1,7x pero el precio por byte baja 1,7^2
     coste de la ronda k = C0 * 1,7^-k  -> serie GEOMETRICA CONVERGENTE
  Si en cambio Mf NO sigue a Mlt (ventana separada para la tarifa):
     coste de la ronda k = C0 * 1,7^+k  -> serie que EXPLOTA
Saturacion: la tarifa toca su suelo de 1 brek/peso cuando Mf > sqrt(base*REF_WEIGHT).
"""
BREK=10**8; ZL=100_000; TX_B=350
BASE=(10**9*BREK)>>26; RW=384_000
SUB=1.7; INF=10/17
def tarifa(mf):
    F=BASE*RW//int(mf)//int(mf); return max(1,F-F//20)
SAT=(BASE*RW)**0.5
print(f"La tarifa satura en 1 brek/peso cuando Mf > sqrt(base x REF_WEIGHT) = {SAT/1e6:.1f} MB")
rondas_sat=0; m=ZL
while m<SAT: m*=SUB; rondas_sat+=1
print(f"Desde la zona libre hasta ahi: {rondas_sat} rondas de 1,7x\n")

def ataque(dias_ventana, tarifa_sigue_mlt):
    mitad=dias_ventana*86400/2
    mlt=ZL; total=0; hist=[]
    for k in range(rondas_sat):
        mf = mlt if tarifa_sigue_mlt else ZL          # <- la unica diferencia
        coste = mitad*int(SUB*mlt)*tarifa(mf)/BREK
        total += coste; hist.append(coste)
        mlt *= SUB
    return total, mlt, hist, mitad*rondas_sat/86400

print("=== A) HOY: la tarifa sigue a Mlt (Mf = Mlt). La bola de nieve ===")
print(f"{'ventana':>10}{'ronda 1':>16}{'TOTAL hasta saturar':>22}{'% suministro':>14}{'tiempo':>12}")
for nombre,d in (("12 h",0.5),("1 dia",1),("7 dias",7),("30 dias",30),("180 dias",180),("1 ano",365)):
    tot,mlt,h,t=ataque(d,True)
    tt = f"{t:.1f} dias" if t<400 else f"{t/365:.1f} anos"
    print(f"{nombre:>10}{h[0]/1e6:>13,.1f} M{tot/1e6:>19,.1f} M{tot/1e9*100:>13,.0f}%{tt:>12}".replace(",", " "))
print(f"\n  La serie CONVERGE: el total es solo {sum(SUB**-k for k in range(rondas_sat)):.2f}x la primera ronda.")
print(f"  Llegar a saturar la tarifa deja Mlt en {ZL*SUB**rondas_sat/1e6:.1f} MB por bloque =")
print(f"  {ZL*SUB**rondas_sat/TX_B:,.0f} tx/s libres y {ZL*SUB**rondas_sat*31_536_000/1e12:,.0f} TB/ano de cadena.".replace(",", " "))

print("\n=== B) ARREGLO: anclar la tarifa a una ventana LARGA aparte (Mf != Mlt) ===")
print(f"{'ventana de Mlt':>16}{'ronda 1':>16}{'TOTAL hasta saturar':>22}{'% suministro':>14}")
for nombre,d in (("12 h",0.5),("1 dia",1),("7 dias",7),("30 dias",30)):
    tot,mlt,h,t=ataque(d,False)
    print(f"{nombre:>16}{h[0]/1e6:>13,.1f} M{tot/1e6:>19,.0f} M{tot/1e9*100:>13,.0f}%".replace(",", " "))
print(f"\n  Ahora la serie EXPLOTA: el total es {sum(SUB**k for k in range(rondas_sat)):.0f}x la primera ronda.")

print("\n=== C) Y lo que NADIE mira: cuanto tarda en volver a la normalidad ===")
print(f"  Mlt baja a 0,588x por media ventana (C-WGT-04). Desde {ZL*SUB**rondas_sat/1e6:.1f} MB hasta la zona libre:")
for nombre,d in (("12 h",0.5),("1 dia",1),("30 dias",30),("180 dias",180),("1 ano",365)):
    r=0; m=ZL*SUB**rondas_sat
    while m>ZL: m*=INF; r+=1
    t=r*d/2
    print(f"    ventana {nombre:>9}: {r} rondas x media ventana = {t:.1f} dias" + ("" if t<365 else f" = {t/365:.1f} anos"))
