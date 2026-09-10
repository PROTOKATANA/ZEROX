# Auditoría D8b de la ronda 14C — correcciones

**Informe auditado:** `informe.md` · **Auditoría completa:** `audita-d8b.md`

## Correcciones a la tabla

| Punto | Corrección |
|---|---|
| «Avalanche es un comité / se excluye por los 2.000 AVAX» | **Avalanche NO es un comité**: muestreo abierto y Sybil pluggable (`arXiv:1906.08936:271-273, :318-319`). Los 2.000 AVAX son requisito de despliegue, no del protocolo. La exclusión, si se mantiene, es por Sybil/peso, no por comité. |
| «Sin comité ⇒ no existe finalidad determinista rápida (CAP)» | **Atribución forzada.** El teorema cubre «adaptativo + finalidad con UNA regla» (`lewispye-roughgarden-cap.txt:759`); las **reglas duales caen fuera** de su alcance (`cap-adaptividad-finalidad.txt:97-98`). Además `C-REORG-07` ya es finalidad determinista sin comité (fail-stop). La conclusión operativa sobrevive; la frase «no existe» es falsa sin «adaptativa». |
| DAGKNIGHT «4-17 s» | Viene de 14A, que 14B reetiquetó como adaptación propia (control positivo LAGUNA). No es cifra publicable. |
| Falta Parallel Chains/OHIE | `dag-nativo-poas-propuesta.md:1108,1231`; no mejora irreversibilidad, pero falta en la tabla. |

## Lo que sobrevive

- **DAGKNIGHT completo** sigue siendo la única vía sin comité, sin dinero y con orden total que baja
  del baseline; pero es **LAGUNA** hasta validar la regla de cliente y cerrar el ataque de retención
  + cadena privada (8-12/12 semillas).
- **Sin comité no hay finalidad determinista rápida** en el sentido operativo revisado: ninguna de
  las alternativas la mejora.
- El baseline GHOSTDAG (130,41 s medidos a α=0,33) y `C-REORG-07` (3,33 h deterministas) siguen
  siendo el suelo firme.

## Lo que D8b dejó abierto y merece ronda propia

**Avalanche/Snowball sobre peso de espacio**, ahora que se sabe que no es un comité: queda por
resolver **de dónde se muestrea sin registro** (el espacio no tiene censo) y si el sondeo abierto
con peso de espacio resiste Sybil sin dinero. Es el único candidato no-comité con latencia
sub-segundo en la literatura.
