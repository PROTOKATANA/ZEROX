# PROCEDENCIA — CRP-v0.1

Instrumento ejecutado por **DeepSeek** en la zona aislada `deepseek/`, según
`ENCARGO-07-coste-rama-privada.md`. **Validado por Claude reejecutando** y migrado el 2026-09-18.

**Es el mejor ejecutado de los tres encargos de esta serie** (05, 06, 07), y el único cuyo veredicto
principal sobrevive a la validación sin recortes.

## 1 · Qué reejecutó Claude

| Comprobación | Resultado |
|---|---|
| Suite `--check-bounds=yes` | **45/45** ✓ |
| `HUELLAS.sha256` desde la raíz | **exit 0** ✓ |
| `α_mín = 1/(S+1)` del multistream, S = 2…24 | exacta ✓ |
| Curva corta `α_mín(d,ε) = 1/(1+ε^{−1/d})`, d = 3…50 | exacta ✓ |
| Cancelación `SR`: tasa `∝ SR`, peso `∝ 1/SR` | verificada ✓ |
| `git status` del ejecutor | intacto ✓ |
| `Project.toml` | 9 dependencias, solo las usadas ✓ |

## 2 · Lo que hizo bien, y que los encargos 05 y 06 no hicieron

- **No heredó.** `INFORME.md` §5 dice explícitamente «recalculado para esta pregunta (no heredado
  del encargo 05)» sobre la multiplicidad `m` de D6. Era la instrucción del encargo y es lo que
  falló en los anteriores.
- **No propagó un error del encargo.** El `ENCARGO-07` que leyó contenía una **cuenta equivocada de
  Claude** (§4.1). El informe escribe la correcta: publicar exige `α > 1`, no `α > 0,5`.
- **Verificó contra el oráculo en vez de razonar en prosa.** U3″ entre ramas disjuntas se comprobó
  en cuatro casos con GDR-v0.2, no se argumentó.
- **Etiquetó con honestidad**, incluido lo que no midió (§3 de este documento).

## 3 · El resultado, y lo que Claude añade

### 3.1 · El umbral es `1/2`, igual que PoW — y el `SR` endógeno no es vector

`α_mínimo = 1/2` exacto para PoW lineal, GHOSTDAG sobre PoW y PoST-DAG, en ambos regímenes.

La razón es una **identidad, no una estadística**: la tasa de soluciones válidas es `∝ SR` y el peso
es `w(B) = ⌊2^128/(SR+1)⌋ ∝ 1/SR`, así que **el producto se cancela**. Un adversario que fuerce un
`SR` bajo obtiene bloques más pesados y proporcionalmente menos frecuentes.

**Esto descarta la sospecha principal con la que se escribió el encargo** (§3.2 del `ENCARGO-07`):
el controlador de rango **no** es explotable para inflar `blue_work` en media. El riesgo que sí
queda es de **varianza** —fijar `sr` bajo compra cola con el mismo trabajo medio: `P(adv > hon)`
sube de 0,022 a 0,308 con `K = 64`—, y de ahí sale la propiedad MUST que `PROPUESTA.md` pide para
R-FIN-13′.

### 3.2 · Un hueco declarado no medido, acotado por Claude

`INFORME.md` §8 declara **no medido** el efecto de «rojos asimétricos»: un adversario que construye
en privado, sin latencia, podría sufrir menos bloques rojos que la red honesta, y tener por tanto
más `blue_work` efectivo por unidad de espacio.

Claude lo acota con datos que ya existen en el repositorio. Si la honesta pierde una fracción `f`
del trabajo por rojos y el adversario no pierde nada, el umbral pasa a `α > (1−f)/(2−f)`:

| fracción roja honesta | origen | `α_mínimo` |
|---|---|---|
| 0,0000 | ronda 11a, Δ = 4 s | **0,5000** |
| 0,0020 | ronda 11a, Δ = 8 s | 0,4995 |
| 0,0828 | ronda 11a, Δ = 12 s | 0,4784 |
| 0,2858 | ronda 11a, Δ = 16 s | 0,4166 |

