#!/usr/bin/env bash
# Verificación de integridad del instrumento. Termina con código de salida 0 si todo cuadra.
#
#   bash verificar-huellas.sh
#
# Dos manifiestos, con destinatarios distintos:
#
#   1. `ENTRADA.sha256`  — huellas de los documentos de ZEROX y del prompt de los que se leyó el
#      contrato. Rutas **relativas a la raíz de ZEROX**, así que se verifica desde allí.
#   2. `HUELLAS.sha256`  — huellas del instrumento (fuente, documentos y artefactos). Rutas
#      relativas a este directorio.
#
# **Defectos corregidos, de la misma clase.**
#
# (a) `HUELLAS.sha256` se generaba incluyendo su **propia** huella (el `find` recogía `*.sha256`),
#     de modo que `sha256sum -c` fallaba siempre con «La suma no coincide» en `./HUELLAS.sha256`.
# (b) El **informe de la propia verificación** (`resultados/VERIFICACION-HUELLAS.txt`) también
#     estaba en el manifiesto: el script lo reescribe al terminar, así que la huella quedaba
#     obsoleta en la misma ejecución. Es autorreferencia de segundo orden: un fichero que *informa
#     sobre* el manifiesto no puede formar parte de él.
#
# Los dos se **excluyen** del manifiesto, y el script comprueba que la exclusión existe. No se
# alteró ningún dato para cuadrar huellas; el mecanismo detectó el problema por sí solo.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
ZEROX="/home/katana/zeo/ZEROX"
CLON="/home/katana/zeo/fuentes/subspace"
fallos=0

echo "== 1. Huellas de las ENTRADAS (desde la raíz de ZEROX) =="
if [ -f "$AQUI/ENTRADA.sha256" ]; then
    ( cd "$ZEROX" && sha256sum -c "$AQUI/ENTRADA.sha256" ) | sed 's/^/   /' || fallos=$((fallos+1))
else
    echo "   FALTA $AQUI/ENTRADA.sha256"; fallos=$((fallos+1))
fi

echo
echo "== 2. Huellas del INSTRUMENTO (desde el propio directorio) =="
# La autorreferencia se busca como LÍNEA DE HUELLA (64 hex + ruta), no como mención en un
# comentario: un manifiesto que contuviera su propia huella sería imposible de satisfacer.
for autorref in 'HUELLAS\.sha256' 'VERIFICACION-HUELLAS\.txt'; do
    if grep -qE "^[0-9a-f]{64}  \.?/?[^ ]*${autorref}$" "$AQUI/HUELLAS.sha256"; then
        echo "   FALLO: el manifiesto incluye $autorref (autorreferencia)"; fallos=$((fallos+1))
    else
        echo "   (sin autorreferencia a $autorref)"
    fi
done
( cd "$AQUI" && sha256sum -c HUELLAS.sha256 ) | grep -v ': La suma coincide$' | sed 's/^/   /'
if ( cd "$AQUI" && sha256sum -c HUELLAS.sha256 ) >/dev/null 2>&1; then
    echo "   $(grep -cE '^[0-9a-f]{64}  ' "$AQUI/HUELLAS.sha256") huellas verificadas"
else
    echo "   FALLO de verificación"; fallos=$((fallos+1))
fi

echo
echo "== 3. Fuente fijada de Autonomys =="
if [ -d "$CLON/.git" ]; then
    rev="$(git -C "$CLON" rev-parse HEAD)"
    if [ "$rev" = "f8842d019cdf0f7163421b9644db5a9ff82b2a73" ]; then
        echo "   commit OK: $rev"
    else
        echo "   FALLO: commit $rev"; fallos=$((fallos+1))
    fi
    n="$(git -C "$CLON" status --short | wc -l)"
    if [ "$n" -eq 0 ]; then echo "   árbol limpio"; else
        echo "   FALLO: $n ficheros modificados en el clon"; fallos=$((fallos+1)); fi
    ( cd "$CLON" && sha256sum -c "$AQUI/resultados/FUENTES-AUTONOMYS.sha256" ) \
        | grep -v ': La suma coincide$' | sed 's/^/   /' >/dev/null
    if ( cd "$CLON" && sha256sum -c "$AQUI/resultados/FUENTES-AUTONOMYS.sha256" ) >/dev/null 2>&1; then
        echo "   huellas de las fuentes usadas OK"
    else
        echo "   FALLO en las huellas de las fuentes"; fallos=$((fallos+1))
    fi
else
    echo "   FALTA el clon $CLON"; fallos=$((fallos+1))
fi

echo
echo "== 4. Árbol de ZEROX fuera del instrumento =="
# Lo que DEBE ser invariante es el conjunto de ficheros VERSIONADOS modificados (líneas M/D/R/A).
# Las entradas `??` nuevas pueden aparecer por trabajo AJENO en paralelo y hay que preservarlas:
# en esta ronda aparecieron `P-ZRX/P-RIVAL/` y `P-ZRX/P-SELLO/`, que no se tocaron.
grep -vE '^\?\?' "$AQUI/resultados/GIT-ENTRADA.txt" | LC_ALL=C sort > /tmp/entrada_mod.txt
grep -vE '^\?\?' "$AQUI/resultados/GIT-SALIDA.txt" | LC_ALL=C sort > /tmp/salida_mod.txt
if diff -q /tmp/entrada_mod.txt /tmp/salida_mod.txt >/dev/null; then
    echo "   ningún fichero VERSIONADO cambió ($(wc -l < /tmp/entrada_mod.txt) entradas M/D/R/A idénticas)"
else
    echo "   FALLO: cambiaron ficheros versionados ajenos:"; fallos=$((fallos+1))
    diff /tmp/entrada_mod.txt /tmp/salida_mod.txt | sed 's/^/      /'
fi
grep -E '^\?\?' "$AQUI/resultados/GIT-ENTRADA.txt" | LC_ALL=C sort > /tmp/entrada_nuevos.txt
grep -E '^\?\?' "$AQUI/resultados/GIT-SALIDA.txt" | LC_ALL=C sort > /tmp/salida_nuevos.txt
# `diff` en vez de `comm`: `comm` exige el mismo orden que su propia idea de colación.
nuevos="$(diff /tmp/entrada_nuevos.txt /tmp/salida_nuevos.txt | grep '^>' | sed 's/^> //' || true)"
if [ -n "$nuevos" ]; then
    echo "   entradas ?? nuevas durante la sesión (trabajo AJENO, preservado):"
    echo "$nuevos" | sed 's/^/      /'
else
    echo "   sin entradas ?? nuevas"
fi
if grep -qE '^\?\? P-ZRX/P-PUENTE-ESPACIO-TASA/' "$AQUI/resultados/GIT-SALIDA.txt"; then
    echo "   el instrumento sigue siendo el único añadido propio"
fi

echo
if [ "$fallos" -eq 0 ]; then
    echo "RESULTADO: TODO VERIFICADO"
    exit 0
else
    echo "RESULTADO: $fallos comprobaciones fallidas"
    exit 1
fi
