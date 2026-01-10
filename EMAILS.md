# 📧 Sistema de Notificaciones por Email - Winbit

## Resumen

Winbit utiliza **Action Mailer + Resend** para enviar notificaciones automáticas tanto a clientes (inversores) como a administradores.

---

## 🔑 Configuración

### Variables de Entorno Requeridas:

```bash
# Resend API Key (obtener en https://resend.com/api-keys)
RESEND_API_KEY=re_xxxxxxxxxxxxx

# Email "desde" (From)
RESEND_FROM_EMAIL=Winbit <noreply@yourdomain.com>

# Host de la aplicación (para links en emails)
APP_HOST=winbit-rails-55a941b2fe50.herokuapp.com
```

### Setup en Heroku:

```bash
heroku config:set RESEND_API_KEY=re_xxxxxxxxxxxxx -a winbit-rails
heroku config:set RESEND_FROM_EMAIL="Winbit <noreply@yourdomain.com>" -a winbit-rails
heroku config:set APP_HOST=winbit-rails-55a941b2fe50.herokuapp.com -a winbit-rails
```

---

## 📧 Emails Implementados

### Para Inversores (InvestorMailer):

#### 1. Depósitos:
- **`deposit_created`**: Email cuando el cliente crea una solicitud de depósito
  - Asunto: "✅ Depósito recibido - Pendiente de revisión"
  - Contenido: Confirma que se recibió la solicitud y está pendiente de aprobación

- **`deposit_approved`**: Email cuando el admin aprueba el depósito
  - Asunto: "🎉 Depósito aprobado - Fondos acreditados"
  - Contenido: Confirma que los fondos fueron acreditados + nuevo balance

- **`deposit_rejected`**: Email cuando el admin rechaza el depósito
  - Asunto: "❌ Depósito rechazado"
  - Contenido: Explica el motivo del rechazo + opciones para reintentar

#### 2. Retiros:
- **`withdrawal_created`**: Email cuando el cliente solicita un retiro
  - Asunto: "✅ Retiro solicitado - Pendiente de procesamiento"
  - Contenido: Confirma que se recibió la solicitud + horarios de procesamiento

- **`withdrawal_approved`**: Email cuando el admin aprueba el retiro
  - Asunto: "🎉 Retiro aprobado - Fondos enviados"
  - Contenido: Confirma que los fondos fueron enviados + nuevo balance

- **`withdrawal_rejected`**: Email cuando el admin rechaza el retiro
  - Asunto: "❌ Retiro rechazado"
  - Contenido: Explica el motivo del rechazo + opciones para reintentar

### Para Administradores (AdminMailer):

#### 1. Nuevas Solicitudes:
- **`new_deposit_notification`**: Notifica cuando hay un nuevo depósito pendiente
  - Destinatarios: `jaimegarciamendez@gmail.com`, `winbit.cfds@gmail.com`
  - Asunto: "💰 Nuevo depósito de [Cliente] - $X.XXX,XX"
  - Contenido: Detalles del cliente, monto, método, link al backoffice

- **`new_withdrawal_notification`**: Notifica cuando hay un nuevo retiro pendiente
  - Destinatarios: `jaimegarciamendez@gmail.com`, `winbit.cfds@gmail.com`
  - Asunto: "💸 Nueva solicitud de retiro de [Cliente] - $X.XXX,XX"
  - Contenido: Detalles del cliente, monto, método, tipo (parcial/total), link al backoffice

---

## 🔄 Flujo de Envío

### Cuando se crea una solicitud (depósito o retiro):

```ruby
# app/controllers/api/public/requests_controller.rb
InvestorMailer.deposit_created(investor, request).deliver_later
AdminMailer.new_deposit_notification(request).deliver_later
```

### Cuando se aprueba una solicitud:

```ruby
# app/services/requests/approve.rb
InvestorMailer.deposit_approved(investor, request).deliver_later
```

### Cuando se rechaza una solicitud:

```ruby
# app/services/requests/reject.rb
InvestorMailer.deposit_rejected(investor, request, reason).deliver_later
```

---

## 🧪 Testing

### Correr tests de mailers:

```bash
bundle exec rspec spec/mailers/
```

### Tests incluidos:
- ✅ Verifican headers (destinatario, asunto, remitente)
- ✅ Verifican contenido del body (nombre del cliente, montos, etc.)
- ✅ Cubren todos los escenarios (creación, aprobación, rechazo)

---

## 💰 Costos

**Free Tier de Resend:**
- 3,000 emails/mes gratis
- 100 emails/día gratis

**Estimado para Winbit** (con ~50-100 solicitudes/mes):
- ~150-200 emails/mes
- **Costo: $0/mes** (dentro del free tier)

---

## 🎨 Templates

Los templates HTML están en:
- `app/views/investor_mailer/`
- `app/views/admin_mailer/`

Utilizan estilos inline para máxima compatibilidad con clientes de email.

---

## 📝 Notas Importantes

1. Los emails se envían **de forma asíncrona** usando `deliver_later`
2. Si falla el envío de email, **no bloquea** la creación/aprobación/rechazo de solicitudes
3. Los errores de email se loguean en Rails.logger pero no interrumpen el flujo
4. En development, los emails se envían a través de Resend SMTP

---

## 🔧 Troubleshooting

### "Email no se envía en development":
- Verificá que `RESEND_API_KEY` esté configurado en `.env`
- Revisá los logs de Rails: `tail -f log/development.log`

### "Email no llega en production":
- Verificá que las config vars de Heroku estén correctas
- Revisá los logs de Heroku: `heroku logs --tail -a winbit-rails`
- Verificá el dashboard de Resend para ver el estado de los envíos

### "Email va a spam":
- Considerá usar un dominio propio y configurar SPF/DKIM
- Resend permite configurar dominios custom para mejor entregabilidad

---

**Última actualización:** 2026-01-11  
**Estado:** ✅ Sistema de emails funcionando en development y production
