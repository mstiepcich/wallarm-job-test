#!/usr/bin/env bash
# run_lab_tests_no_create.sh
# Runs 5 repetitions of several tests against http://192.168.0.28
# Assumes wordlist.txt, payloads_simple.txt and targets.txt already exist
# Run only on your own testing infrastructure.

set -euo pipefail

TARGET="http://192.168.0.28"
ITERATIONS=5
LOGDIR="./test_logs_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOGDIR"

# simple logger helper
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# 1) Reflected XSS in query parameter (5 repetitions)
log "Starting reflected XSS (query param) x $ITERATIONS"
for i in $(seq 1 $ITERATIONS); do
  q='<script>alert(1)</script>'
  out="$LOGDIR/xss_query_${i}.txt"
  log "Reflected XSS query #$i -> $out"
  curl -s -o "$out" -w "HTTP_CODE:%{http_code}\n" "$TARGET/anything/test?name=$q"
  sleep 1
done

# 2) POST JSON with XSS payload (5 repetitions)
log "Starting POST JSON XSS x $ITERATIONS"
for i in $(seq 1 $ITERATIONS); do
  out="$LOGDIR/xss_post_${i}.txt"
  payload='{"user":"test","comment":"<script>alert(1)</script>"}'
  log "POST JSON XSS #$i -> $out"
  curl -s -X POST "$TARGET/post" -H "Content-Type: application/json" -d "$payload" -o "$out" -w "HTTP_CODE:%{http_code}\n"
  sleep 1
done

# 3) Header tampering / suspicious user-agent tests (5 repetitions)
log "Starting header tampering tests x $ITERATIONS"
USER_AGENTS=("sqlmap/1.0" "curl/7.79.0" "BadBot/1.0" "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" "python-requests/2.28.1")
for i in $(seq 1 $ITERATIONS); do
  ua=${USER_AGENTS[$(( (i-1) % ${#USER_AGENTS[@]} ))]}
  out="$LOGDIR/header_tamper_${i}.txt"
  log "Header tamper #$i UA='$ua' -> $out"
  curl -s -D - -o "$out" -w "HTTP_CODE:%{http_code}\n" \
    -H "User-Agent: $ua" \
    -H "X-Forwarded-For: 8.8.8.$i" \
    "$TARGET/headers"
  sleep 1
done

# 4) Lightweight fuzzing / enumeration with ffuf (5 repetitions)
log "Starting ffuf directory fuzzing x $ITERATIONS (uses wordlist.txt)"
for i in $(seq 1 $ITERATIONS); do
  out="$LOGDIR/ffuf_dirs_${i}.json"
  log "ffuf dirs #$i -> $out"
  ffuf -w wordlist.txt -u "$TARGET/FUZZ" -mc 200,301,302,403 -fs 0 -t 20 -o "$out" -of json || true
  sleep 2
done

log "Starting ffuf parameter fuzzing (uses payloads_simple.txt) x $ITERATIONS"
for i in $(seq 1 $ITERATIONS); do
  out="$LOGDIR/ffuf_params_${i}.json"
  log "ffuf params #$i -> $out"
  ffuf -w payloads.txt -u "$TARGET/anything?param=FUZZ" -mc 200,302,403 -t 10 -o "$out" -of json || true
  sleep 2
done

# 5) Rate-limit / HTTP flood control with vegeta (5 repetitions, light)
log "Starting vegeta lightweight tests x $ITERATIONS (uses targets.txt; rate=5,duration=6s)"
for i in $(seq 1 $ITERATIONS); do
  outbin="$LOGDIR/vegeta_result_${i}.bin"
  report="$LOGDIR/vegeta_report_${i}.txt"
  log "vegeta #$i -> $report"
  vegeta attack -rate=5 -duration=6s -targets="targets.txt" | tee "$outbin" | vegeta report > "$report" || true
  sleep 2
done

# 6) Body fuzzing / payloads in POST body (5 repetitions)
log "Starting body fuzzing / payload tests x $ITERATIONS (uses payloads_simple.txt)"
LINECOUNT=$(wc -l < payloads.txt 2>/dev/null || echo 0)
for i in $(seq 1 $ITERATIONS); do
  if [ "$LINECOUNT" -gt 0 ]; then
    idx=$(( (i % LINECOUNT) + 1 ))
    payload=$(sed -n "${idx}p" payloads.txt)
  else
    payload='<script>alert(1)</script>'
  fi
  out="$LOGDIR/body_fuzz_${i}.txt"
  log "Body fuzz #$i payload='${payload}' -> $out"
  curl -s -X POST "$TARGET/post" -H "Content-Type: application/x-www-form-urlencoded" -d "value=$payload" -o "$out" -w "HTTP_CODE:%{http_code}\n"
  sleep 1
done

# 7) Simulated SSRF using httpbin redirect endpoints (5 repetitions)
log "Starting SSRF-simulated tests x $ITERATIONS (redirect-to local addresses)"
SSRF_TARGETS=("http://127.0.0.1:80/" "http://localhost:8080/" "http://10.0.0.1/")
for i in $(seq 1 $ITERATIONS); do
  st=${SSRF_TARGETS[$(( (i-1) % ${#SSRF_TARGETS[@]} ))]}
  out="$LOGDIR/ssrf_${i}.txt"
  log "SSRF #$i -> redirect-to $st -> $out"
  curl -s -v "$TARGET/redirect-to?url=$st" -o "$out" 2>&1 || true
  sleep 1
done

# 8) HTTP method tampering tests (5 repetitions)
log "Starting HTTP method tampering tests x $ITERATIONS"
METHODS=(TRACE PUT DELETE OPTIONS PATCH)
for i in $(seq 1 $ITERATIONS); do
  m=${METHODS[$(( (i-1) % ${#METHODS[@]} ))]}
  out="$LOGDIR/method_${m}_${i}.txt"
  log "Method test #$i method=$m -> $out"
  curl -s -X "$m" "$TARGET/anything" -o "$out" -w "HTTP_CODE:%{http_code}\n" || true
  sleep 1
done

# 9) SQL-like payload tests (5 repetitions) - only to trigger WAF signatures
log "Starting SQL-like payload tests x $ITERATIONS (pattern firing only)"
SQL_PAYLOADS=(
  "1' OR '1'='1"
  "' OR 1=1 -- "
  "' UNION SELECT NULL --"
  "\" OR \"\" = \""
  "admin'--"
)
for i in $(seq 1 $ITERATIONS); do
  p=${SQL_PAYLOADS[$(( (i-1) % ${#SQL_PAYLOADS[@]} ))]}
  out="$LOGDIR/sqli_${i}.txt"
  log "SQL-like #$i payload='$p' -> $out"
  curl -s "$TARGET/anything?search=$(printf '%s' "$p" | jq -s -R -r @uri)" -o "$out" -w "HTTP_CODE:%{http_code}\n" || true
  sleep 1
done

# 10) Custom Wallarm test loop provided by user (50 iterations)
log "Starting custom Wallarm loop provided by user (50 iterations)"
for i in $(seq 50); do
  out="$LOGDIR/wallarm_test_${i}.txt"
  log "Wallarm custom test #$i -> $out"
  curl -s -o "$out" -w "HTTP_CODE:%{http_code}\n" "$TARGET/?wallarm_test_xxxx=union+select+$i"
  sleep 1
done

log "All tests finished. Logs saved in: $LOGDIR"
echo "Check nginx logs and Wallarm console to correlate detections with requests."

