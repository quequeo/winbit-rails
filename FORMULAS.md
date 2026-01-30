## Fórmulas y lógica financiera (Winbit)

Este documento describe **qué calcula Winbit** y **cómo**, para que los números sean auditables.

### 1) Modelo de movimientos (fuente de la verdad)
- **`PortfolioHistory`**: movimientos ya ejecutados (`status = COMPLETED`)
  - `event`: `DEPOSIT`, `WITHDRAWAL`, `OPERATING_RESULT`, `TRADING_FEE`, ...
  - `amount`: monto del movimiento (USD).  
    - Depósitos y resultados operativos suelen ser positivos.
    - Trading fee se guarda como monto **negativo**.
  - `previous_balance`, `new_balance`: “foto” de saldo antes/después del movimiento.
  - `date`: timestamp del movimiento.

- **`InvestorRequest`**: solicitudes del inversor (tabla `requests`)
  - Para depósitos/retiros en admin, al aprobar se crea un `PortfolioHistory` y se recalcula el portfolio.

### 2) Balance actual (`Portfolio.current_balance`)
Se deriva como el saldo final luego de “replay” del historial:

\[
current\_balance = \sum \Delta_i
\]

donde \(\Delta_i\) depende del evento:
- `DEPOSIT`: \(+\lvert amount\rvert\)
- `WITHDRAWAL`: \(-\lvert amount\rvert\)
- `OPERATING_RESULT`: \(+amount\)
- `TRADING_FEE`: \(-\lvert amount\rvert\)

### 3) Total invertido (`Portfolio.total_invested`)
En Winbit, “total invertido” es el **neto actualmente invertido**:

\[
total\_invested = \sum deposits - \sum withdrawals
\]

No descuenta trading fees (porque no son un retiro del inversor sino un costo de performance).

### 4) Resultado acumulado “legacy” (NO es el % principal)
Campos:
- `Portfolio.accumulated_return_usd`
- `Portfolio.accumulated_return_percent`

Definición:

\[
acc\_usd = current\_balance - total\_invested
\]
\[
acc\_\% = \begin{cases}
\frac{acc\_usd}{total\_invested}\times 100 & \text{si } total\_invested > 0 \\
0 & \text{si } total\_invested = 0
\end{cases}
\]

**Importante**: este % cambia si el inversor retira mucho capital (puede “inflarse”).  
Por eso el % **principal** del producto es el **TWR** (estrategia).

### 5) Operativa diaria (aplicación de `DailyOperatingResult`)
Para una fecha \(d\) con porcentaje \(p\%\):
- Se considera el saldo al “cierre operativo” (en backend usamos **17:00** del día \(d\)).
- Delta por inversor:

\[
\Delta = round2(balance\_{before} \times \frac{p}{100})
\]

- Saldo después:

\[
balance\_{after} = round2(balance\_{before} + \Delta)
\]

Se crea:
- `DailyOperatingResult(date, percent, applied_by, applied_at, notes)`
- un `PortfolioHistory` `OPERATING_RESULT` por inversor elegible.

### 6) Trading fee (comisión por performance)
Para un inversor y un período \([start..end]\):
- Profit base:

\[
profit = \sum OPERATING\_RESULT.amount \text{ dentro del período}
\]

- Fee:

\[
fee = round2(profit \times \frac{fee\_\%}{100})
\]

Se crea:
- `TradingFee(period_start, period_end, profit_amount, fee_percentage, fee_amount, applied_at, ...)`
- `PortfolioHistory` `TRADING_FEE` por \(-fee\)

### 7) Rentabilidad principal: **TWR** (Time-Weighted Return)
Objetivo: rentabilidad de la estrategia **independiente de depósitos/retiros**.

Definición por sub-períodos (se cortan en cada flujo externo):
- Flujos externos: `DEPOSIT`, `WITHDRAWAL`
- Performance interna: `OPERATING_RESULT`, `TRADING_FEE`, etc. (impactan el valor pero no cortan)

Para cada sub-período \(i\):
\[
r_i = \frac{V_{end,i} - V_{start,i}}{V_{start,i}}
\]

TWR total del período:
\[
TWR = \left(\prod_i (1+r_i)\right) - 1
\]

En Winbit:
- \(V_{end,i}\) se toma **justo antes** de un depósito/retiro (usando el `previous_balance` del flujo o el saldo calculado al timestamp).
- Trading fees reducen TWR porque son performance interna (bajan \(V\)).

### 8) PnL (USD) del período, consistente con TWR
Para un rango:
\[
PnL = V_{end} - V_{start} - net\_flows
\]
\[
net\_flows = \sum deposits - \sum withdrawals
\]

### 9) Backfill (cargar movimientos en el pasado)
Si se aprueba un depósito/retiro con fecha pasada o se carga una operativa histórica, Winbit ejecuta un **re-cálculo** (replay) del historial en orden cronológico:
- Reescribe `previous_balance/new_balance` coherentes.
- Recalcula `current_balance`, `total_invested` y retornos derivados.

Servicio: `PortfolioRecalculator.recalculate!(investor)`

