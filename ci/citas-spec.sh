#!/usr/bin/env bash
# ¿Hay reglas del SPEC que ningún código cita?
#
# Es la otra mitad de ci/alcance-consenso.sh. Aquella pregunta si hay código que nadie ejecuta;
# esta, si hay reglas que nadie implementa. Las dos han dado positivos graves en este proyecto.
#
# Una regla sin cita puede ser tres cosas, y solo la primera es un fallo:
#   - un hueco: la regla existe, el código debería cumplirla, y nadie la escribió
#   - una prohibición: la regla dice qué NO hacer, y no hay nada que citar
#   - trabajo futuro: la fase que la implementa no ha llegado
#
# Las dos últimas van en ci/reglas-sin-codigo.txt con su motivo. Las primeras fallan aquí.
#
# ⚠️ Citar en rango NO cuenta. `C-BLK-01..03` no lo encuentra ninguna búsqueda por número, y esa
# búsqueda es cómo se comprueba la trazabilidad. Se escriben los tres números.
#
# ── Tercer estado: citada pero sin cablear (decisión de Katana, B-07) ─────────────────────────
#
# Hasta la cabecera DAG este guardián solo conocía dos estados: citada o no citada. Y "citada" lo
# trataba como "implementada", que es un grep de por medio y no lo mismo. La cabecera DAG rompió
# esa equivalencia: `zx-core` y `zx-p2p` ganaron código real —tipos, parsers, máquina de estados,
# tests— para reglas que el nodo todavía no ejecuta, porque nada está cableado a `zx-node`.
#
# Quitarlas de reglas-sin-codigo.txt las dejaba sin vigilancia: este guardián ya no las mira, y
# ci/alcance-consenso.sh tampoco, porque solo vigila zx-consensus y zx-storage. Diez reglas en un
# punto ciego, tres de ellas citadas únicamente por una línea de comentario de cabecera de módulo.
#
# De ahí la tercera lista, que es el mismo patrón que ci/consenso-pendiente.txt en el otro eje:
#
#   ci/reglas-sin-codigo.txt    la regla no la cita nadie      (no hay código)
#   ci/reglas-sin-cablear.txt   la cita código que nadie ejecuta (hay código, falta la llamada)
#   ninguna de las dos          citada y en la ruta activa
#
# Un ID va en UNA de las dos, nunca en ambas, y el guardián falla en los dos sentidos: si una regla
# de sin-cablear deja de estar citada, está mal archivada; si una de sin-codigo aparece citada,
# hay que moverla. Cuando el relé se cablee, mover la regla deja de ser opcional.
#
# ⚠️ LÍMITE, dicho aquí para que nadie se confíe: borrar una regla de las DOS listas la da por
# hecha y este guardián no lo detecta — para él, "citada y sin declarar" es "en la ruta activa".
# No puede distinguir una llamada real de una cita en un comentario; es grep, no un grafo de
# llamadas. Lo que sí impide es el deslizamiento silencioso: sacar una regla de sin-cablear es
# ahora un borrado explícito en un archivo versionado, no el efecto colateral de escribir un
# comentario. Quien cubra el hueco de verdad es ci/alcance-consenso.sh, y hoy solo vigila
# zx-consensus y zx-storage: extenderlo a zx-core y zx-p2p es trabajo aparte.
set -uo pipefail
cd "$(dirname "$0")/.."

LISTA=ci/reglas-sin-codigo.txt
SIN_CABLEAR=ci/reglas-sin-cablear.txt
sin_cita=()

while read -r r; do
  grep -rq --include=*.rs -e "$r" crates/ || sin_cita+=("$r")
done < <(grep -oP '^\*\*\K[A-Z]+-[A-Z]+-[0-9]+[a-z]?' SPEC.md | sort -u)

no_declaradas=()
for r in "${sin_cita[@]:-}"; do
  [ -z "$r" ] && continue
  grep -qxF "$r" "$LISTA" 2>/dev/null || no_declaradas+=("$r")
done

if [ "${#no_declaradas[@]}" -gt 0 ]; then
  echo "Reglas del SPEC que ningún código cita y que no están declaradas:"
  printf '  %s\n' "${no_declaradas[@]}"
  echo
  echo "Si la regla debería estar implementada, impleméntala o añade la cita donde ya lo esté."
  echo "Si es una prohibición o trabajo futuro, añádela a $LISTA con el motivo."
  echo "Ojo: citar en rango (C-XXX-01..03) NO cuenta. Escribe los números."
  exit 1
fi

esta_sin_citar() {
  for r in "${sin_cita[@]:-}"; do [ "$r" = "$1" ] && return 0; done
  return 1
}

# Una regla de reglas-sin-codigo.txt que SÍ se cita: o se ha implementado del todo y sale, o tiene
# código sin cablear y pasa a reglas-sin-cablear.txt. Quedarse donde está no es una opción.
obsoletas=()
while read -r linea; do
  case "$linea" in ''|'#'*) continue;; esac
  esta_sin_citar "$linea" || obsoletas+=("$linea")
done < "$LISTA"

if [ "${#obsoletas[@]}" -gt 0 ]; then
  echo "Estas ya se citan en el código y siguen en $LISTA:"
  printf '  %s\n' "${obsoletas[@]}"
  echo
  echo "Si la ruta activa ya las ejecuta, quítalas de $LISTA."
  echo "Si solo hay código que nadie llama todavía, muévelas a $SIN_CABLEAR con su motivo."
  exit 1
fi

# Y al revés: una regla declarada sin cablear que ya no cita nadie está mal archivada. Sin esta
# mitad, la lista nueva se convierte en el vertedero donde se esconde lo que no se quiere mirar.
#
# No hace falta una comprobación aparte para una regla que esté en las DOS listas: si está citada
# la caza el bloque anterior, y si no lo está la caza este. Se probaron los dos casos. Un tercer
# bloque para eso sería código que no alcanza nadie, justo lo que busca ci/alcance-consenso.sh.
mal_archivadas=()
if [ -f "$SIN_CABLEAR" ]; then
  while read -r linea; do
    case "$linea" in ''|'#'*) continue;; esac
    esta_sin_citar "$linea" && mal_archivadas+=("$linea")
  done < "$SIN_CABLEAR"
fi

if [ "${#mal_archivadas[@]}" -gt 0 ]; then
  echo "Estas están en $SIN_CABLEAR pero ningún código las cita:"
  printf '  %s\n' "${mal_archivadas[@]}"
  echo
  echo "Sin código que las cite, su sitio es $LISTA."
  echo "Si además sigue en $LISTA, quítala de una de las dos: una regla tiene un solo estado."
  exit 1
fi

total=$(grep -cP '^\*\*[A-Z]+-[A-Z]+-[0-9]+' SPEC.md)
n_cablear=$(grep -cvE '^\s*(#|$)' "$SIN_CABLEAR" 2>/dev/null || echo 0)
echo "Citas del SPEC: $total reglas, todas implementadas o declaradas."
echo "De ellas, $n_cablear con código que todavía no ejecuta nadie ($SIN_CABLEAR). OK"
