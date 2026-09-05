#!/usr/bin/env bash
# ¿Hay código de consenso que el nodo no alcanza nunca?
#
# Cuatro veces en este proyecto la respuesta ha sido que sí, y las cuatro el hueco era grave:
# la dificultad esperada no se comprobaba, ni la rama, ni los timestamps, y el nodo no pedía un
# cuerpo jamás. Las cuatro reglas estaban escritas y probadas en `zx-consensus`. Lo que faltaba
# era la llamada.
#
# Este guardián busca funciones públicas de `zx-consensus` que:
#   1. no llama nadie desde los crates de arriba, Y
#   2. tampoco las llama nadie dentro de su propio crate — es decir, no son auxiliares internas.
#
# ⚠️ Vigila `zx-consensus` Y `zx-storage`. Al principio solo miraba el primero, y el mismo día en que
# se escribió el guardián se añadió a `zx-storage` un método público —`aplicar_lote`— que no llamaba
# nadie: el guardián construido para detectar exactamente eso no lo vio, porque el código muerto
# estaba en el crate que no miraba. Si mañana `zx-mempool` gana superficie pública, va en la lista.
#
# Eso las deja en un solo sitio: puntos de entrada que nadie usa. Cada uno es o un hueco o una
# decisión consciente, y las conscientes van en `ci/consenso-pendiente.txt` con su motivo.
#
# Es una heurística de `grep`, no un análisis del grafo de llamadas: puede tener falsos positivos
# (un nombre citado en un comentario cuenta como llamada). Se acepta a propósito — el coste de un
# falso positivo es añadir una línea a un archivo, y el de un falso negativo ya se ha pagado
# cuatro veces.
set -uo pipefail
cd "$(dirname "$0")/.."

VIGILADOS=(zx-consensus zx-storage)
PENDIENTE=ci/consenso-pendiente.txt
huerfanas=()

for crate in "${VIGILADOS[@]}"; do
  # Los consumidores de un crate son todos los demás, él mismo excluido.
  consumidores=()
  for otro in zx-core zx-consensus zx-storage zx-mempool zx-p2p zx-node; do
    [ "$otro" = "$crate" ] && continue
    [ -d "crates/$otro/src" ] && consumidores+=("crates/$otro/src")
  done

  for archivo in "crates/$crate"/src/*.rs; do
    [ -e "$archivo" ] || continue
    modulo=$(basename "$archivo" .rs)
    while read -r f; do
      [ -z "$f" ] && continue
      # ¿La llama alguien de fuera del crate?
      if grep -rqE "\b$f\s*\(" "${consumidores[@]}" 2>/dev/null; then continue; fi
      # ¿La llama alguien dentro del propio crate, fuera de su definición?
      usos=$(grep -rhoE "\b$f\s*\(" "crates/$crate/src" 2>/dev/null | wc -l)
      defs=$(grep -rhoE "fn\s+$f\s*\(" "crates/$crate/src" 2>/dev/null | wc -l)
      if [ "$usos" -gt "$defs" ]; then continue; fi
      huerfanas+=("$crate::$modulo::$f")
    done < <({
        # Funciones libres y métodos inherentes públicos.
        grep -oP '^\s*pub (const )?(async )?fn \K\w+' "$archivo" 2>/dev/null
        # Y los métodos declarados en un trait, que NO llevan `pub` y por eso se escapaban: se
        # reconocen porque la declaración termina en `;` en vez de abrir cuerpo. Un trait público
        # es API pública igual que una función libre — y esto lo aprendimos por las malas, con
        # `aplicar_lote` invisible para su propio guardián.
        grep -oP '^\s*fn \K\w+(?=.*;\s*$)' "$archivo" 2>/dev/null
      } | sort -u)
  done
done

no_declaradas=()
for h in "${huerfanas[@]:-}"; do
  [ -z "$h" ] && continue
  grep -qxF "$h" "$PENDIENTE" 2>/dev/null || no_declaradas+=("$h")
done

if [ "${#no_declaradas[@]}" -gt 0 ]; then
  echo "Puntos de entrada de consenso que NADIE alcanza y que no están declarados:"
  printf '  %s\n' "${no_declaradas[@]}"
  echo
  echo "Cada uno es un hueco o una decisión. Si es un hueco, cablea la llamada."
  echo "Si es deliberado, añádelo a $PENDIENTE con el motivo y la fase en que se cierra."
  exit 1
fi

# Al revés: algo declarado pendiente que ya se cableó debe salir de la lista, o el archivo
# empieza a describir un pasado que ya no existe.
obsoletas=()
while read -r linea; do
  case "$linea" in ''|'#'*) continue;; esac
  encontrada=0
  for h in "${huerfanas[@]:-}"; do [ "$h" = "$linea" ] && encontrada=1 && break; done
  [ "$encontrada" -eq 0 ] && obsoletas+=("$linea")
done < "$PENDIENTE"

if [ "${#obsoletas[@]}" -gt 0 ]; then
  echo "Estas ya se alcanzan: quítalas de $PENDIENTE."
  printf '  %s\n' "${obsoletas[@]}"
  exit 1
fi

echo "Alcance: ${#VIGILADOS[@]} crates vigilados, todo punto de entrada se usa o está declarado. OK"
