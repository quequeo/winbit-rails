import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { DatePicker } from '../components/ui/DatePicker';

type Investor = {
  id: string;
  name: string;
  email: string;
};

export const ReferralCommissionsPage = () => {
  const [investors, setInvestors] = useState<Investor[]>([]);
  const [investorId, setInvestorId] = useState('');
  const [amount, setAmount] = useState('');
  const [appliedAt, setAppliedAt] = useState('');
  const [applying, setApplying] = useState(false);
  const [flash, setFlash] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  useEffect(() => {
    api
      .getAdminInvestors()
      .then((res: any) => {
        const list = Array.isArray(res?.data) ? res.data : [];
        setInvestors(list.map((inv: any) => ({ id: inv.id, name: inv.name, email: inv.email })));
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    if (!flash) return;
    const t = setTimeout(() => setFlash(null), 4000);
    return () => clearTimeout(t);
  }, [flash]);

  const handleApply = async () => {
    if (!investorId) {
      setFlash({ type: 'error', message: 'Seleccioná un inversor' });
      return;
    }
    const num = Number(amount);
    if (!Number.isFinite(num) || num <= 0) {
      setFlash({ type: 'error', message: 'Ingresá un monto mayor a 0' });
      return;
    }

    try {
      setApplying(true);
      await api.applyReferralCommission(investorId, {
        amount: num,
        applied_at: appliedAt.trim() || undefined,
      });
      setFlash({ type: 'success', message: 'Comisión por referido aplicada correctamente' });
      setAmount('');
      setAppliedAt('');
      setInvestorId('');
    } catch (err: any) {
      setFlash({ type: 'error', message: err.message || 'Error al aplicar comisión por referido' });
    } finally {
      setApplying(false);
    }
  };

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Comisiones por referido</h1>
        <p className="mt-1 text-sm text-gray-600">
          Cargá un monto puntual al balance de un inversor. Si usás una fecha pasada, se recalcula el historial.
        </p>
      </div>

      {flash ? (
        <div
          className={
            `mb-4 rounded-lg border px-4 py-3 text-sm ` +
            (flash.type === 'success'
              ? 'border-green-200 bg-green-50 text-green-800'
              : 'border-red-200 bg-red-50 text-red-800')
          }
        >
          <div className="flex items-start justify-between gap-3">
            <span>{flash.message}</span>
            <button type="button" onClick={() => setFlash(null)} className="rounded px-2 py-1 text-xs hover:bg-black/5">
              Cerrar
            </button>
          </div>
        </div>
      ) : null}

      <div className="max-w-2xl rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <label className="mb-1 block text-sm font-medium text-gray-700">Inversor</label>
            <Select
              portal
              value={investorId}
              onChange={setInvestorId}
              options={[
                { value: '', label: 'Seleccionar...' },
                ...investors.map((inv) => ({
                  value: inv.id,
                  label: `${inv.name} — ${inv.email}`,
                })),
              ]}
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Monto (USD)</label>
            <Input
              type="number"
              inputMode="decimal"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              onWheel={(e) => e.currentTarget.blur()}
              placeholder="Ej: 50"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Fecha (opcional)</label>
            <DatePicker value={appliedAt} onChange={setAppliedAt} />
          </div>
        </div>

        <div className="mt-5 flex justify-end">
          <Button onClick={() => void handleApply()} disabled={applying}>
            {applying ? 'Aplicando...' : 'Aplicar comisión'}
          </Button>
        </div>
      </div>
    </div>
  );
};
