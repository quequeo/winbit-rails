# Winbit Rails - Admin Frontend

React + TypeScript admin interface for managing Winbit investments.

## Features

- 📊 **Dashboard** - Overview of investors, AUM, and pending requests
- 👥 **Investors** - Manage investor accounts and portfolios
- 💼 **Portfolios** - Update portfolio balances and performance metrics
- 📝 **Requests** - Process deposit and withdrawal requests
- 👤 **Admins** - Manage admin users and permissions
- 🔐 **Google OAuth** - Secure authentication via Devise
- 💰 **Argentine Format** - All currency values use format `$XX.XXX,XX` (dot for thousands, comma for decimals)

## Tech Stack

- **Frontend:** React 18 + TypeScript + Vite
- **Styling:** Tailwind CSS
- **Routing:** React Router v6
- **Authentication:** Google OAuth (via Rails Devise)
- **Testing:** Vitest + React Testing Library

## Development

```bash
# Install dependencies
npm install

# Start development server (runs on port 5174)
npm run dev

# Run tests
npm test

# Run tests with coverage
npm test -- --coverage

# Build for production
npm run build

# Preview production build
npm run preview

# Run linter
npm run lint

# Type check
npm run type-check
```

## Testing & Coverage

**Current Test Coverage:** 85.68%

| Metric | Percentage |
|--------|-----------|
| Lines | 85.68% |
| Statements | 85.68% |
| Branches | 85.03% |
| Functions | 65.28% |

### Test Suite

- **Total Tests:** 125 tests passing
- **Test Framework:** Vitest + React Testing Library
- **Test Files:** 10 test files

### Key Coverage Areas

- ✅ **API Service (`api.ts`):** 100% coverage (28 tests)
- ✅ **Formatters (`formatters.ts`):** 100% coverage (19 tests)
- ✅ **UI Components:** 100% coverage (Button, Input)
- ✅ **Pages:**
  - `DashboardPage` - 100% (7 tests)
  - `EditPortfolioPage` - 100% (11 tests)
  - `LoginPage` - 100% (12 tests)
  - `InvestorsPage` - 100% (13 tests)
  - `PortfoliosPage` - 100% (7 tests)
  - `RequestsPage` - 97.34% (15 tests)
  - `AdminsPage` - 98.41% (13 tests)

### Running Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm test -- --watch

# Run tests with coverage report
npm test -- --coverage

# Run specific test file
npm test -- src/lib/api.test.ts
```

## Project Structure

```
src/
├── components/
│   ├── ui/              # Reusable UI components (Button, Input)
│   └── layout/          # Layout components (AdminLayout)
├── lib/                 # Utilities
│   ├── api.ts          # API client for Rails backend
│   └── formatters.ts   # Number/currency formatters (Argentine format)
├── pages/              # Page components
│   ├── DashboardPage.tsx
│   ├── InvestorsPage.tsx
│   ├── PortfoliosPage.tsx
│   ├── EditPortfolioPage.tsx
│   ├── RequestsPage.tsx
│   ├── AdminsPage.tsx
│   └── LoginPage.tsx
├── App.tsx
└── main.tsx
```

## Number Format (Argentine Standard)

The app uses Argentine number formatting:

- **Thousands separator:** Point (`.`) - Example: `15.226`
- **Decimal separator:** Comma (`,`) - Example: `15.226,00`
- **Currency format:** `$15.226,00` (no space between $ and number)
- **Percentage format:** `1,50%`

### Formatter Functions

```typescript
import { formatCurrencyAR, formatNumberAR, formatPercentAR } from './lib/formatters';

formatCurrencyAR(15226.50);  // "$15.226,50"
formatNumberAR(15226.50);    // "15.226,50"
formatPercentAR(15.75);      // "15,75%"
```

## API Integration

The frontend communicates with the Rails API at `http://localhost:3000` (development) or the configured `VITE_API_BASE_URL`.

All requests include credentials (`credentials: 'include'`) for session-based authentication.

### Key API Endpoints

- `GET /api/admin/session` - Current user session
- `GET /api/admin/dashboard` - Dashboard statistics
- `GET /api/admin/investors` - List investors
- `GET /api/admin/portfolios` - List portfolios
- `PATCH /api/admin/portfolios/:id` - Update portfolio
- `GET /api/admin/requests` - List requests
- `POST /api/admin/requests/:id/approve` - Approve request
- `POST /api/admin/requests/:id/reject` - Reject request
- `GET /api/admin/admins` - List admins
- `DELETE /users/sign_out` - Sign out

## Authentication Flow

1. User clicks "Ingresar con Google"
2. Redirects to `/users/auth/google_oauth2` (Rails Devise)
3. Google OAuth consent screen
4. Rails validates and creates session
5. Redirects back to frontend
6. Frontend checks `/api/admin/session`
7. If authorized, shows admin interface
8. If unauthorized, redirects to login with error message

## Environment Variables

Create a `.env` file (optional):

```bash
VITE_API_BASE_URL=http://localhost:3000  # Rails API URL
```

If not set, defaults to `http://localhost:3000` in development and same-origin in production.

## Building for Production

```bash
npm run build
```

The built files will be in `dist/` and should be served by Rails from `public/` directory.

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers (iOS Safari, Chrome Mobile)
