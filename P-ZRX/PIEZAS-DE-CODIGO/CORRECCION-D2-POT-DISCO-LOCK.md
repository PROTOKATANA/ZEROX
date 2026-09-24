# Corrección de alcance · D2 PoT/disco

La primera ejecución quedó interrumpida al detectar que editó `Cargo.lock` antes de detenerse como exigía la orden. El líder inspeccionó el diff: solo añadió `"zx-pot"` a las dependencias de `zx-node`, sin cambiar versiones ni paquetes. La arista directa de test en `crates/zx-node/Cargo.toml` requiere esa entrada para usar `--locked`; `ORDEN-D2-POT-DISCO-DEV.md` queda actualizada y autoriza **solo** esa línea. Esta autorización provisional de integración no fija parámetros de consenso ni toca código de producción.

Retoma la orden actualizada. Verifica que `Cargo.lock` conserve exclusivamente esa línea; completa el test y los comandos de comprobación. No hagas commit ni push. Si necesitas editar otros archivos o ampliar el lock, detente y repórtalo.
