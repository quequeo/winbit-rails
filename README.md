# Winbit (Backoffice) — winbit-rails

Backoffice administrativo (Rails 8) + UI (React/Vite/TS) servido desde Rails.

## Arquitectura
- **Backend**: Rails API + Postgres + Devise + Google OAuth
- **UI**: `ui/` (React + Vite + TypeScript + Tailwind). Rails sirve el build desde `public/`.

## 📋 Requisitos

- Ruby **3.2.4** (ver `.ruby-version`)
- Node **>= 20.x**
- Postgres **>= 14**
- Git hooks configurados (se instalan automáticamente con `bin/setup`)

## Setup local

### Variables de entorno

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

# Resend (notificaciones por email)
RESEND_API_KEY=re_xxxxxxxxxxxxx
RESEND_FROM_EMAIL=Winbit <noreply@yourdomain.com>

# Frontend URL (para links en emails y redirects OAuth)
FRONTEND_URL=http://localhost:5173

# CORS (frontend permitido)
CORS_ORIGINS=http://localhost:5173,https://winbit-6579c.web.app

# App Host (para links en emails)
APP_HOST=localhost:3000
```

### Backend (Rails)

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

### UI (Backoffice)

La UI vive en `ui/` pero en `http://localhost:3000` se ve lo que está en `public/`.

Para ver cambios en `localhost:3000` después de editar `ui/`:

```bash
cd ui
npm install
npm run build

cd ..
rsync -av --delete ui/dist/ public/
```

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

## Fórmulas / finanzas
Ver el documento de fórmulas en el root del monorepo:
- `../FORMULAS.md`

## 📧 Sistema de Notificaciones por Email

Winbit utiliza **Resend** para enviar notificaciones automáticas:

### Emails para Inversores:
- ✅ Depósito creado, aprobado, rechazado
- ✅ Retiro creado, aprobado, rechazado

### Emails para Admins:
- 💰 Nuevo depósito pendiente
- 💸 Nuevo retiro pendiente

### Configuración:

```bash
# Obtener API key en https://resend.com/api-keys
heroku config:set RESEND_API_KEY=re_xxxxxxxxxxxxx -a winbit-rails
heroku config:set RESEND_FROM_EMAIL="Winbit <noreply@yourdomain.com>" -a winbit-rails
```

### Costos:
- **Free tier**: 3,000 emails/mes
- **Estimado Winbit**: ~150-200 emails/mes
- **Costo real**: $0/mes (dentro del free tier)

📖 **Documentación completa:** Ver [EMAILS.md](./EMAILS.md)

---

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

## Backfill de depósitos/retiros (admin)
En `Solicitudes` → `+ Agregar Solicitud` podés setear **Fecha (opcional)** y crear una solicitud ya **Aprobada**.
Si la fecha es pasada, el sistema recalcula el historial y el portfolio para mantener consistencia.

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

> **⚠️ IMPORTANTE**: Heroku está configurado para hacer **deploy automático** desde el branch `main` de GitHub.
> 
> **NO es necesario hacer** `git push heroku main` - solo hacer `git push origin main` y Heroku se encarga del resto.

### Configuración inicial (ya realizada)

```bash
# Login
heroku login

# Agregar remote (solo para comandos heroku, no para deploy)
git remote add heroku https://git.heroku.com/winbit-rails.git
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

