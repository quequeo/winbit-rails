/**
 * Formatea números en formato argentino: $XX.XXX,XX
 * - Separador de miles: punto (.)
 * - Separador decimal: coma (,)
 * - Símbolo: $
 */
export const formatCurrencyAR = (value: number): string => {
  return value.toLocaleString('es-AR', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).replace('US$', '$').replace(/\u00A0/g, ''); // Remover US$ y espacios no-break
};

/**
 * Formatea números sin símbolo de moneda: XX.XXX,XX
 */
export const formatNumberAR = (value: number): string => {
  return value.toLocaleString('es-AR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
};

/**
 * Formatea porcentajes: XX,XX%
 */
export const formatPercentAR = (value: number): string => {
  return value.toLocaleString('es-AR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }) + '%';
};
