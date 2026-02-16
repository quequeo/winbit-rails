# AGENTS.md — winbit-rails (Backoffice)

Guía única de convenciones, criterios de aceptación y reglas operativas para el backoffice de Winbit.

## 0) Regla fundamental

Si algo no está claro o hay más de una opción válida, el agente DEBE preguntar antes de actuar. Nunca asumir. Nunca tomar decisiones ambiguas sin confirmación explícita del usuario.

## 0.1) Archivos raíz del repositorio

- `README.md` — Setup, uso, API reference y troubleshooting. NO se edita sin autorización.
- `FORMULAS.md` — Documentación de fórmulas financieras (TWR, etc.). NO se edita sin autorización.
- `AGENTS.md` — Este archivo. Convenciones y reglas operativas.

## 1) Stack y versiones

- **Backend:** Rails 8 API + SPA server sobre Ruby 3.3.9.
- **Frontend admin (SPA):** React 19 + Vite 7 + TypeScript + Tailwind CSS 4, servido desde `public/`.
- **Base de datos:** PostgreSQL.
- **Serializacion:** JSON directo en controllers (sin serializer gems).
- **Auth admin:** Google OAuth2 vía Devise + OmniAuth.
- **Auth clientes:** Firebase Auth (validación en API pública).
- **Emails:** Resend (AdminMailer, InvestorMailer).
- **Testing backend:** RSpec + SimpleCov.
- **Testing frontend:** Vitest + React Testing Library.
- **Linting:**
  - Ruby: RuboCop (`rubocop-rails-omakase`).
  - Frontend: ESLint 9 (flat config).
  - Seguridad: Brakeman.
- **Deploy:** Heroku (auto-deploy desde GitHub `main`).

## 2) Estructura del repositorio

```text
winbit-rails/
├── app/
│   ├── controllers/
│   │   └── api/
│   │       ├── admin/         # Endpoints del backoffice (auth requerida)
│   │       └── public/        # Endpoints para winbit-app (sin auth admin)
│   ├── models/                # ActiveRecord models (11)
│   ├── services/              # Service objects (10)
│   ├── mailers/               # AdminMailer, InvestorMailer
│   └── views/                 # Solo templates de email (ERB)
├── config/
│   ├── routes.rb
│   └── environments/
├── db/
│   ├── migrate/
│   └── schema.rb
├── lib/
│   └── middleware/            # Custom middleware (NoCacheHtml)
├── spec/                      # RSpec tests
├── ui/                        # Frontend admin (React + Vite + TS)
│   ├── src/
│   │   ├── components/        # UI components + layout
│   │   ├── pages/             # Page components
│   │   └── lib/               # api.ts, formatters.ts
│   └── package.json
├── .ruby-version              # 3.3.9
├── Gemfile
├── Procfile                   # release: db:migrate, web: puma
└── AGENTS.md
```

## 3) Configuración obligatoria

