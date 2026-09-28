# Encargo 04 — alternativa con nuevo formato de parcela

**Tipo:** investigación autorizada de alternativa; no es decisión de migrar.
**Apertura:** la brecha del formato antiguo está documentada en `P-COBERTURA`
y el usuario ha pedido evaluar precompromiso + PoRep + auditorías. La
conclusión depende de G1/G2 y del coste de replotear. **Zona de entrega:**
`P-ZRX/P-REGISTRO-SECTORES/investigacion/04-formato-alternativo/`.
**Prohibido:** sustituir el formato actual en consenso, añadir criptografía
casera o prometer una barrera absoluta basada solo en hardware medido.

## Pregunta falsable

¿Puede un formato con sellado ligado a identidad, datos y aleatoriedad de la
cadena aportar una propiedad temporal o de retención que el PoAS actual no
ofrece, con coste honesto y migración aceptables?

## Trabajo

1. Fijar la propiedad ausente: prueba de cómputo completo, dificultad de
   regeneración dentro de una ventana o dependencia no reutilizable de la
   cadena. Mostrar cuál hipótesis del argumento de simulación de
   `P-COBERTURA` cambia; una raíz nueva sin cambiar la generación no basta.
2. Comparar al menos: sellado secuencial con prueba verificable, codificación
   con aleatoriedad posterior al precompromiso y una opción sin cambio de
   formato que acepte expresamente solo encarecimiento. Usar PoRep de
   Filecoin como referencia de propiedades, no importar su SNARK o sus
   parámetros por analogía.
3. Para cada candidato, especificar identidad de sector, derivación de
   aleatoriedad finalizada, datos públicos/secretos, circuito o prueba
   auditada, seguridad frente a precomputación, compresión, reutilización
   entre identidades/ramas, aceleración y paralelismo. Si una opción exige
   secreto del granjero, estudiar pérdida y recuperación de la clave.
4. Medir tiempo de plot/seal honesto y adversarial, verificación, tamaño de
   prueba, capacidad temporal de disco, rendimiento de farming y retardo de
   entrada. Contrastar con el adelanto PoT y la ventana de auditoría; incluir
   hardware acelerado y sensibilidad, no solo la máquina local.
5. Diseñar migración versionada: convivencia y orden entre parcelas viejas y
   nuevas, nuevas identidades, replot completo o parcial, inicialización,
   poda, hardware doméstico y coordinación con el arranque PoW temporal de
   POS2T. Mostrar si una ventaja en oportunidades surge del nuevo formato y
   cómo impedir que el stake la amplifique.

## Salida y criterio de cierre

Entregar `PROPIEDAD.md`, `MODELO.md`, `INFORME.md`, perfil reproducible y
`DECISIONES-PENDIENTES.md`. Concluir **descartar**, **investigar una primitiva
auditada concreta** o **preparar propuesta de migración**. La tercera salida
requiere una ventaja demostrada bajo hipótesis explícitas y un coste de
entrada/reploteo cuantificado; nunca se deriva solo de que Filecoin use PoRep.

Leer `V-ZRX/LINEO.md` antes de programar auditorías. Julia CPU y C++/CUDA
solo cuando corresponda; no crear auditorías Python.
