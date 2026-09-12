# Identidad económica desde el verificador PoAS real

Fecha: 2026-09-11. Categoría: consenso. **Revisión documental y razonamiento condicional**,
sin ejecutar cálculos, simulaciones, tests ni Python en esta subtarea. Se han leído AGENTS,
README, MIGRACION, LINEO íntegro, SPEC §§6–7 y los informes CBE/identidad-copias. No se cambia
consenso de producción ni se atribuyen a este documento resultados del harness de otro agente.

Fuente primaria: `PDF/autonomys-subspace`, commit
`f8842d019cdf0f7163421b9644db5a9ff82b2a73`; árbol limpio al inspeccionarlo. Las referencias
`A/...` de abajo significan `PDF/autonomys-subspace/crates/...`. Son referencias a este checkout,
no una afirmación de que ZEROX ya integre sus reglas completas.

## 1. Recomendación concreta, condicionada

Recomiendo estudiar como identidad económica mínima:

```text
Opportunity = (dominio_económico_estable, slot, public_key,
               sector_index, history_size, piece_offset)
```

El dominio identifica la red y, únicamente si el protocolo lo define, una era económica estable.
No es un identificador libre del productor, un hash de padres, un rango de solución ni una nueva
era por bifurcación. **Esta recomendación no congela todavía la serialización ni la regla entre
flujos PoT.** Requiere cerrar qué retos e historias admitidos comparten derecho económico.

En un contexto archivado fijo y autenticado, `chunk` es redundante para distinguir la oportunidad,
bajo binding KZG y resistencia a colisiones de los hashes empleados: los campos anteriores
determinan la pieza, su compromiso de registro y el s-bucket; ese compromiso tiene un único valor
escalar admisible en ese índice. `piece_offset`, en cambio, no es redundante: participa en la
semilla PoS y en la selección de pieza. Dos offsets no deben colapsarse sólo porque sus chunks
sean iguales. La afirmación sobre `chunk` es unicidad criptográfica **condicionada**, no una
medición ni un teorema de coste de almacenamiento. Se desarrolla en §3.

La recomendación omite firma, dirección de recompensa, cuerpo, padres y bytes de prueba. Cambiar
esos envoltorios no debe crear un segundo derecho por sí solo. Pero una prueba alternativa puede
cambiar la **elegibilidad antes de adjudicar**: deduplicar el pago no elimina esa selección.
Ese problema requiere su propia prueba o medición (§4).

## 2. Qué verifica exactamente la fuente fijada

Sea C un contexto de validación autenticado: versión/reglas y dominio de red, slot, salida PoT
admitida, rango, raíces de historia y parámetros de selección/vida de sectores. C no se obtiene
aceptando parámetros libres de quien presenta la solución. Con esos datos:

```text
sector_id = Blake3_keyed(hash(public_key), LE(sector_index) || LE(history_size))
global_challenge = Blake3(Blake3(pot_output) || LE(slot))
sector_slot_challenge = sector_id XOR global_challenge
s_bucket = LE_u16(primeros 2 bytes de sector_slot_challenge)
seed = Blake3(sector_id || bytes(piece_offset))
masked_chunk = chunk XOR Blake3(proof_of_space)
distance = distancia circular de los valores u64 derivados del reto y masked_chunk
elegible por rango si distance <= floor(solution_range / 2)
```

No se sustituye XOR por hash ni se confunde el `chunk` escalar decodificado de la solución con
el chunk enmascarado que lee la auditoría del plot. Fuentes:

- `A/subspace-core-primitives/src/sectors.rs:34`, `:56`, `:117`, `:126`:
  bucket, sector_id, reto de sector y semilla.
- `A/subspace-core-primitives/src/pot.rs:272` y `src/lib.rs:108`: reto global.
- `A/subspace-verification/src/lib.rs:120` y `:228`: distancia y aplicación al verificador.
- `A/subspace-farmer-components/src/plotting.rs:648`: el plot enmascara usando la prueba que
  devuelve `find_proof`; `src/proving.rs:257` y `:317`: reconstrucción y envío del chunk escalar.