- `.ruby-version` con `3.3.9`.
- `.env` local, versionar solo `.env.example` si existe.
- Variables mínimas:
  - `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
  - `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`
  - `RAILS_MASTER_KEY`
  - `CORS_ORIGINS` (comma-separated, incluye Firebase Hosting y localhost)
- CORS con `rack-cors` (inicializado en `config/initializers/cors.rb`).

## 4) Modelos principales

| Modelo | Tabla | Asociaciones clave |
|--------|-------|--------------------|
| `User` | `users` | Admin/Superadmin. `has_many :applied_trading_fees`. Devise + OmniAuth. Roles: `ADMIN`, `SUPERADMIN`. |
| `Investor` | `investors` | `has_one :portfolio`, `has_many :portfolio_histories`, `has_many :investor_requests`, `has_many :trading_fees`. Status: `ACTIVE`/`INACTIVE`. |
| `Portfolio` | `portfolios` | `belongs_to :investor`. Balance y retornos. |
| `PortfolioHistory` | `portfolio_histories` | `belongs_to :investor`. Eventos: `DEPOSIT`, `WITHDRAWAL`, `OPERATING_RESULT`, `TRADING_FEE`, `TRADING_FEE_ADJUSTMENT`, `REFERRAL_COMMISSION`. |
| `InvestorRequest` | `requests` | `belongs_to :investor`. Tipos: `DEPOSIT`/`WITHDRAWAL`. Status: `PENDING`/`APPROVED`/`REJECTED`. |
| `TradingFee` | `trading_fees` | `belongs_to :investor`, `belongs_to :applied_by` (User). Períodos con `period_start`/`period_end`. |
| `DailyOperatingResult` | `daily_operating_results` | `belongs_to :applied_by` (User). Resultado diario (%). |
| `Wallet` | `wallets` | Assets: `USDT`/`USDC`. Networks: `TRC20`/`BEP20`/`ERC20`/`POLYGON`. |
| `ActivityLog` | `activity_logs` | `belongs_to :user`, `belongs_to :target` (polymorphic). Auditoría de acciones admin. |
| `AppSetting` | `app_settings` | Key-value para configuración global. |

### Reglas de modelos

- Validaciones de presencia/formato/rangos en modelos.
- Constantes para estados (sin magic strings): `User::ROLES`, `Investor::STATUSES`, etc.
- Scopes con nombres claros.
- Foreign keys siempre.
- Evitar N+1 con `includes`/`preload`. Para asociaciones polimórficas usar `preload`.
- Lógica de negocio en modelos y services, no en controllers.

## 5) API y controllers

### Estructura de namespaces

- `Api::Admin::*` — Requiere sesión admin (Devise). Para el backoffice SPA.
- `Api::Public::*` — Sin auth admin. Para winbit-app (portal de clientes).
- `SpaController` — Sirve `public/index.html` para rutas no-API (catch-all).

### Reglas de controllers

- Strong params obligatorios (`params.permit(...)`) en todo create/update.
- Controllers livianos: autentican, validan params, delegan a services, renderizan JSON.
- Autorización por roles con `before_action :require_superadmin!` para acciones destructivas o sensibles.
- Status HTTP coherentes: `200` ok, `201` create, `204` destroy, `404` not found, `422` validación, `403` forbidden.
- **Paginación:** implementación manual con `page`/`per_page` (default 200, max 200). Devolver `pagination` object en respuesta.
- **N+1:** siempre usar `includes` en queries de `index`.

### Acciones que requieren SUPERADMIN

- `AdminsController`: create, update, destroy
- `InvestorsController`: destroy
- `PortfoliosController`: update
- `SettingsController`: update
- `DailyOperatingResultsController`: create

## 6) Services

Services en `app/services/` para casos de uso:

| Service | Responsabilidad |
|---------|----------------|
| `PortfolioRecalculator` | Recalcula balances y retornos desde PortfolioHistory. |
| `TimeWeightedReturnCalculator` | Calcula TWR por sub-períodos. |
| `DailyOperatingResultApplicator` | Aplica resultados operativos diarios a todos los portfolios activos. |
| `TradingFeeCalculator` | Calcula comisiones de trading por período. |
| `TradingFeeApplicator` | Aplica comisiones calculadas. |
| `ReferralCommissionApplicator` | Aplica comisiones por referido a un inversor. |
| `Requests::Approve` | Aprueba solicitudes, actualiza portfolio, envía emails. |
| `Requests::Reject` | Rechaza solicitudes, envía emails. |
| `ActivityLogger` | Registra acciones admin con metadata. |
| `NotificationGate` | Controla si se envían notificaciones por email. |

### Reglas de services

- Un service por caso de uso.
- No rescatar `StandardError` amplio. Rescatar errores específicos.
- Transacciones cuando se modifican múltiples registros.

## 7) Rutas

- `resources ... only:` siempre.
- `member` para acciones sobre recurso singular (`toggle_status`, `approve`, `reject`).
- Rutas anidadas cuando correspondan (`investors/:id/referral_commissions`).
- Catch-all `*path` para SPA (excluye `/api`, `/users`, `/rails`).

## 8) Testing y cobertura

### Backend (RSpec)

- SimpleCov configurado en `rails_helper.rb`.
- Request specs por recurso/endpoint.
- Model specs para TODOS los modelos.
- Service specs para casos de uso críticos.
- Mailer specs.
- Casos válidos e inválidos (incluyendo 404, 422, 403).

### Frontend admin (Vitest)

- Vitest + React Testing Library + jsdom.
- Tests de componentes: loading, error, render de datos.
- Tests de flujos: submit de formularios, interacciones.
- Mock de API/servicios.
- `findByRole` (no `getByRole`) para elementos que aparecen después de fetch async.

### Correr tests

```bash
# Backend
bundle exec rspec

# Frontend admin
cd ui && npm run test:run

