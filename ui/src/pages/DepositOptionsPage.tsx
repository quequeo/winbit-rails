import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { ConfirmDialog } from '../components/ui/ConfirmDialog';

type DepositOption = {
  id: string;
  category: string;
  label: string;
  currency: string;
  details: Record<string, string>;
  active: boolean;
  position: number;
  createdAt: string;
  updatedAt: string;
};

const CATEGORIES = [
  { value: 'CASH_ARS', label: 'Efectivo ARS' },
  { value: 'CASH_USD', label: 'Efectivo USD' },
  { value: 'BANK_ARS', label: 'Transferencia bancaria ARS' },
  { value: 'LEMON', label: 'Lemon Cash' },
  { value: 'CRYPTO', label: 'Cripto' },
  { value: 'SWIFT', label: 'Transferencia internacional' },
];

const CURRENCIES = ['ARS', 'USD', 'USDT', 'USDC'];

const DEFAULT_CURRENCY: Record<string, string> = {
  CASH_ARS: 'ARS',
  CASH_USD: 'USD',
  BANK_ARS: 'ARS',
  LEMON: 'ARS',
  CRYPTO: 'USDT',
  SWIFT: 'USD',
};

const CATEGORY_FIELDS: Record<string, { key: string; label: string; placeholder: string }[]> = {
  CASH_ARS: [{ key: 'instructions', label: 'Instrucciones (opcional)', placeholder: 'Ej: Coordinar con el equipo' }],
  CASH_USD: [{ key: 'instructions', label: 'Instrucciones (opcional)', placeholder: 'Ej: Coordinar con el equipo' }],
  BANK_ARS: [
    { key: 'bank_name', label: 'Banco *', placeholder: 'Ej: Banco Galicia' },
    { key: 'holder', label: 'Titular *', placeholder: 'Ej: Winbit SRL' },
    { key: 'cbu_cvu', label: 'CBU / CVU *', placeholder: 'Ej: 0070000000000000001' },
    { key: 'alias', label: 'Alias (opcional)', placeholder: 'Ej: winbit.pesos' },
  ],
  LEMON: [
    { key: 'lemon_tag', label: 'Lemon Tag *', placeholder: 'Ej: $winbit' },
  ],
  CRYPTO: [
    { key: 'address', label: 'Dirección *', placeholder: 'Ej: TF7j33woKnMVFALtvRVdnFWnneNrUCVvAr' },
    { key: 'network', label: 'Red *', placeholder: 'Ej: TRC20, BEP20, ERC20, Polygon' },
  ],
  SWIFT: [
    { key: 'bank_name', label: 'Banco *', placeholder: 'Ej: Mercury' },
    { key: 'holder', label: 'Titular *', placeholder: 'Ej: Winbit LLC' },
    { key: 'swift_code', label: 'Código SWIFT *', placeholder: 'Ej: MERYUS33' },
    { key: 'account_number', label: 'Nº de cuenta *', placeholder: 'Ej: 123456789' },
    { key: 'routing_number', label: 'Routing number (opcional)', placeholder: 'Ej: 084009519' },
    { key: 'bank_address', label: 'Dirección del banco (opcional)', placeholder: 'Ej: 33 Whitehall St, New York' },
  ],
};

const categoryLabel = (cat: string) => CATEGORIES.find((c) => c.value === cat)?.label || cat;

type FormState = {
  category: string;
  label: string;
  currency: string;
  position: number;
  details: Record<string, string>;
};

const emptyForm = (cat = 'CASH_ARS'): FormState => ({
  category: cat,
  label: '',
  currency: DEFAULT_CURRENCY[cat] || 'ARS',
  position: 0,
  details: {},
});

