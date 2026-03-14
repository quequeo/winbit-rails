import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { OperatingHistoryPage } from "./OperatingHistoryPage";
import { api } from "../lib/api";

vi.mock("../lib/api", () => ({
  api: {
    getDailyOperatingResults: vi.fn(),
    getDailyOperatingMonthlySummary: vi.fn(),
    getDailyOperatingByMonth: vi.fn(),
  },
}));

describe("OperatingHistoryPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("loads monthly summary and daily history", async () => {
    vi.mocked(api.getDailyOperatingResults).mockResolvedValueOnce({
      data: [
        {
          id: "1",
          date: "2025-12-31",
          percent: 0.1,
          notes: "Cierre de año",
          created_at: "2025-12-31T20:00:00Z",
        },
      ],
      meta: { page: 1, per_page: 10, total: 1, total_pages: 1 },
    });
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValueOnce({
      data: [
        {
          month: "2025-12",
          days: 2,
          compounded_percent: 1.23,
          first_date: "2025-12-01",
          last_date: "2025-12-31",
        },
      ],
    });

    render(<OperatingHistoryPage />);

    await waitFor(() => {
      expect(screen.getByText("Historial de Operativas")).toBeInTheDocument();
    });

    expect(screen.getByText("Resumen por mes")).toBeInTheDocument();
    expect(screen.getAllByText(/Dic 2025/i).length).toBeGreaterThan(0);
    expect(screen.getByText("Detalle diario")).toBeInTheDocument();
    expect(screen.getByText("2025-12-31")).toBeInTheDocument();
    expect(screen.getByText("Cierre de año")).toBeInTheDocument();
  });

  it("opens month detail modal", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getDailyOperatingResults).mockResolvedValueOnce({
      data: [],
      meta: { page: 1, per_page: 10, total: 0, total_pages: 1 },
    });
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValueOnce({
      data: [
        {
          month: "2025-12",
          days: 1,
          compounded_percent: 0.5,
          first_date: "2025-12-01",
          last_date: "2025-12-31",
        },
      ],
    });
    vi.mocked(api.getDailyOperatingByMonth).mockResolvedValueOnce({
      data: [
        {
          id: "d1",
          date: "2025-12-10",
          percent: 0.2,
          notes: "Ajuste intradía",
        },
      ],
    });

    render(<OperatingHistoryPage />);

    await waitFor(() => {
      expect(screen.getAllByText(/Dic 2025/i).length).toBeGreaterThan(0);
    });

    const viewBtn = screen.getByLabelText("Ver detalle");
    await user.click(viewBtn);

    await waitFor(() => {
      expect(screen.getByText("Detalle del mes")).toBeInTheDocument();
    });
    expect(screen.getByText("2025-12-10")).toBeInTheDocument();
    expect(screen.getByText("Ajuste intradía")).toBeInTheDocument();
  });

  it("navigates monthly summary older/newer and refreshes", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getDailyOperatingResults).mockResolvedValue({
      data: [],
      meta: { page: 1, per_page: 10, total: 0, total_pages: 1 },
    } as never);
    vi.mocked(api.getDailyOperatingMonthlySummary)
      .mockResolvedValueOnce({
        data: [
          {
            month: "2025-12",
            days: 2,
            compounded_percent: 1,
            first_date: "2025-12-01",
            last_date: "2025-12-31",
          },
        ],
      })
      .mockResolvedValueOnce({
        data: [
          {
            month: "2024-12",
            days: 1,
            compounded_percent: 0.5,
            first_date: "2024-12-01",
            last_date: "2024-12-31",
          },
        ],
      })
      .mockResolvedValueOnce({
        data: [
          {
            month: "2025-12",
            days: 2,
            compounded_percent: 1,
            first_date: "2025-12-01",
            last_date: "2025-12-31",
          },
        ],
      })
      .mockResolvedValueOnce({
        data: [
          {
            month: "2025-12",
            days: 2,
            compounded_percent: 1,
            first_date: "2025-12-01",
            last_date: "2025-12-31",
          },
        ],
      });

    render(<OperatingHistoryPage />);

    await waitFor(() =>
      expect(screen.getAllByText(/Dic 2025/i).length).toBeGreaterThan(0),
    );

    await user.click(screen.getByTitle("Meses anteriores"));
    await waitFor(() =>
      expect(api.getDailyOperatingMonthlySummary).toHaveBeenCalledWith({
        months: 12,
        offset: 12,
      }),
    );

    await user.click(screen.getByTitle("Meses siguientes"));
    await waitFor(() =>
      expect(api.getDailyOperatingMonthlySummary).toHaveBeenCalledWith({
        months: 12,
        offset: 0,
      }),
    );

    await user.click(screen.getByRole("button", { name: "Actualizar" }));
    await waitFor(() => {
      expect(api.getDailyOperatingResults).toHaveBeenCalledWith({
        page: 1,
        per_page: 10,
      });
    });
  });

  it("shows error banner when history load fails", async () => {
    vi.mocked(api.getDailyOperatingResults).mockRejectedValueOnce(
      new Error("History failed"),
    );
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValueOnce({
      data: [],
    });

    render(<OperatingHistoryPage />);

    await waitFor(() => {
      expect(screen.getByText("History failed")).toBeInTheDocument();
    });
  });

  it("shows error when month detail fails and empty state when no detail rows", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getDailyOperatingResults).mockResolvedValueOnce({
      data: [],
      meta: { page: 1, per_page: 10, total: 0, total_pages: 1 },
    });
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValueOnce({
      data: [
        {
          month: "2025-12",
          days: 1,
          compounded_percent: 0.5,
          first_date: "2025-12-01",
          last_date: "2025-12-31",
        },
      ],
    });
    vi.mocked(api.getDailyOperatingByMonth).mockResolvedValueOnce({ data: [] });
    vi.mocked(api.getDailyOperatingByMonth).mockRejectedValueOnce(
      new Error("Detail failed"),
    );

    render(<OperatingHistoryPage />);

    await waitFor(() =>
      expect(screen.getByLabelText("Ver detalle")).toBeInTheDocument(),
    );
    await user.click(screen.getByLabelText("Ver detalle"));

    await waitFor(() => {
      expect(
        screen.getByText("No hay operativas cargadas para este mes."),
      ).toBeInTheDocument();
    });

    await user.click(screen.getByRole("button", { name: "Cerrar" }));
    await waitFor(() =>
      expect(screen.queryByText("Detalle del mes")).not.toBeInTheDocument(),
    );

    await user.click(screen.getByLabelText("Ver detalle"));
    await waitFor(() => {
      expect(screen.getByText("Detail failed")).toBeInTheDocument();
    });
  });
});
