# Banco Obsidian — KYC Stack

> **Tema:** Roxo `#7c4dff` + Preto `#0a0a0a` • **Nome fake:** Banco Obsidian

Stack de KYC para abertura de conta bancária (simulação Banco Obsidian) com **microserviços em Go** (`Gin` + `GORM` + `Postgres 16` + `Redis 7` + `Asynq`), **Backoffice Next.js 16** (`App Router` + `shadcn/radix` + `Tailwind 4` + `next/font Inter/JetBrains Mono`) e **App Flutter** (`google_fonts`, `crypto`, `FaceTec SDK`) — 100% dockerizada. **Segurança ponta a ponta com HASH KEY (HMAC-SHA256)**: apenas o app autenticado (`X-API-Key/Timestamp/Nonce/Signature` sobre `SHA256(body)`, `constant-time` + `nonce SETNX 10min` anti-replay) chama `api/v1`; backoffice usa `JWT 30min` em cookie `HttpOnly + Secure + SameSite=Strict` + `CSRF double-submit`, `CSP`, `X-Frame-Options: DENY`, proteção contra `Session Hijacking`, `CSRF`, `XSS` (auto-escape), `SQL Injection` (placeholders/`escapeLike`) e `Clickjacking`. **Idempotência** garantida por `CPF unique` (índice único + `409`/`200` para mesmo payload) e `Idempotency-Key` (hash do body, cache de resposta) — garante **um cadastro por cliente** mesmo com retries/rede instável. **Performance**: jobs em background `Redis/Asynq` (fila `kyc` prioridade 6 + `default`; `CustomerProfileJob` e `KycProcessingJob` assíncronos só no app, backoffice 100% síncrono sem FaceTec async), `Postgres` indexado, `Redis` para nonce/idempotência, `Docker` multi-stage (`Go 1.27 Alpine` + `Node 20` standalone) e CORS otimizado para Flutter Web (porta aleatória).

---

## Arquitetura

```
┌─────────────┐     HMAC SHA256      ┌─────────────────────┐     Asynq/Redis     ┌──────────────┐
│  kyc-app    │ ──────────────────► │  kyc-go (Gin)       │ ──────────────────► │  kyc-worker  │
│  Flutter    │  X-API-Key/Timestamp│  :8080 -> :3002     │   customer:profile  │   Go/Asynq   │
│  + crypto   │  X-Nonce/Signature  │  api/v1 (async)     │   kyc:processing    │  FaceTec     │
└─────────────┘  Idempotency-Key    │  /api/admin (JWT)   │   + Simulação       └──────────────┘
                                    └─────────┬───────────┘
                                              │ GORM (pg)
                                    ┌─────────▼───────────┐
                                    │  postgres:16        │
                                    │  + redis:7          │
                                    └─────────┬───────────┘
                                              │
┌─────────────┐   Cookie httpOnly   ┌─────────▼───────────┐
│kyc-backoffice│ ──────────────────► │  kyc-go /api/admin  │
│  Next.js 16  │   JWT + CSRF        │  síncrono (sem      │
│  shadcn/radix│   SameSite Strict   │  FaceTec async)     │
└─────────────┘   CSP headers       └─────────────────────┘
       ▲
       │ fetch http://kyc-go:8080 (SSR)
       │
   Browser (3001)
```

### Serviços (docker-compose.yml)

| Serviço | Porta Host | Interno | Descrição |
|---------|------------|---------|-----------|
| `postgres` | `5433` | `5432` | Postgres 16 (substitui SQLite) |
| `redis` | `6380` | `6379` | Redis 7 (Asynq + HMAC nonce) |
| `kyc-go` | `3002` | `8080` | API Go (Gin) - gateway + customer + kyc |
| `kyc-worker` | — | — | Worker Asynq (consome filas `kyc, default`) |
| `kyc-backoffice` | `3001` | `3001` | Next.js 16 App Router + shadcn |
| `facetec-server` | `8080` | `8080` | FaceTec Server SDK (profile `facetec`, opcional) |

---

## Endpoints

### `api/v1` — Apenas App com HASH KEY (HMAC)

Todos exigem headers:

```
X-API-Key: obsidian_app
X-Timestamp: <unix seconds>
X-Nonce: <uuid v4>
X-Signature: HMAC-SHA256 hex de "TIMESTAMP\nNONCE\nMETHOD\nPATH\nBODY_SHA256"
Idempotency-Key: <uuid v4> (opcional, recomendado)
```

