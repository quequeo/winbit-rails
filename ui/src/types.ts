/** API response types (match backend serializers) */
export interface ApiAdmin {
  id: string;
  email: string;
  name?: string;
  role: 'ADMIN' | 'SUPERADMIN';
  superadmin?: boolean;
  notify_deposit_created?: boolean;
  notify_withdrawal_created?: boolean;
}

export interface ApiInvestor {
  id: string;
  email: string;
  name?: string;
  status?: string;
  tradingFeeFrequency?: string;
  tradingFeePercentage?: number;
  hasPassword?: boolean;
  portfolio?: { currentBalance?: number; totalInvested?: number };
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
  requestedAt?: string;
  processedAt?: string;
  attachmentUrl?: string;
  investor: { name: string; email: string };
}
