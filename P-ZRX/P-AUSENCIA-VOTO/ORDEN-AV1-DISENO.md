# ORDEN-AV1 — Sorteo verificable después y falta «elegido sin voto»: diseño, contrato v0 y calibración

## 1. Identidad y contexto

- **ID:** AV-1. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente Sonnet (diseño y análisis;
  sin código de producto; cálculos en Julia, **nunca** Python).
- **Zona (la única en la que puede escribir):** `/home/katana/zeo/ZEROX/deepseek/AV1/`.
- **Programa:** `P-ZRX/P-AUSENCIA-VOTO/PROGRAMA.md`, parte de la misma solución que `P-ZRX/P-FINALIDAD-VOTOS/`.
- **Objetivo único:** diseñar cómo se demuestra, después de la ronda, que una clave salió elegida y no votó; y
  diseñar la consecuencia que decidió Katana (pérdida de la prima `b` y confiscación de una cantidad pequeña),
  con su semántica, su tasa de falsos positivos y su coste para el atacante y para el honesto. Se entrega como
  contrato v0 que extiende el de FV-1, sin fijar parámetros de producción.
- **Pregunta falsable:** «Existe un esquema en el que se cumplen a la vez estas cinco condiciones:
  - (a) durante la ronda, nadie salvo el propio granjero sabe si ha salido elegido;
  - (b) pasado un plazo `W`, cualquiera puede demostrar con datos públicos que la clave `P` salió en la ronda
    `n` y no tiene voto admitido;
  - (c) un honesto que votó a tiempo siempre puede demostrarlo, aunque su voto se quedara fuera del
    certificado o se lo bloquearan en la red;
  - (d) el coste en datos por granjero y día cabe en un presupuesto que el informe declara;
  - (e) con la consecuencia de Katana, pausar le cuesta al atacante una cantidad absoluta que crece con la
    duración de la pausa, y la pérdida esperada de un honesto queda acotada y declarada por perfil.»

  Se refuta con un contraejemplo concreto a cualquiera de las cinco, o demostrando que (a) y (b) son
  incompatibles sin un coste que el informe cuantifique.

## 2. Entradas (leer íntegras)

**`P-ZRX/P-AUSENCIA-VOTO/`:** `PROGRAMA.md`, con la conversación y la decisión de Katana.

**`P-ZRX/P-FINALIDAD-VOTOS/`:**
- `PROGRAMA.md`, `CONTEXTO.md`, `DECISIONES.md` y `REVISION-FV1.md`;
- `resultados-FV1/CONTRATO-FINALIDAD-VOTOS-v0.md` (en especial FV-04…FV-10, FV-20…FV-22 y FV-EVP-01…06) y
  `resultados-FV1/INFORME.md`.

**`P-ZRX/P-SLASHING/`:**
- `PROGRAMA.md` y `DECISIONES.md` (`DS-L01`…`DS-L05`; destino de fondos 2/8 y 6/8);
- `CONTRATO-EVIDENCIA-v0.md` y `REVISION-SL1.md`;
- `SL2/INFORME.md`, `REVISION-SL2.md` y `REVISION-SL2b.md` (método de calibración contra falsos positivos).

**Otras del árbol:**
- `AUTO-ZRX.md`, los bloques «PoStake» y «Mecanismos de Filecoin candidatos» (ausencias: semántica y tasa de
  falsos positivos; suspender no es confiscar);
- `D-ZRX/SPEC.md` §5 y `P-ZRX/P-DISUASION/REVISION-DS5.md` (castigo correlacionado).

**Fuentes externas (lectura primaria; si el visor no lee un PDF, descárgalo con `curl` a la zona):**
- RFC 9381 (ECVRF), en particular la unicidad de la salida;
- Algorand: el artículo de SOSP 2017 (Gilad y otros) y la documentación de claves de participación y del
  estado en línea / fuera de línea;
- eth2book, «Rewards and penalties» e «Inactivity leak»: Ethereum penaliza la atestación omitida con una
  cantidad pequeña, distinta del *slashing*, y es el precedente directo de la decisión de Katana;
- la literatura de elección secreta de líder (*Single Secret Leader Election*, Boneh y otros): localizarla y
  decir si aporta algo.

## 3. Decisiones que no se reabren

1. **Decisión de Katana:** quien sale elegido y no vota **pierde la prima `b`** durante un tiempo y **se le
   confisca una cantidad pequeña** `m_aus`. Los fallos propios (apagón, red, PC apagado) se pagan: es un coste
   aceptado. **No** se aceptan los falsos positivos provocados por el atacante; para ellos tiene que existir una
   defensa (pregunta falsable, condición (c)).