**String canônica:** `TIMESTAMP + "\n" + NONCE + "\n" + METHOD + "\n" + PATH + "\n" + SHA256(body)`
`Signature = HMAC-SHA256(secret, canonical)` — comparação `constant-time`.

- `POST /api/v1/customers` — Etapa 1: perfil + endereço completo
  - Body: `{ customer: { cpf, nome, sobrenome, data_nascimento (YYYY-MM-DD), email?, telefone?, logradouro, numero, complemento?, bairro, cidade, estado (2), cep (00000-000), pais } }`
  - Idempotência: `CPF unique` (409 se duplicado + payload diferente, 200 se mesmo payload) + `Idempotency-Key` (cache de resposta).
  - Validações: CPF 11 dígitos, CEP `00000-000`, idade ≥18 e ≤120, estado 2 letras, nome 2-100 chars.
  - Sucesso: `201 { customer, message: "Perfil criado - prossiga para KYC" }` + job `customer:profile` no Redis.

- `GET /api/v1/customers/:cpf` — consulta cadastro
- `PATCH /api/v1/customers/:cpf` — edita antes de aprovar (bloqueia se `kyc_approved/account_active`)
- `POST /api/v1/customers/:cpf/kyc` — Etapa 2: documento + selfie FaceTec
  - Body: `{ requestBlob: "<base64 FaceTec>", documentType: "rg|cnh|passport" }`
  - Valida `can_submit_kyc?` (só se `profile_completed/kyc_pending/kyc_rejected`)
  - Cria `KycSession` pendente + enfileira `KycProcessingJob` (Redis Asynq) → `202 { kycSessionId, status: "kyc_pending", message: "processamento em background" }`
  - Worker tenta FaceTec Server real; se offline, **simulação determinística** 80% aprova (`SHA256(blob)[0] %5 !=0`).

- `GET /api/v1/customers/:cpf/status` — status consolidado `{ customer, kyc: { id, status, livenessProven, success, matchLevel } }`
- `GET /api/v1/facetec/config|status` / `POST /api/v1/facetec/process` — proxy FaceTec

### `/api/admin` — Backoffice (síncrono, sem FaceTec async)

- `POST /api/admin/login` — `{ email, password }` → `{ token (JWT 30min), admin }` + `Set-Cookie: admin_token=... HttpOnly; Secure; SameSite=Strict; Max-Age=1800`
  - Seed: `admin@obsidian.com / Obsidian123!` (`kyc-go/.env` / `kyc-go/internal/config`)
- `GET /api/admin/customers?q=&status=&page=` — lista com **sanitização SQLi** (`escapeLike` + placeholders), paginação 50, filtro status
- `GET /api/admin/customers/:id` — detalhe + `KycSessions`
- `POST /api/admin/customers/:id/approve|reject` — ação síncrona (requisito: backoffice sem jobs async FaceTec)

---

## Backoffice — `kyc-backoffice/` (Next.js 16 + shadcn/radix)

