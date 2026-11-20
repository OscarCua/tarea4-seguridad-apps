$base = "http://localhost:3000"
$out  = "reports\p39"
New-Item -ItemType Directory -Force $out | Out-Null
Remove-Item "$out\*.txt" -ErrorAction SilentlyContinue
$pw = "Asvs#Prueba2026!"
$ua = "usuarioa.asvs@test.local"
$ub = "usuariob.asvs@test.local"

function Call($method, $path, $body, $token) {
  $h = [IO.Path]::GetTempFileName(); $b = [IO.Path]::GetTempFileName()
  $a = @("-s","-X",$method,"$base$path","-D",$h,"-o",$b,"-w","%{http_code}","-H","Content-Type: application/json")
  if ($token) { $a += @("-H","Authorization: Bearer $token") }
  if ($body)  { $f = [IO.Path]::GetTempFileName(); [IO.File]::WriteAllText($f,$body); $a += @("--data-binary","@$f") }
  $code = & curl.exe @a
  [pscustomobject]@{ Status=$code; Headers=(Get-Content $h -Raw); Body=(Get-Content $b -Raw) }
}
function Snip($s, $n) { if ($null -eq $s) { return "" }; $s = $s.Trim(); if ($s.Length -gt $n) { $s.Substring(0,$n) } else { $s } }
function Log($id, $text) { Add-Content -Path "$out\$id.txt" -Value $text; Write-Host "$id -> $text" }
function Login($email, $pass) {
  $r = Call "POST" "/rest/user/login" (@{email=$email;password=$pass} | ConvertTo-Json -Compress) $null
  try { ($r.Body | ConvertFrom-Json).authentication } catch { $null }
}

# Preparacion: registrar usuarios A y B
foreach ($u in @($ua,$ub)) {
  $r = Call "POST" "/api/Users" (@{email=$u;password=$pw;passwordRepeat=$pw} | ConvertTo-Json -Compress) $null
  Write-Host "Registro $u -> HTTP $($r.Status)"
}

# TC-SEC-001: contrasena corta (6 caracteres)
$r = Call "POST" "/api/Users" (@{email="corta$(Get-Random)@test.local";password="abc123";passwordRepeat="abc123"} | ConvertTo-Json -Compress) $null
Log "TC-SEC-001" ("HTTP " + $r.Status + " | " + (Snip $r.Body 200))

# TC-SEC-002: 20 intentos fallidos de login
$codes = @(); $sw = [Diagnostics.Stopwatch]::StartNew()
1..20 | ForEach-Object {
  $r = Call "POST" "/rest/user/login" (@{email=$ua;password="mala$_"} | ConvertTo-Json -Compress) $null
  $codes += $r.Status
}
$sw.Stop()
$ok = Call "POST" "/rest/user/login" (@{email=$ua;password=$pw} | ConvertTo-Json -Compress) $null
$resumen = ($codes | Group-Object | ForEach-Object { "$($_.Name)x$($_.Count)" }) -join ", "
Log "TC-SEC-002" ("Codigos: $resumen | segundos: " + [math]::Round($sw.Elapsed.TotalSeconds,1) + " | login correcto despues: HTTP " + $ok.Status)

# TC-SEC-003: token nuevo en cada autenticacion
$a1 = Login $ua $pw; Start-Sleep 2; $a2 = Login $ua $pw
$w = Call "GET" "/rest/user/whoami" $null $a1.token
Log "TC-SEC-003" ("Tokens iguales: " + ($a1.token -eq $a2.token) + " | whoami con token1 tras segundo login: HTTP " + $w.Status + " " + (Snip $w.Body 120))
Set-Content -Path "$env:TEMP\tokenA.txt" -Value $a2.token

# TC-SEC-005: acceso a la cesta de otro usuario
$A = Login $ua $pw; $B = Login $ub $pw
$own = Call "GET" "/rest/basket/$($A.bid)" $null $A.token
$oth = Call "GET" "/rest/basket/$($B.bid)" $null $A.token
Log "TC-SEC-005" ("bid A=$($A.bid) bid B=$($B.bid) | propia: HTTP $($own.Status) | ajena: HTTP $($oth.Status) " + (Snip $oth.Body 200))

# TC-SEC-006: inyeccion SQL en login
$r = Call "POST" "/rest/user/login" (@{email="' OR 1=1--";password="x"} | ConvertTo-Json -Compress) $null
Log "TC-SEC-006" ("HTTP " + $r.Status + " | " + (Snip $r.Body 250))

# TC-SEC-007: cabecera CSP
$p = Call "GET" "/" $null $null
$q = Call "GET" "/rest/products/search?q=apple" $null $null
$c1 = [regex]::IsMatch($p.Headers,"(?im)^content-security-policy:")
$c2 = [regex]::IsMatch($q.Headers,"(?im)^content-security-policy:")
Log "TC-SEC-007" "CSP en '/': $c1 | CSP en API: $c2"

# TC-SEC-008: errores con informacion interna
$e1 = Call "GET" "/rest/products/search?q='" $null $null
$e2 = Call "POST" "/rest/user/login" '{"email":' $null
$pat = "(?i)(stack|SQLITE|node_modules|\(.*:\d+:\d+\))"
Log "TC-SEC-008" ("Busqueda q=': HTTP $($e1.Status) filtra=" + [regex]::IsMatch($e1.Body,$pat) + " | " + (Snip $e1.Body 200))
Log "TC-SEC-008" ("JSON malo: HTTP $($e2.Status) filtra=" + [regex]::IsMatch($e2.Body,$pat) + " | " + (Snip $e2.Body 200))

# TC-SEC-009: TLS
$loc = [regex]::Match($p.Headers,"(?im)^location:\s*(.+)$").Groups[1].Value
$tls = & curl.exe -k -s -o NUL -w "%{http_code}" https://localhost:3000
Log "TC-SEC-009" "HTTP: $($p.Status) Location: '$loc' | HTTPS: $tls (000 = no hay TLS)"

Write-Host "`nListo. Resultados en $out"