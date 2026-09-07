# Relojes efímeros — sexta propuesta para un DAG sobre PoAS

**Fecha:** 2026-09-08 · **PROPUESTA SIN AUDITAR.** Idea de Katana: ataca un axioma que las cinco
rondas anteriores compartían sin cuestionarlo — que debe existir un reloj canónico elegido por
peso, color o voto. Transcrita íntegra, con la pregunta central del agente principal añadida en
§4. Rondas anteriores: `dag-poas-auditoria.md`, `dag-poas-inyeccion-auditoria.md`,
`dag-poas-candidatos-auditoria.md`, `dag-poas-voto-auditoria.md`, `dag-poas-balizas-auditoria.md`
(el teorema de cierre: ninguna exclusividad de identidad funciona en PoAS permisionless). Esta
propuesta no toca exclusividad de identidad: elimina la necesidad de elegir entre relojes.

## 0 · El axioma que rompe

Las cinco rondas anteriores asumían que dos relojes en desacuerdo debían resolverse eligiendo uno.
Ahí nacían todos los fallos: partición (rondas 1, 2, 5), simetría de cobertura racional (ronda 3),
semilla anclada (ronda 4). En Autonomys el PoT es un pliegue, `estado_nuevo = H(estado_viejo ‖
entropía)`: dos flujos que divergen una vez divergen para siempre, y esa memoria es la que convierte
un desacuerdo transitorio en una bifurcación permanente. **La propuesta quita la memoria**: el
reloj se resetea en cada inyección en vez de plegarse. Un reloj vive `I` slots y muere. No hay fork
choice entre relojes: nunca.

## 1 · Algoritmo

- Intervalo `k` cubre `[kI, (k+1)I)`. Ventana `W_k` cerrada `D_v + Δ_rojo` slots antes de `kI`.
- Para un bloque `b`: `semilla_k(b) = VDF(H(k ‖ chunk_min(azules de past(b) en W_k)), D_v)`.
  Ventana vacía: `H(k)`.
- El flujo del intervalo `k` para `b` arranca de `semilla_k(b)` y no de nada anterior. Los desafíos
  de `b` salen de ese flujo. La validez de `b` es función de `past(b)` y de nada más: absoluta y
  bien fundada.
- Ninguna regla relaciona el reloj de `b` con el reloj de los bloques de su pasado. Se fusiona
  todo. El coloreado es GHOSTDAG puro. Un bloque bajo otro reloj no es inválido ni rojo por serlo:
  es un bloque.
- Emisión y dificultad por slot, no por bloque: la coinbase de un slot se reparte entre sus bloques
  azules y el reajuste mira bloques por slot totales.
- Filtro de plot con umbral `τ` por reloj: el sector `σ` audita el reloj `c` en el slot `s` solo si
  `H(σ, s, semilla_c) < τ`. Con `τ = 1/2`, dos relojes vivos cuestan la misma E/S que uno hoy; con
  `1/4`, cuatro.
- Cota de fusión a profundidad `k` (como Kaspa): un bloque no puede tener padres más viejos que `k`.
  Consecuencia: el número de semillas distintas que pueden existir a la vez está acotado.
- Los granjeros auditan contra todos los relojes que definan los tips a profundidad `k` en su
  vista, normalmente uno. Los timekeepers computan esos flujos, normalmente uno.

## 2 · Por qué disuelve, según el autor, cada fallo previo

- **Partición** (rondas 1, 2, 5): dos nodos que discrepan en el mínimo producen bloques con dos
  relojes, ambos referenciables y azules. Cuando sus conos coinciden en la ventana siguiente, sus
  semillas coinciden y los relojes colapsan en uno. La divergencia permanente exige partición de
  red real, no un desacuerdo.
- **Simetría de D9** (ronda 3): las dos loterías existen y todo el mundo juega las dos, pero no hay
  que elegir ganador: el peso cuenta bloques azules del DAG, vengan del reloj que vengan. No hay
  moneda que caer de un lado.
- **Diez relojes del atacante**: fabricar un reloj distinto exige excluir bloques de la banda de
  frontera de la cota de fusión; los honestos ven esos bloques en los tips y los juegan también.
  Ventaja relativa: ninguna.
- **Validez relativa y curación** (ronda 2): no hay regla cruzada, así que no hay nada relativo que
  romper ni nada que dejar de fusionar.
- **El teorema de estructura** (ronda 5): presuponía el pliegue. El evento sigue siendo
  impredecible, pero ya no hace falta que esté acordado: se acuerda a profundidad `D_v + Δ_rojo` y
  mientras tanto conviven las alternativas sin coste de consenso.

## 3 · Lo que el propio autor señala sin cerrar

1. **Grinding privado.** En una bifurcación privada la ventana solo tiene bloques del atacante:
   retener el mínimo da la segunda semilla, retener los dos primeros la tercera, `j+1` opciones con
   `j` bloques suyos en la ventana. Máximo `j+1` sorteos del intervalo siguiente en vez de uno,
   compone entre intervalos. Es el double dipping de Chia en versión «elegir el mínimo», degrada el
   umbral por debajo de la mitad. **«La ceguera por VDF no ayuda en privado porque no hay plazo.»**
