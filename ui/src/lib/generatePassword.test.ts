import { describe, expect, it } from "vitest";
import { generatePassword } from "./generatePassword";

describe("generatePassword", () => {
  it("genera 10 caracteres por defecto", () => {
    expect(generatePassword()).toHaveLength(10);
  });

  it("respeta el largo pedido y el mínimo de 6", () => {
    expect(generatePassword(14)).toHaveLength(14);
    expect(() => generatePassword(5)).toThrow();
  });

  it("no usa caracteres ambiguos y siempre tiene letra y número", () => {
    for (let i = 0; i < 200; i += 1) {
      const p = generatePassword();
      expect(p).not.toMatch(/[0O1lI]/);
      expect(p).toMatch(/[a-zA-Z]/);
      expect(p).toMatch(/[2-9]/);
    }
  });

  it("no repite contraseñas", () => {
    const set = new Set(Array.from({ length: 100 }, () => generatePassword()));
    expect(set.size).toBe(100);
  });
});