- **Stack:** App Router, TypeScript, Tailwind 4, shadcn `base-nova` (button, card, table, badge, input, dialog, etc.), `next-themes`, `lucide-react`, `sonner`
- **Tema:** dark por padrão, gradiente `obsidian-gradient` (`#12001a → #2d0b4a → #000`), cards `obsidian-card` com borda roxa.
- **Rotas:**
  - `/` → redirect `/login`
  - `/login` — Client Component vazio (sem valores padrão), `required` nativo nos `Input` de email/senha, chama `POST /api/auth/login` (BFF proxy → Go), toast, `router.push /dashboard`
  - `/dashboard` — Server Component, `fetch http://kyc-go:8080/api/admin/customers` com `Authorization: Bearer <token>` via `cookies().get("admin_token")`, redirect `/login` se 401
  - `/dashboard/[id]` — detalhe (a criar, já tem API)
  - `middleware.ts` — guard `/dashboard` (sem token → `/login`), injeta headers `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, CSP etc.

- **Segurança Backoffice:**
  - Cookie `admin_token` HttpOnly + Secure + SameSite Strict + 30min expire (anti Session Hijacking)
  - Cookie `csrf_token` double-submit (lido por JS, enviado em header `X-CSRF-Token` futuro) + `SameSite Strict`
  - `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: camera=(), microphone=()`, CSP `default-src 'self'`
  - XSS: React auto-escapa, sem `dangerouslySetInnerHTML`, tabelas com `escapeLike`
  - SQLi: queries via GORM placeholders, não interpolação
  - Rate limiting: a delegar para infra (`golang.org/x/time/rate` / `go-redis/redis_rate` se necessário)

**Env:**
```
API_URL=http://kyc-go:8080          # dentro docker (SSR)
NEXT_PUBLIC_API_URL=http://localhost:3002 # browser (fetch direto se necessário)
```

**Build:** `next build` → `output: "standalone"` (Docker multi-stage).

---

## App Flutter — `kyc-app/` (Banco Obsidian)

### Preservado
- `lib/screens/kyc_screen.dart` — fluxo FaceTec genérico (3D Liveness, Enrollment, Verification, Photo ID Match) mantida como aba **“Avançado”**.

### Novo fluxo 2 etapas (roxo/preto)

- **Tema:** `lib/theme/obsidian_theme.dart` — `ThemeData` dark, `seedColor: #7c4dff`, `scaffoldBackgroundColor: #0a0a0a`, gradiente, inputs `fillColor: #0F0F0F`, botões roxo/preto. Usado em `MaterialApp(theme: ObsidianTheme.dark)`.

- **Navigation:** `lib/main.dart` → `ObsidianApp` → `AppNavigator` (bottom `NavigationBar` com 4 abas: Início, Perfil, KYC, Avançado)
  - `OnboardingScreen` — hero com logo ◈, passos Perfil → Documento → Conta, CTA “COMEÇAR CADASTRO”
  - `ProfileStepScreen` — Form vazio (sem valores pré-preenchidos) com validação `required` (*). Campos obrigatórios: CPF (11 dígitos) *, nome *, sobrenome *, DOB (YYYY-MM-DD) *, logradouro *, número *, bairro *, cidade *, UF (2 letras) *, CEP (00000-000) *. Opcionais: email (valida formato), telefone (≥10 dígitos), complemento. País fixo `Brasil` (desabilitado). Todos com `validator` + `AutovalidateMode.onUserInteraction`. Chama `CustomerService.createProfile` (HMAC + Idempotency-Key). Em sucesso, navega para KYC.
  - `KycStepScreen` — Mostra CPF + status + último KYC, dropdown `documentType` (rg/cnh/passport), cards “Foto do RG/CNH” e “Selfie 3D”, botão “ENVIAR PARA VALIDAÇÃO KYC” → `CustomerService.submitKyc` → mostra log e faz polling de `getStatus`. Fallback para blob fake se FaceTec SDK não instalado (testa worker).
  - `KycScreen` (preservada) — `externalDatabaseRefID` agora vazio com validação `required` (*), bloqueia fluxo se vazio.

- **Serviços:**
  - `lib/config/app_config.dart` — `backendBaseUrl` (default `http://localhost:3002` para host, `http://10.0.2.2:3002` para emulator), endpoints `v1Customers`, `v1CustomerKyc`, etc., `hmacKeyId/Secret` (via `String.fromEnvironment`)
  - `lib/services/hmac_service.dart` — Gera `X-API-Key`, `X-Timestamp`, `X-Nonce`, `X-Signature` com `crypto` (HMAC-SHA256), canônica idêntica ao Go.
  - `lib/services/customer_service.dart` — `createProfile`, `getCustomer`, `getStatus`, `submitKyc` (todos com HMAC headers + `Idempotency-Key: uuid`).
  - `lib/services/facetec_service.dart` — mantido, `fetchConfig`, `isServerRunning`, `processRequest`, mocks para dev sem SDK.

**Pubspec:** adicionado `crypto: ^3.0.0` (para HMAC).

---

## Microserviços Go — `kyc-go/`

```
kyc-go/
  cmd/api/main.go         # Gin, CORS, DB, Asynq client, handlers, seed admin
  cmd/worker/main.go      # Asynq server, Processor (CustomerProfile + KYCProcessing)
  internal/config/config.go
  internal/hmac/hmac.go   # Middleware HMAC (5min tolerance, nonce SETNX 10min)
  internal/middleware/security.go # SecurityHeaders, Recovery, CSP
  internal/models/models.go # Customer, KycSession, IdempotencyKey, Admin + AutoMigrate
  internal/handlers/customers.go # Create/Show/Update/KYC/Status + serialização
  internal/handlers/admin.go     # Login (JWT), List/Get/Approve/Reject
  internal/handlers/facetec.go
  internal/worker/tasks.go
  internal/facetec/facetec.go
  go.mod / Dockerfile / .env / .env.example
```

