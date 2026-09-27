# Plan de 0.0.2 — mecanismos de Filecoin (registro de sectores, PoRep, auditorías)

**Decisión de Katana (2026-09-27):** la versión **0.0.2** añade los mecanismos de Filecoin que 0.0.1 dejó fuera
(`SEC-0`). **Firma del plan:** Claude (director). **Estado:** esbozo; se desarrolla al cerrar 0.0.1.

## Por qué no entraron en 0.0.1

Con el formato PoAS actual, las auditorías solo **encarecen** al sembrador (RFT-04; D-02: regenerar en vez de guardar
cuesta ≈ 7 GTX 1070 y 677 W por TiB) y ningún sellado distingue ramas (RFT-06): no resuelven el doble farmeo en rama
privada. Son un programa de semanas (formato, auditorías, ciclo de vida en el DAG, oráculo, Rust).

## Alcance (programa `P-ZRX/P-REGISTRO-SECTORES/`, IPA D-01…D-05)

| Paso | Contenido | Estado al cerrar 0.0.1 |
|---|---|---|
| D-01 | Compromiso y alta de un sector (encargo 01) | G1 superada (S01) |
| D-02 | Auditorías, regeneración y fallos honestos (encargo 02): plazos, falsos positivos (S02b) | primera parte hecha: encarecen, no impiden |
| D-03 | Ciclo de vida del sector en el DAG y vínculo con la garantía (encargo 03) | sin empezar |
| D-04 | Formato alternativo / PoRep (encargo 04), empezando por la revisión de fuentes primarias de Filecoin | sin empezar |
| D-05 | Sistema completo: precompromiso + PoRep + auditorías (encargo 05) | sin empezar |

**Primer paso:** reescribir los encargos 01–05 en la plantilla de órdenes de `AUTO-ZRX.md` §6 (IPA E-09), sin tocar los
originales de Katana.

## Lo que 0.0.2 desbloquea

- El **peso definitivo** de la capa de votos (FV-D01: sectores registrados con garantía): sustituye a la fuente
  provisional de dev (FV-D08) y **se elimina** la de garantía.
- La **garantía por unidad de espacio** en vez de por clave (RFT-23, IPA C-02).
- Auditorías que encarecen al sembrador, con tasa de falsos positivos medida antes de castigar nada (el mandato exige
  distinguir fallo demostrado de disco, red o censura).

## Límites que ya se saben (no reabrir sin evidencia nueva)

RFT-03 (un compromiso no fecha nada), RFT-04 (sobre el formato actual, auditar no distingue guardado de regenerado),
RFT-06 (ningún sellado separa ramas), RFT-14 (ningún mecanismo de Filecoin encarece de forma exigible el doble farmeo
del atacante con espacio propio). Ningún parámetro de Filecoin se copia como parámetro de ZEROX (`AUTO-ZRX.md` §4).
