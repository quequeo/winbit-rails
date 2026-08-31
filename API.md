# API — winbit-rails

Documentación de los endpoints del backend. Base URL: `http://localhost:3000` (local) o la URL de producción.

> **Referencia:** Rutas en `config/routes.rb`. Mantener este archivo actualizado cuando cambien endpoints.

---

## Autenticación

La **API pública** no requiere token de admin. Los inversores se identifican por email (validado contra Firebase en producción).

La **API admin** requiere sesión de admin (Google OAuth). Los endpoints admin devuelven 401 si no hay sesión válida.

---

## API Pública (`/api/public/v1`)

Usada por **winbit-app** (portal de inversores).

### GET /api/public/v1/investor/:email

Obtiene datos del inversor y su portfolio.

**Parámetros:** `email` en la URL (URL-encoded).

**Respuesta 200:**
```json
{
  "data": {
    "investor": {
      "email": "user@example.com",
      "name": "Juan Pérez"
    },
    "portfolio": {
      "currentBalance": 10000.0,
      "totalInvested": 8000.0,
      "accumulatedReturnUSD": 2000.0,
      "accumulatedReturnPercent": 25.0,
      "annualReturnUSD": 1500.0,
      "annualReturnPercent": 18.75,
      "strategyReturnYtdUSD": 500.0,
      "strategyReturnYtdPercent": 6.25,
      "strategyReturnYtdFrom": "2024-01-01",
      "strategyReturnAllUSD": 2000.0,
      "strategyReturnAllPercent": 25.0,
      "strategyReturnAllFrom": "2023-06-01",
      "updatedAt": "2024-01-15T12:00:00.000Z"
    }
  }
}
```

**Errores:** 404 (inversor no existe), 403 (cuenta inactiva).

---

### GET /api/public/v1/investor/:email/history

Obtiene el historial de movimientos del inversor.

**Respuesta 200:**
```json
{
  "data": [
    {
      "id": 123,
      "investorId": 1,
      "date": "2024-01-15T19:00:00.000Z",
      "event": "DEPOSIT",
      "amount": 1000.0,
      "previousBalance": 9000.0,
      "newBalance": 10000.0,
      "status": "COMPLETED",
      "method": "USDT",
      "tradingFeePeriodLabel": null,
      "tradingFeePercentage": null,
      "tradingFeeSource": null,
      "tradingFeeWithdrawalAmount": null
    }
  ]
}
```

**Eventos:** `DEPOSIT`, `WITHDRAWAL`, `WITHDRAWAL_REVERSAL`, `OPERATING_RESULT`, `TRADING_FEE`, `TRADING_FEE_ADJUSTMENT`, `REFERRAL_COMMISSION`, `DEPOSIT_REVERSAL`.

---

### GET /api/public/v1/investor/:email/withdrawal_fee_preview?amount=X

Preview de la comisión CST para un retiro. **Query param `amount` requerido.**

**Respuesta 200:**
```json
{
  "data": {
    "withdrawalAmount": 1000.0,
    "feeAmount": 60.0,
    "feePercentage": 30.0,
    "realizedProfit": 200.0,
    "pendingProfit": 200.0,
    "hasFee": true
  }
}
```

**Errores:** 400/422 si monto inválido o supera el saldo.

---

### GET /api/public/v1/investor/:email/monthly_report

Descarga el PDF de reporte mensual del inversor. El PDF se sirve como `application/pdf` (stream, no URL pública permanente).

**Parámetros:**
- `email` en la URL (URL-encoded). Debe corresponder a un inversor `ACTIVE`.
- `month` (query, opcional) formato `YYYY-MM`. Si se omite, usa el último mes cerrado (mes calendario anterior).

**Respuesta 200:** binario PDF (`Content-Disposition: attachment`).

**Errores:** 404 (inversor inexistente o no hay PDF para ese mes), 403 (cuenta inactiva), 422 (mes inválido).

Nunca devuelve el PDF de otro inversor: el lookup es por el email de la URL.

---

### GET /api/public/v1/wallets

Lista de wallets habilitadas para depósitos.

**Respuesta 200:**
```json
{
  "data": [
    {
      "network": "USDT-TRC20",
      "address": "TXYZ...",
      "icon": "₮"
    }
  ]
}
```

