import type { InputHTMLAttributes } from 'react';

type Props = InputHTMLAttributes<HTMLInputElement>;

export const Input = ({ className = '', ...props }: Props) => {
  return (
    <input
      {...props}
      className={`w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-[#58b098] focus:outline-none focus:ring-1 focus:ring-[#58b098] ${className}`}
    />
  );
};
