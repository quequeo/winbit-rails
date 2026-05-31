/** API response types (match backend serializers) */
export interface ApiAdmin {
  id: string;
  email: string;
  name?: string;
  role: "ADMIN" | "SUPERADMIN";
  superadmin?: boolean;
  notify_deposit_created?: boolean;
  notify_withdrawal_created?: boolean;
}

export interface ApiInvestorPortfolio {
  currentBalance?: number;
  totalInvested?: number;
  accumulatedReturnUSD?: number;
  accumulatedReturnPercent?: number;
  annualReturnUSD?: number;
  annualReturnPercent?: number;
  strategyReturnYtdUSD?: number;
  strategyReturnYtdPercent?: number;
  strategyReturnYtdFrom?: string | null;
  strategyReturnAllUSD?: number;
  strategyReturnAllPercent?: number;
  strategyReturnAllFrom?: string | null;
  updatedAt?: string;
}

export interface ApiInvestor {
  id: string;
  email: string;
  name?: string;
  status?: string;
  tradingFeeFrequency?: string;
  tradingFeePercentage?: number;
  hasPassword?: boolean;
  portfolio?: ApiInvestorPortfolio;
}

export interface ApiActivityLog {
  id: number;
  action: string;
  action_description: string;
  user: { id: string; name: string; email: string };
  target: { type: string; id: string; display: string };
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface ApiPagination {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

export interface ApiResponse<T> {
  data: T;
}

export interface ApiRequest {
  id: string;
  investorId: string;
  type: string;
  method: string;
  amount: number;
  status: string;
  network?: string;
  walletAddress?: string;
  lemontag?: string;
  requestedAt?: string;
  processedAt?: string;
  attachmentUrl?: string;
  investor: { name: string; email: string };
}

export interface MonthlyReportAnnexRow {
  month: string;
  label: string;
  returnPercent: number | null;
  returnUsd: number | null;
  deposits: number;
  withdrawals: number;
  serviceCost: number;
  portfolioValue: number | null;
  openingSnapshot: boolean;
  entryRow?: boolean;
  source: string;
}

export interface MonthlyReportSummary {
  portfolioValueUsd: number | null;
  winbitMonthlyReturnPercent: number | null;
  accumulatedSinceEntryUsd: number | null;
  accumulatedSinceEntryPercent: number | null;
  accumulated2026Usd: number | null;
  accumulated2026Percent: number | null;
}

export interface MonthlyReport {
  investor: { id: string; name: string; email: string };
  reportMonth: string;
  summary: MonthlyReportSummary;
  annexRows: MonthlyReportAnnexRow[];
}
