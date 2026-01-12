import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { formatNumberAR, formatPercentAR } from '../lib/formatters';

export const EditPortfolioPage = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [inv, setInv] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState(() => ({
    currentBalance: 0,
    totalInvested: 0,
    accumulatedReturnUSD: 0,
    accumulatedReturnPercent: 0,
    annualReturnUSD: 0,
    annualReturnPercent: 0,
  }));

  useEffect(() => {
    // reuse portfolios list endpoint for now (simple)
    api
      .getAdminPortfolios()
      .then((res: any) => {
        const found = res.data.find((x: any) => x.id === id);
        if (!found) {
          setError('No se encontró el inversor/portfolio');
          return;
        }
        setInv(found);
      })
      .catch((e) => setError(e.message));
  }, [id]);

  useEffect(() => {
    if (!inv) return;
    const p = inv.portfolio || {
      current_balance: 0,
      total_invested: 0,
      accumulated_return_usd: 0,
      accumulated_return_percent: 0,
      annual_return_usd: 0,
      annual_return_percent: 0,
    };

    setForm({
      currentBalance: p.current_balance,
      totalInvested: p.total_invested,
      accumulatedReturnUSD: p.accumulated_return_usd,
      accumulatedReturnPercent: p.accumulated_return_percent,
      annualReturnUSD: p.annual_return_usd,
      annualReturnPercent: p.annual_return_percent,
    });
  }, [inv]);

  // Auto-calculate accumulated returns when balance or invested changes
  useEffect(() => {
    const currentBalance = Number(form.currentBalance) || 0;
    const totalInvested = Number(form.totalInvested) || 0;
    const accumulatedReturnUSD = currentBalance - totalInvested;
    const accumulatedReturnPercent = totalInvested > 0 ? (accumulatedReturnUSD / totalInvested) * 100 : 0;

    setForm((prev) => ({
      ...prev,
      accumulatedReturnUSD: Number(accumulatedReturnUSD.toFixed(2)),
      accumulatedReturnPercent: Number(accumulatedReturnPercent.toFixed(2)),
    }));
  }, [form.currentBalance, form.totalInvested]);

  if (error) return <div className="text-red-600">{error}</div>;
  if (!inv) return <div className="text-gray-600">Cargando...</div>;

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setSaving(true);
      await api.updatePortfolio(String(id), form);
      navigate('/portfolios');
    } catch (err: any) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const set = (key: string, value: any) => setForm((prev: any) => ({ ...prev, [key]: value }));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Editar Portfolio</h1>
          <p className="text-gray-600 mt-1">{inv.name}</p>
        </div>
        <Button variant="outline" onClick={() => navigate('/portfolios')}>Volver</Button>
      </div>

      <div className="rounded-lg bg-white p-6 shadow">
        <form onSubmit={onSubmit} className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-sm font-medium text-gray-700">Capital Actual</label>
              <Input type="number" step="0.01" value={form.currentBalance} onChange={(e) => set('currentBalance', e.target.value)} />
              <p className="text-sm font-medium text-[#58b098]">USD {formatNumberAR(Number(form.currentBalance) || 0)}</p>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium text-gray-700">Total Invertido</label>
              <Input type="number" step="0.01" value={form.totalInvested} onChange={(e) => set('totalInvested', e.target.value)} />
              <p className="text-sm font-medium text-[#58b098]">USD {formatNumberAR(Number(form.totalInvested) || 0)}</p>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium text-gray-700">
                Rend. Acum. desde el Inicio
                <span className="ml-1 text-xs text-gray-500">(Auto-calculado)</span>
              </label>
              <div className="w-full rounded-md border border-gray-300 bg-gray-50 px-3 py-2 text-sm font-medium text-gray-900">
                USD {formatNumberAR(Number(form.accumulatedReturnUSD) || 0)}
              </div>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium text-gray-700">
                Rend. Acum. (%)
                <span className="ml-1 text-xs text-gray-500">(Auto-calculado)</span>
              </label>
              <div className="w-full rounded-md border border-gray-300 bg-gray-50 px-3 py-2 text-sm font-medium text-gray-900">
                {formatPercentAR(Number(form.accumulatedReturnPercent) || 0)}
              </div>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium text-gray-700">Rend. Acum. Anual</label>
              <Input type="number" step="0.01" value={form.annualReturnUSD} onChange={(e) => set('annualReturnUSD', e.target.value)} />
              <p className="text-sm font-medium text-[#58b098]">USD {formatNumberAR(Number(form.annualReturnUSD) || 0)}</p>
            </div>
            <div className="space-y-2">
              <label className="text-sm font-medium text-gray-700">Rend. Acum. Anual (%)</label>
              <Input type="number" step="0.01" value={form.annualReturnPercent} onChange={(e) => set('annualReturnPercent', e.target.value)} />
              <p className="text-sm font-medium text-[#58b098]">{formatPercentAR(Number(form.annualReturnPercent) || 0)}</p>
            </div>
          </div>

          <div className="flex justify-end gap-3 pt-4 border-t">
            <Button type="button" variant="outline" onClick={() => navigate('/portfolios')}>
              Cancelar
            </Button>
            <Button type="submit" disabled={saving}>
              Guardar Cambios
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};
