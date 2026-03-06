# Lógica de negocio — Movimientos del portfolio

Este documento describe el flujo y las reglas de negocio para cada tipo de movimiento. Es complementario a `FORMULAS.md` (fórmulas matemáticas) y `CST_FEE_LOGIC.md` (comisión por retiro).

> **Referencia:** Ver `AGENTS.md` para convenciones. Mantener este archivo actualizado cuando cambie la lógica.

---

## 1) Fuente de verdad: PortfolioHistory

Todos los movimientos ejecutados se registran en `PortfolioHistory` con `status = COMPLETED`. Los eventos posibles:

| Evento | Descripción | Signo del amount |
|--------|-------------|------------------|
| `DEPOSIT` | Depósito de capital | Positivo |
| `WITHDRAWAL` | Retiro de capital | Positivo (el descuento se aplica por `previous_balance - amount`) |
| `DEPOSIT_REVERSAL` | Reversión de un depósito aprobado | Positivo |
| `OPERATING_RESULT` | Resultado operativo diario | Positivo o negativo |
| `TRADING_FEE` | Comisión (por retiro —CST— o periódica trimestral) | Negativo |
| `TRADING_FEE_ADJUSTMENT` | Ajuste/reembolso de fee (ej. reversión de retiro) | Positivo |
| `REFERRAL_COMMISSION` | Comisión por referido | Positivo |

---

## 2) Depósitos

### Flujo

1. **Solicitud:** El inversor crea una `InvestorRequest` (tipo `DEPOSIT`) desde winbit-app o el admin.
2. **Validaciones:** Inversor activo, monto > 0, método válido. Para métodos no cash (distinto de CASH_ARS, CASH_USD) se requiere `attachmentUrl` (comprobante).
3. **Aprobación:** Un admin aprueba en el backoffice. `Requests::Approve` crea un `PortfolioHistory` con evento `DEPOSIT` y actualiza el portfolio. Si la fecha es pasada (backfill), ejecuta `PortfolioRecalculator`.
4. **Notificaciones:** Se envían emails al inversor y al admin.

### Métodos de depósito

- `CASH_ARS`, `CASH_USD` — Efectivo (no requiere comprobante obligatorio).
- `USDT`, `USDC`, `CRYPTO` — Cripto; requiere `network` (TRC20, BEP20, ERC20, POLYGON) y `attachmentUrl` (comprobante).
- `LEMON_CASH` — Lemon; requiere `lemontag`.
- `SWIFT` — Transferencia internacional.
- `DepositOption` — Opciones configurables (CBU, Lemon, crypto, etc.) para que el inversor elija cómo depositar.

### Reversión

`Requests::ReverseApprovedDeposit` revierte un depósito aprobado: crea `DEPOSIT_REVERSAL` (amount positivo; el delta aplicado al balance es negativo) y ejecuta `PortfolioRecalculator`.

---

## 3) Retiros

### Flujo

1. **Solicitud:** El inversor crea una `InvestorRequest` (tipo `WITHDRAWAL`).
2. **Validaciones:** Inversor activo, portfolio existe, `current_balance >= amount`.
3. **Preview de fee:** La API pública expone `withdrawal_fee_preview` para que el inversor vea el monto de CST antes de solicitar.
4. **Aprobación:** Un admin aprueba. `Requests::Approve`:
   - Calcula y aplica la CST si hay rentabilidad positiva (ver `CST_FEE_LOGIC.md`).
   - Crea `PortfolioHistory` TRADING_FEE (si aplica) y WITHDRAWAL.
   - Actualiza el portfolio (o ejecuta `PortfolioRecalculator` si es backfill).
5. **Notificaciones:** Emails al inversor y admin.

### Regla clave

El inversor **siempre recibe el monto solicitado**. La CST es un descuento adicional del portfolio. Ver `CST_FEE_LOGIC.md` para la fórmula de rentabilidad y cuándo se cobra.

### Reversión

`Requests::ReverseApprovedWithdrawal` revierte un retiro aprobado: reembolsa el fee (TRADING_FEE_ADJUSTMENT) y el capital (DEPOSIT) y ejecuta `PortfolioRecalculator`.

---

## 4) Operativa diaria (OPERATING_RESULT)

### Concepto

Representa el resultado de la estrategia de trading para un día. Se aplica un **porcentaje** sobre el saldo de cada inversor activo al cierre operativo (17:00 del día).

### Flujo

1. **Preview:** El admin usa `DailyOperatingResultApplicator#preview` para ver el impacto por inversor.
2. **Aplicación:** `DailyOperatingResultApplicator#apply` crea:
   - Un registro `DailyOperatingResult` (fecha, porcentaje, aplicado por).
   - Un `PortfolioHistory` `OPERATING_RESULT` por cada inversor con saldo > 0.
3. **Fórmula:** `delta = round2(balance_before × percent / 100)`.
4. **Restricciones:** No se puede cargar operativa con fecha futura ni duplicada para la misma fecha.

### Inversores elegibles

Solo inversores `ACTIVE` con saldo > 0 al momento del cierre (17:00 del día).

Ver `FORMULAS.md` sección 5 para la fórmula detallada.

---

## 5) Comisión por referido (REFERRAL_COMMISSION)

### Concepto

Crédito manual que el admin aplica a un inversor por referir a otro. Es un **ingreso** (como un depósito): aumenta el balance pero **no cuenta como rentabilidad** para el cálculo de CST.

### Flujo

1. **Aplicación:** El admin usa `POST /api/admin/investors/:id/referral_commissions` con `amount` y opcionalmente `applied_at`.
2. **Servicio:** `ReferralCommissionApplicator` crea un `PortfolioHistory` con evento `REFERRAL_COMMISSION`.
3. **Backfill:** Si `applied_at` es en el pasado y hay movimientos posteriores, se inserta el evento en la fecha correcta y se ejecuta `PortfolioRecalculator`.

### Relación con CST

En la fórmula de rentabilidad (CST), los ingresos `DEPOSIT` y `REFERRAL_COMMISSION` se **restan** del cálculo. Ver `CST_FEE_LOGIC.md` sección 3.

---

## 6) Backfill (movimientos en el pasado)

Si se aprueba un depósito/retiro con fecha pasada, o se carga operativa/comisión referido en el pasado, Winbit ejecuta un **replay** del historial:

- Se inserta el evento en la fecha correcta.
- `PortfolioRecalculator.recalculate!(investor)` reescribe `previous_balance`/`new_balance` de todos los eventos en orden cronológico.
- Se actualizan `Portfolio.current_balance`, `total_invested` y retornos derivados.

Ver `FORMULAS.md` sección 9.

---

## 7) Referencias cruzadas

| Tema | Documento |
|------|-----------|
| Fórmulas (balance, TWR, operativa) | `FORMULAS.md` |
| Comisión por retiro (CST, Vpcust) | `CST_FEE_LOGIC.md` |
| Preguntas CST confirmadas | `../PREGUNTAS_CST.md` (workspace raíz) |
| Código: aprobación de requests | `app/services/requests/approve.rb` |
| Código: reversión depósito | `app/services/requests/reverse_approved_deposit.rb` |
| Código: reversión retiro | `app/services/requests/reverse_approved_withdrawal.rb` |
| Código: operativa diaria | `app/services/daily_operating_result_applicator.rb` |
| Código: comisión referido | `app/services/referral_commission_applicator.rb` |
| Código: fee periódico (trimestral) | `app/services/trading_fee_applicator.rb` |
| Código: recálculo de portfolio | `app/services/portfolio_recalculator.rb` |
