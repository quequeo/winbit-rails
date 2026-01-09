# Winbit Rails + React

Plataforma de administración de inversiones con backend Rails API y frontend React.

## 🏗️ Arquitectura

- **Backend**: Rails 8 API (raíz del proyecto)
  - Postgres + Devise + Google OAuth
  - RSpec para testing
  - Rubocop para linting
  - Brakeman para security scanning
- **Frontend**: React + Vite + TypeScript (`ui/`)
  - TailwindCSS para estilos
  - Vitest + Testing Library para testing
  - ESLint para linting

## 📋 Requisitos

- Ruby **3.2.4** (ver `.ruby-version`)
- Node **>= 20.x**
- Postgres **>= 14**
- Git hooks configurados (se instalan automáticamente con `bin/setup`)

## 🚀 Setup Local

### 1. Clonar y configurar

```bash
git clone https://github.com/quequeo/winbit-rails.git
cd winbit-rails
```

### 2. Variables de entorno

Crear archivo `.env` en la raíz (no se commitea):

```bash
# Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# Google OAuth
GOOGLE_CLIENT_ID=tu_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=tu_client_secret

# Rails
RAILS_MASTER_KEY=tu_master_key
```

### 3. Backend (Rails)

```bash
# Instalar dependencias
bundle install

# Preparar base de datos
bin/rails db:prepare
bin/rails db:seed  # Crea admins y datos demo

# Levantar servidor
bin/rails server -p 3000
```

**API disponible en**: `http://localhost:3000`

### 4. Frontend (React)

```bash
cd ui
npm install
npm run dev
```

**UI disponible en**: `http://localhost:5173`

## 🔑 Autenticación (Google OAuth)

### Setup en Google Cloud Console

