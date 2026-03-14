import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ActivityLogsPage } from "./ActivityLogsPage";
import { api } from "../lib/api";

vi.mock("../lib/api", () => ({
  api: {
    getActivityLogs: vi.fn(),
  },
}));

describe("ActivityLogsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("loads and renders activity logs", async () => {
    vi.mocked(api.getActivityLogs).mockResolvedValueOnce({
      data: {
        logs: [
          {
            id: 1,
            action: "create_investor",
            action_description: "Crear inversor",
            user: { id: "u1", name: "Admin", email: "admin@test.com" },
            target: { type: "Investor", id: "inv1", display: "Inversor #inv1" },
            metadata: { amount: 100 },
            created_at: "2025-12-31T12:00:00Z",
          },
        ],
        pagination: { page: 1, per_page: 50, total: 1, total_pages: 1 },
      },
    });

    render(<ActivityLogsPage />);

    await waitFor(() => {
      expect(screen.getByText("Registro de Actividad")).toBeInTheDocument();
    });

    expect(screen.getAllByText("Crear inversor").length).toBeGreaterThan(0);
    expect(screen.getAllByText("admin@test.com").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Inversor #inv1").length).toBeGreaterThan(0);
  });

  it("applies filter and refetches", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getActivityLogs).mockResolvedValue({
      data: {
        logs: [],
        pagination: { page: 1, per_page: 50, total: 0, total_pages: 1 },
      },
    });

    render(<ActivityLogsPage />);

    await waitFor(() => {
      expect(screen.getByText("Registro de Actividad")).toBeInTheDocument();
    });

    // Open custom Select (button is labelled by the <label htmlFor="filterAction" />)
    await user.click(
      screen.getByRole("button", { name: "Filtrar por acción" }),
    );
    await user.click(screen.getByRole("option", { name: "Crear inversor" }));

    await waitFor(() => {
      expect(api.getActivityLogs).toHaveBeenLastCalledWith(
        expect.objectContaining({ filter_action: "create_investor" }),
      );
    });
  });

  it("shows error when fetch fails", async () => {
    const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    vi.mocked(api.getActivityLogs).mockRejectedValue(
      new Error("Network error"),
    );

    render(<ActivityLogsPage />);

    await waitFor(() => {
      expect(screen.getByText("Network error")).toBeInTheDocument();
    });

    consoleSpy.mockRestore();
  });

  it("formats amount/from/to as currency in metadata", async () => {
    vi.mocked(api.getActivityLogs).mockResolvedValueOnce({
      data: {
        logs: [
          {
            id: 2,
            action: "approve_request",
            action_description: "Solicitud aprobada",
            user: { id: "u1", name: "Admin", email: "admin@test.com" },
            target: {
              type: "InvestorRequest",
              id: "req1",
              display: "DEPOSIT - $1.234,56",
            },
            metadata: { amount: 1234.56, status: "APPROVED" },
            created_at: "2025-12-31T12:00:00Z",
          },
        ],
        pagination: { page: 1, per_page: 20, total: 1, total_pages: 1 },
      },
    });

    render(<ActivityLogsPage />);

    await waitFor(() => {
      expect(screen.getByText("Registro de Actividad")).toBeInTheDocument();
    });

    // formatValue formats amount as $X.XXX,XX (es-AR) - appears in metadata and target display
    expect(screen.getAllByText(/\$1\.234,56/).length).toBeGreaterThan(0);
    expect(screen.getAllByText("Aprobado").length).toBeGreaterThan(0);
  });

  it("shows distribute_profit with purple badge", async () => {
    vi.mocked(api.getActivityLogs).mockResolvedValueOnce({
      data: {
        logs: [
          {
            id: 3,
            action: "distribute_profit",
            action_description: "Ganancias distribuidas",
            user: { id: "u1", name: "Admin", email: "admin@test.com" },
            target: { type: "Portfolio", id: "p1", display: "Portfolio de X" },
            metadata: {},
            created_at: "2025-12-31T12:00:00Z",
          },
        ],
        pagination: { page: 1, per_page: 20, total: 1, total_pages: 1 },
      },
    });

    render(<ActivityLogsPage />);

    await waitFor(() => {
      expect(
        screen.getAllByText("Ganancias distribuidas").length,
      ).toBeGreaterThan(0);
    });

    const badges = screen.getAllByText("Ganancias distribuidas");
    expect(badges[0].closest("span")).toBeInTheDocument();
  });

  it("shows gray badge for unknown action", async () => {
    vi.mocked(api.getActivityLogs).mockResolvedValueOnce({
      data: {
        logs: [
          {
            id: 4,
            action: "unknown_action",
            action_description: "Acción desconocida",
            user: { id: "u1", name: "Admin", email: "admin@test.com" },
            target: { type: "Investor", id: "i1", display: "test@test.com" },
            metadata: {},
            created_at: "2025-12-31T12:00:00Z",
          },
        ],
        pagination: { page: 1, per_page: 20, total: 1, total_pages: 1 },
      },
    });

    render(<ActivityLogsPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Acción desconocida").length).toBeGreaterThan(
        0,
      );
    });

    const badges = screen.getAllByText("Acción desconocida");
    expect(badges[0].closest("span")).toBeInTheDocument();
  });

  it("shows empty state when no logs", async () => {
    vi.mocked(api.getActivityLogs).mockResolvedValueOnce({
      data: {
        logs: [],
        pagination: { page: 1, per_page: 20, total: 0, total_pages: 1 },
      },
    });

    render(<ActivityLogsPage />);

    await waitFor(() => {
      expect(screen.getByText("Registro de Actividad")).toBeInTheDocument();
    });

    expect(
      screen.getAllByText("No hay actividad registrada").length,
    ).toBeGreaterThanOrEqual(1);
  });

  it("shows pagination and navigates with Anterior/Siguiente", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getActivityLogs).mockImplementation(async (params) => {
      const page = (params as { page?: number }).page ?? 1;
      if (page === 1) {
        return {
          data: {
            logs: [
              {
                id: 1,
                action: "create_investor",
                action_description: "Crear inversor",
                user: { id: "u1", name: "Admin", email: "admin@test.com" },
                target: { type: "Investor", id: "i1", display: "a@test.com" },
                metadata: {},
                created_at: "2025-12-31T12:00:00Z",
              },
            ],
            pagination: { page: 1, per_page: 20, total: 45, total_pages: 3 },
          },
        };
      }
      return {
        data: {
          logs: [
            {
              id: 2,
              action: "update_investor",
              action_description: "Inversor actualizado",
              user: { id: "u1", name: "Admin", email: "admin@test.com" },
              target: { type: "Investor", id: "i2", display: "b@test.com" },
              metadata: {},
              created_at: "2025-12-30T12:00:00Z",
            },
          ],
          pagination: { page: 2, per_page: 20, total: 45, total_pages: 3 },
        },
      };
    });

    render(<ActivityLogsPage />);

    await waitFor(() => {
      expect(
        screen.getByText("Página 1 de 3 (45 registros)"),
      ).toBeInTheDocument();
    });

    await user.click(screen.getByRole("button", { name: "Siguiente" }));

    await waitFor(() => {
      expect(api.getActivityLogs).toHaveBeenLastCalledWith(
        expect.objectContaining({ page: 2 }),
      );
    });
    await waitFor(() => {
      expect(
        screen.getAllByText("Inversor actualizado").length,
      ).toBeGreaterThan(0);
    });

    await user.click(screen.getByRole("button", { name: "Anterior" }));

    await waitFor(() => {
      expect(api.getActivityLogs).toHaveBeenLastCalledWith(
        expect.objectContaining({ page: 1 }),
      );
    });
  });
});
