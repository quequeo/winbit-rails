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
    "inline-flex items-center justify-center rounded-lg font-medium transition focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-dark-bg disabled:opacity-50 disabled:cursor-not-allowed";

  const sizes = {
    sm: "px-3 py-2 text-sm",
    md: "px-4 py-2 text-sm",
  };

  const variants: Record<Variant, string> = {
    default: "bg-primary text-white hover:bg-primary/80 focus:ring-primary",
    outline:
      "border border-b-default bg-dark-card text-t-primary hover:border-primary hover:text-primary focus:ring-primary",
    destructive: "bg-red-600 text-white hover:bg-red-700 focus:ring-red-600",
    ghost: "bg-transparent text-t-muted hover:bg-primary-dim focus:ring-primary",
  };

  return (
    <button
      {...props}
      className={`${base} ${sizes[size]} ${variants[variant]} ${className}`}
    />
  );
};
