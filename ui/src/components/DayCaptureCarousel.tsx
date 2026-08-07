import { useEffect, useState } from "react";

export type DayCaptureItem = {
  id: string;
  captureDate: string;
  asset?: string | null;
  resultLabel?: string | null;
  originalFilename: string;
  imageUrl: string;
};

type Props = {
  open: boolean;
  date: string;
  captures: DayCaptureItem[];
  onClose: () => void;
};

export const DayCaptureCarousel = ({
  open,
  date,
  captures,
  onClose,
}: Props) => {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    if (open) setIndex(0);
  }, [open, date, captures]);

  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
      if (event.key === "ArrowLeft") {
        setIndex((prev) => (prev - 1 + captures.length) % captures.length);
      }
      if (event.key === "ArrowRight") {
        setIndex((prev) => (prev + 1) % captures.length);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, captures.length, onClose]);

  if (!open || captures.length === 0) return null;

  const current = captures[Math.min(index, captures.length - 1)];
  const meta = [current.asset, current.resultLabel].filter(Boolean).join(" · ");

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 p-4"
      role="dialog"
      aria-modal="true"
      aria-label={`Capturas del ${date}`}
      onClick={onClose}
    >
      <div
        className="relative flex max-h-[92vh] w-full max-w-md flex-col overflow-hidden rounded-xl border border-b-accent bg-dark-card shadow-xl"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-center justify-between gap-3 border-b border-b-default px-4 py-3">
          <div>
            <p className="text-sm font-semibold text-t-primary">{date}</p>
            <p className="text-xs text-t-muted">
              {index + 1} / {captures.length}
              {meta ? ` · ${meta}` : ""}
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-md border border-b-default px-2 py-1 text-sm text-t-muted hover:bg-dark-section"
            aria-label="Cerrar"
          >
            ✕
          </button>
        </div>

        <div className="relative flex min-h-0 flex-1 items-center justify-center bg-black/40 px-10 py-4">
          {captures.length > 1 ? (
            <button
              type="button"
              className="absolute left-2 top-1/2 z-10 -translate-y-1/2 rounded-full border border-b-default bg-dark-card/90 px-2 py-1 text-lg text-t-primary hover:bg-primary-dim"
              onClick={() =>
                setIndex((prev) => (prev - 1 + captures.length) % captures.length)
              }
              aria-label="Captura anterior"
            >
              ‹
            </button>
          ) : null}

          <img
            src={current.imageUrl}
            alt={current.originalFilename}
            className="max-h-[70vh] w-auto max-w-full object-contain"
          />

          {captures.length > 1 ? (
            <button
              type="button"
              className="absolute right-2 top-1/2 z-10 -translate-y-1/2 rounded-full border border-b-default bg-dark-card/90 px-2 py-1 text-lg text-t-primary hover:bg-primary-dim"
              onClick={() => setIndex((prev) => (prev + 1) % captures.length)}
              aria-label="Captura siguiente"
            >
              ›
            </button>
          ) : null}
        </div>

        <p className="truncate border-t border-b-default px-4 py-2 text-xs text-t-dim">
          {current.originalFilename}
        </p>
      </div>
    </div>
  );
};
