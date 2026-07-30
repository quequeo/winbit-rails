import { useEffect, useMemo, useRef, useState } from "react";
import { DayPicker } from "react-day-picker";
import { es } from "react-day-picker/locale";
import { Input } from "./Input";

type Props = {
  value: string; // YYYY-MM-DD or ''
  onChange: (isoDate: string) => void;
  placeholder?: string;
  disabled?: boolean;
  id?: string;
};

const toIsoDate = (d: Date) => {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
};

const parseIsoDate = (iso: string) => {
  if (!iso || !/^\d{4}-\d{2}-\d{2}$/.test(iso)) return undefined;
  const [y, m, d] = iso.split("-").map((x) => Number(x));
  if (!y || !m || !d) return undefined;
  const dt = new Date(y, m - 1, d);
  if (!Number.isFinite(dt.getTime())) return undefined;
  // Reject impossible dates like 2025-02-31 that Date would roll over.
  if (
    dt.getFullYear() !== y ||
    dt.getMonth() !== m - 1 ||
    dt.getDate() !== d
  ) {
    return undefined;
  }
  return dt;
};

const calendarStartMonth = new Date(2018, 0);
const calendarEndMonth = () => {
  const now = new Date();
  return new Date(now.getFullYear() + 1, 11);
};

export const DatePicker = ({
  value,
  onChange,
  placeholder = "YYYY-MM-DD",
  disabled,
  id,
}: Props) => {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState(value || "");
  const rootRef = useRef<HTMLDivElement | null>(null);

  const selected = useMemo(() => parseIsoDate(value), [value]);
  const endMonth = useMemo(() => calendarEndMonth(), []);

  useEffect(() => {
    setDraft(value || "");
  }, [value]);

  useEffect(() => {
    if (!open) return;

    const onMouseDown = (e: MouseEvent) => {
      const el = rootRef.current;
      if (!el) return;
      if (e.target instanceof Node && !el.contains(e.target)) setOpen(false);
    };

    document.addEventListener("mousedown", onMouseDown);
    return () => document.removeEventListener("mousedown", onMouseDown);
  }, [open]);

  const handleSelect = (d?: Date) => {
    if (!d) return;
    onChange(toIsoDate(d));
    setOpen(false);
  };

  return (
    <div ref={rootRef} className="relative min-w-[11rem]">
      <div className="relative">
        <Input
          id={id}
          value={draft}
          placeholder={placeholder}
          disabled={disabled}
          readOnly
          className="cursor-pointer pr-10"
          onClick={() => {
            if (!disabled) setOpen(true);
          }}
          onFocus={() => {
            if (!disabled) setOpen(true);
          }}
          onKeyDown={(e) => {
            if (e.key === "Escape") setOpen(false);
            if (e.key === "Enter" || e.key === " ") {
              e.preventDefault();
              if (!disabled) setOpen(true);
            }
          }}
        />
        <button
          type="button"
          aria-label="Abrir calendario"
          className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-t-dim hover:bg-primary-dim hover:text-t-muted disabled:opacity-40"
          onClick={() => !disabled && setOpen((v) => !v)}
          disabled={disabled}
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            className="h-5 w-5"
            aria-hidden="true"
          >
            <path
              d="M7 3v2M17 3v2M4 8h16M6 5h12a2 2 0 012 2v13a2 2 0 01-2 2H6a2 2 0 01-2-2V7a2 2 0 012-2z"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </button>
      </div>

      {open ? (
        <div className="absolute z-50 mt-2 w-[340px] rounded-lg border border-b-default bg-dark-card p-3 pt-10 shadow-lg">
          <DayPicker
            mode="single"
            locale={es}
            selected={selected}
            defaultMonth={selected}
            onSelect={handleSelect}
            captionLayout="dropdown"
            startMonth={calendarStartMonth}
            endMonth={endMonth}
            reverseYears
            weekStartsOn={1}
            showOutsideDays
            classNames={{
              month_caption: "relative flex items-center justify-center mb-3",
              dropdowns: "flex items-center justify-center gap-2",
              dropdown_root: "relative inline-flex",
              dropdown:
                "appearance-auto cursor-pointer rounded-md border border-b-default bg-dark-section px-2 py-1.5 text-sm font-medium text-t-primary hover:border-b-accent focus:outline-none focus:border-b-accent",
              months_dropdown: "months_dropdown min-w-[7.5rem]",
              years_dropdown: "years_dropdown min-w-[4.5rem]",
              nav: "absolute inset-x-0 top-0 flex items-center justify-between",
              button_previous:
                "inline-flex h-8 w-8 items-center justify-center rounded-md border border-b-default text-t-muted hover:bg-primary-dim",
              button_next:
                "inline-flex h-8 w-8 items-center justify-center rounded-md border border-b-default text-t-muted hover:bg-primary-dim",
              month_grid: "w-full border-collapse",
              weekdays: "flex",
              weekday: "w-10 text-center text-xs text-t-dim font-medium",
              week: "flex w-full mt-1",
              day: "w-10 h-10 text-center",
              day_button: "h-10 w-10 rounded-md text-sm hover:bg-primary-dim",
              selected: "bg-primary text-white hover:bg-primary/80 rounded-md",
              today: "border border-primary rounded-md",
              outside: "text-t-dim",
            }}
          />
        </div>
      ) : null}
    </div>
  );
};
