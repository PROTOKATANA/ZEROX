# Decisiones pendientes — P-RNG

Ninguna opción siguiente está decidida. Las recomendaciones son de esta investigación, no de Katana.

| Decisión real | Opción | Qué gana | Qué paga/reabre | Qué cierra |
|---|---|---|---|---|
| D1. Objetivo | A: buscar un coste universal; B: tarifar por ataque | A promete una narrativa simple; B conserva restricciones | A conduce a PoW material o rediseño de parcela; B deja riesgos separados | **Recomendación: B**; cierra la expectativa de equivalencia PoW |
| D2. Registro de parcelas | A: seguir sin registro; B: compromiso completo previo por lote | B demuestra edad/entrada y habilita permanencia | estado/acumulador, poda, altas, solución y migración | B cierra falsa antigüedad y capacidad instantánea, no multistream |
| D3. Edad | A: umbral; B: rampa `w(a)`; C: sin edad | A es simple; B reduce escalón; C mantiene entrada inmediata | A/B favorecen incumbentes y exigen calendario DAG | alquiler corto/sembrador, condicionado a medir la ventana adversarial |
| D4. Recompensa propia como garantía | A: solo madurez; B: vesting condicionado a parcela; C: slashing por doble billete | B cobra permanencia; C castiga una prueba estrecha | locks, liquidez, pruebas, reorg y emisión efectiva | abandono/doble uso demostrable; no ataque no publicado |
| D5. Caducidad C-EXP | A: conservar hasta medir; B: acortar; C: alargar | B sube recurrencia; C baja desgaste honesto | B energía/TBW regresivos; C abarata capacidad persistente | **Recomendación: A**; ningún cambio sin medición y calendario DAG |
| D6. Sellado nuevo | A: no; B: PoRep/sello reutilizable; C: sello ligado a ancestry | B encarece alta; C cobra ramas | B cambia parcela; C obliga al honesto a re-sellar forks | **Recomendación: A por ahora**; abrir investigación solo si B+H falla |
| D7. Trabajo por bloque | A: no; B: pequeño/simbólico; C: material | C es el único coste directo por rama | energía continua, ASIC/pools, nuevo híbrido y peso | **Recomendación: A**; B no aporta garantía, C roza/viola valores |
| D8. Unidad de estado/coste | A: por clave; B: por sector; C: por lote y byte | C amortiza costes y resiste Sybil económico | acumulador/lotes más complejos | **Recomendación: C**; evita tarifa fija regresiva por identidad |
| D9. Tolerancia a fallos | A: una auditoría falla y pierde; B: ventana y varias pruebas; C: salida voluntaria | A es simple; B/C protegen doméstico | B/C retrasan detección y agrandan regeneración posible | pendiente de medir red, apagados y regeneración |
| D10. Gate de adopción | A: texto; B: prototipo + medición homogénea | B evita seguridad por intuición | coste de investigación | **Recomendación: B**: comparar base/B/B+H/A+B+H con `C_certeza`, `q_fD_f`, `c_irr` y `ΔC_irr^ataque` |

## Secuencia propuesta

1. Decidir D1. Si se elige coste universal bajo las restricciones actuales, registrar que no hay
   candidata conocida y no fingir que una caducidad lo aporta.
2. Si se elige tarifar por ataque, decidir D2 y autorizar solo un prototipo fuera del SPEC.
3. Medir compromiso/estado, alquiler, resembrado y fallos domésticos antes de D3–D5.
4. Rechazar cualquier D6/D7 que no muestre primero qué ataque adicional cierra y su coste para el
   pequeño granjero bajo el mismo riesgo.

## Condiciones de descarte anticipado

- Registro cuya prueba no abarque todos los bytes: no demuestra antigüedad útil.
- Penalización basada en identidad sin valor bloqueado: Sybil la vuelve cero.
- Fianza que el recién llegado deba comprar: viola la entrada sin monedas.
- Edad o tarifa fija por identidad: regresiva y subdivisible.
- Sellado reutilizable presentado como exclusividad por rama: afirmación falsa.
- Trabajo “pequeño” presentado como seguridad principal sin demostrar que decide el ataque.
- Parámetro numérico elegido antes de medir coste, adversario y pérdida honesta: no adoptable.
