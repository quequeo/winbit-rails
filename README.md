# Winbit Rails + React (Vite UI)

Este repo contiene:

- **Rails** en la **raíz** (API) con Postgres + Devise + Google OAuth.
- **`ui/`**: SPA en **React + Vite** (Admin).

## Requisitos

- Ruby **3.2.4** (ver `.ruby-version`)
- Node **>= 20**
- Postgres corriendo en `localhost:5432`

## Levantar Backend (Rails)

1) Preparar gems y base de datos:

```bash
cd winbit-rails
bundle check || bundle install

# Recomendado: copiar `env.example` a `.env` (NO se commitea)
# y completar las variables ahí (se cargan con dotenv-rails).
#
# Alternativa: exportarlas en tu shell, por ejemplo:
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres

bin/rails db:prepare
bin/rails db:seed
```

2) Levantar servidor:

```bash
bin/rails server -p 3000
```

### Endpoints útiles

- `GET /api/public/wallets`
- `GET /api/public/investor/:email`
- `GET /api/public/investor/:email/history`
- `POST /api/public/requests`

## Levantar Frontend (React + Vite)

```bash
cd winbit-rails/ui
npm run dev
```

Abrí `http://localhost:5173`.

### Configuración API

Por default el frontend usa `http://localhost:3000`. Si necesitás cambiarlo:

```bash
VITE_API_BASE_URL=http://localhost:3000 npm run dev
```

## Login (Google OAuth)

El backend usa Devise + Google OAuth. Para que el login funcione en local:

- Definí `GOOGLE_CLIENT_ID` y `GOOGLE_CLIENT_SECRET` (en tu shell o en tu entorno)
- En Google Cloud, agregá como redirect URI:
  - `http://localhost:3000/users/auth/google_oauth2/callback`
- El seed crea estos admins (solo esos emails pueden entrar):
  - `winbit.cfds@gmail.com`
  - `jaimegarciamendez@gmail.com`