---

### GET /api/public/v1/deposit_options

Opciones de depósito activas (CBU, Lemon, crypto, etc.).

**Respuesta 200:**
```json
{
  "data": [
    {
      "id": 1,
      "category": "CRYPTO",
      "label": "USDT TRC20",
      "currency": "USDT",
      "details": { "address": "...", "network": "TRC20" }
    }
  ]
}
```

---

### POST /api/public/v1/auth/login

Login con email y contraseña (inversores con password).

**Body:**
```json
{
  "email": "user@example.com",
  "password": "secret"
}
```

**Respuesta 200:**
```json
{
  "investor": {
    "email": "user@example.com",
    "name": "Juan"
  }
}
```

**Errores:** 401 (credenciales inválidas), 403 (cuenta desactivada).

---

### POST /api/public/v1/auth/change_password

Cambiar contraseña del inversor.

**Body:**
```json
{
  "email": "user@example.com",
  "current_password": "old",
  "new_password": "new123"
}
```

**Respuesta 200:** `{ "message": "Contraseña actualizada correctamente" }`

**Errores:** 401 (contraseña actual incorrecta), 422 (nueva contraseña < 6 caracteres).

---

### POST /api/public/v1/requests

Crear solicitud de depósito o retiro.

**Body (flat o bajo `request`):**
```json
{
  "email": "user@example.com",
  "type": "DEPOSIT",
  "amount": 1000,
  "method": "USDT",
  "network": "TRC20",
  "transactionHash": "0x...",
  "attachmentUrl": "https://...",
  "lemontag": "@user"
}
```

**Campos:**
- `email` (requerido)
- `type`: `DEPOSIT` | `WITHDRAWAL`
- `amount` (requerido, > 0)
- `method`: `CASH_ARS`, `CASH_USD`, `USDT`, `USDC`, `LEMON_CASH`, `SWIFT`, `CRYPTO`, etc.
- `network`: `TRC20`, `BEP20`, `ERC20`, `POLYGON` (para crypto)
- `transactionHash`, `attachmentUrl`, `lemontag` (opcionales; para depósitos no cash se requiere `attachmentUrl`)

**Respuesta 201:**
```json
{
  "data": {
    "id": 1,
    "investorId": 1,
    "type": "DEPOSIT",
    "amount": 1000.0,
    "method": "USDT",
    "status": "PENDING",
    "requestedAt": "2024-01-15T12:00:00.000Z"
  }
}
```

**Errores:** 400 (datos inválidos, saldo insuficiente para retiro), 404 (inversor no encontrado), 403 (inversor inactivo).

---

## API Admin (`/api/admin/v1`)

