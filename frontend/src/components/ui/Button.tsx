import type { ButtonHTMLAttributes } from 'react';

type Variant = 'default' | 'outline' | 'destructive' | 'ghost';

type Props = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant;
  size?: 'sm' | 'md';
};

export const Button = ({
  variant = 'default',
  size = 'md',
  className = '',
  ...props
}: Props) => {
  const base =
    'inline-flex items-center justify-center rounded-lg font-medium transition focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed';

  const sizes = {
    sm: 'px-3 py-2 text-sm',
    md: 'px-4 py-2 text-sm',
  };

  const variants: Record<Variant, string> = {
    default: 'bg-[#58b098] text-white hover:bg-[#4aa48d] focus:ring-[#58b098]',
    outline:
      'border border-gray-300 bg-white text-gray-800 hover:border-[#58b098] hover:text-[#58b098] focus:ring-[#58b098]',
    destructive: 'bg-red-600 text-white hover:bg-red-700 focus:ring-red-600',
    ghost: 'bg-transparent text-gray-700 hover:bg-gray-100 focus:ring-gray-300',
  };

  return (
    <button
      {...props}
      className={`${base} ${sizes[size]} ${variants[variant]} ${className}`}
    />
  );
};
