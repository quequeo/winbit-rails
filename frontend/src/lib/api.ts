const DEFAULT_BASE_URL = 'http://localhost:3000';

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || DEFAULT_BASE_URL;

async function request(path: string, options?: RequestInit) {
  const res = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    credentials: 'include',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(options?.headers || {}),
    },
  });

  if (!res.ok) {
    // Devise returns 401/403 when not authenticated/authorized.
    if (res.status === 401) throw new Error('Unauthorized');
    if (res.status === 403) throw new Error('Forbidden');

    const contentType = res.headers.get('content-type') || '';
    const body = contentType.includes('application/json') ? JSON.stringify(await res.json()) : await res.text();
    throw new Error(body || `Request failed: ${res.status}`);
  }

  if (res.status === 204) {
    return null;
  }

  const contentType = res.headers.get('content-type') || '';
  if (!contentType.includes('application/json')) {
    const text = await res.text();
    return text ? { data: text } : null;
  }

  // Avoid "Unexpected end of JSON input" on empty bodies.
  const text = await res.text();
  return text ? JSON.parse(text) : null;
}

export const api = {
  getAdminSession: () => request('/api/admin/session'),
  getAdminDashboard: () => request('/api/admin/dashboard'),
  getAdminInvestors: () => request('/api/admin/investors'),
  signOut: () => request('/users/sign_out', { method: 'DELETE' }),
  getAdminRequests: (params?: { status?: string; type?: string }) => {
    const qs = new URLSearchParams();
    if (params?.status) qs.set('status', params.status);
    if (params?.type) qs.set('type', params.type);
    const suffix = qs.toString() ? `?${qs.toString()}` : '';
    return request(`/api/admin/requests${suffix}`);
  },
  approveRequest: (id: string) => request(`/api/admin/requests/${id}/approve`, { method: 'POST' }),
  rejectRequest: (id: string) => request(`/api/admin/requests/${id}/reject`, { method: 'POST' }),
  getAdminPortfolios: () => request('/api/admin/portfolios'),
  updatePortfolio: (investorId: string, body: any) => request(`/api/admin/portfolios/${investorId}`, { method: 'PATCH', body: JSON.stringify(body) }),
  getAdminAdmins: () => request('/api/admin/admins'),
};
