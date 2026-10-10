import type { InputHTMLAttributes } from "react";

type Props = InputHTMLAttributes<HTMLInputElement>;

export const Input = ({ className = "", ...props }: Props) => {
  return (
    <input
      {...props}
      className={`w-full rounded-md border border-[rgba(71,151,133,0.25)] bg-[#111513] text-white px-3 py-2 text-sm focus:border-primary focus:outline-none focus:ring-1 focus:ring-[rgba(71,151,133,0.3)] ${className}`}
    />
  );
};
