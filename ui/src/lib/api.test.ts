import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { api, API_BASE_URL } from "./api";

// Mock fetch globally
const mockFetch = vi.fn();
global.fetch = mockFetch;

describe("api", () => {
  beforeEach(() => {
    mockFetch.mockClear();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe("API_BASE_URL", () => {
    it("should have a default base URL", () => {
      expect(API_BASE_URL).toBeDefined();
      expect(typeof API_BASE_URL).toBe("string");
    });
  });

  describe("request helper", () => {
    it("should handle successful JSON responses", async () => {
      const mockData = { data: { users: [] } };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify(mockData),
      });

      const result = await api.getAdminSession();
      expect(result).toEqual(mockData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/session"),
        expect.objectContaining({
          credentials: "include",
          headers: expect.objectContaining({
            Accept: "application/json",
            "Content-Type": "application/json",
          }),
        }),
      );
    });

    it("should handle 204 No Content responses", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
      });

      const result = await api.signOut();
      expect(result).toBeNull();
    });

    it("should handle empty response bodies", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => "",
      });

      const result = await api.getAdminSession();
      expect(result).toBeNull();
    });

    it("should throw Unauthorized error on 401", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 401,
        headers: new Headers(),
      });

      await expect(api.getAdminSession()).rejects.toThrow("Unauthorized");
    });

    it("should throw Forbidden error on 403", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 403,
        headers: new Headers(),
      });

      await expect(api.getAdminSession()).rejects.toThrow("Forbidden");
    });

    it("should handle JSON error responses", async () => {
      const errorData = { error: "Something went wrong" };
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        headers: new Headers({ "content-type": "application/json" }),
        json: async () => errorData,
      });

      await expect(api.getAdminSession()).rejects.toThrow();
    });

    it("should handle text error responses", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        headers: new Headers({ "content-type": "text/plain" }),
        text: async () => "Internal Server Error",
      });

      await expect(api.getAdminSession()).rejects.toThrow(
        "Internal Server Error",
      );
    });

    it("should handle non-JSON successful responses", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "text/html" }),
        text: async () => "<html>Test</html>",
      });

      const result = await api.getAdminSession();
      expect(result).toEqual({ data: "<html>Test</html>" });
    });
  });

  describe("getAdminDashboard", () => {
    it("should fetch admin dashboard", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { stats: {} } }),
      });

      await api.getAdminDashboard();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/dashboard"),
        expect.any(Object),
      );
    });
  });

  describe("getAdminInvestors", () => {
    it("should fetch investors without params", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminInvestors();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/investors"),
        expect.any(Object),
      );
      expect(mockFetch).toHaveBeenCalledWith(
        expect.not.stringContaining("?"),
        expect.any(Object),
      );
    });

    it("should fetch investors with sort params", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminInvestors({ sort_by: "name", sort_order: "asc" });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("sort_by=name&sort_order=asc"),
        expect.any(Object),
      );
    });
  });

  describe("getAdminRequests", () => {
    it("should fetch requests without params", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminRequests();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/requests"),
        expect.any(Object),
      );
    });

    it("should fetch requests with filter params", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminRequests({ status: "PENDING", type: "DEPOSITO" });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("status=PENDING&type=DEPOSITO"),
        expect.any(Object),
      );
    });

    it("should fetch requests with investor_id param", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminRequests({ investor_id: "inv-123" });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("investor_id=inv-123"),
        expect.any(Object),
      );
    });
  });

  describe("createRequest", () => {
    it("should create a new request", async () => {
      const requestBody = {
        investor_id: "1",
        request_type: "DEPOSITO",
        method: "CRYPTO",
        amount: 1000,
        network: "TRC20",
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.createRequest(requestBody);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/requests"),
        expect.objectContaining({
          method: "POST",
          body: JSON.stringify(requestBody),
        }),
      );
    });
  });

  describe("updateRequest", () => {
    it("should update an existing request", async () => {
      const requestBody = {
        investor_id: "1",
        request_type: "RETIRO",
        method: "BANK",
        amount: 500,
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.updateRequest("1", requestBody);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/requests/1"),
        expect.objectContaining({
          method: "PATCH",
          body: JSON.stringify(requestBody),
        }),
      );
    });
  });

  describe("deleteRequest", () => {
    it("should delete a request", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
      });

      await api.deleteRequest("1");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/requests/1"),
        expect.objectContaining({
          method: "DELETE",
        }),
      );
    });
  });

  describe("approveRequest", () => {
    it("should approve a request", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { status: "APPROVED" } }),
      });

      await api.approveRequest("1");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/requests/1/approve"),
        expect.objectContaining({
          method: "POST",
        }),
      );
    });
  });

  describe("rejectRequest", () => {
    it("should reject a request", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { status: "REJECTED" } }),
      });

      await api.rejectRequest("1");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/requests/1/reject"),
        expect.objectContaining({
          method: "POST",
        }),
      );
    });
  });

  describe("Admin operations", () => {
    it("should fetch admins", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getAdminAdmins();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/admins"),
        expect.any(Object),
      );
    });

    it("should create an admin", async () => {
      const adminData = {
        email: "admin@test.com",
        name: "Test Admin",
        role: "ADMIN" as const,
      };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.createAdmin(adminData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/admins"),
        expect.objectContaining({
          method: "POST",
          body: JSON.stringify(adminData),
        }),
      );
    });

    it("should update an admin", async () => {
      const adminData = {
        email: "admin@test.com",
        name: "Updated Admin",
        role: "SUPERADMIN" as const,
      };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.updateAdmin("1", adminData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/admins/1"),
        expect.objectContaining({
          method: "PATCH",
          body: JSON.stringify(adminData),
        }),
      );
    });

    it("should delete an admin", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
      });

      await api.deleteAdmin("1");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/admins/1"),
        expect.objectContaining({
          method: "DELETE",
        }),
      );
    });
  });

  describe("Investor operations", () => {
    it("should create an investor", async () => {
      const investorData = {
        email: "investor@test.com",
        name: "Test Investor",
      };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.createInvestor(investorData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/investors"),
        expect.objectContaining({
          method: "POST",
          body: JSON.stringify(investorData),
        }),
      );
    });

    it("should update an investor", async () => {
      const investorData = {
        email: "investor@test.com",
        name: "Updated Investor",
      };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { id: 1 } }),
      });

      await api.updateInvestor("1", investorData);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/investors/1"),
        expect.objectContaining({
          method: "PATCH",
          body: JSON.stringify(investorData),
        }),
      );
    });

    it("should delete an investor", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
      });

      await api.deleteInvestor("1");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/investors/1"),
        expect.objectContaining({
          method: "DELETE",
        }),
      );
    });

    it("should toggle investor status", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.toggleInvestorStatus("1");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/investors/1/toggle_status"),
        expect.objectContaining({ method: "POST" }),
      );
    });

    it("should apply referral commission", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.applyReferralCommission("inv-1", { amount: 100 });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining(
          "/api/admin/v1/investors/inv-1/referral_commissions",
        ),
        expect.objectContaining({
          method: "POST",
          body: JSON.stringify({ amount: 100 }),
        }),
      );
    });
  });

  describe("getAdminDashboard", () => {
    it("should include days param when provided", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.getAdminDashboard({ days: 30 });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("days=30"),
        expect.any(Object),
      );
    });
  });

  describe("Settings", () => {
    it("should fetch admin settings", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.getAdminSettings();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/settings"),
        expect.any(Object),
      );
    });

    it("should update admin settings", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.updateAdminSettings({ investor_notifications_enabled: true });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/settings"),
        expect.objectContaining({
          method: "PATCH",
          body: JSON.stringify({ investor_notifications_enabled: true }),
        }),
      );
    });
  });

  describe("Activity logs", () => {
    it("should fetch with pagination and filters", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { logs: [] } }),
      });

      await api.getActivityLogs({
        page: 2,
        per_page: 50,
        filter_action: "create_investor",
      });
      const url = mockFetch.mock.calls[0][0];
      expect(url).toContain("page=2");
      expect(url).toContain("per_page=50");
      expect(url).toContain("filter_action=create_investor");
    });
  });

  describe("reverseRequest", () => {
    it("should reverse a request", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.reverseRequest("1");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/requests/1/reverse"),
        expect.objectContaining({ method: "POST" }),
      );
    });
  });

  describe("Daily operating", () => {
    it("getDailyOperatingMonthlySummary with params", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getDailyOperatingMonthlySummary({ months: 6, offset: 1 });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("months=6"),
        expect.any(Object),
      );
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("offset=1"),
        expect.any(Object),
      );
    });

    it("getDailyOperatingByMonth", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getDailyOperatingByMonth({ month: "2025-01" });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("month=2025-01"),
        expect.any(Object),
      );
    });

    it("previewDailyOperatingResult", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.previewDailyOperatingResult({
        date: "2025-01-15",
        percent: 1.5,
        notes: "Test",
      });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("date=2025-01-15"),
        expect.any(Object),
      );
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("percent=1.5"),
        expect.any(Object),
      );
    });

    it("createDailyOperatingResult", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.createDailyOperatingResult({
        date: "2025-01-15",
        percent: 1.5,
      });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/daily_operating_results"),
        expect.objectContaining({
          method: "POST",
          body: JSON.stringify({ date: "2025-01-15", percent: 1.5 }),
        }),
      );
    });
  });

  describe("Trading fees", () => {
    it("getTradingFees with params", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getTradingFees({
        investor_id: "inv-1",
        include_voided: true,
        page: 2,
      });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("investor_id=inv-1"),
        expect.any(Object),
      );
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("include_voided=true"),
        expect.any(Object),
      );
    });

    it("getTradingFeesSummary with period", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify([]),
      });

      await api.getTradingFeesSummary({
        period_start: "2025-01-01",
        period_end: "2025-12-31",
      });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("period_start=2025-01-01"),
        expect.any(Object),
      );
    });

    it("calculateTradingFee", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ profit_amount: 100 }),
      });

      await api.calculateTradingFee({
        investor_id: "inv-1",
        fee_percentage: 30,
        period_start: "2025-01-01",
        period_end: "2025-12-31",
      });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("investor_id=inv-1"),
        expect.any(Object),
      );
    });

    it("applyTradingFee", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.applyTradingFee({
        investor_id: "inv-1",
        fee_percentage: 30,
        notes: "Q4",
      });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/trading_fees"),
        expect.objectContaining({
          method: "POST",
          body: JSON.stringify({
            investor_id: "inv-1",
            fee_percentage: 30,
            notes: "Q4",
          }),
        }),
      );
    });

    it("updateTradingFee", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.updateTradingFee("fee-1", {
        fee_percentage: 25,
        notes: "Adjusted",
      });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/trading_fees/fee-1"),
        expect.objectContaining({
          method: "PATCH",
          body: JSON.stringify({ fee_percentage: 25, notes: "Adjusted" }),
        }),
      );
    });

    it("deleteTradingFee", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.deleteTradingFee("fee-1");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/trading_fees/fee-1"),
        expect.objectContaining({ method: "DELETE" }),
      );
    });
  });

  describe("Deposit options", () => {
    it("getDepositOptions", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: [] }),
      });

      await api.getDepositOptions();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/deposit_options"),
        expect.any(Object),
      );
    });

    it("createDepositOption", async () => {
      const body = {
        category: "CRYPTO",
        label: "USDT",
        currency: "USDT",
        details: { address: "0x" },
      };
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 201,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.createDepositOption(body);
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/deposit_options"),
        expect.objectContaining({
          method: "POST",
          body: JSON.stringify(body),
        }),
      );
    });

    it("updateDepositOption", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.updateDepositOption("opt-1", { active: false });
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/deposit_options/opt-1"),
        expect.objectContaining({
          method: "PATCH",
          body: JSON.stringify({ active: false }),
        }),
      );
    });

    it("deleteDepositOption", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
      });

      await api.deleteDepositOption("opt-1");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/deposit_options/opt-1"),
        expect.objectContaining({ method: "DELETE" }),
      );
    });

    it("toggleDepositOption", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: {} }),
      });

      await api.toggleDepositOption("opt-1");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining(
          "/api/admin/v1/deposit_options/opt-1/toggle_active",
        ),
        expect.objectContaining({ method: "POST" }),
      );
    });
  });

  describe("adminLogin", () => {
    it("should POST credentials", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers({ "content-type": "application/json" }),
        text: async () => JSON.stringify({ data: { email: "admin@test.com" } }),
      });

      await api.adminLogin("admin@test.com", "secret");
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining("/api/admin/v1/auth/login"),
        expect.objectContaining({
          method: "POST",
          body: JSON.stringify({ email: "admin@test.com", password: "secret" }),
        }),
      );
    });
  });

  describe("adminLogout", () => {
    it("should DELETE to users/sign_out", async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        status: 204,
        headers: new Headers(),
      });

      await api.adminLogout();
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringMatching(/users\/sign_out/),
        expect.objectContaining({ method: "DELETE" }),
      );
    });
  });
});
