import { useEffect, useMemo, useRef, useState } from 'react';
import { DayPicker } from 'react-day-picker';
import { Input } from './Input';

type Props = {
  value: string; // YYYY-MM-DD or ''
  onChange: (isoDate: string) => void;
  placeholder?: string;
  disabled?: boolean;
  id?: string;
};

const toIsoDate = (d: Date) => {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
};

const parseIsoDate = (iso: string) => {
  if (!iso || !/^\d{4}-\d{2}-\d{2}$/.test(iso)) return undefined;
  const [y, m, d] = iso.split('-').map((x) => Number(x));
  if (!y || !m || !d) return undefined;
  const dt = new Date(y, m - 1, d);
  return Number.isFinite(dt.getTime()) ? dt : undefined;
};

export const DatePicker = ({ value, onChange, placeholder = 'YYYY-MM-DD', disabled, id }: Props) => {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement | null>(null);

  const selected = useMemo(() => parseIsoDate(value), [value]);

  useEffect(() => {
    if (!open) return;

    const onMouseDown = (e: MouseEvent) => {
      const el = rootRef.current;
      if (!el) return;
      if (e.target instanceof Node && !el.contains(e.target)) setOpen(false);
    };

    document.addEventListener('mousedown', onMouseDown);
    return () => document.removeEventListener('mousedown', onMouseDown);
  }, [open]);

  const handleSelect = (d?: Date) => {
    if (!d) return;
    onChange(toIsoDate(d));
    setOpen(false);
  };

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        className="w-full text-left"
        onClick={() => !disabled && setOpen((v) => !v)}
        disabled={disabled}
      >
        <Input
          id={id}
          value={value || ''}
          placeholder={placeholder}
          readOnly
          disabled={disabled}
          className="cursor-pointer pr-10"
        />
        <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-gray-400">
          <svg viewBox="0 0 24 24" fill="none" className="h-5 w-5" aria-hidden="true">
            <path
              d="M7 3v2M17 3v2M4 8h16M6 5h12a2 2 0 012 2v13a2 2 0 01-2 2H6a2 2 0 01-2-2V7a2 2 0 012-2z"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </span>
      </button>

      {open ? (
        <div className="absolute z-50 mt-2 w-[320px] rounded-lg border border-gray-200 bg-white p-3 shadow-lg">
          <DayPicker
            mode="single"
            selected={selected}
            onSelect={handleSelect}
            weekStartsOn={1}
            showOutsideDays
            classNames={{
              caption: 'flex items-center justify-between mb-3',
              caption_label: 'text-sm font-semibold text-gray-900',
              nav: 'flex items-center gap-2',
              nav_button:
                'inline-flex h-8 w-8 items-center justify-center rounded-md border border-gray-200 text-gray-700 hover:bg-gray-50',
              table: 'w-full border-collapse',
              head_row: 'flex',
              head_cell: 'w-10 text-center text-xs text-gray-500 font-medium',
              row: 'flex w-full mt-1',
              cell: 'w-10 h-10 text-center',
              day: 'h-10 w-10 rounded-md text-sm hover:bg-gray-100',
              day_selected: 'bg-[#58b098] text-white hover:bg-[#4a9d84]',
              day_today: 'border border-[#58b098]',
              day_outside: 'text-gray-300',
            }}
          />
        </div>
      ) : null}
    </div>
  );
};

