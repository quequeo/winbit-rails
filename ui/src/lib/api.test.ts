import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { api, API_BASE_URL } from './api';

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('api', () => {
  beforeEach(() => {
    mockFetch.mockClear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('API_BASE_URL', () => {
    it('should have a default base URL', () => {
      expect(API_BASE_URL).toBeDefined();
      expect(typeof API_BASE_URL).toBe('string');
    });
  });

  describe('request helper', () => {
    it('should handle successful JSON responses', async () => {
      const mockData = { data: { users: [] } };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify(mockData),
      });

      const result = await api.getAdminSession();
      expect(result).toEqual(mockData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/session'),
        expect.objectContaining({
          credentials: 'include',
          headers: expect.objectContaining({
            Accept: 'application/json',
            'Content-Type': 'application/json',
          }),
        }),
      );
    });

    it('should handle 204 No Content responses', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
      });

      const result = await api.signOut();
      expect(result).toBeNull();
    });

    it('should handle empty response bodies', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => '',
      });

      const result = await api.getAdminSession();
      expect(result).toBeNull();
    });

    it('should throw Unauthorized error on 401', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        headers: new Headers(),
      });

      await expect(api.getAdminSession()).rejects.toThrow('Unauthorized');
    });

    it('should throw Forbidden error on 403', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 403,
        headers: new Headers(),
      });

      await expect(api.getAdminSession()).rejects.toThrow('Forbidden');
    });

    it('should handle JSON error responses', async () => {
      const errorData = { error: 'Something went wrong' };
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        headers: new Headers({ 'content-type': 'application/json' }),
        json: async () => errorData,
      });

      await expect(api.getAdminSession()).rejects.toThrow();
    });

    it('should handle text error responses', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        headers: new Headers({ 'content-type': 'text/plain' }),
        text: async () => 'Internal Server Error',
      });

      await expect(api.getAdminSession()).rejects.toThrow('Internal Server Error');
    });

    it('should handle non-JSON successful responses', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'text/html' }),
        text: async () => '<html>Test</html>',
      });

      const result = await api.getAdminSession();
      expect(result).toEqual({ data: '<html>Test</html>' });
    });
  });

  describe('getAdminDashboard', () => {
    it('should fetch admin dashboard', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: { stats: {} } }),
      });

      await api.getAdminDashboard();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/dashboard'),
        expect.any(Object),
      );
    });
  });

  describe('getAdminInvestors', () => {
    it('should fetch investors without params', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminInvestors();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/investors'),
        expect.any(Object),
      );
      expect(mockFetch).toHaveBeenCalledWith(
        expect.not.stringContaining('?'),
        expect.any(Object),
      );
    });

    it('should fetch investors with sort params', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminInvestors({ sort_by: 'name', sort_order: 'asc' });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('sort_by=name&sort_order=asc'),
        expect.any(Object),
      );
    });
  });

  describe('getAdminRequests', () => {
    it('should fetch requests without params', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminRequests();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/requests'),
        expect.any(Object),
      );
    });

    it('should fetch requests with filter params', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminRequests({ status: 'PENDING', type: 'DEPOSITO' });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('status=PENDING&type=DEPOSITO'),
        expect.any(Object),
      );
    });
  });

  describe('createRequest', () => {
    it('should create a new request', async () => {
      const requestBody = {
        investor_id: '1',
        request_type: 'DEPOSITO',
        method: 'CRYPTO',
        amount: 1000,
        network: 'TRC20',
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.createRequest(requestBody);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/requests'),
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(requestBody),
        }),
      );
    });
  });

  describe('updateRequest', () => {
    it('should update an existing request', async () => {
      const requestBody = {
        investor_id: '1',
        request_type: 'RETIRO',
        method: 'BANK',
        amount: 500,
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.updateRequest('1', requestBody);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/requests/1'),
        expect.objectContaining({
          method: 'PATCH',
          body: JSON.stringify(requestBody),
        }),
      );
    });
  });

  describe('deleteRequest', () => {
    it('should delete a request', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
      });

      await api.deleteRequest('1');
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/requests/1'),
        expect.objectContaining({
          method: 'DELETE',
        }),
      );
    });
  });

  describe('approveRequest', () => {
    it('should approve a request', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: { status: 'APPROVED' } }),
      });

      await api.approveRequest('1');
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/requests/1/approve'),
        expect.objectContaining({
          method: 'POST',
        }),
      );
    });
  });

  describe('rejectRequest', () => {
    it('should reject a request', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: { status: 'REJECTED' } }),
      });

      await api.rejectRequest('1');
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/requests/1/reject'),
        expect.objectContaining({
          method: 'POST',
        }),
      );
    });
  });

  describe('Portfolio operations', () => {
    it('should fetch portfolios', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminPortfolios();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/portfolios'),
        expect.any(Object),
      );
    });

    it('should update a portfolio', async () => {
      const portfolioData = { current_balance: 10000 };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: portfolioData }),
      });

      await api.updatePortfolio('1', portfolioData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/portfolios/1'),
        expect.objectContaining({
          method: 'PATCH',
          body: JSON.stringify(portfolioData),
        }),
      );
    });
  });

  describe('Admin operations', () => {
    it('should fetch admins', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminAdmins();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/admins'),
        expect.any(Object),
      );
    });

    it('should create an admin', async () => {
      const adminData = { email: 'admin@test.com', name: 'Test Admin', role: 'ADMIN' as const };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.createAdmin(adminData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/admins'),
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(adminData),
        }),
      );
    });

    it('should update an admin', async () => {
      const adminData = { email: 'admin@test.com', name: 'Updated Admin', role: 'SUPERADMIN' as const };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.updateAdmin('1', adminData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/admins/1'),
        expect.objectContaining({
          method: 'PATCH',
          body: JSON.stringify(adminData),
        }),
      );
    });

    it('should delete an admin', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
      });

      await api.deleteAdmin('1');
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/admins/1'),
        expect.objectContaining({
          method: 'DELETE',
        }),
      );
    });
  });

  describe('Investor operations', () => {
    it('should create an investor', async () => {
      const investorData = { email: 'investor@test.com', name: 'Test Investor' };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.createInvestor(investorData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/investors'),
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(investorData),
        }),
      );
    });

    it('should update an investor', async () => {
      const investorData = { email: 'investor@test.com', name: 'Updated Investor' };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ 'content-type': 'application/json' }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.updateInvestor('1', investorData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/investors/1'),
        expect.objectContaining({
          method: 'PATCH',
          body: JSON.stringify(investorData),
        }),
      );
    });

    it('should delete an investor', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
      });

      await api.deleteInvestor('1');
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/admin/investors/1'),
        expect.objectContaining({
          method: 'DELETE',
        }),
      );
    });
  });
});