La Δ medida en `veritas/finalidad/delta-medido-v1/` es **0,26–0,60 s** (Δ_99 p99), unas **25 veces
por debajo** del primer escalón de la tabla, donde la fracción roja ya es 0,0000.

**Conclusión: con la Δ medida el efecto no mueve el umbral.** El hueco queda acotado, no cerrado por
medición directa; si Δ se degradara por encima de ~10 s, habría que medirlo de verdad.

### 3.3 · El único vector que baja el umbral, y no es nuevo

**Multistream de PoT**, que es el **ATAQUE 2** de `research/dag-poas-auditoria.md` (2026-09-06), ya
calificado allí de **gravedad crítica**. Cuota efectiva `S·α/(1−α+S·α)`, luego `α_mín = 1/(S+1)`:

| `S` | 2 | 4 | 8 | 16 | 24 |
|---|---:|---:|---:|---:|---:|
| `α_mínimo` | 0,333 | 0,200 | 0,111 | 0,059 | **0,040** |

`S ≈ 24` es el límite de IOPS de un SSD de 100 k. **Coste: `S` núcleos más IOPS, cero espacio
adicional.**

Lo que este instrumento aporta no es el ataque —ya estaba— sino **convertirlo de «sospecha fuerte»
en un número**, y establecer que es **el único** vector medido que mueve el umbral.

La auditoría original ya decía de qué depende: «una regla (validez del PoT en DAG) que la propuesta
no escribe; cualquiera de las dos opciones falla (split o esto)». Esa regla sigue sin escribirse y
está inventariada en `TAREAS.md` §2.1 como «inyección de entropía y **dependencias por flujo**».

## 4 · Errores de Claude en este encargo

### 4.1 · Una cuenta equivocada en el encargo

`ENCARGO-07` §3.1 afirmaba que si el adversario publica en la honesta —que crece a `λ`— y además
construye en privado a `α·λ`, «necesita `α > 0,5`». **Falso:** eso exige `α > 1`. El `α > 0,5`
aparece sólo en el caso en que **no** publica, donde la honesta crece a `(1−α)·λ`.

Lo encontró una revisión externa. **Es el peor sitio donde se puede colar un error**: una cuenta mal
escrita en un encargo se propaga al modelo que lo ejecuta. El ejecutor **no** la propagó, pero eso
fue suerte, no diseño. Corregido en el encargo, con la corrección anotada a la vista.

### 4.2 · Editar un archivo que estaba en uso

Claude corrigió `ENCARGO-07-coste-rama-privada.md` a las **00:31**, con el instrumento ya en marcha
(`Project.toml` a las 00:19, `INFORME.md` a las 00:33). **No se sabe qué versión leyó el ejecutor**,
y esa incertidumbre es un fallo de procedencia aunque el resultado saliera bien.

Un encargo en ejecución **no se edita**: se anota la corrección aparte y se comunica, o se espera al
cierre. Que el informe escriba la cuenta correcta no prueba que viera la corrección; pudo deducirla.

### 4.3 · Lo que no vio Claude en el encargo anterior

Los defectos del encargo 06 (`veritas/consenso/prueba-recursiva-v1/PROCEDENCIA.md` §3) estaban
**escritos en los docstrings del código que Claude reejecutó**, y no los vio: reprodujo los
experimentos y de ahí pasó a dar por bueno el veredicto. **Reproducir no es validar.**

## 5 · Límites que el instrumento declara, y se conservan

- El acoplamiento espacio↔solución es **supuesto declarado**; `sr0` y `λ0` son de normalización.
- El multistream es **condicional** al diseño del flujo de PoT, no un veredicto.
- **R-FIN-13′ no está especificado**: el resultado sobre el controlador es una **familia** y una
  **propiedad**, no una constante. La curva corta con controlador real queda **inconclusa**.
- El efecto de rojos asimétricos: **no medido** por el instrumento; acotado en §3.2 de este
  documento con la Δ ya medida.
- `F = 2 h` **no se usa** en ninguna cifra, por orden del encargo.