2. **Cantidad fija por plaza,** no correlacionada (DS-5, `DS-L02`). Destino de fondos coherente con `DS-L03`,
   salvo que el informe justifique otro.
3. **R3 no cambia.** La cadena nunca espera a los votantes; sin quórum, la finalidad se pausa.
4. **Es una falta distinta de la doble firma,** con su propio tipo de prueba en la familia de `EvidenceTx` /
   `EvidenceVoto` (SL-1, FV-EVP).
5. **Modelo de amenaza de Katana:** el atacante tiene recursos de Estado. Todo coste se da en términos
   absolutos, y hay que distinguir lo imposible de lo caro.

## 4. Lo que tiene que contener

### A. Sorteo secreto y verificable después

Evalúa como mínimo estos cuatro esquemas, o descártalos con su razón:

1. **Publicación completa.** El granjero publica después las pruebas VRF de todas sus rondas; por ejemplo, al
   renovar la prueba de disponibilidad de FV-05.
2. **VRF por ventana, revelada al final.** Hay una salida VRF por ventana y la plaza de cada ronda se deriva de
   ella. Hay que decir cuánto secreto se pierde al votar (¿revela el calendario de la ventana?) y si una prueba
   de conocimiento cero lo evita, y a qué coste.
3. **Compromiso al inicio de la ventana.** El granjero compromete, con una raíz de Merkle, sus salidas VRF de la
   ventana; al votar abre solo la hoja de esa ronda. Después se auditan hojas pasadas al azar. Hay que dar la
   probabilidad de detectar ausencias sistemáticas frente a ausencias sueltas.
4. **Lo que aporte la literatura** (elección secreta de líder, Algorand).

Para cada esquema:
- los datos por granjero y día;
- qué secreto queda y hasta cuándo;
- la primitiva, que tiene que estar auditada; preferir ECVRF sobre Ed25519, como en FV-06;
- el coste de verificación;
- **qué pasa si el granjero no publica o no abre.** No publicar **nunca** puede salirle mejor que publicar.
  Candidatos: sin compromiso no hay prima; no se puede retirar la garantía sin rendir cuentas de todos los
  sorteos del periodo.

### B. La falta y su prueba

1. **Definición exacta de «elegido sin voto admitido»** en la ronda `n`.
2. **Defensa ante censura:** el honesto puede incluir su propio voto firmado en la cadena durante un plazo de
   gracia, aunque no entrara en el certificado. Hay que acotar qué puede hacer un atacante que controla la
   producción de bloques durante ese plazo.
3. **Formato de la prueba de ausencia,** con incidente único, deduplicación, ventana de admisión frente al
   retiro de la garantía (heredando EV-15/EV-15b), reorganización y deshacer.
4. **Coherencia con la prueba de doble voto** (FV-EVP): no se puede castigar dos veces el mismo hecho.

### C. La consecuencia

1. **Pérdida de la prima:** duración, cómo se recupera y cómo interactúa con la vigencia de FV-05.
2. **Confiscación `m_aus`:** de qué saldo sale (activo, pendiente o en retirada), qué pasa si no hay saldo
   suficiente, y el destino de los fondos.
3. **Alcance: decidido por Katana, lectura (i).** Todo elegido que no vota paga, tenga prima o no. En sus
   palabras: *«a todo elegido que no vota y está en el sorteo, al no votar, es el precio que pagar por apagar»*.
   Acepta que eso cuesta más a todos, incluido quien apaga el PC por la noche.
   - **No hay retirada.** Todos los registrados están siempre en el sorteo (FV-04). La única forma de dejar de
     participar es dejar de estar registrado con garantía activa, y eso también quita el derecho a producir
     (`C-BON-04`).
   - **La prima suaviza el coste de estar apagado.** Quien está apagado no tiene prima (peso ×1), así que le
     toca `b` veces menos que a quien está encendido. Cuantifícalo.

   **Comparadores, que no se diseñan pero sí se calculan:**
   - **(ii)** solo paga el elegido con prima. Se descarta porque el atacante deja caducar su prima, vota a ×1
     sin pagar y, si censura las pruebas de disponibilidad de los honestos, pausa gratis: `a + (1−a)(1−p)` de
     plazas que no firman, 0,400 con `a = 0,25` y `p = 0,8`. El director había afirmado lo contrario y se
     retractó.
   - **(iii)** (ii) más un aviso de «me retiro» que solo quita la prima. Se descarta por la objeción de Katana:
     cualquiera avisa, no apaga y esquiva la sanción.
   - **(iv)** (i) más una retirada que saca del sorteo, con retardo y duración mínima. El director la
     propuso, y la descarta él mismo tras la pregunta de Katana de si rompe que todos participen. La rompe,
     porque contradice FV-04 y la decisión FV-D01. Y tiene un coste de seguridad: **encoge el denominador**.
     Si los honestos se retiran (por ejemplo, de noche), la parte del atacante entre los activos sube: con
     `a = 0,25`, de 0,308 con el 25 % de los honestos retirados a 0,400 con el 50 % y a 0,571 con el 75 %.
     Si se protege con un suelo `E` medido sobre el total, el atacante pausa gratis retirándose él.