2. **Verificación de relojes ajenos**: validar un bloque bajo un reloj que no computas exige
   computar ese flujo desde su semilla, hasta `I` slots. Acotado por la banda de frontera, pero sin
   número.
3. **Lookahead**: `Δ_rojo + D_v(1 − 1/s)`, como la ronda 2. Se puede acortar `D_v` porque retener el
   mínimo en público ya no bifurca nada, solo da dos semillas.
4. **El filtro `τ`** sube la varianza del granjero pequeño: va contra la prioridad de
   descentralización en el margen.
5. **Reajuste, caducidad de sectores y archivado** se anclan al conjunto azul a profundidad, que ya
   no depende de ningún reloj — sin especificar cómo (heredado de todas las rondas anteriores).

## 4 · La pregunta central que añade el agente principal, y por qué la propuesta puede caer aquí

**Hipótesis del agente principal, más fuerte que la del autor: el grinding privado no degrada el
umbral, probablemente anula la ceguera por completo.** La ceguera por retardo de VDF solo funciona
cuando existe una carrera: en todas las propuestas anteriores solo un reloj podía ganar, así que
decidir tarde costaba la carrera. Aquí no hay carrera: todo bloque válido bajo cualquier flujo es
azul y cobra. Un atacante puede calcular las `j+1` semillas candidatas en privado, con tiempo real
sin límite (nada en el diseño obliga a revelar la elección antes de conocer el resultado; la cota
de fusión a profundidad `k` limita cuán viejo puede ser un padre, no cuándo hay que publicar), y
publicar solo la rama que más le convenga. Es el fallo de SpaceMint (Park et al., citado en la
investigación histórica de esta sesión: *«el minero puede generar una secuencia de bloques en
privado casi sin coste y, al proponerla, no se detecta nada ilegal»*), heredado entero y aplicado
al desafío en vez de a la cadena. **Pregunta para D9: ¿existe alguna condición de temporización en
el diseño que fuerce al atacante a comprometerse antes de terminar de evaluar las `j+1` ramas? Si
no existe, la ceguera queda anulada, no degradada, y hay que decirlo con esas palabras.**

**Hueco menor, sin cerrar:** el reparto de la coinbase del slot entre sus bloques azules no está
especificado (¿a partes iguales? ¿ponderado?). Es la misma clase de ambigüedad que abrió huecos en
las rondas 3 y 5 (D8: caso «sin inyector», comparación por hash de candidato en vez de por flujo).
D8 tiene que mirar si algún reparto crea incentivo a inundar un slot con bloques propios o a
retenerlos para otro.

## 5 · La segunda dirección, si esta cae por el grinding privado

Dejar de tener reloj global: cada bloque lleva su propio VDF desde el output de su padre
seleccionado (el trunk de Chia), y el protocolo honesto extiende las `k` primeras de cada slot en
vez de solo una. El árbol de trunks tiene anchura `k`, la ventaja de double dipping tiende a cero
al crecer `k` porque los honestos ya lo hacen todo, y el ledger es GHOSTDAG sobre el follaje. Coste:
E/S ×k salvo filtro por rama, `k` flujos por timelord. Es un DAG de anchura acotada con relojes por
rama, no un DAG libre, sin inyector ni ventana ni mínimo — el grinding es el de Chia, ya medido
(greenpaper §2.2, φ acotado por bloques por desafío). No desarrollada en detalle aquí; se retoma
solo si la ronda 6 tumba la primera dirección por el grinding privado.

## 6 · Lo que D9 tiene que atacar

1. **La pregunta del §4**, formalmente: modela el juego del atacante privado con `j` bloques
   propios reales en la ventana, `D_v` de VDF por evaluación, sin restricción de temporización de
   reveal salvo la cota de fusión `k`. ¿Puede evaluar las `j+1` ramas en privado y publicar la mejor
   sin coste? Si sí, ¿queda algo de la ceguera, o es cero?
2. Si sobrevive algo: deriva el umbral resultante con `j+1` opciones, comparado con `φ₅₀ = 1,2815`
   y con el punto fijo `α*` de rondas anteriores.
3. Acuerdo honesto sobre el conjunto de la ventana con retardo acotado (repite el método de
   `baliza_acuerdo.py` de la ronda 5: `Λ = D_v + Δ_rojo` frente a retardo `U(0,D)`).
4. Convergencia del reajuste con bloques-por-slot-totales, sin fork choice entre relojes.
5. Verificación de relojes ajenos: número de flujos vivos acotado por la banda de frontera.

## 7 · Lo que D8 tiene que atacar

1. **El reparto de coinbase por slot** (§4 hueco menor): ¿incentiva inundar o retener?
2. Coste real, en núcleos y CPU, de verificar `m` relojes vivos por bloque, con `m` acotado por la
   cota de fusión `k`: ¿spam de relojes como en las rondas 3 y 5?
3. Interacción con C-EXP-02/04 (altura, caducidad de sectores): sin definir en ninguna ronda.
4. Filtro `τ`: ¿algún atacante lo explota para reducir el coste de auditar varios relojes por
   debajo de lo que paga un granjero honesto?
5. Cliente ligero, poda, C-REORG-07: heredado sin cambio (confirmar si sigue aplicando igual).
