// Contratos que opera Winbit, con el mismo nombre y logo que ve el inversor
// en la app (winbit-app/src/utils/operatingTrade.js). Así el admin y la app
// muestran cada operación igual: logo, "MBT — Micro Bitcoin" y LONG/SHORT.

export type OperatingContract = "MBT" | "MES" | "MNQ" | "MYM";

const CONTRACT_ALIASES: Record<string, OperatingContract> = {
  MBT: "MBT",
  BTC: "MBT",
  BITCOIN: "MBT",
  XBT: "MBT",
  MES: "MES",
  ES: "MES",
  SP500: "MES",
  SPX: "MES",
  "S&P500": "MES",
  MNQ: "MNQ",
  NQ: "MNQ",
  NASDAQ: "MNQ",
  NDX: "MNQ",
  MYM: "MYM",
  YM: "MYM",
  DOW: "MYM",
  DOWJONES: "MYM",
  DJI: "MYM",
  DJIA: "MYM",
};

const CONTRACT_INFO: Record<OperatingContract, { name: string; logo: string }> = {
  MBT: { name: "Micro Bitcoin", logo: "/images/operating-assets/btc.png" },
  MES: { name: "S&P 500", logo: "/images/operating-assets/sp500.png" },
  MNQ: { name: "Nasdaq", logo: "/images/operating-assets/nasdaq.png" },
  MYM: { name: "Dow Jones", logo: "/images/operating-assets/dow-jones.png" },
};

export const operatingContract = (
  asset: string | null | undefined,
): OperatingContract | null => {
  const key = String(asset ?? "")
    .trim()
    .toUpperCase()
    .replace(/[\s_]+/g, "");
  return key ? (CONTRACT_ALIASES[key] ?? null) : null;
};

export const operatingContractInfo = (asset: string | null | undefined) => {
  const contract = operatingContract(asset);
  return contract ? { contract, ...CONTRACT_INFO[contract] } : null;
};

export const operatingDirection = (
  value: string | null | undefined,
): "LONG" | "SHORT" | null => {
  const raw = String(value ?? "")
    .trim()
    .toUpperCase();
  if (raw === "LONG" || raw === "LARGO") return "LONG";
  if (raw === "SHORT" || raw === "CORTO") return "SHORT";
  return null;
};
