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
      ? "bg-[rgba(196,107,107,0.2)] text-[#c46b6b] border border-[rgba(196,107,107,0.25)] hover:bg-[rgba(196,107,107,0.3)]"
      : "bg-[rgba(101,167,165,0.2)] text-white border border-[rgba(101,167,165,0.35)] hover:bg-[rgba(101,167,165,0.3)]";

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      <div
        className="fixed inset-0 bg-black/70 backdrop-blur-sm transition-opacity"
        onClick={onClose}
      />

      <div className="flex min-h-full items-center justify-center p-4">
        <div className="relative w-full max-w-md transform overflow-hidden rounded-lg admin-card !transition-none border border-[rgba(101,167,165,0.25)]">
          <div className="border-b border-b-default px-6 py-4">
            <h3 className="text-lg font-semibold text-white">{title}</h3>
          </div>

          <div className="px-6 py-4">
            {typeof message === "string" ? (
              <p className="text-sm text-t-muted">{message}</p>
            ) : (
              <div className="text-sm text-t-muted">{message}</div>
            )}
          </div>

          <div className="flex justify-end gap-3 border-t border-b-default px-6 py-4">
            <button
              onClick={onClose}
              className="rounded-lg border border-[rgba(101,167,165,0.25)] bg-dark-section px-4 py-2 text-sm font-medium text-t-muted transition-all duration-200 hover:bg-primary-dim focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-dark-bg"
            >
              {cancelText}
            </button>
            <button
              onClick={handleConfirm}
              className={`rounded-lg px-4 py-2 text-sm font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-dark-bg focus:ring-primary ${confirmButtonClass}`}
            >
              {confirmText}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
