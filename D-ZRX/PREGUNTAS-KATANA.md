# Preguntas reservadas a Katana

**Mantiene:** Claude (director, `AUTO-ZRX.md`). **Abierto:** 2026-09-26 ≈ 22:58. Aquí van solo las decisiones
que no se deducen de la evidencia (una preferencia de Katana) o que son acciones externas irreversibles
(`R-ZRX/TRASPASO-2026-09-26.md` §0). Cada una lleva opciones, qué implica cada opción, su coste y la
recomendación del director con su motivo. **Mientras no haya respuesta, el trabajo sigue por lo que no
depende de ella**; lo que sí depende queda marcado `bloqueado (Katana)` en `D-ZRX/IPA-ZRX.md`.

| ID | Pregunta | Bloquea | Estado |
|---|---|---|---|
| PK-01 | Fuente de peso provisional de la capa de votos mientras no exista el registro de sectores | FV-4 (Rust de la capa); **no** bloquea 0.0.1 ni FV-2/FV-3 | abierta |
| PK-02 | ¿Se aseguran los 95 archivos que solo existen en `.trash/zerox`? | nada hoy; su pérdida sería irreversible | abierta |

---

## PK-01 · Fuente de peso provisional de la capa de finalidad por votos

**Contexto.** Decidiste (FV-D01) que el peso del voto sea **sectores registrados con garantía**, con sorteo
VRF entre todos los registrados y prima `b = 2` (FV-D05). El registro de sectores no existe: sus programas
(IPA D-01…D-03) están abiertos y fuera de 0.0.1; D-02 (auditorías) solo **encarece** y D-03 (ciclo de vida
en el DAG) ni ha empezado. Sin una fuente de peso, la capa no se puede implementar (FV-4). Lo que **no**
depende del peso sigue adelante: FV-2 (modelo cuantitativo, el peso es un parámetro por clave), FV-3
(oráculo), el formato del voto, el firmante seguro del voto (SL-4b1 ya porta el del bloque) y el plazo de
gracia.

**Lo que obliga a cualquier opción** (refutaciones vigentes): la tabla de poder se encadena por certificado
(RFT-19); con censura de las pruebas de disponibilidad pausar exige el 20 % y sellar a solas el 50 % **del
peso** (RFT-17, `b = 2`); un certificado falso adoptado no se revierte (RFT-18); la multa por no votar tiene
que crecer con el peso del infractor (RFT-20, FV-D06). La fuente de peso decide **qué recurso** hay que
reunir para llegar a ese 20 % o 50 %.

| Opción | Qué implica de verdad | Qué se paga | Qué se cierra |
|---|---|---|---|
| **1. Esperar al registro** para la capa real; FV-2/FV-3 ahora con el peso simbólico; FV-4 después de D-01…D-03 | La capa nace con el peso que elegiste: el atacante necesita el 20 %/50 % del **espacio registrado con garantía**, lo que junta dos recursos (disco y moneda) | La capa no se mide en red hasta que exista el registro (semanas de trabajo: formato, auditorías, ciclo de vida, oráculo, Rust); la mitigación del doble farmeo sigue siendo teórica mientras tanto | Nada; es la opción que no compromete ningún principio |
| **2. Garantía como peso solo en la red dev** (interfaz `FuentePeso`; bloqueo de tipo para que no se active fuera de `Red::Dev`), y sectores cuando exista el registro | Se implementa y mide ya **la mecánica** (sorteo VRF, certificados encadenados, pausa, latencia de sellado frente a `Δ`, participación); lo medido sobre la seguridad **no** se transfiere, porque en dev el peso es moneda | Código de una fuente que se tirará (pequeño si la interfaz está bien puesta); riesgo de que «provisional» se quede: exige una puerta que impida activar la capa fuera de dev sin el registro | Durante la fase dev, el voto pesa por saldo: el principio de complementariedad («más stake no da más poder», IPA C-06) se suspende **para la finalidad** en dev |
| **3. Garantía como peso en cualquier red** hasta el registro | La capa sería PoS en la finalidad: sellar a solas cuesta comprar el 50 % de la garantía (con censura) | Contradice FV-D01 y «ZEROX sobrevive con sus cultivadores»: el granjero doméstico con mucho disco y poca moneda casi no vota; la moneda de arranque sale del PoW, que un rico en hash concentra (A-10: una GTX 1070 rinde 7,6 veces una CPU de 16 núcleos) | La complementariedad en la finalidad, fuera de dev |
| **4. Producción reciente como estimador del espacio** (bloques ganados en una ventana, verificable en la cadena) | Aproxima «espacio» sin registro; es R2 (recurso verificado en cadena) | Ruido de Poisson: el granjero pequeño con pocos bloques tiene un peso muy variable; la garantía castigable es `q` por clave, no proporcional al peso, así que la multa y la confiscación no crecen con el peso (el problema de RFT-20 vuelve); premia producir en la cadena pública y no mide el espacio que se retiene para una rama privada | Ata la finalidad a la producción, que es justo lo que el doble farmeo explota |

**Recomendación del director: opción 2**, con la opción 1 como alternativa si prefieres no suspender el
principio ni siquiera en dev. Motivo: las incógnitas que deciden si la capa es viable en la práctica
—latencia de sellado frente a `Δ`, participación de granjeros que se apagan, coste de verificar certificados—
no dependen de la fuente de peso y se pueden medir ya en la red dev; la seguridad sí depende del peso y
**solo** se afirmará con sectores. La opción 2 cuesta poco si la fuente de peso queda tras una interfaz y
tiene un bloqueo de activación fuera de dev (como el perfil dev hoy, D-P05). Descarto la 3 (contradice tu
decisión FV-D01 fuera del laboratorio) y la 4 (reabre RFT-20 y ata la finalidad a lo que el atacante
manipula).

**Si no respondes:** sigo con FV-2 y FV-3 (no dependen del peso) **después** de cerrar 0.0.1, y no empiezo
FV-4.

---

## PK-02 · Los 95 archivos que solo existen en `/home/katana/zeo/.trash/zerox`

**Contexto (IPA E-07).** En la papelera, fuera de git, quedan 95 archivos del árbol antiguo que ningún commit
conserva, entre ellos `P-RELOJ`, `P-ECLIPSE`, `P-STAKE`, `P-VIVEZA` y `T-ZRX/ESTADO-RELOJ.md`. Las tres
fuentes que citan RFT, IPA y SPEC ya están copiadas con huellas en `R-ZRX/LEGADO/`. Vaciar la papelera
perdería el resto sin vuelta atrás.

| Opción | Implica | Coste |
|---|---|---|
| **A. Copiar los 95 a `R-ZRX/LEGADO/solo-trash/` con huellas y procedencia**, sin promoverlos | Nada se pierde; quedan en git como archivo, marcados no normativos | Algo de tamaño en el repositorio (texto, poco) y ruido en `R-ZRX/` |
| B. Dejarlos donde están | Cero trabajo | Un vaciado de la papelera los borra; hay investigación (reloj, eclipse, viveza) que no se ha reproducido en el árbol nuevo |

**Recomendación: A.** Es barata y evita una pérdida irreversible; el mandato ya pide conservar lo necesario
para reproducir decisiones (`AUTO-ZRX.md` §2). La pregunto porque decide qué entra en el repositorio y
porque la papelera es tuya.
