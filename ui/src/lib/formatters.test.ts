import { describe, it, expect } from 'vitest';
import { formatCurrencyAR, formatNumberAR, formatPercentAR } from './formatters';

describe('formatters', () => {
  describe('formatCurrencyAR', () => {
    it('should format positive numbers with currency symbol', () => {
      const result = formatCurrencyAR(1234.56);
      expect(result).toContain('1');
      expect(result).toContain('234');
      expect(result).toContain('56');
      expect(result).toContain('$');
    });

    it('should format negative numbers', () => {
      const result = formatCurrencyAR(-500.25);
      expect(result).toContain('500');
      expect(result).toContain('25');
      expect(result).toContain('-');
    });

    it('should format zero', () => {
      const result = formatCurrencyAR(0);
      expect(result).toContain('0');
      expect(result).toContain('00');
    });

    it('should format large numbers with thousands separator', () => {
      const result = formatCurrencyAR(1234567.89);
      expect(result).toContain('1');
      expect(result).toContain('234');
      expect(result).toContain('567');
      expect(result).toContain('89');
    });

    it('should always show two decimal places', () => {
      const result = formatCurrencyAR(100);
      expect(result).toContain('00');
    });

    it('should format small decimal values', () => {
      const result = formatCurrencyAR(0.99);
      expect(result).toContain('0');
      expect(result).toContain('99');
    });
  });

  describe('formatNumberAR', () => {
    it('should format positive numbers without currency symbol', () => {
      const result = formatNumberAR(1234.56);
      expect(result).not.toContain('$');
      expect(result).toContain('1');
      expect(result).toContain('234');
      expect(result).toContain('56');
    });

    it('should format negative numbers', () => {
      const result = formatNumberAR(-500.25);
      expect(result).not.toContain('$');
      expect(result).toContain('500');
      expect(result).toContain('25');
      expect(result).toContain('-');
    });

    it('should format zero', () => {
      const result = formatNumberAR(0);
      expect(result).toContain('0');
      expect(result).toContain('00');
    });

    it('should format large numbers', () => {
      const result = formatNumberAR(9876543.21);
      expect(result).toContain('9');
      expect(result).toContain('876');
      expect(result).toContain('543');
      expect(result).toContain('21');
    });

    it('should always show two decimal places', () => {
      const result = formatNumberAR(50);
      expect(result).toContain('50');
      expect(result).toContain('00');
    });
  });

  describe('formatPercentAR', () => {
    it('should format percentages with % symbol', () => {
      const result = formatPercentAR(15.75);
      expect(result).toContain('15');
      expect(result).toContain('75');
      expect(result).toContain('%');
    });

    it('should format negative percentages', () => {
      const result = formatPercentAR(-5.25);
      expect(result).toContain('-');
      expect(result).toContain('5');
      expect(result).toContain('25');
      expect(result).toContain('%');
    });

    it('should format zero percentage', () => {
      const result = formatPercentAR(0);
      expect(result).toContain('0');
      expect(result).toContain('00');
      expect(result).toContain('%');
    });

    it('should format large percentages', () => {
      const result = formatPercentAR(125.99);
      expect(result).toContain('125');
      expect(result).toContain('99');
      expect(result).toContain('%');
    });

    it('should always show two decimal places', () => {
      const result = formatPercentAR(10);
      expect(result).toContain('10');
      expect(result).toContain('00');
      expect(result).toContain('%');
    });

    it('should format small decimal percentages', () => {
      const result = formatPercentAR(0.05);
      expect(result).toContain('0');
      expect(result).toContain('05');
      expect(result).toContain('%');
    });
  });

  describe('Argentine locale format consistency', () => {
    it('should use comma as decimal separator', () => {
      const currency = formatCurrencyAR(100.50);
      const number = formatNumberAR(100.50);
      const percent = formatPercentAR(100.50);
      
      // All should use comma for decimals (es-AR format)
      expect(currency).toMatch(/[,]/);
      expect(number).toMatch(/[,]/);
      expect(percent).toMatch(/[,]/);
    });

    it('should use dot as thousands separator for large numbers', () => {
      const currency = formatCurrencyAR(10000.00);
      const number = formatNumberAR(10000.00);
      
      // Should contain dot as thousands separator
      expect(currency).toMatch(/10[.,]000/);
      expect(number).toMatch(/10[.,]000/);
    });
  });
});