4. **Premio al voto (pendiente de Katana):** calcula el balance esperado del honesto con premio cero y con
   premio positivo, sin decidir.

### D. Análisis adversarial

Una tabla por ataque, con coste absoluto, daño y si queda imposible o solo caro:
1. pausa sostenida del atacante bajo (i), (ii) y (iv), en función de `a`, `b`, `K` y `m_aus`, con y sin censura
   de las pruebas de disponibilidad honestas;
1b. solo para el comparador (iv): abuso de la retirada (retirarse tras conocer la propia plaza, entrar y salir
   continuamente, retirarse en masa para disparar el suelo `E`) y el efecto del denominador encogido;
2. hacer perder a honestos: bloquear o retrasar sus votos, eclipsarlos, o censurar su voto durante el plazo de
   gracia;
3. repartirse en muchas claves o votar a ratos para conservar la prima;
4. ausencias honestas correlacionadas (apagón regional, fallo común del cliente): pérdida agregada y si
   compromete la viveza;
5. manipular el sorteo verificable (entropía de la ventana, momento del compromiso);
6. abuso de las pruebas de ausencia (spam, duplicados, reorganizaciones);
7. el granjero doméstico honesto: ¿le sale más a cuenta no registrarse? Si deja de registrarse, baja el peso
   total y la capa se debilita.

### E. Cálculos (Julia, proyecto fijado en `deepseek/AV1/calc/`)

1. **Datos por granjero y día** de cada esquema de A, con `K` y la duración de ronda del contrato de FV-1.
2. **Coste absoluto de la pausa por hora** para el atacante, en función de `a`, `b`, `K` y `m_aus`, con la
   dinámica de pérdida de prima y el caso de censura de C.3.
3. **Pérdida esperada del honesto por perfil** (encendido 24 h; 16 h al día; un apagón al mes), bajo (i), (ii)
   y (iv), con premio y sin premio. En (iv), el perfil de 16 h declara la retirada con antelación.
4. **Tasa de falsos positivos** por causa: fallo propio, bloqueo del atacante, fallo correlacionado.
5. **Región de `m_aus`:** pausar cuesta al menos lo que el informe proponga como mínimo, y la pérdida del
   honesto no supera lo que proponga como máximo. Hay que decir si esa región está vacía.

Semillas fijas y **no consecutivas**. Todo generador aleatorio lleva una **tabla de cobertura por tipo de caso,
con mínimos**.

### F. Informe

- Respuesta a la pregunta falsable.
- El esquema recomendado y la tabla de los cuatro.
- Una **redacción propuesta de R5** para que Katana la ratifique. Por ejemplo: «toda falta castigada deja prueba
  pública verificable: votar dos cosas contradictorias, o salir elegido y no votar». Hay que decir qué rompe o
  qué no rompe de R1–R4.
- Las enmiendas necesarias a textos vigentes: orden FV-1 (decisión 5), contrato de FV-1 (FV-20) y `DS-L01`
  para el voto.
- Las decisiones para Katana, con opciones, coste y recomendación: `m_aus`, duración
  de la pérdida de prima y premio al voto. El alcance ya está decidido: (i).
- Lo que no está medido.

## 5. Entregable y límites

Entregables, todos en la zona:
- `deepseek/AV1/CONTRATO-AUSENCIA-v0.md` (reglas `AV-*`, cada una con su justificación y un caso);
- `deepseek/AV1/INFORME.md`;
- `deepseek/AV1/calc/` (`Project.toml`, `Manifest.toml`, `run.jl`, tests y resultados);
- `deepseek/AV1/HUELLAS.sha256`.

Límites:
- Solo lectura fuera de la zona. **No lances subagentes ni forks.** Sin git, sin Python y sin credenciales.
- Etiqueta cada afirmación: [P] fuente primaria leída, [S] secundaria, [D] derivación propia, [H] hipótesis.
  Ninguna cifra de memoria.
- Presupuesto: **4 h de reloj** y cómputo ligero (hasta 4 hilos, minutos). Si se agota, entrega lo hecho y lo
  que falta.