`verify_solution` comprueba PoS para seed/bucket, rango y apertura KZG del chunk. Con
`piece_check_params=Some(...)` comprueba además límite de historia, offset y pertenencia del
compromiso de registro a la historia suministrada; la comprobación de expiración tiene a su vez
un compromiso opcional. Véase `A/subspace-verification/src/lib.rs:208`, `:240`, `:263`, `:274`,
`:303`, `:325`. El límite `history_size <= current_history_size + 1` tiene una explicación local
sobre incorporación de una raíz nueva; no se traslada aquí como decisión para el DAG.

**Frontera de validación:** `piece_check_params=None` no demuestra pertenencia al archivo,
límite de offset/historia ni expiración. El `Some` exterior tampoco vuelve obligatoria la rama
opcional de expiración. La función recibe una salida PoT; no autentica por sí sola toda su cadena,
flujo o admisibilidad temporal. Tampoco valida cuerpos, sello DAG, selección de padres ni orden.
Un harness parcial debe declarar esas omisiones, aunque obtenga `Ok(distance)`.

## 3. Equivalencia de declaraciones y redundancia de chunk

Fijado C, sean V_C las soluciones criptográficamente válidas bajo las comprobaciones exigibles,
incluida pertenencia a una historia confiable. Definimos provisionalmente:

```text
s ~_C s'  si sus (pk, sector_index, history_size, piece_offset, slot) coinciden.
```

La igualdad de esta proyección es reflexiva, simétrica y transitiva. Eso establece una relación
de equivalencia matemática, **no** demuestra todavía que cada clase corresponda a la misma
cantidad de recurso ni que todas las clases tengan probabilidades equitativas.

Para dos soluciones de una clase, el sector_id y la semilla coinciden. La selección de pieza
también coincide, siempre que C fije `max_pieces_in_sector`, `recent_segments` y
`recent_history_fraction` (`A/subspace-core-primitives/src/sectors.rs:72`). El contexto debe
seleccionar el compromiso de segmento correspondiente al índice de pieza derivado, no uno
aportado arbitrariamente por el productor.

Bajo binding de esa apertura y resistencia a colisiones del hash de compromiso usado por
`is_record_commitment_hash_valid`, queda fijado el compromiso de registro
(`A/subspace-verification/src/lib.rs:325`). Bajo binding de su apertura en el s-bucket fijo,
queda fijado el escalar `chunk` (`:263`). Esta cadena justifica omitir el escalar de la identidad
en C; no implica poder recuperarlo eficientemente sin los datos. Se presupone también el
tratamiento canónico/validación de representaciones de escalares, puntos y compromisos por las
primitivas llamadas; aquí no se reauditan KZG ni sus supuestos criptográficos.

En consecuencia, no se debe confundir:

| Cambio | Dependencia observada | Conclusión permitida |
|---|---|---|
| `pk`, `sector_index`, `history_size` | Cambian sector_id, semilla y selección de pieza. | Cambian la declaración; no está probado aquí cuánto espacio/tiempo adicional cuesta servirla. |
| `piece_offset` | Cambia semilla y selección de pieza. | Es coordenada relevante aunque dos piezas o chunks coincidan; igualdad de datos no demuestra igualdad de oportunidad. |
| `chunk` | Apertura de un registro en un índice fijado por C. | No es un nonce libre bajo binding; es redundante en una clase validada con C fijo. |
| `slot` | Cambia el reto global y potencialmente el bucket. | Es una nueva ronda de la definición candidata; no exige nuevo almacenamiento ni constituye por sí solo tiempo físico. |
| Salida/flujo PoT | La salida cambia el reto global; no existe un campo libre `flow_id` dentro de `verify_solution`. | Hace falta una regla externa de admisión y equivalencia entre contextos; no añadir automáticamente un nuevo derecho por hash de flujo. |
| Prueba PoS | Se verifica y su hash enmascara el chunk. | Representaciones válidas de la misma clase pueden afectar elegibilidad; §4, sin afirmar que una mutación arbitraria sea válida. |
| Testigos KZG | Certifican la declaración contra compromisos. | Sus bytes no necesitan formar parte de la identidad; no se afirma unicidad de representación de todos los testigos. |
| Recompensa, sello, cuerpo, padres | No entran en la distancia de esta función. | No crean derecho por sí solos; padres pueden cambiar C y el orden, y la autorización de envoltorios corresponde al protocolo exterior. |

