import type { ButtonHTMLAttributes } from "react";

type Variant = "default" | "outline" | "destructive" | "ghost";

type Props = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant;
  size?: "sm" | "md";
};

export const Button = ({
  variant = "default",
  size = "md",
  className = "",
  ...props
}: Props) => {
  const base =
    "inline-flex items-center justify-center rounded-lg font-medium transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-dark-bg disabled:opacity-50 disabled:cursor-not-allowed";

  const sizes = {
    sm: "px-3 py-2 text-sm",
    md: "px-4 py-2 text-sm",
  };

  const variants: Record<Variant, string> = {
    default:
      "bg-[rgba(101,167,165,0.25)] text-white border border-[rgba(101,167,165,0.45)] hover:bg-[rgba(101,167,165,0.35)] hover:border-[rgba(101,167,165,0.65)] hover:-translate-y-0.5 hover:shadow-[0_0_14px_rgba(101,167,165,0.15)] focus:ring-primary",
    outline:
      "border border-[rgba(101,167,165,0.25)] bg-dark-card text-t-primary hover:border-[rgba(101,167,165,0.55)] hover:text-primary focus:ring-primary",
    destructive:
      "bg-[rgba(196,107,107,0.2)] text-[#d48080] border border-[rgba(196,107,107,0.25)] hover:bg-[rgba(196,107,107,0.3)] focus:ring-error",
    ghost:
      "bg-transparent text-t-muted hover:bg-primary-dim focus:ring-primary",
  };

  return (
    <button
      {...props}
      className={`${base} ${sizes[size]} ${variants[variant]} ${className}`}
    />
  );
};
