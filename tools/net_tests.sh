#!/usr/bin/env bash
# Test di rete automatici: host + client sulla stessa macchina (127.0.0.1) con diverse condizioni di lag.
# Uso: ./tools/net_tests.sh [durata_secondi]      (richiede Godot nel PATH)
# Esce con codice 0 solo se tutti i test passano.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
DUR="${1:-30}"
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"
PORT=7800
fail=0

run_case() { # nome netsim
	local name="$1" ns="$2"
	PORT=$((PORT + 1))
	local args=()
	[[ -n "$ns" ]] && args=(--netsim "$ns")
	timeout $((DUR + 60)) "$GODOT" --headless -- --autotest-net-host --port "$PORT" --duration "$((DUR + 6))" > "$LOG_DIR/host_$name.log" 2>&1 &
	local hp=$!
	sleep 2
	timeout $((DUR + 60)) "$GODOT" --headless -- --autotest-net-client --port "$PORT" --duration "$DUR" "${args[@]}" > "$LOG_DIR/client_$name.log" 2>&1
	local cr=$?
	wait $hp
	local hr=$?
	local metrics; metrics="$(grep -h "NET client:" "$LOG_DIR/client_$name.log" | sed 's/^ *//')"
	if [[ $cr -eq 0 && $hr -eq 0 ]]; then
		echo "[OK]      $name  ->  $metrics"
	else
		echo "[FALLITO] $name (host=$hr client=$cr)  ->  $metrics"
		grep -h "FALLITO\|FAIL" "$LOG_DIR/host_$name.log" "$LOG_DIR/client_$name.log" | sed 's/^/          /'
		fail=1
	fi
}

run_robust() { # il client viene terminato bruscamente a metà partita
	PORT=$((PORT + 1))
	timeout 120 "$GODOT" --headless -- --autotest-net-host --port "$PORT" --duration 60 --expect-disconnect > "$LOG_DIR/host_robust.log" 2>&1 &
	local hp=$!
	sleep 2
	timeout 60 "$GODOT" --headless -- --autotest-net-client --port "$PORT" --duration 30 --die-after 4 > "$LOG_DIR/client_robust.log" 2>&1
	wait $hp
	local hr=$?
	if [[ $hr -eq 0 ]] && grep -q "ROBUST OK" "$LOG_DIR/host_robust.log"; then
		echo "[OK]      robustezza: client terminato a metà partita -> vittoria a tavolino e nuova partita senza crash"
	else
		echo "[FALLITO] robustezza (host=$hr)"
		grep -h "FALLITO\|FAIL\|ERROR" "$LOG_DIR/host_robust.log" | head -5 | sed 's/^/          /'
		fail=1
	fi
}

echo "Log in $LOG_DIR"
run_case "lan_0ms" ""
run_case "80ms" "latency=80"
run_case "150ms_jitter30_loss3" "latency=150,jitter=30,loss=3"
run_case "250ms_loss5" "latency=250,loss=5"
run_robust
exit $fail