# Todo junto (CI)
bundle exec rspec && npm --prefix ui run test:run
```

## 9) Estilo y calidad de código

### Ruby

- RuboCop con `rubocop-rails-omakase`.
- Overrides en `.rubocop.yml`: trailing commas permitidas, string literals flexibles.
- Métodos pequeños y nombres expresivos.
- Callbacks solo si agregan valor claro.

### TypeScript (frontend admin)

- ESLint 9 (flat config).
- Prettier (no configurado explícitamente, usar defaults de ESLint).
- Componentes funcionales con hooks.
- API layer centralizado en `lib/api.ts`.
- Formato argentino para números: `$XX.XXX,XX` (función manual en `formatters.ts`, NO `toLocaleString`).

## 10) Seguridad

- Auth admin: Google OAuth2 vía Devise (sesión basada en cookies).
- Roles: `ADMIN` (lectura + operaciones básicas), `SUPERADMIN` (todo).
- Strong params en todo controller.
- Brakeman sin warnings críticos (excluir `EOLRuby` en CI).
- CORS configurado para orígenes permitidos.
- Middleware `NoCacheHtml`: previene cache del `index.html` del SPA.

## 11) Deploy

### Heroku

- **Auto-deploy desde GitHub:** push a `main` → deploy automático.
- **NO usar:** `git push heroku main`.
- **Procfile:** `release: bundle exec rails db:migrate` + `web: bundle exec puma -C config/puma.rb`.
- Build del frontend admin: debe hacerse antes del deploy (assets en `public/`).

### CI (GitHub Actions)

Jobs:
1. `scan_ruby` — Brakeman (`bin/brakeman --no-pager -x EOLRuby`)
2. `lint` — RuboCop
3. `test` — RSpec con servicio PostgreSQL
4. `ui_test` — Vitest (frontend admin)

## 12) Protocolo Git y PRs

### Reglas de branches

- Un branch por cambio puntual y atómico.
- Nombres de branch: `feature/<descripcion-corta>` o `fix/<descripcion-corta>`.
- Base siempre: `main`.

### Reglas de commits

- Mensaje conciso (1-2 líneas).
- NUNCA mencionar Cursor, Claude, AI, LLM, copilot ni herramientas de IA.
- PROHIBIDO cualquier trailer `Co-authored-by` que mencione IA.
- Usar `git -c commit.cleanup=verbatim` para evitar trailers automáticos.

### Flujo de trabajo (PR obligatorio)

1. `git checkout main && git pull origin main`
2. `git checkout -b feature/<nombre>`
3. Implementar cambio + tests
4. Verificar: `bundle exec rspec && bundle exec rubocop && npm --prefix ui run test:run`
5. `git add` (solo archivos relevantes, nunca secretos)
6. `git commit` (mensaje conciso)
7. `git push -u origin feature/<nombre>`
8. `gh pr create` (título descriptivo, body con summary y test plan)
9. Esperar que CI pase (Brakeman, RuboCop, RSpec, Vitest)
10. `gh pr merge --squash --delete-branch`
11. Volver a paso 1 para siguiente cambio

### Pre-push

- `bundle exec rspec` (todos en verde)
- `bundle exec rubocop` (sin offenses)
- `npm --prefix ui run test:run` (frontend en verde)
- Si alguno falla, corregir antes de pushear.

### Permisos operativos

El agente tiene autorización para: `git add`, `commit`, `push`, `gh pr create`, `gh pr merge`.

Condiciones:
- Cambios atómicos y trazables.
- Quality gates en verde (local + CI).
- Sin secretos versionados.
- No comandos destructivos salvo solicitud explícita.

## 13) Convenciones de negocio

- **Event names:** Siempre en inglés mayúsculas (`DEPOSIT`, `WITHDRAWAL`, `PROFIT`, `TRADING_FEE`, etc.).
- **Status:** `PENDING`, `COMPLETED`, `REJECTED`, `ACTIVE`, `INACTIVE`, `APPROVED`.
- **Formato numérico:** Argentino `$XX.XXX,XX` (punto miles, coma decimales).
- **Emails de soporte:** winbit.cfds@gmail.com
- **Admins autorizados:** jaimegarciamendez@gmail.com, winbit.cfds@gmail.com

## 14) Qué NO hacer

1. NO hacer `git push heroku main` (auto-deploy desde GitHub).
2. NO usar `toLocaleString` para formato argentino.
3. NO usar nombres de eventos en español (siempre inglés).
4. NO commitear sin pasar tests y linters.
5. NO crear archivos .md sin que el usuario lo pida.
6. NO usar `getByRole` para elementos async en tests (usar `findByRole`).
7. NO rescatar `StandardError` amplio en services.
8. NO permitir acciones destructivas sin `require_superadmin!`.
