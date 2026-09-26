# P-AUSENCIA-VOTO — Programa: que no votar cuando te toca tenga un precio

**Fecha:** 2026-09-26. **Director:** Claude. **Origen:** conversación con Katana del 2026-09-26.

**Forma parte de la misma solución que `P-ZRX/P-FINALIDAD-VOTOS/`** (capa de finalidad por votos que arrincona
el doble farmeo). Este programa completa esa capa: aquel diseña quién vota y cómo se sella; este decide qué
pasa cuando alguien sale elegido y no vota. Todo lo que no se diga aquí lo fija `P-FINALIDAD-VOTOS`
(`PROGRAMA.md`, `CONTEXTO.md`, `DECISIONES.md`, contrato de `resultados-FV1/`).

## Por qué

- **Pausar el sello es gratis.** El ataque de pausa consiste en salir elegido y no votar, y hoy no cuesta nada:
  «no firmar no es falta» (`P-FINALIDAD-VOTOS/CONTEXTO.md` §4.5; contrato de FV-1, FV-20).
- **Con la prima `b` el problema empeora.** `REVISION-FV1.md`: con prima `b > 1` y control de red suficiente
  para censurar las pruebas de disponibilidad de los honestos, el umbral de pausa cae por debajo de un tercio
  (`a ≥ 1/(2b+1)`: 11,1 % con `b = 4`), y pausar sigue sin castigo.
- **No se puede castigar lo que no se puede demostrar.** Con el sorteo secreto de FV-06, solo el dueño de la
  clave sabe si salió; quien sale y no vota no deja rastro. Por eso hace falta un sorteo **secreto durante la
  ronda y verificable después**.

## La conversación, resumida

1. Katana preguntó si votar es obligatorio. Respuesta del director: no, porque el sorteo secreto no deja
   rastro y castigar la ausencia castigaría a honestos.
2. Katana: *«después de todo si salió en el sorteo y no votó está perjudicando de cierta forma a la red, ya que
   el objetivo del sorteo es decidir quién vota y si no lo hace es un puesto/plaza perdida»*.
3. El director añadió el motivo de seguridad: salir elegido y no votar es exactamente la pausa del atacante.
   Propuso dos cosas: un sorteo verificable después y, como consecuencia, **quitar la prima `b` durante un
   tiempo, sin confiscar garantía**, por los falsos positivos honestos y por el riesgo de que el atacante
   bloquee votos ajenos.
4. **Decisión de Katana, que va más allá de la recomendación del director:** *«creo que no votar es un problema
   serio, por tanto creo que si alguien no vota se le quita la prima y se confisca una cantidad relativamente
   pequeña, de esta forma se desincentiva no votar. Los errores se pagan: si se desconecta por un apagón de
   corriente, etc., es una pérdida que él tiene que asumir.»*

5. **Alcance.** El director propuso tres lecturas: (i) castigar a todo elegido; (ii) solo al que tenía prima;
   (iii) la (ii) más un aviso de «me retiro» sin castigo. Recomendó la (ii) o la (iii).
6. **Objeción de Katana a (iii):** *«todos podrían decir que van a apagar como aviso, luego no apagan y así
   esquivan la sanción»*. El director le dio la razón y fue más allá:
   - **(ii) tiene la misma puerta:** basta con dejar caducar la prima.
   - **El atacante la aprovecha:** a peso ×1 no paga nada por no votar. Si además censura las pruebas de los
     honestos, pausa gratis (40 % de plazas que no firman con `a = 0,25` y `p = 0,8`).
   - **Retractación:** su afirmación «con (ii) el atacante no se libra» era falsa.
   - **Nueva propuesta, (iv):** todo elegido que no vota paga, y la retirada **saca del sorteo** en vez de
     quitar la sanción, con retardo y duración mínima. Declarar y no apagar deja de tener premio: no te toca
     plaza.

7. **Katana elige la (i):** *«creo que me quedo con la (i) a pesar de que conlleve un mayor coste para todos,
   pero mi conclusión es que a todo elegido que no vota y está en el sorteo, al no votar, es el precio que
   pagar por apagar»*. También preguntó si la retirada de (iv) rompe que todos participen.
   - **Respuesta del director:** sí, lo rompe. Contradice FV-04 y FV-D01 («todos los registrados en el
     sorteo»).
   - **Además tiene un coste de seguridad que el director no había visto:** encoge el denominador. Si los
     honestos se retiran de noche, la parte del atacante entre los activos sube: con `a = 0,25` y la mitad de
     los honestos retirados, 0,400. Y si se protege con un suelo `E`, el atacante pausa gratis retirándose él.
   - **Conclusión:** la (i) pura, sin retirada, es coherente con el principio de Katana y además es más
     segura.

## Decisiones de Katana (2026-09-26, provisionales hasta AV-1)

- **Quien sale elegido y no vota pierde la prima `b` durante un tiempo y se le confisca una cantidad pequeña.**
- **Los fallos propios se pagan** (apagón, corte de red, PC apagado): es un coste aceptado conscientemente.
- **Alcance (i):** paga todo elegido que no vota, tenga prima o no. **No hay retirada:** todos los registrados
  están siempre en el sorteo. La única salida es dejar de estar registrado con garantía activa, y eso también
  quita el derecho a producir.
- **Queda pendiente, sin decidir, si se premia votar** (recompensa por voto incluido en un certificado).

## Límites

- **R3 no cambia:** la cadena nunca espera a los votantes; sin quórum, la finalidad solo se pausa. Castigar la
  ausencia no vuelve indispensable a nadie.
- **R5 se amplía, y es Katana quien lo ratifica.** Hoy dice «votar dos cosas contradictorias es prueba y
  castigo». La ausencia no es un acto firmado, así que solo puede castigarse si deja **prueba pública
  verificable**. AV-1 propone la redacción nueva.
- **El mandato exige semántica y tasa de falsos positivos demostradas antes de castigar una ausencia**
  (`AUTO-ZRX.md`, bloques de PoStake y de Filecoin). Este programa las entrega; la activación sigue necesitando
  la ratificación de Katana.
- **Sin castigo correlacionado** (DS-5, `DS-L02`): la cantidad es fija por plaza y no crece con el número de
  ausentes.
- **Los falsos positivos provocados por el atacante no entran en «los errores se pagan».** Si el atacante
  bloquea el voto de un honesto, el honesto tiene que poder demostrar que votó.
- **Esta decisión sustituye, para la capa de votos, a** «no se castiga ninguna ausencia» (orden FV-1,
  decisión 5; contrato de FV-1, FV-20; `DS-L01` para el voto). Esos textos se enmiendan cuando se ratifique
  AV-1.

## Encargos

| ID | Qué | Ejecutor | Depende de |
|---|---|---|---|
| AV-1 | Sorteo secreto y verificable después; falta «elegido sin voto» con su prueba y su defensa; consecuencia (prima y confiscación pequeña); falsos positivos; coste para el atacante y para el honesto | Sonnet | Contrato de FV-1 (segunda ejecución, `REVISION-FV1.md`) |
| AV-2 | Oráculo Julia y vectores de la falta de ausencia (extiende el oráculo de evidencia de P-SLASHING) | DeepSeek | AV-1 ratificado |
| AV-3 | Implementación Rust dentro de la capa de votos (con FV-4) | Sonnet | AV-2, FV-3 |

AV-2 y AV-3 se redactan cuando AV-1 esté ratificado.
