# CST — Lógica de cobro de comisión por retiro

Este documento describe cómo se calcula y aplica la comisión por retiro. Es la fuente de verdad para la implementación en `Requests::Approve` y en el preview de la API pública.

> **Referencia:** Ver `AGENTS.md` para convenciones generales. Mantener este archivo actualizado cuando cambie la lógica de fees.

---

## Glosario

| Sigla | Significado | Descripción |
|------|-------------|-------------|
| **CST** | Comisión de Servicio de Trading | La comisión que se cobra al inversor sobre la rentabilidad acumulada cuando retira fondos. |
| **Vpcust** / **VPCUST** | Valor Post Cobro Último Servicio de Trading | Capital neto desde el cual se mide la nueva rentabilidad. Es el saldo después del último fee o retiro. |
| **PCST** | Valor Pre Cobro Servicio de Trading | Saldo antes del último fee. No se usa en el modelo actual; el cálculo se basa en **Vpcust** (post cobro). |

---

## 1) Regla estructural

- **El inversor siempre recibe el monto que solicita retirar.** No se descuenta la comisión del retiro.
- La comisión es un **descuento adicional** del portfolio.
- **No existe fee pendiente:** siempre se cobra el X% completo sobre la rentabilidad acumulada y se actualiza la base (Vpcust).

---

## 2) Variable clave: Vpcust

**Vpcust** = Valor Post Cobro Último Servicio de Trading.

Representa el capital neto desde el cual se mide la **nueva** rentabilidad.

- Se actualiza **después de cada cobro de comisión** (TRADING_FEE).
- Se actualiza **después de cada retiro**, incluso si no hubo comisión (el saldo post-retiro pasa a ser el nuevo Vpcust).

En el código, Vpcust es el `new_balance` del último evento `TRADING_FEE` o `WITHDRAWAL` en `PortfolioHistory` (ordenado por fecha descendente).

---

## 3) Fórmula de rentabilidad

```
Rentabilidad del período = Saldo actual − Vpcust − Ingresos del período
```

**Ingresos del período** = eventos `DEPOSIT` + `REFERRAL_COMMISSION` desde el último reset (Vpcust).

- Los depósitos y comisiones por referido **no cuentan como rentabilidad**; se restan del cálculo.

---

## 4) Cuándo se cobra comisión en un retiro

- **Sí se cobra** si hay rentabilidad positiva acumulada.
- **No se cobra** si la rentabilidad es cero o negativa (ej.: retiro en pérdida).

El fee se calcula sobre **toda la ganancia acumulada**, no proporcional al monto retirado.

```
fee_amount = round2(rentabilidad_acumulada × (fee_percentage / 100))
```

---

## 5) Ejemplo numérico

| Paso | Saldo | Rentabilidad | Acción | Comisión | Nuevo saldo |
|------|-------|---------------|--------|----------|-------------|
| Inicial | 1.000 | — | Depósito 1.000 | — | 1.000 |
| Operativa +20% | 1.200 | 200 | — | — | 1.200 |
| Retiro 100 | 1.040 | 0 | Retiro 100 + fee 30%×200=60 | 60 | 1.040 |
| Retiro 100 (sin nueva rent.) | 940 | 0 | Retiro 100 | 0 | 940 |
| Operativa +30% | 1.222 | 282 | — | — | 1.222 |
| Cierre trimestral | 1.141 | 0 | Fee 30%×282=84,60 | 84,60 | 1.141 |

---

## 6) Implementación en código

### 6.1) `pending_profit_until` (Requests::Approve, Api::Public::InvestorsController)

```ruby
# 1. Último evento de reset (TRADING_FEE o WITHDRAWAL)
last_reset = PortfolioHistory
  .where(investor_id:, event: %w[TRADING_FEE WITHDRAWAL], status: 'COMPLETED')
  .where('date <= ?', as_of)
  .order(date: :desc, created_at: :desc)
  .first

vpcust = last_reset ? last_reset.new_balance : 0
reset_at = last_reset&.date

# 2. Ingresos desde el reset (DEPOSIT y REFERRAL_COMMISSION no cuentan como rentabilidad)
inflows = if reset_at
  PortfolioHistory
    .where(investor_id:, event: %w[DEPOSIT REFERRAL_COMMISSION], status: 'COMPLETED')
    .where('date > ? AND date <= ?', reset_at, as_of)
    .sum(:amount)
else
  PortfolioHistory
    .where(investor_id:, event: %w[DEPOSIT REFERRAL_COMMISSION], status: 'COMPLETED')
    .where('date <= ?', as_of)
    .sum(:amount)
end

# 3. Rentabilidad
pending = current_balance - vpcust - inflows
pending = pending > 0 ? pending : 0
```

### 6.2) `calculate_and_apply_withdrawal_fee`

- Usa `pending_profit_until` para obtener la rentabilidad acumulada.
- Si `pending_profit > 0`: `fee_amount = round2(pending_profit × percentage/100)`.
- Valida: `requested_amount + fee_amount <= previous_balance`.
- Crea `TradingFee` (source: WITHDRAWAL) y `PortfolioHistory` TRADING_FEE (monto negativo).
- El saldo final: `previous_balance - requested_amount - fee_amount`.

### 6.3) Orden de eventos en historial

Cuando retiro y comisión comparten la misma fecha, se muestran **TRADING_FEE antes que WITHDRAWAL** para que el Vpcust (saldo post-comisión) quede visualmente arriba del retiro. Ver `sort_history_items` en `Api::Public::InvestorsController`.

---

## 7) Preview de fee (API pública)

El endpoint `GET /api/public/v1/investor/:email/withdrawal_fee_preview?amount=X` (query param `amount` requerido) usa la misma lógica:

- `preview_pending_profit(investor, current_balance: portfolio.current_balance)`
- `fee_amount = round2(pending_profit × fee_percentage/100)` si hay rentabilidad positiva
- Retorna `{ withdrawalAmount, feeAmount, feePercentage, pendingProfit, realizedProfit, hasFee }` para que el inversor vea el costo antes de solicitar el retiro.

---

## 8) Retiro en pérdida

Si `saldo_actual < Vpcust` (rentabilidad negativa), no se cobra comisión. El retiro se procesa normalmente y el nuevo Vpcust = saldo post-retiro.

---

## 9) Referencias

- `app/services/requests/approve.rb` — `calculate_and_apply_withdrawal_fee`, `pending_profit_until`, `create_withdrawal_histories!`
- `app/controllers/api/public/investors_controller.rb` — `preview_pending_profit`, `withdrawal_fee_preview`, `sort_history_items`
- `../PREGUNTAS_CST.md` (workspace raíz) — Preguntas y respuestas confirmadas con el dueño.
