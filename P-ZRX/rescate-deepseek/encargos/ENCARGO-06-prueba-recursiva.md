# Encargo 06 — ¿Da una prueba recursiva el IBD sin confianza que los niveles no dan?

**Ejecutor:** DeepSeek, en la zona aislada `deepseek/`.
**Diseñado por:** Claude (Opus 5), 2026-09-17, bajo decisión de Katana del 2026-09-17.
**Categoría Veritas propuesta:** `consenso` (dominante); `criptografía` secundaria.
**Ruta de trabajo:** `deepseek/veritas/consenso/prueba-recursiva-v1/`.
**Destino final, si se valida:** `veritas/consenso/prueba-recursiva-v1/`.

---

## 0 · Antes de escribir una línea

**Lee íntegro `veritas/LINEO.md`.** Obligatorio por `AGENTS.md` y C-SPEC-03; su §8 te aplica entero.

Lee además, en este orden:

1. **`veritas/consenso/poda-post-v1/`** — el encargo 05, tuyo, ya validado y migrado. En especial
   `DERIVACIONES.md` **D5** (el teorema de los tres requisitos), `INFORME.md` §1.2 y §4, y
   `PROPUESTA.md` **P3**. Este encargo arranca **exactamente donde ese terminó**.
2. `veritas/consenso/poda-post-v1/PROCEDENCIA.md` §3.2 — dice por qué existe este encargo y qué
   quedó fuera del anterior.
3. `SPEC.md` §11 completo (C-GD-01…11, C-ORD-01…04), §9 (Orchard/Halo2) y §12.1 (C-CHK).
4. `TAREAS.md` §2.4 «Pruning» y §2.6 (estado UTXO).
5. `research/orchard-math-verification.md` y `research/orchard-bundle.md`.

---

## 1 · De dónde viene este encargo

PPP-v0.1 demostró (D5) que **ningún predicado de nivel** sirve como prueba de poda en ZEROX: un
nivel de solución no liga a la ancestría, y un nivel de hash de cabecera no mide espacio. En PoW las
dos propiedades viven en el mismo objeto; en PoST se separan.

**Ese teorema cubre predicados de nivel.** No cubre una vía distinta: una **prueba recursiva** de la
función de transición del consenso —el modelo de Mina— que no necesita ligar recurso a historia
porque no acredita gasto, acredita **cómputo correcto**.

**Esa laguna es de mi encargo, no de tu ejecución:** el 05 preguntaba por el análogo a los *niveles*
de PoW, y eso contestaste. Este encargo cierra lo que quedó.

**La pregunta:** ¿puede una prueba recursiva dar IBD sin confianza en ZEROX, y a qué coste?

---

## 2 · La trampa principal, dicha por delante

**No confundas validez con selección.** Es el error que hundiría este encargo entero si se descubre
al final.

Una prueba recursiva acredita: *«partiendo del génesis, esta secuencia de transiciones es válida y
conduce a este estado, con este `blue_work`»*. Eso es **validez**.

Lo que un nodo nuevo necesita es distinto: *«esta es LA cadena canónica»*. Y en GHOSTDAG la cadena
canónica no es una propiedad de una historia aislada: es el resultado de comparar **todas** las
ramas del DAG. Una prueba de validez perfecta no dice que **no exista otra rama con más
`blue_work`**. Un adversario puede construir una rama privada válida, probarla recursivamente, y su
prueba **verificará correctamente**.

**Ese es el mismo agujero que D5 encontró, con otro traje.** El encargo 05 lo dijo así: «nada de lo
que un tercero puede comprobar sin el DAG determina el DAG».

Así que la pregunta real no es «¿se puede probar la transición?» —se puede, es cómputo— sino:

> **¿Existe algo que un nodo nuevo pueda comprobar, sin el DAG, que le diga que ninguna rama
> competidora tiene más `blue_work`?**

Si la respuesta es no, la prueba recursiva **no resuelve (2)** y el veredicto vuelve a ser negativo,
esta vez por una razón distinta y con el problema cerrado por las dos vías. **Eso sería un resultado
excelente**, y debe decirse con esas palabras.

Mina tiene este problema y lo trata con reglas de densidad y ventanas de *long-range fork*. Mira qué
hace y **si es transferible a un DAG con mergesets**, o si depende de que su cadena sea lineal.

---

## 3 · Alcance obligatorio

### 3.1 · La pregunta de selección (§2) — prioridad máxima

Tratar primero. Si sale «no», los puntos 3.2–3.5 pasan a ser secundarios y se declara así.

### 3.2 · Coste de probar GHOSTDAG recursivamente

Mina prueba una cadena **lineal**. ZEROX tiene que probar, por bloque de cadena:

- el mergeset y su orden (C-GD-04, C-GD-05) con **hasta 180 bloques**;
- el coloreo por k-cluster con `k = 30` (C-GD-06), que es el caso caro: el anticono azul se recorre
  por candidato;
- U2/U3″ (C-GD-07), que exige identidad de billete;
- los acumuladores `blue_score` / `blue_work` en **u256** (C-GD-02, C-GD-08);
- el orden de aplicación y los conflictos (C-ORD-03, C-ORD-04).

