import type { InputHTMLAttributes } from "react";

type Props = InputHTMLAttributes<HTMLInputElement>;

export const Input = ({ className = "", ...props }: Props) => {
  return (
    <input
      {...props}
      className={`w-full rounded-md border border-b-default bg-dark-card text-t-primary px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary ${className}`}
    />
  );
};
