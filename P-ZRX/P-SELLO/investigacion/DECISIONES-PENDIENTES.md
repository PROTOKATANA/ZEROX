# DECISIONES-PENDIENTES — P-SELLO

**La vía está muerta.** No hay ninguna bifurcación de diseño que Katana pueda decidir para salvarla:
`T_bajo` barato implica regenerable y `T_bajo` caro implica que el honesto no llega, y las dos cosas
están demostradas sobre la clase de objeto que el formato permite (`INFORME.md` F1/F3). Este fichero
no inventa decisiones.

**Única acción de registro (no es una decisión de protocolo):** cerrar la fila **13** de
`P-ZRX/PROPUESTAS-VIABLES.md` con este informe, del mismo modo que se cerraron las filas 1, 6, 7 y 11,
y anotar las dos correcciones a premisas ajenas que la revisión de fuentes encontró:

1. **`P-ZRX/PROPUESTAS-VIABLES.md`, fila 13, nota del 2026-09-23** — la pregunta «¿es coherente
   “barato de re-ligar pero obligatorio de almacenar”?» tiene respuesta **no** para la clase
   determinista-pública, y **no** hay primitiva abierta que la haga posible fuera de esa clase.
2. **Encargo §2.3, primera viñeta** — la afirmación de que «la propia investigación de Filecoin
   identifica minar varias ramas con el mismo almacenamiento como problema abierto» **no se sostiene
   en las fuentes abiertas**: lo que Filecoin dice es que ata el sellado a la cadena contra **ataques
   de largo alcance** (`sealing.md:41`) y que retroceder un mes exigiría regenerar todo (`sealing.md:81`);
   no hay una regla ni un problema abierto declarado sobre ramas coetáneas. La segunda parte —«el
   sellado compromete una rama solo desde ese sellado»— **sí** está respaldada, con el matiz de que la
   ligadura es a la **época/ticket**, no a la rama.

**Lo único que reabriría la vía** (y no depende de ZEROX, sino de una primitiva): una prueba sucinta
que distinga «almacenado» de «regenerado dentro del plazo» sin cambiar el objeto. Es exactamente lo que
`P-ZRX/P-COBERTURA/` demuestra imposible para el formato fijado. **No se propone seguir buscándola en
esta familia.**