Estima el **tamaño del circuito** en restricciones, y el coste de generar la prueba **por bloque**,
a la tasa nominal de **1 bloque/s** (A″). Compáralo con una cadena lineal equivalente. **Si probar
un bloque cuesta más que un slot, el esquema no cierra**, y esa es una conclusión legítima y
cuantificada.

No necesitas implementar el circuito. Necesitas **contar**: operaciones, comparaciones u256,
hashes, y traducirlas a restricciones con una referencia citada. Declara el margen de error.

### 3.3 · Qué hace falta que ZEROX no tiene

- **Estado UTXO con datos de deshacer** (§2.6): **hoy no existe**. Sin él no hay qué comprometer.
  `PROPUESTA.md` P3.3 ya lo señaló.
- Un **compromiso del estado** verificable (raíz de UTXO, acumulador tipo Utreexo, otro).
- La **disponibilidad de datos**: la prueba acredita el estado, pero el nodo nuevo necesita **los
  datos** para operar. ¿De dónde salen? Si la respuesta es «de archivales», eso es la capa social
  del encargo 05 y **no cuenta como solución**.

### 3.4 · La infraestructura que ZEROX ya prevé

`orchard = "=0.15.5"` (SPEC §9) es **Halo2 sobre el ciclo Pallas/Vesta**, que es la familia que
permite recursión sin *trusted setup* y la que usa Mina. **Comprueba si eso es una ventaja real o
una coincidencia de nombres**: una cosa es tener las curvas en el árbol de dependencias y otra es
tener un sistema de recursión utilizable. Di cuál de las dos es, con la fuente delante.

### 3.5 · Vectores adversariales

Como mínimo: rama privada probada recursivamente (§2); *long-range fork* desde un punto antiguo;
coste de generar pruebas como vector de DoS asimétrico; y qué pasa si el probador honesto no puede
seguir el ritmo de 1 bloque/s mientras el adversario elige cuándo probar.

---

## 4 · Prohibiciones explícitas

1. **No fijes parámetros** ni propongas constantes de producción.
2. **No uses `F = 2 h`**: es provisional.
3. **No edites `SPEC.md` ni `TAREAS.md`.** El SPEC lo redacta Claude. Tus salidas van en
   `PROPUESTA.md`.
4. **Nada de Python.** Julia en CPU; C++/CUDA sólo si el perfil lo justifica.
5. **No toques nada fuera de `deepseek/`.** Registra `git status --short` al empezar y al terminar.
6. **No declares horas como evidencia.**
7. **Recorta el `Project.toml` de la plantilla.** En el encargo 05 entregaste 28 dependencias
   declaradas y usaste dos; hubo que recortarlo al migrar (`PROCEDENCIA.md` §2). Declara **solo lo
   que uses**, stdlib incluida.
8. **No presentes «se puede probar la transición» como «IBD resuelto».** Es la trampa del §2.
9. **No cites un archivo sin comprobar que existe**, con ruta desde la raíz del repositorio.

---

## 5 · Entregables

En `deepseek/veritas/consenso/prueba-recursiva-v1/`, estructura de LINEO §1:

| Archivo | Contenido |
|---|---|
| `CONTRATO.md` | qué calcula, qué **no** acredita, presupuesto declarado **antes** de ejecutar |
| `MODELO.md` | el modelo: qué prueba el circuito, adversario, supuestos criptográficos |
| `INFORME.md` | **veredicto sobre la pregunta de selección (§2) primero**, después coste. Etiquetas `demostrado`/`medido`/`estimado`/`no demostrado`/`inconcluso` |
| `PROPUESTA.md` | si procede: qué haría falta, con supuestos y coste. **Propuesta, no SPEC** |
| `PROGRESO.md` | bitácora con `date`, no estimaciones |
| `HUELLAS.sha256` | rutas **desde la raíz del repo**, como en PPP-v0.1 |
| `src/`, `test/`, `bench/`, `run.jl`, `resultados/` | según LINEO §1 |

**Una estimación de coste no es una cifra suelta.** Cada número lleva: de qué operación sale, con
qué factor de conversión a restricciones, de qué fuente sale ese factor, y qué margen tiene.

---

## 6 · Criterio de terminación

LINEO §10, y además:

**Un «no» por coste es tan válido como un «no» por imposibilidad**, y hay que distinguirlos: «no
cierra a 1 bloque/s con la tecnología citada» no es lo mismo que «no puede funcionar». Si es lo
primero, di **a qué tasa sí cerraría** y qué tendría que mejorar.

**Se rechaza:** confundir validez con selección (§2); dar por buena una estimación de restricciones
sin fuente; presentar Halo2-en-el-árbol-de-dependencias como recursión disponible; y omitir la
dependencia de §2.6.

**Si agotas el presupuesto:** para, checkpoint, **inconcluso**, con entrada mínima reproducible.

---

## 7 · Después

Claude valida **reejecutando**, no leyendo tus `resultados/`. Sólo entonces se migra y se commitea.
`deepseek/` se borra al cerrar el encargo: lo que deba sobrevivir vive en el instrumento.

Si algo de este encargo te parece equivocado —y en particular si crees que la trampa del §2 no es
tal— **dilo antes de ejecutarlo**, no después.