`Solution` enumera sus campos en `A/subspace-core-primitives/src/solutions.rs:254`; su método
`:277` transforma el formato de la dirección de recompensa sin reconstruir la prueba.
No contiene un campo autónomo `proof_nonce`. `PosProof` es un arreglo de bytes con K=20 y hash
Blake3 (`A/subspace-core-primitives/src/pos.rs:101`): sus grados de libertad admisibles se buscan
en el verificador, no inventando un nonce libre.

La equivalencia entre soluciones de **distintos** C no queda resuelta por demostrar ~_C.
Para retirar el flujo de Opportunity debe decidirse qué contextos alternativos del mismo slot
consumen el mismo derecho y analizar su efecto sobre elegibilidad. Si cambia la raíz archivada o
el reto, la unicidad de chunk demostrada dentro de C no demuestra igualdad de chunks entre C.
Tampoco obliga a convertir cada raíz o rango alternativo en una oportunidad cobrable nueva.

## 4. Unicidad contable no es unicidad de elegibilidad

Para seed/bucket fijos, sea P_C el conjunto de pruebas aceptadas por el verificador PoS. El farmer
ordinario usa una prueba `p0` obtenida por su generador. Para una clase con chunk fijo, el predicado
que puede explorar quien tenga acceso a alternativas válidas es:

```text
existe p en P_C : distance_C(chunk XOR Blake3(p)) <= floor(range_C / 2)
```

El evento para `p0` está contenido en ese evento existencial. La inclusión es lógica; no demuestra
que sea estricta en una instancia dada, cuántas alternativas existan, que sus distancias sean
independientes, cuánto cueste obtenerlas ni la ventaja económica resultante. No se calcula aquí
una probabilidad ni se afirma un ataque completo con dos PoAS ganadoras.

La separación entre generación y verificación sí aparece explícitamente en las fuentes:

- `A/subspace-proof-of-space/src/chia.rs:58` elige `.next()` del iterador.
- El mismo archivo `:46` verifica mediante `Tables::verify_only`; no exige igualdad a aquella
  primera prueba. `src/chia_v2.rs:53` delega en ese mismo verificador aunque genere de otra forma.
- `src/chiapos/tables.rs:191` enumera candidatos; `:296` verifica los valores internos y el prefijo
  final del reto, sin demostrar minimalidad ni unicidad del candidato elegido.
- `src/chiapos/tables/tests.rs:175` documenta cambios de selección por desempate, y `:280`
  verifica cada prueba enumerada. Es evidencia de diseño/test escrito, no una ejecución nueva
  ni por sí sola un vector con cardinalidad mayor que uno.

La auditoría del farmer examina múltiples chunks del bucket, no una única oportunidad por
sector/bucket (`A/subspace-farmer-components/src/auditing.rs:236`). Al preparar soluciones se
asocia cada candidato a `piece_offset` (`src/proving.rs:393`) y se obtiene la prueba (`:300`).
Una prueba alternativa para el mismo chunk puede no coincidir con la usada para codificar el
plot. Determinar si el adversario puede aprovecharla a tiempo exige considerar recuperación del
registro, testigos, enumeración y cómputo. No se da por gratuito todo ese trabajo, ni se exige sin
prueba almacenar otro sector completo para efectuarlo.

**Consecuencia de diseño:** no añadir `proof_hash` a Opportunity para cobrar variantes. Tampoco
afirmar que omitirlo neutraliza el grinding. Exigir «la primera prueba» sería una regla nueva cuya
canonicidad y coste de verificación habría que resolver; el verificador actual no la impone.