export const DepositOptionsPage = () => {
  const [options, setOptions] = useState<DepositOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState<FormState>(emptyForm());
  const [submitting, setSubmitting] = useState(false);

  const [editingId, setEditingId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState<FormState>(emptyForm());

  const [deleteConfirm, setDeleteConfirm] = useState<{ isOpen: boolean; option: DepositOption | null }>({
    isOpen: false,
    option: null,
  });

  const [success, setSuccess] = useState<string | null>(null);

  const fetchOptions = async () => {
    try {
      setLoading(true);
      setError(null);
      const res = await api.getDepositOptions();
      setOptions((res as { data: DepositOption[] })?.data || []);
    } catch (err: any) {
      setError(err?.message || 'Error al cargar opciones');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchOptions();
  }, []);

  const showSuccess = (msg: string) => {
    setSuccess(msg);
    setTimeout(() => setSuccess(null), 3000);
  };

  const handleCategoryChange = (cat: string, setter: (s: FormState) => void, current: FormState) => {
    setter({
      ...current,
      category: cat,
      currency: DEFAULT_CURRENCY[cat] || current.currency,
      details: {},
    });
  };

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      await api.createDepositOption({
        category: formData.category,
        label: formData.label,
        currency: formData.currency,
        position: formData.position,
        details: formData.details,
      });
      setFormData(emptyForm());
      setShowForm(false);
      showSuccess('Opción creada exitosamente');
      fetchOptions();
    } catch (err: any) {
      const msg = tryParseError(err);
      setError(msg);
    } finally {
      setSubmitting(false);
    }
  };

  const startEdit = (opt: DepositOption) => {
    setEditingId(opt.id);
    setEditForm({
      category: opt.category,
      label: opt.label,
      currency: opt.currency,
      position: opt.position,
      details: { ...opt.details },
    });
  };

  const handleUpdate = async (e: React.FormEvent, id: string) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      await api.updateDepositOption(id, {
        category: editForm.category,
        label: editForm.label,
        currency: editForm.currency,
        position: editForm.position,
        details: editForm.details,
      });
      setEditingId(null);
      showSuccess('Opción actualizada exitosamente');
      fetchOptions();
    } catch (err: any) {
      const msg = tryParseError(err);
      setError(msg);
    } finally {
      setSubmitting(false);
    }
  };

  const handleToggle = async (opt: DepositOption) => {
    try {
      await api.toggleDepositOption(opt.id);
      fetchOptions();
    } catch (err: any) {
      setError(err?.message || 'Error al cambiar estado');
    }
  };

  const confirmDelete = async () => {
    if (!deleteConfirm.option) return;
    try {
      await api.deleteDepositOption(deleteConfirm.option.id);
      showSuccess('Opción eliminada');
      fetchOptions();
    } catch (err: any) {
      setError(err?.message || 'Error al eliminar');
    }
  };

  if (loading) {
    return (
      <div className="rounded-lg bg-white p-6 shadow-sm">
        <div className="text-gray-600">Cargando opciones de depósito...</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-gray-900">Opciones de depósito</h1>
          <p className="mt-1 text-gray-600">
            Gestiona las opciones que ven los clientes para depositar fondos.
          </p>
        </div>
        <Button onClick={() => { setShowForm(!showForm); setError(null); }} className="shrink-0">
          {showForm ? 'Cancelar' : '+ Nueva opción'}
        </Button>
      </div>

      {error && (
        <div className="rounded-lg bg-red-50 p-4 text-sm text-red-800">{error}</div>
      )}
      {success && (
        <div className="rounded-lg bg-green-50 p-4 text-sm text-green-800">{success}</div>
      )}

      {showForm && (
        <DepositOptionForm
          form={formData}
          setForm={setFormData}
          onSubmit={handleCreate}
          onCancel={() => setShowForm(false)}
          submitting={submitting}
          title="Nueva opción de depósito"
          submitLabel="Crear"
          onCategoryChange={(cat) => handleCategoryChange(cat, setFormData, formData)}
        />
      )}

      {options.length === 0 && !showForm ? (
        <div className="rounded-lg bg-white p-8 text-center shadow-sm">
          <p className="text-gray-500">No hay opciones de depósito configuradas.</p>
          <p className="mt-1 text-sm text-gray-400">Crea la primera opción usando el botón de arriba.</p>
        </div>
      ) : (
        <>
          {/* Mobile: cards */}
          <div className="grid gap-3 px-1 md:hidden">
            {options.map((opt) => (
              <div key={opt.id} className="w-full overflow-hidden rounded-lg bg-white p-4 shadow">
                {editingId === opt.id ? (
                  <DepositOptionForm
                    form={editForm}
                    setForm={setEditForm}
                    onSubmit={(e) => handleUpdate(e, opt.id)}
                    onCancel={() => setEditingId(null)}
                    submitting={submitting}
                    title="Editar opción"
                    submitLabel="Guardar"
                    onCategoryChange={(cat) => handleCategoryChange(cat, setEditForm, editForm)}
                  />
                ) : (
                  <OptionCard
                    opt={opt}
                    onEdit={() => startEdit(opt)}
                    onToggle={() => handleToggle(opt)}
                    onDelete={() => setDeleteConfirm({ isOpen: true, option: opt })}
                  />
                )}
              </div>
            ))}
          </div>

          {/* Desktop: table */}
          <div className="hidden md:block rounded-lg bg-white p-6 shadow">
            <div className="overflow-x-auto">
              <table className="min-w-full">
                <thead>
                  <tr className="text-left text-sm text-gray-500">
                    <th className="py-2">Pos</th>
                    <th className="py-2">Categoría</th>
                    <th className="py-2">Label</th>
                    <th className="py-2">Moneda</th>
                    <th className="py-2">Detalles</th>
                    <th className="py-2">Estado</th>
                    <th className="py-2 text-right">Acciones</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {options.map((opt) => (
                    <tr key={opt.id} className="text-sm">
                      {editingId === opt.id ? (
                        <td colSpan={7} className="py-4">
                          <DepositOptionForm
                            form={editForm}
                            setForm={setEditForm}
                            onSubmit={(e) => handleUpdate(e, opt.id)}
                            onCancel={() => setEditingId(null)}
                            submitting={submitting}
                            title="Editar opción"
                            submitLabel="Guardar"
                            onCategoryChange={(cat) => handleCategoryChange(cat, setEditForm, editForm)}
                          />
                        </td>
                      ) : (
                        <>
                          <td className="py-2 text-gray-500">{opt.position}</td>
                          <td className="py-2">
                            <span className="inline-flex rounded-full bg-gray-100 px-2 py-1 text-xs font-medium text-gray-700">
                              {categoryLabel(opt.category)}
                            </span>
                          </td>
                          <td className="py-2 font-medium">{opt.label}</td>
                          <td className="py-2">{opt.currency}</td>
                          <td className="py-2">
                            <DetailsPreview details={opt.details} category={opt.category} />
                          </td>
                          <td className="py-2">
                            <button
                              onClick={() => handleToggle(opt)}
                              className={`inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
                                opt.active
                                  ? 'bg-green-100 text-green-800 hover:bg-green-200'
                                  : 'bg-red-100 text-red-800 hover:bg-red-200'
                              }`}
                            >
                              {opt.active ? 'Activo' : 'Inactivo'}
                            </button>
                          </td>
                          <td className="py-2 text-right">
                            <div className="flex justify-end gap-2">
                              <button
                                onClick={() => startEdit(opt)}
                                className="rounded p-2 text-[#58b098] hover:bg-[#58b098]/10"
                                title="Editar"
                              >
                                <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                                </svg>
                              </button>
                              <button
                                onClick={() => setDeleteConfirm({ isOpen: true, option: opt })}
                                className="rounded p-2 text-red-600 hover:bg-red-50"
                                title="Eliminar"
                              >
                                <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                </svg>
                              </button>
                            </div>
                          </td>
                        </>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}

      <ConfirmDialog
        isOpen={deleteConfirm.isOpen}
        onClose={() => setDeleteConfirm({ isOpen: false, option: null })}
        onConfirm={confirmDelete}
        title="Eliminar opción de depósito"
        message={
          deleteConfirm.option ? (
            <>
              ¿Eliminar <span className="font-semibold">{deleteConfirm.option.label}</span> ({categoryLabel(deleteConfirm.option.category)})?
              <br />
              <span className="text-red-600">Esta acción no se puede deshacer.</span>
            </>
          ) : ''
        }
        confirmText="Eliminar"
        cancelText="Cancelar"
        confirmVariant="danger"
      />
    </div>
  );
};

function DepositOptionForm({
  form,
  setForm,
  onSubmit,
  onCancel,
  submitting,
  title,
  submitLabel,
  onCategoryChange,
}: {
  form: FormState;
  setForm: (s: FormState) => void;
  onSubmit: (e: React.FormEvent) => void;
  onCancel: () => void;
  submitting: boolean;
  title: string;
  submitLabel: string;
  onCategoryChange: (cat: string) => void;
}) {
  const fields = CATEGORY_FIELDS[form.category] || [];

  return (
    <div className="rounded-lg bg-white p-6 shadow">
      <h2 className="mb-4 text-lg font-semibold text-gray-900">{title}</h2>
      <form onSubmit={onSubmit} className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Categoría *</label>
            <select
              required
              value={form.category}
              onChange={(e) => onCategoryChange(e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#58b098] focus:outline-none focus:ring-1 focus:ring-[#58b098]"
            >
              {CATEGORIES.map((c) => (
                <option key={c.value} value={c.value}>{c.label}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Label *</label>
            <Input
              required
              value={form.label}
              onChange={(e) => setForm({ ...form, label: e.target.value })}
              placeholder="Ej: Banco Galicia - Pesos"
            />
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Moneda *</label>
            <select
              required
              value={form.currency}
              onChange={(e) => setForm({ ...form, currency: e.target.value })}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#58b098] focus:outline-none focus:ring-1 focus:ring-[#58b098]"
            >
              {CURRENCIES.map((c) => (
                <option key={c} value={c}>{c}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Posición</label>
            <Input
              type="number"
              min="0"
              value={form.position}
              onChange={(e) => setForm({ ...form, position: parseInt(e.target.value) || 0 })}
            />
          </div>
        </div>

        {fields.length > 0 && (
          <div className="rounded-lg border border-gray-200 p-4">
            <h3 className="mb-3 text-sm font-semibold text-gray-700">
              Detalles — {categoryLabel(form.category)}
            </h3>
            <div className="grid gap-3 sm:grid-cols-2">
              {fields.map((f) => (
                <div key={f.key}>
                  <label className="mb-1 block text-sm font-medium text-gray-700">{f.label}</label>
                  <Input
                    value={form.details[f.key] || ''}
                    onChange={(e) =>
                      setForm({ ...form, details: { ...form.details, [f.key]: e.target.value } })
                    }
                    placeholder={f.placeholder}
                  />
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex gap-3">
          <Button type="submit" disabled={submitting}>
            {submitting ? 'Guardando...' : submitLabel}
          </Button>
          <Button type="button" onClick={onCancel} className="bg-gray-500 hover:bg-gray-600">
            Cancelar
          </Button>
        </div>
      </form>
    </div>
  );
}

function OptionCard({
  opt,
  onEdit,
  onToggle,
  onDelete,
}: {
  opt: DepositOption;
  onEdit: () => void;
  onToggle: () => void;
  onDelete: () => void;
}) {
  return (
    <>
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold text-gray-900">{opt.label}</p>
          <p className="mt-1 text-xs text-gray-500">
            {categoryLabel(opt.category)} &middot; {opt.currency}
          </p>
        </div>
        <button
          onClick={onToggle}
          className={`shrink-0 inline-flex rounded-full px-2 py-1 text-xs font-semibold ${
            opt.active
              ? 'bg-green-100 text-green-800'
              : 'bg-red-100 text-red-800'
          }`}
        >
          {opt.active ? 'Activo' : 'Inactivo'}
        </button>
      </div>
      <div className="mt-3 border-t pt-3">
        <DetailsPreview details={opt.details} category={opt.category} />
      </div>
      <div className="mt-3 flex gap-2">
        <button onClick={onEdit} className="rounded p-2 text-[#58b098] hover:bg-[#58b098]/10" title="Editar">
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
          </svg>
        </button>
        <button onClick={onDelete} className="rounded p-2 text-red-600 hover:bg-red-50" title="Eliminar">
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
    </>
  );
}

function DetailsPreview({ details, category }: { details: Record<string, string>; category: string }) {
  const fields = CATEGORY_FIELDS[category] || [];
  const entries = fields
    .filter((f) => details[f.key])
    .map((f) => ({ label: f.label.replace(' *', '').replace(' (opcional)', ''), value: details[f.key] }));

  if (entries.length === 0) {
    return <span className="text-xs text-gray-400">Sin detalles</span>;
  }

  return (
    <div className="space-y-1">
      {entries.map((e) => (
        <p key={e.label} className="text-xs text-gray-600">
          <span className="font-medium">{e.label}:</span> {e.value}
        </p>
      ))}
    </div>
  );
}

function tryParseError(err: any): string {
  try {
    const parsed = JSON.parse(err?.message || '{}');
    return parsed?.error || err?.message || 'Error desconocido';
  } catch {
    return err?.message || 'Error desconocido';
  }
}