Requiere sesión de admin. Usada por el backoffice.

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/auth/login` | Login admin (email + password) |
| GET | `/session` | Sesión actual |
| GET | `/dashboard` | Resumen del dashboard |
| GET | `/investors` | Lista de inversores |
| GET | `/investors/:id` | Detalle de inversor |
| POST | `/investors` | Crear inversor |
| PATCH | `/investors/:id` | Actualizar inversor |
| DELETE | `/investors/:id` | Eliminar inversor |
| POST | `/investors/:id/toggle_status` | Activar/desactivar |
| POST | `/investors/:id/referral_commissions` | Aplicar comisión por referido |
| GET | `/requests` | Lista de solicitudes |
| POST | `/requests` | Crear solicitud |
| PATCH | `/requests/:id` | Actualizar solicitud |
| DELETE | `/requests/:id` | Eliminar solicitud |
| POST | `/requests/:id/approve` | Aprobar solicitud |
| POST | `/requests/:id/reject` | Rechazar solicitud |
| POST | `/requests/:id/reset_approval_to_pending` | Superadmin: deshace la aprobación (elimina los movimientos de historial generados por esa aprobación, deja la solicitud en `PENDING` y recalcula el portfolio). Solo si no hay `OPERATING_RESULT` posterior para el inversor. |
| GET | `/deposit_options` | Opciones de depósito |
| GET | `/daily_operating_results` | Operativa diaria |
| GET | `/daily_operating_results/series` | Serie diaria (params: `months`/`offset` o `from`/`to` YYYY-MM-DD) para gráficos/Excel |
| POST | `/daily_operating_results` | Cargar operativa |
| GET | `/operation_day_captures` | Capturas por día: sin `date` devuelve `{date,count}`; con `date=YYYY-MM-DD` lista capturas del día |
| GET | `/operation_day_captures/:id` | Metadata de una captura |
| GET | `/operation_day_captures/:id/image` | Binario PNG de la captura (sesión admin) |
| POST | `/operation_day_captures` | Superadmin: subir PNG (multipart `file`). Solo si existe `StrategyOperation` ese día. Idempotente por `original_filename` |
| GET | `/trading_fees` | Comisiones |
| POST | `/trading_fees` | Aplicar comisión |
| GET | `/trading_fees/investors_summary` | Resumen comisiones por inversor |
| GET | `/email_campaigns/preview` | Preview de campaña email (params: `month` YYYY-MM, opcional `subject`, `body`, `investor_id`). Lista inversores ACTIVE con `{{nombre}}`, `{{ganancia_usd}}`, `{{ganancia_pct}}`, etc. desde MonthlyReportBuilder. |
| POST | `/email_campaigns/send_one` | Envía email personalizado a un inversor (`month`, `subject`, `body`, `investor_id`). Multipart opcional: `attachment` (PDF/XLSX ≤10MB). Omite NotificationGate. From: `RESEND_FROM_EMAIL` (prod: `Winbit <noreply@winbit.com.ar>`); Reply-To: `RESEND_REPLY_TO` (default `winbit.cfds@gmail.com`). |
| POST | `/email_campaigns/send_mass` | Envía campaña a todos los ACTIVE con email (`month`, `subject`, `body`, `confirm=true`). Multipart opcional: `attachments[investor_id]` = archivo PDF/XLSX ≤10MB por destinatario. Sin adjunto → `deliver_later`; con adjunto → `deliver_now`. Omite NotificationGate. |
| GET | `/monthly_report_pdfs` | Lista PDFs de reporte mensual por mes (`month=YYYY-MM` requerido). Devuelve `present`, `missing` y `counts`. |
| POST | `/monthly_report_pdfs/bulk` | Carga masiva. Multipart: `month` + `files[]` (PDFs o ZIP). Por defecto es preview (`preview=true`): no escribe en DB y devuelve `assignments` (filename, parsedName, status assign/replace/skip, investor o reason). Persiste solo con `preview=false` o `confirm=true`. Asigna por nombre `Reporte julio - NOMBRE APELLIDO.pdf`. Con `investor_id` + un PDF, asigna directo a ese inversor. Máx. 15MB por PDF. |
| GET | `/monthly_report_pdfs/:id/file` | Descarga el PDF (sesión admin). |
| DELETE | `/monthly_report_pdfs/:id` | Elimina el PDF cargado. |
| GET | `/monthly_report_emails/preview` | Preview de envío de reporte mensual (params: `month` YYYY-MM, opcional `subject`, `body`, `investor_id`). Lista destinatarios elegibles (ACTIVE, balance > 0, PDF del mes) y omitidos. Interpola las mismas variables que campañas (`{{nombre}}` = nombre completo del inversor). |
| POST | `/monthly_report_emails/send_one` | Envía el email del reporte a un inversor (`month`, `subject`, `body`, `investor_id`) con el PDF ya cargado como adjunto (`Reporte julio 2026 - NOMBRE.pdf`). 422 si no es elegible. Omite NotificationGate (`force: true`). |
| POST | `/monthly_report_emails/send_mass` | Envía el reporte a todos los elegibles del mes (`month`, `subject`, `body`, `confirm=true`). Adjunta el PDF almacenado de cada uno. Omite NotificationGate. |
| GET | `/referral_commissions` | Comisiones por referido |
| GET | `/settings` | Configuración |
| PATCH | `/settings` | Actualizar configuración |
| GET | `/activity_logs` | Log de actividad |

---

## Formato de errores

```json
{
  "error": "Mensaje de error",
  "details": { }
}
```

Status HTTP: 400 (bad request), 401 (unauthorized), 403 (forbidden), 404 (not found), 422 (unprocessable entity), 500 (server error).
