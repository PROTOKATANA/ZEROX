# ADENDA 1 al encargo P-CIERRE — fase 1 validada; se AUTORIZA la fase 2

**De:** Claude (validador), 2026-09-20. **Solo lectura.** Regístrala en `PROGRESO.md`. **Solo tiene efecto
si Katana te la entrega**: él confirma D-3, D-9 y D-10.

## 1 · Validación de la fase 1

Comprobado por el validador: entrada congelada íntegra; `SPEC.md`, `TAREAS.md` y `ci/` sin tocar; los
cuatro `PROCEDENCIA.md` idénticos byte a byte a los de `P-CIERRE/procedencia/`; 0 fallos en las
`HUELLAS.sha256` de los cuatro destinos; el **único** cambio de código es la ruta del `include` de GDR en
`AnclaInyeccion.jl` (diff completo de `src/` revisado); `puerta-cobertura-v1/src` idéntico; sin restos en
la raíz del repositorio. Del plan: **leídas las 14 dudas y seis ediciones delicadas** (E-26, E-31, E-35,
E-40, E-47 y la estructura); **no comparadas línea a línea las 55**. El diff final se revisa antes del commit.

Bien visto lo del control de identidad escrito en el CWD. **Añade a `TAREAS.md` (Nivel 5, deuda de
evidencia)** que ANCLA-v0.2 escribe `resultados/` relativo al directorio de trabajo y no al del instrumento.

## 2 · Las 14 dudas: se aprueba lo que haces por defecto

D-1, D-2, D-4, D-5, D-6, D-7, D-8, D-11, D-12, D-13 y D-14: **conforme**. Y, confirmadas por Katana:

- **D-3:** se traslada `C-FLU-02`; su medición pendiente queda en `TAREAS.md` §2.9 como **condición
  incumplida declarada**, no como trabajo opcional.
- **D-9:** se retiran de `C-FLU-17` las dos frases que D-F9 = C superó; vale tu redacción compatible.
- **D-10:** vale tu reescritura de `C-REORG-07` («mientras las dos convivan, la que rige el destino es
  `C-FIN-01`; `C-REORG-07` describe lo que el código hace hoy»).

## 3 · Dos correcciones al plan antes de aplicar

1. **E-31 se contradice con E-40.** La nota ⚠️ de `C-FIN-01` dice que el SPEC «ordena que no se publiquen
   ambas como simultáneamente activas», pero esa frase vive en `C-REORG-07` y **E-40 la sustituye**.
   Reescribe la nota para que diga lo que va a ser verdad después de las dos ediciones: conviven dos reglas
   de profundidad, rige `C-FIN-01`, `C-REORG-07` es transitoria, y la reconciliación sigue pendiente
   (§13, `TAREAS.md` §2.9).
2. **E-47 afirma sin reserva «el umbral del diseño con un solo flujo es `α_mínimo = 1/2` … y eso no ha
   cambiado».** Esa cifra es de CRP-v0.1, que tú mismo señalas en §8.1(2) que CRP-v0.2 declara «baseline
   idealizado; veredicto protocolario inconcluso», con v0.2/v0.3 sin validar. **Añade la reserva en la
   misma frase** y remite a §2.9(e). Es exactamente el titular ancho que este cierre viene a corregir: no
   lo sustituyas por otro.

## 4 · Fase 2

Aplica el plan con esas dos correcciones, en el orden de tu §10. Después: los cuatro guardianes en verde,
`cargo test --workspace` sin regresiones (581 / 0 / 6), y `P-CIERRE/ejecucion/INFORME.md` con
`git diff --stat`, el recuento de `ci/citas-spec.sh` antes/después y **todo lo que quedó distinto del plan**.
**Sin commit.** Si al aplicar aparece algo que el plan no preveía, **para y pregunta**.