- **DB:** `postgres://kyc:kyc@postgres:5432/kyc?sslmode=disable` (GORM, `AutoMigrate`)
- **Redis:** `redis://redis:6379/0` (go-redis + Asynq `RedisClientOpt`)
- **Auth:** JWT `HS256` 30min, `admin_token` cookie HttpOnly Secure SameSite Strict.
- **CORS:** `KYC_APP_ORIGIN=http://localhost:3001,http://localhost:3002,http://localhost:5173` (configurável)

### Background Jobs (Regra: só App async, Backoffice sync)

- **Fila `kyc` (prioridade 6) + `default` (3)** — Asynq
- `CustomerProfileJob` (`customer:profile`) — mock enriquecimento
- `KycProcessingJob` (`kyc:processing`) — chama FaceTec Server (`/process-request`), fallback simulação 80% aprova, atualiza `KycSession` (`success, livenessProven, matchLevel`) e `Customer.status`.

---

## Docker

```bash
# build
docker compose build

# up (sem facetec, já que precisa do ZIP)
docker compose up -d postgres redis
docker compose up -d kyc-go kyc-worker kyc-backoffice

# logs
docker logs kyc-stack-kyc-go-1 -f
docker logs kyc-stack-kyc-worker-1 -f

# health
curl http://localhost:3002/health
curl http://localhost:3002/up

# backoffice
open http://localhost:3001/login  # admin@obsidian.com / Obsidian123!

# com facetec (após extrair ZIP para ./facetec-server/FaceTec-Server-Webservice/)
docker compose --profile facetec up -d facetec-server
```

**Portas host ajustadas para evitar conflito com host (run-flow em :5432/:3000):**
- postgres `:5433`, redis `:6380`, kyc-go `:3002`, backoffice `:3001`.

---

## Segurança — Mitigações

| Ataque | Mitigação |
|--------|-----------|
| **Session Hijacking** | `admin_token` HttpOnly + Secure + SameSite Strict, expire 30min, JWT expiração curta (30min), `Referrer-Policy: strict-origin-when-cross-origin` |
| **CSRF** | `SameSite=Strict` + CSRF double-submit (`csrf_token` cookie lido por JS) + verificação header `X-CSRF-Token`; backoffice usa `POST` com cookie HttpOnly, app usa HMAC (não vulnerável a CSRF por não usar cookie) |
| **SQL Injection** | GORM placeholders (`Where("cpf = ?", cpf)`), `escapeLike`, sem interpolação |
| **XSS** | React auto-escape, sem `dangerouslySetInnerHTML`, `Content-Security-Policy: default-src 'self'`, `X-XSS-Protection: 1; mode=block`, `X-Content-Type-Options: nosniff` |
| **Clickjacking** | `X-Frame-Options: DENY`, `frame_ancestors: none` no CSP |
| **Replay / Idempotência** | HMAC: `Timestamp` 5min tolerância + `Nonce` SETNX 10min no Redis (anti-replay); `Idempotency-Key` + `CPF unique` (409/200) |
| **Brute Force** | Rate limiting com `golang.org/x/time/rate` / `go-redis/redis_rate` se necessário; senha bcrypt |
| **Hash Key vazamento** | `API_HMAC_SECRET` via env, não commitado, logs com filtro de `password/secret/token` |
| **CORS** | `gin-contrib/cors` com origins explícitas (`KYC_APP_ORIGIN`), `AllowCredentials: true` só para origins confiáveis |

---

## Teste ponta a ponta (HMAC)

