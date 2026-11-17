// Contraseña inicial aleatoria para inversores que no entran con Google.
// Sin caracteres que se confunden al copiarlos o dictarlos (0/O, 1/l/I).
const LETTERS = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";
const DIGITS = "23456789";
const ALPHABET = LETTERS + DIGITS;

const randomIndex = (max: number): number => {
  // Rechazo para evitar sesgo de módulo.
  const limit = Math.floor(0x100000000 / max) * max;
  const buf = new Uint32Array(1);
  for (;;) {
    crypto.getRandomValues(buf);
    if (buf[0] < limit) return buf[0] % max;
  }
};

export const generatePassword = (length = 10): string => {
  if (length < 6) throw new Error("La contraseña debe tener al menos 6 caracteres");
  for (;;) {
    let out = "";
    for (let i = 0; i < length; i += 1) out += ALPHABET[randomIndex(ALPHABET.length)];
    // Garantiza al menos una letra y un número.
    if (/[a-zA-Z]/.test(out) && /[2-9]/.test(out)) return out;
  }
};
