#!/usr/bin/env bash
# Prova l'eseguibile Windows (build/DawnAndAsh.exe) con Wine, senza un PC Windows:
#   1. autotest della partita di allenamento;
#   2. screenshot con la grafica (Vulkan via Wine) in <cartella log>/shots;
#   3. partite in rete Linux <-> Windows (build/DawnAndAsh.x86_64 contro l'exe), anche con lag simulato.
# Uso: ./tools/windows_tests.sh [--no-shots]   (richiede wine e ./build.sh già eseguito)
# Usa un prefisso Wine temporaneo: ~/.wine non viene toccato. Esce con codice 0 solo se tutto passa.
set -uo pipefail
cd "$(dirname "$0")/.."
command -v wine >/dev/null || { echo "Manca wine (sudo pacman -S wine)"; exit 1; }
EXE=build/DawnAndAsh.exe
LIN=build/DawnAndAsh.x86_64
[[ -f "$EXE" && -x "$LIN" ]] || { echo "Mancano $EXE o $LIN: esegui prima ./build.sh"; exit 1; }
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
if [[ -z "${WINEPREFIX:-}" ]]; then   # prefisso temporaneo (~380 MB), cancellato alla fine
	WINEPREFIX="$LOG_DIR/wineprefix"
	trap 'rm -rf "$LOG_DIR/wineprefix"' EXIT
fi
export WINEPREFIX WINEDLLOVERRIDES="mscoree,mshtml=" WINEDEBUG=-all
WIN=(wine "$EXE")
DUR=30
fail=0
echo "Log in $LOG_DIR"
wineboot -i >/dev/null 2>&1

if timeout 300 "${WIN[@]}" --headless -- --autotest-training > "$LOG_DIR/autotest.log" 2>&1 && grep -q "AUTOTEST OK" "$LOG_DIR/autotest.log"; then
	echo "[OK]      autotest allenamento ($(grep -o 'tick medio.*' "$LOG_DIR/autotest.log"))"
else
	echo "[FALLITO] autotest allenamento"; grep -h "FALLITO\|FAIL\|ERROR" "$LOG_DIR/autotest.log" | head -5; fail=1
fi

if [[ "${1:-}" != "--no-shots" ]]; then
	mkdir -p "$LOG_DIR/shots"
	timeout 400 "${WIN[@]}" -- --shots "Z:$LOG_DIR/shots" > "$LOG_DIR/shots.log" 2>&1
	n=$(find "$LOG_DIR/shots" -name '*.png' | wc -l)
	if [[ $n -ge 20 ]]; then
		echo "[OK]      grafica: $n screenshot in $LOG_DIR/shots ($(grep -o 'Vulkan.*\|OpenGL.*\|D3D12.*' "$LOG_DIR/shots.log" | head -1))"
	else
		echo "[FALLITO] grafica: solo $n screenshot"; fail=1
	fi
fi

run_net() { # nome porta netsim host... -- client...
	local name=$1 port=$2 ns=$3; shift 3
	local host=() client=()
	while [[ $1 != -- ]]; do host+=("$1"); shift; done; shift; client=("$@")
	local extra=(); [[ -n "$ns" ]] && extra=(--netsim "$ns")
	timeout 150 "${host[@]}" --headless -- --autotest-net-host --hero kael --port "$port" --duration $((DUR + 10)) > "$LOG_DIR/host_$name.log" 2>&1 &
	local hp=$!
	sleep 4
	timeout 150 "${client[@]}" --headless -- --autotest-net-client --port "$port" --duration "$DUR" --hero peppino "${extra[@]}" > "$LOG_DIR/client_$name.log" 2>&1
	local cr=$?
	wait $hp
	local hr=$?
	local metrics; metrics="$(grep -h "NET client:" "$LOG_DIR/client_$name.log" | sed 's/^ *//')"
	if [[ $cr -eq 0 && $hr -eq 0 ]]; then
		echo "[OK]      $name  ->  $metrics"
	else
		echo "[FALLITO] $name (host=$hr client=$cr)  ->  $metrics"
		grep -h "FALLITO\|FAIL\|Versione diversa" "$LOG_DIR/host_$name.log" "$LOG_DIR/client_$name.log" | head -5 | sed 's/^/          /'
		fail=1
	fi
}
run_net "host_linux_client_windows" 7901 "" "$LIN" -- "${WIN[@]}"
run_net "host_windows_client_linux" 7902 "" "${WIN[@]}" -- "$LIN"
run_net "host_windows_client_linux_150ms" 7903 "latency=150,jitter=30,loss=3" "${WIN[@]}" -- "$LIN"
exit $fail