```bash
# login admin
curl -X POST http://localhost:3002/api/admin/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@obsidian.com","password":"Obsidian123!"}'

# criar perfil (HMAC)
python3 - <<'PY'
import hmac, hashlib, json, time, uuid, urllib.request, urllib.error
secret="obsidian_hmac_secret_2026_change_me_32bytes!"
key_id="obsidian_app"
ts=str(int(time.time())); nonce=str(uuid.uuid4())
body=json.dumps({"customer":{"cpf":"52998224725","nome":"Pietro","sobrenome":"Vieira","data_nascimento":"1995-06-15","email":"pietro@obsidian.com","telefone":"11999999999","logradouro":"Av. Paulista","numero":"1000","complemento":"Apto 101","bairro":"Bela Vista","cidade":"São Paulo","estado":"SP","cep":"01310-100","pais":"Brasil"}})
body_hash=hashlib.sha256(body.encode()).hexdigest()
canonical="\n".join([ts, nonce, "POST", "/api/v1/customers", body_hash])
sig=hmac.new(secret.encode(), canonical.encode(), hashlib.sha256).hexdigest()
headers={"X-API-Key":key_id,"X-Timestamp":ts,"X-Nonce":nonce,"X-Signature":sig,"Content-Type":"application/json","Idempotency-Key":str(uuid.uuid4())}
req=urllib.request.Request("http://localhost:3002/api/v1/customers", data=body.encode(), headers=headers, method="POST")
print(urllib.request.urlopen(req).read().decode()[:800])
PY

# sem HMAC deve falhar 401
curl -X POST http://localhost:3002/api/v1/customers -H "Content-Type: application/json" -d '{"customer":{"cpf":"123"}}' # 401

# KYC async
# (mesma lógica HMAC, POST /api/v1/customers/52998224725/kyc {requestBlob, documentType})

# polling
# GET /api/v1/customers/52998224725/status (com HMAC)
```

---

## Flutter

```bash
cd kyc-app
flutter pub get
flutter run --dart-define=BACKEND_URL=http://10.0.2.2:3002 # emulator
# ou
flutter run --dart-define=BACKEND_URL=http://localhost:3002 # desktop/web
```

**APK Release (produção VPS `191.252.204.221.sslip.io` com HMAC produção):**
```bash
# Universal (50MB) - debug signing
flutter build apk --release \
  --dart-define=BACKEND_URL=https://191.252.204.221.sslip.io \
  --dart-define=HMAC_SECRET=70358b8445e26c0845cdf866a84ee51800d14706019e2fe5a6a9fdea4e9781f5 \
  --dart-define=HMAC_KEY_ID=obsidian_app
# → build/app/outputs/flutter-apk/app-release.apk (48MB)

# Split por ABI (recomendado, ~15-19MB cada) - sem google_fonts/permission_handler + minify
flutter build apk --release --split-per-abi \
  --dart-define=BACKEND_URL=https://191.252.204.221.sslip.io \
  --dart-define=HMAC_SECRET=70358b8445e26c0845cdf866a84ee51800d14706019e2fe5a6a9fdea4e9781f5 \
  --dart-define=HMAC_KEY_ID=obsidian_app
# → app-armeabi-v7a-release.apk (14.9MB) / app-arm64-v8a-release.apk (17.4MB) / app-x86_64-release.apk (18.9MB)
# Para Play Store: flutter build appbundle --release (mesmos dart-define)
```

Fluxo 3 steps (sem tabs): **1 Cadastro completo** (`ProfileStepScreen`) → **2 Enviar documentos** (`DocumentStepScreen` RG/CNH/passport, fake blob) → **3 Aguardando** (`WaitingScreen` polling `getStatus` 10s, backoffice aprova/reprova).

---

## Próximos passos / Notas

- FaceTec Device SDK real: instalar `facetec_sdk` no `pubspec.yaml`, implementar `FaceTecSession` em `facetec_service.dart` (TODOs já documentados).
- Rate limiting Go: adicionar `gin` middleware com `go-redis/redis_rate`.
- Observabilidade: Prometheus + Grafana, structured logging.
- Split real em 3 binários: `cmd/gateway`, `cmd/customer`, `cmd/kyc` se escalar (hoje já é modular em `internal/*`).
- Postgres migrations versionadas: trocar `AutoMigrate` por `golang-migrate` em prod.

---

## Credenciais

- **Admin Backoffice:** `admin@obsidian.com` / `Obsidian123!` (via `ADMIN_SEED_EMAIL/PASSWORD`)
- **HMAC:** `obsidian_app` / `obsidian_hmac_secret_2026_change_me_32bytes!` (trocar em prod)
- **JWT:** `obsidian_jwt_secret_2026_change_me_64bytes_hex!_dev_only` (trocar em prod)

---

Built with Go 1.27 + Gin, Next.js 16, Flutter 3.47, Postgres 16, Redis 7, Docker.
