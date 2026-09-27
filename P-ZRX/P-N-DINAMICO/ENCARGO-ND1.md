# ENCARGO ND-1 — `N` dinámico sin llave: ley de adaptación del reloj PoT y sus ataques

**LINEO (`V-ZRX/LINEO.md`) rige el instrumento**; léelo íntegro antes de escribir código.

## 1. Identidad

- **ID:** ND-1. **Redactado:** 2026-09-27 (≈ 22:00) por Claude (director). **Ejecutor:** DeepSeek (`deepseek-flash`,
  esfuerzo `high`). **Hoja de ruta:** 0.0.2, paso 1 (investigación de viabilidad). **Se lanza al cerrar 0.0.1**, salvo
  indicación de Katana.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/ND1/`. **Base:** la raíz en el commit de
  `ENTRADA-ND1.sha256` (se congela al lanzar). Es **investigación**: ni una línea de código de producto.
- **Requisito de Katana (2026-09-27, literal):** «lo preferible sería que se adapte de forma dinámica sin que nadie lo
  tenga que calibrar manualmente y sin llave mágica. Mitigar los posibles ataques que puedan existir.» Principio que lo
  enmarca, también suyo: **ZEROX sobrevive por sí solo, sin nadie detrás.**
- **Qué se excluye por ese principio:** cualquier llave (`root`, comité, votación, firma de un equipo), un trinquete que
  solo se libere con un hard fork, la calibración manual por red, y una cadena externa como fuente de tiempo (haría a
  ZEROX depender de otra red; P-RELOJ ya mostró que no resuelve el coste de verificar).

## 2. Lo que ya se sabe (no lo rehagas; valídalo o refútalo si lo usas)

- `R-ZRX/LEGADO/reloj/ESTADO-RELOJ.md` — estado del reloj en el árbol viejo: cinco opciones, frontera
  `ρ_max = ε·K` (`K = 16` medido con AVX-512/VAES, ≈ 8 con solo AES-NI), «`N` dinámico no cuesta más verificación que
  estático» (aritmética del director de entonces, §5), techo del tipo `u32` (§4.1), y **cuatro defectos de P-RELOJ**
  (§10) que no debes heredar.
- `R-ZRX/LEGADO/solo-trash/P-ZRX/P-RELOJ/` — encargo, informe e instrumento `reloj-adaptativo-v1`. Resultados que
  importan aquí: el reloj no puede medirse a sí mismo (hacen falta timestamps); **un adversario minoritario que sesga la
  mediana sube `N`** (≈ 3,4 % por ventana con `α = 0,10`, acumulable: el ataque es **encarecer la verificación**); sin
  trinquete el adaptador **oscila** al conectar y desconectar el timelord más rápido (hasta el 96 % de `N_max` con retardo
  largo); la región de manipulación **sin mayoría** quedó **inconclusa**.
- `D-ZRX/RFT-ZRX.md` RFT-12 (segundo VDF: el adelanto pasa de ≈ `L` a `(L + I)(1 − 1/ρ)`, no se anula).
- **Hechos del diseño actual comprobados por el director:**
  - 0.0.1 usa `N` constante (`N_dev = 138 873 760`, decisión D-P10 en `P-ZRX/P-DAG/DECISIONES-W05.md`) y `SR`
    constante (D-P11).
  - La cabecera PoST lleva `timestamp u64` que el productor escribe y **nadie valida**. El PoW sí lo valida:
    `crates/zx-consensus/src/timestamps.rs` (monotonía y FTL). Es IPA B-13.
  - El mismo `N_dev` dio 1,66 s por slot en W06d1 y 1,28 s en W07b, en la misma máquina (causa no investigada).
  - `F_SLOTS`, `R_SLOTS`, `Plazo_slots` y `M_margen_slots` se cuentan en slots: su duración real depende de `N`.

## 3. Preguntas (cada una con respuesta falsable y su evidencia)

**N0 · Precedentes, leídos en su código fuente** (archivo:línea y commit; nada de memoria). Chia: cómo ajusta las
iteraciones de su VDF por época (fórmula, ventana, límite de cambio, qué timestamps usa). Kaspa: ventana de ajuste y
mediana de tiempo **en un DAG** (qué bloques cuentan). Autonomys: `set_pot_slot_iterations` (llave `root` y trinquete).
Bitcoin y Zcash: el ataque de manipulación de timestamps (*timewarp*) y cómo lo contienen (BIP-54). Para cada uno: qué
problema resuelve, qué deja abierto y qué se puede trasladar a ZEROX.

**N1 · Reglas de timestamp para la cabecera PoST** (requisito previo). Propón:
- monotonía respecto al pasado del bloque (¿mediana sobre la cadena seleccionada o sobre una ventana del conjunto azul,
  como Kaspa?);
- FTL frente al reloj local, con rechazo **diferible** y sin penalizar al par, como el PoW;
- relación timestamp–slot.

Analiza qué le pasa a un nodo con el reloj desviado y a una partición.

**N2 · La ley `L`.**
- Estimador sobre una ventana `W` de la cadena seleccionada, objetivo `τ`, ganancia, y límite de cambio por época en las
  dos direcciones.
- Suelo y techo: el techo sale del presupuesto de verificación `ε·K` del hardware más débil admitido, que es una
  **entrada**, no la decides tú.
- Cuantización `N % 16` y ampliación del tipo.
- **Activación diferida:** el `N` de la época `e + 2` queda fijado por el estado al cerrar `e`, de forma determinista
  en cada rama, también tras una reorganización.
- `N` inicial en el corte.
- Interacción con el controlador de `SR` (bloques por slot) y con los plazos contados en slots.

**N3 · Ataques.** Cada uno con su cota en función de `α` (fracción de la producción o del peso), el FTL `φ`, el retraso
`δ`, `W` y el límite `c`, con **aritmética exacta** en la frontera:
- (a) sesgo minoritario que **sube** `N` y su acumulación época tras época (el ataque de P-RELOJ): ¿el límite y el
  estimador acotan la deriva acumulada, o no?
- (b) sesgo que **baja** `N` en la cadena pública (más slots por segundo real).
- (c) rama privada con timestamps falsos (*timewarp*): efecto en la selección (FC-3, `blue_work`), en GHOSTDAG y en
  `C-FIN-01` (`F_SLOTS` más corto en tiempo real).
- (d) atacante con reloj más rápido (`ρ > 1`) que calcula en privado y publica: ¿`N` dinámico empeora, mejora o no
  cambia su adelanto frente a `N` fijo? Interacción con el segundo VDF.
- (e) oscilación al conectar y desconectar el timelord más rápido, **sin trinquete manual**: amplitud acotada por `c`,
  pico del coste de verificar, y si `N` baja cuando el rápido se va.
- (f) nodo eclipsado o con el reloj desviado; partición en la que cada lado adapta distinto, y la reunión.
- (g) ¿el timestamp libre da grano sobre el hash de la cabecera (desempates GHOSTDAG, FC-3, cualquier aleatoriedad)?
  ¿Añade algo a lo que ya dan otros campos libres?
- (h) ruido de carga honesto (el 1,66 s frente a 1,28 s): robustez del estimador.

**N4 · Veredicto.** ¿Existe una ley `L` que cumpla los tres requisitos de Katana: sin calibración manual, sin llave y
con los ataques de N3 acotados a cifras escritas? Si existe, entrega `BORRADOR-REGLA.md` con el mecanismo redactado y los
parámetros que dependen de `ρ_max`, `K` y `ε` marcados `<<PENDIENTE>>`. Si no existe, di **dónde está el corte exacto**
y cuál es la opción menos mala, con su coste.

## 4. Método

- Instrumento Julia en tu zona con la estructura de LINEO §1: `CONTRATO.md`, `MODELO.md`, `METODO.md`, `HIPOTESIS.md`,
  `PROCEDENCIA.md`, `HUELLAS.sha256`, `BITACORA.md`, `Project.toml`, `Manifest.toml`, `run.jl`, `src/`, `test/` y
  `resultados/`.
- **Aritmética exacta** (`Rational{BigInt}` o intervalos) en fronteras y cotas.
- Simulación del adaptador con **12 semillas no consecutivas**.
- El adversario de N3 **optimiza** su estrategia (búsqueda exhaustiva o programación dinámica en ventanas pequeñas); no
  basta con estrategias al azar.
- Cada cifra lleva su clase (`medido`, `citado` o `derivado`) y su procedencia.
- `ρ_max`, `K` y `ε` son **símbolos**. Los valores medidos por P-RELOJ en esta máquina (`K = 16`, 7,74 ns por bloque de
  10 rondas) sirven como punto de ejemplo, etiquetados, nunca como constantes.

## 5. Entrega y límites

- `INFORME.md`: la **primera línea responde N4**.
- Además: `BORRADOR-REGLA.md` (solo si N4 es afirmativo), `PROGRESO.md` y `HORAS.log` (`date -Is` real), y el nombre del
  modelo.
- **Prohibido Python** (también para editar texto). Nada fuera de la zona; sin git en el repositorio; sin secretos.
- Presupuesto: **6 h, 4 hilos**, `nice -n 5`.
- Si falta una definición, infórmala **antes** de seguir. Ninguna afirmación sin la evidencia que la sostiene.