1. Ir a [Google Cloud Console](https://console.cloud.google.com/)
2. Crear un proyecto o usar uno existente
3. Habilitar "Google+ API"
4. Crear credenciales OAuth 2.0
5. Agregar URIs de redirección autorizadas:
   - Local: `http://localhost:3000/users/auth/google_oauth2/callback`
   - Producción: `https://winbit-rails-55a941b2fe50.herokuapp.com/users/auth/google_oauth2/callback`

### Admins autorizados

Solo estos emails pueden acceder (definidos en `db/seeds.rb`):
- `winbit.cfds@gmail.com`
- `jaimegarciamendez@gmail.com`

Para agregar más admins, crear registro en tabla `users` con rol `ADMIN` o `SUPERADMIN`.

## 🧪 Testing

### Backend (RSpec)

```bash
# Ejecutar todos los tests
bundle exec rspec

# Ejecutar tests específicos
bundle exec rspec spec/requests/api/admin/investors_spec.rb

# Con cobertura
COVERAGE=true bundle exec rspec
```

**Cobertura actual**: 79.36% (173 tests, 323/407 lines)

### Frontend (Vitest)

```bash
cd ui

# Ejecutar todos los tests
npm run test

# Con cobertura
npm run test -- --coverage

# Modo watch
npm run test -- --watch

# Solo un archivo
npm run test src/pages/InvestorsPage.test.tsx
```

**Cobertura actual**: 85.68% (124 tests)

| Métrica | Backend (Rails) | Frontend (React) |
|---------|----------------|------------------|
| **Lines** | 79.36% | 85.68% |
| **Branches** | N/A | 85.03% |
| **Functions** | N/A | 65.28% |
| **Total Tests** | 173 | 124 |

### Coverage por Componente (Frontend)

- ✅ API Service (`api.ts`): 100%
- ✅ Formatters (`formatters.ts`): 100%
- ✅ Pages: 84.53% promedio
  - DashboardPage: 100%
  - EditPortfolioPage: 100%
  - LoginPage: 100%
  - InvestorsPage: 100%
  - PortfoliosPage: 100%
  - RequestsPage: 97.34%
  - AdminsPage: 98.41%

## 🛠️ Scripts Útiles

### Importar datos de inversores desde spreadsheet

```bash
# En Heroku
heroku run rake investors:import -a winbit-rails

# Local
bin/rails investors:import
```

Este script actualiza portfolios con datos de capital y retornos.

### Linting y Security

```bash
# Backend
bundle exec rubocop              # Lint
bundle exec rubocop -a           # Auto-fix
bundle exec brakeman             # Security scan

# Frontend
cd ui
npm run lint                     # ESLint
npm run lint:fix                 # Auto-fix
```

## 🔄 Pre-Push Hooks

El proyecto tiene hooks de pre-push configurados que ejecutan automáticamente:

1. ✅ Bundle check
2. ✅ RSpec tests
3. ✅ Rubocop lint
4. ✅ Brakeman security scan
5. ✅ Vitest tests

Si algún check falla, el push es rechazado. Configuración en `.githooks/pre-push`.

## 📊 Modelos de Datos

- **User**: Admins del sistema (ADMIN, SUPERADMIN)
- **Investor**: Inversores con portfolios
- **Portfolio**: Balance actual y retornos acumulados
- **PortfolioHistory**: Historial de movimientos
- **InvestorRequest**: Solicitudes de depósito/retiro
- **Wallet**: Configuración de billeteras crypto

## 🌐 API Endpoints

### Public API

- `GET /api/public/wallets` - Billeteras disponibles
- `GET /api/public/investor/:email` - Info de inversor
- `GET /api/public/investor/:email/history` - Historial de movimientos
- `POST /api/public/requests` - Crear solicitud de depósito/retiro

### Admin API (requiere autenticación)

- **Admins**: `/api/admin/admins` (CRUD)
- **Investors**: `/api/admin/investors` (CRUD + sorting)
- **Portfolios**: `/api/admin/portfolios` (list, update)
- **Requests**: `/api/admin/requests` (CRUD + approve/reject)
- **Dashboard**: `/api/admin/dashboard` (estadísticas)

## 🚢 Deploy (Heroku)

### Configuración

```bash
# Login
heroku login

# Agregar remote
git remote add heroku https://git.heroku.com/winbit-rails.git

# Deploy
git push heroku main
```

### Buildpacks (en orden)

1. `heroku/nodejs` - Para construir UI React
2. `heroku/ruby` - Para Rails

### Config Vars necesarias

```bash
heroku config:set GOOGLE_CLIENT_ID=xxx
heroku config:set GOOGLE_CLIENT_SECRET=xxx
heroku config:set RAILS_MASTER_KEY=xxx
heroku config:set NODE_ENV=production
```

`DATABASE_URL` se configura automáticamente al agregar Heroku Postgres.

### Comandos útiles

```bash
# Ver logs
heroku logs --tail -a winbit-rails

# Ejecutar migraciones
heroku run rails db:migrate -a winbit-rails

# Importar datos
heroku run rake investors:import -a winbit-rails

# Console
heroku run rails console -a winbit-rails
```

## 📝 Desarrollo

### Agregar un nuevo admin

```ruby
# En rails console
User.create!(
  email: 'nuevo@ejemplo.com',
  name: 'Nuevo Admin',
  role: 'ADMIN'
)
```

### Crear inversor de prueba

```ruby
# En rails console
investor = Investor.create!(
  email: 'test@ejemplo.com',
  name: 'Inversor Test',
  status: 'ACTIVE'
)

Portfolio.create!(
  investor: investor,
  current_balance: 10000,
  total_invested: 10000,
  accumulated_return_usd: 0,
  accumulated_return_percent: 0,
  annual_return_usd: 0,
  annual_return_percent: 0
)
```

## 🔧 Troubleshooting

### Error: "No puedo conectarme a Postgres"

```bash
# Verificar que Postgres está corriendo
pg_isready

# Verificar variables de entorno
echo $POSTGRES_HOST
```

### Error: "redirect_uri_mismatch" en Google OAuth

Verificar que las URIs en Google Cloud Console coincidan exactamente:
- Local: `http://localhost:3000/users/auth/google_oauth2/callback`
- Producción: `https://tu-app.herokuapp.com/users/auth/google_oauth2/callback`

### Tests fallan en pre-push

```bash
# Ejecutar tests manualmente para ver detalles
bundle exec rspec
cd ui && npm run test:run
```

## 📄 Licencia

Privado - Winbit

