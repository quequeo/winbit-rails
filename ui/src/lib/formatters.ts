/**
 * Formatea números en formato argentino: $XX.XXX,XX
 * - Separador de miles: punto (.)
 * - Separador decimal: coma (,)
 * - Símbolo: $
 * Version: 3.0 - Manual formatting (no locale dependency)
 */
export const formatCurrencyAR = (value: number): string => {
  // Convertir a número si es string
  const num = typeof value === 'string' ? parseFloat(value) : value;
  
  // Formatear manualmente sin depender de locales
  const fixed = num.toFixed(2); // "15314.00"
  const parts = fixed.split('.'); // ["15314", "00"]
  
  // Agregar puntos cada 3 dígitos desde la derecha
  const integerPart = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  
  // Unir con coma como separador decimal
  return `$${integerPart},${parts[1]}`;
};

/**
 * Formatea números sin símbolo de moneda: XX.XXX,XX
 */
export const formatNumberAR = (value: number): string => {
  const num = typeof value === 'string' ? parseFloat(value) : value;
  const fixed = num.toFixed(2);
  const parts = fixed.split('.');
  const integerPart = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return `${integerPart},${parts[1]}`;
};

/**
 * Formatea porcentajes: XX,XX%
 */
export const formatPercentAR = (value: number): string => {
  const num = typeof value === 'string' ? parseFloat(value) : value;
  const fixed = num.toFixed(2);
  const parts = fixed.split('.');
  const integerPart = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  return `${integerPart},${parts[1]}%`;
};
