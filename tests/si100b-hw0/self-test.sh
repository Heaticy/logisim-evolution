#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
file=${1:-"$root/ex1.circ"}
case "$file" in /*) ;; *) file="$PWD/$file" ;; esac
if [ ! -f "$file" ] || [ "$(basename -- "$file")" != ex1.circ ]; then
    printf '%s\n' 'ERROR - Select your ex1.circ file.' >&2
    exit 2
fi

launcher=${LOGISIM_EXE:-logisim-evolution}
if ! version=$("$launcher" --version 2>&1) ||
    ! printf '%s\n' "$version" | grep -iEq 'Logisim-evolution[[:space:]]+v?5\.0\.0([[:space:]]|$)'; then
    printf '%s\n' 'ERROR - Install the SI100B Logisim-evolution 5.0.0 and reopen Terminal.' >&2
    exit 2
fi

scratch=$(mktemp -d)
trap 'rm -f "$scratch/table" "$scratch/error"; rmdir "$scratch"' EXIT
failed=0
for circuit in NAND1 NOR1 XOR1 MUX2 MUX4; do
    if "$launcher" --tty table --toplevel-circuit "$circuit" "$file" >"$scratch/table" 2>"$scratch/error" &&
        awk -v circuit="$circuit" '
            FNR == 1 && NR == FNR { width=NF; for(i=1;i<=NF;i++) labels[i]=$i; next }
            NR == FNR {
                key=$1; for(i=2;i<NF;i++) key=key " " $i
                expected[key]=$NF; total++; next
            }
            FNR == 1 {
                if(NF!=width) invalid=1
                for(i=1;i<=NF;i++) indices[$i]=i
                for(i=1;i<=width;i++) if(!(labels[i] in indices)) invalid=1
                next
            }
            {
                if(invalid || NF!=width) { invalid=1; next }
                key=$indices[labels[1]]
                for(i=2;i<width;i++) key=key " " $indices[labels[i]]
                actual=$indices[labels[width]]
                if(key in seen) invalid=1
                seen[key]=1; count++
                if((key in expected) && actual==expected[key]) correct++
                else if(example=="") example="Input " key " -> " actual " (expected " expected[key] ")."
            }
            END {
                if (invalid || count!=total || correct!=total) {
                    printf "FAIL %s (%d/%d) %s\n", circuit, correct, total, example
                    exit 1
                }
                printf "PASS %s (%d/%d)\n", circuit, correct, total
            }
        ' "$root/vectors/$circuit.txt" "$scratch/table"; then
        :
    else
        if [ ! -s "$scratch/table" ]; then
            printf 'FAIL %s - Logisim did not return a truth table.\n' "$circuit"
        fi
        failed=1
    fi
done
exit "$failed"
