import type { ReactNode } from "react";

interface ConfirmDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string | ReactNode;
  confirmText?: string;
  cancelText?: string;
  confirmVariant?: "danger" | "primary";
}

export const ConfirmDialog = ({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  confirmText = "Confirmar",
  cancelText = "Cancelar",
  confirmVariant = "danger",
}: ConfirmDialogProps) => {
  if (!isOpen) return null;

  const handleConfirm = () => {
    onConfirm();
    onClose();
  };

  const confirmButtonClass =
    confirmVariant === "danger"
      ? "bg-red-600 text-white hover:bg-red-700 focus:ring-red-600"
      : "bg-primary text-white hover:bg-primary/80 focus:ring-primary";

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black transition-opacity"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="flex min-h-full items-center justify-center p-4">
        <div className="relative w-full max-w-md transform overflow-hidden rounded-lg bg-dark-card shadow-xl border border-b-default transition-all">
          {/* Header */}
          <div className="border-b border-b-default px-6 py-4">
            <h3 className="text-lg font-semibold text-t-primary">{title}</h3>
          </div>

          {/* Content */}
          <div className="px-6 py-4">
            {typeof message === "string" ? (
              <p className="text-sm text-t-muted">{message}</p>
            ) : (
              <div className="text-sm text-t-muted">{message}</div>
            )}
          </div>

          {/* Footer */}
          <div className="flex justify-end gap-3 border-t border-b-default px-6 py-4">
            <button
              onClick={onClose}
              className="rounded-lg border border-b-default bg-dark-section px-4 py-2 text-sm font-medium text-t-muted hover:bg-primary-dim focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-dark-bg"
            >
              {cancelText}
            </button>
            <button
              onClick={handleConfirm}
              className={`rounded-lg px-4 py-2 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-dark-bg ${confirmButtonClass}`}
            >
              {confirmText}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
