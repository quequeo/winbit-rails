# winbit-rails (Backoffice)

Backoffice administrativo de Winbit: API Rails + admin UI en `ui/`.

## Stack

- Ruby `3.3.9`
- Rails `8`
- PostgreSQL
- React + Vite + TypeScript (en `ui/`)

## URLs

- Local API/UI: `http://localhost:3000`
- Produccion: `https://admin.winbit.com.ar`

## Setup local

1) Crear `.env` en la raiz.

Variables minimas:

```bash
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
RAILS_MASTER_KEY=...
RESEND_API_KEY=...
RESEND_FROM_EMAIL=...
FRONTEND_URL=http://localhost:5173
CORS_ORIGINS=http://localhost:5173,https://app.winbit.com.ar
APP_HOST=localhost:3000
```

2) Instalar dependencias y preparar DB:

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed
```

3) Levantar servidor:

```bash
bin/rails server -p 3000
```

## Admin UI (`ui/`)

Para desarrollar la UI:

```bash
cd ui
npm install
npm run dev
```

Para publicar la UI en `public/` (servida por Rails):

```bash
cd ui
npm run build
cd ..
rsync -av --delete ui/dist/ public/
```

## Tests y calidad

```bash
# Backend
bundle exec rspec
bundle exec rubocop
bundle exec brakeman --no-pager -x EOLRuby

# Frontend admin
npm --prefix ui run test:run
npm --prefix ui run lint
```

## Deploy

Heroku hace auto-deploy desde GitHub `main`.

- Hacer push a `origin/main`
- No usar `git push heroku main`

## Notas funcionales

- Backfill de solicitudes: desde admin se puede aprobar una solicitud con fecha pasada; el sistema recalcula historial y portfolio.
- Formula financiera (TWR y derivadas): ver `FORMULAS.md`.

## Documentacion operativa

- Convenciones del repo: `AGENTS.md`
- Rutas API: `config/routes.rb`