## 5. Contrato mínimo condicional antes de integrar

1. **Dos claves, dos finalidades.** Opportunity clasifica el derecho según §1. Una clave de caché
   de validación debe incluir el contexto autenticado completo relevante (reto/salida PoT,
   rango, raíces confiables, parámetros, versión) y la declaración/pruebas efectivamente
   verificadas. Una caché que sólo use Opportunity podría reutilizar indebidamente un éxito para
   otra prueba o rango. El hash de contexto de caché no se convierte en identidad económica.
2. **Validación antes de adjudicación.** Usar las comprobaciones PoAS completas exigidas por el
   protocolo, autenticar PoT/raíces y el envoltorio. No confundir prueba faltante con inválida,
   ni descartar un cuerpo obligatorio porque la identidad ya esté consumida. El perfil DA0 sigue
   requiriendo todos los cuerpos nuevos y no ofrece garantía de disponibilidad adversarial
   (`veritas/consenso/contrato-billete-v1/CONTRATO.md:70`, `:84`).
3. **Consumo único contextual y reversible.** Una clase elegible se adjudica como máximo una vez
   en cada historia aplicada; registro, ejecución, conteo y emisión comparten el evento. Es la
   propiedad contable de CBE, condicionada a identidad, orden y elegibilidad. No demuestra que el
   número de clases o su probabilidad estén correctamente calibrados respecto del espacio.
4. **Cerrar el dominio antes de congelar TicketId.** Especificar equivalencia entre retos/raíces
   admisibles del mismo slot, sin que rango, padres o un flujo elegido por el productor regeneren
   el derecho. Esa regla puede agrupar oportunidades de ramas, pero no elimina la capacidad de
   probar varios retos si el protocolo las admite; hay que modelar esa selección separadamente.
5. **Medir/probar el conjunto de oportunidades.** Relacionar las clases declaradas por pk,
   sector, historia y offset con recursos efectivos, y la multiplicidad de pruebas con el evento
   de elegibilidad. No alimentar el retarget con una pretendida tasa de billetes únicos hasta
   cerrar esa relación y su ventana. Ningún umbral de ventana ni tiempo de Cortex se fija aquí.

## 6. Evidencia siguiente que discrimina las hipótesis

El harness real separado debe poder identificar exactamente qué nivel demuestra:

- Dos offsets con chunk idéntico y pruebas/contexto válidos distinguen declaraciones que una
  identidad sin offset colapsaría. Una fixture sintética puede probar la necesidad estructural
  del campo sin demostrar por sí sola el coste o la tasa de esas declaraciones en un plot real.
- Dos pruebas distintas aceptadas para el mismo seed/bucket refutan la unicidad PoS en esa
  instancia. La prueba debe pasar el verificador real, no sólo proceder de un generador distinto.
- Mantener chunk, compromisos/testigos y contexto fijos, variar únicamente una prueba PoS
  aceptada y comprobar `verify_solution` discrimina el efecto real sobre la distancia y el rango.
  Debe declarar si omite piece checks o usa historia/rango sintéticos: eso no sería validación
  integral de una oportunidad de ZEROX. El rango del experimento debe registrarse, no presentarse
  como parámetro adoptado si se elige sólo para construir un caso.
- La conclusión de ventaja efectiva exige además disponibilidad de las alternativas antes del
  deadline, coste de obtenerlas y adversario compuesto. No sale de un único par ni de la unicidad
  del registro. No se programan ni ejecutan esos experimentos en este documento.

**Dictamen:** hay fundamento para recomendar Opportunity sin `chunk` bajo contexto archivado
fijo, pero conservando `piece_offset`. La equivalencia entre contextos y la amplificación de
elegibilidad siguen siendo obligaciones concretas, no razones para añadir campos arbitrarios.
Este resultado orienta la identidad y el harness; no certifica aún finalidad, disponibilidad real,
seguridad económica global ni la semántica final del retarget.
