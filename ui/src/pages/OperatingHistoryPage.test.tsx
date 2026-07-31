import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { OperatingHistoryPage } from "./OperatingHistoryPage";
import { api } from "../lib/api";

vi.mock("../lib/api", () => ({
  api: {
    getDailyOperatingResults: vi.fn(),
    getDailyOperatingMonthlySummary: vi.fn(),
    getDailyOperatingSeries: vi.fn(),
    getStrategyOperations: vi.fn(),
  },
}));

vi.mock("../lib/exportOperatingToExcel", () => ({
  exportOperatingToExcel: vi.fn(),
}));

vi.mock("../components/ui/DatePicker", () => ({
  DatePicker: ({
    value,
    onChange,
    id,
  }: {
    value: string;
    onChange: (iso: string) => void;
    id?: string;
  }) => (
    <input
      id={id}
      value={value}
      onChange={(e) => onChange(e.target.value)}
    />
  ),
}));

describe("OperatingHistoryPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.localStorage.clear();
    vi.mocked(api.getStrategyOperations).mockResolvedValue({ data: [] });
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
    vi.mocked(api.getDailyOperatingSeries).mockResolvedValue({ data: [] });
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValueOnce({
      data: [
        {
          month: "2025-12",
          days: 2,
          compounded_percent: 1.23,
          total_usd: 7239,
          first_date: "2025-12-01",
          last_date: "2025-12-31",
        },
      ],
    });

    render(<OperatingHistoryPage />);

    await waitFor(() => {
      expect(screen.getByText("Historial de Operativas")).toBeInTheDocument();
    });

    expect(screen.getByText("Rendimiento por mes")).toBeInTheDocument();
    expect(screen.getAllByText(/Dic 2025/i).length).toBeGreaterThan(0);
    expect(screen.getByText("Detalle diario")).toBeInTheDocument();
    expect(screen.getByText("2025-12-31")).toBeInTheDocument();
    expect(screen.getByText("Cierre de año")).toBeInTheDocument();
    expect(screen.queryByLabelText("Ver detalle")).not.toBeInTheDocument();
  });

  it("toggles USD visibility on monthly cards and persists preference", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getDailyOperatingResults).mockResolvedValue({
      data: [],
      meta: { page: 1, per_page: 10, total: 0, total_pages: 1 },
    } as never);
    vi.mocked(api.getDailyOperatingSeries).mockResolvedValue({ data: [] });
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValue({
      data: [
        {
          month: "2025-12",
          days: 1,
          compounded_percent: 1.23,
          total_usd: 7239,
          first_date: "2025-12-01",
          last_date: "2025-12-31",
        },
        {
          month: "2025-11",
          days: 1,
          compounded_percent: 0.5,
          total_usd: 1200,
          first_date: "2025-11-01",
          last_date: "2025-11-30",
        },
      ],
    } as never);

    const { unmount } = render(<OperatingHistoryPage />);

    await waitFor(() => {
      expect(screen.getByText("$7,239.00")).toBeInTheDocument();
    });
    expect(screen.getByText("$1,200.00")).toBeInTheDocument();
    expect(
      screen.getByText((_, el) => el?.textContent === "+1.23%"),
    ).toBeInTheDocument();

    const hideButtons = screen.getAllByLabelText("Ocultar importes USD");
    expect(hideButtons.length).toBe(2);
    await user.click(hideButtons[0]);

    await waitFor(() => {
      expect(screen.queryByText("$7,239.00")).not.toBeInTheDocument();
    });
    expect(screen.queryByText("$1,200.00")).not.toBeInTheDocument();
    expect(screen.getAllByText("••••").length).toBe(2);
    expect(
      screen.getByText((_, el) => el?.textContent === "+1.23%"),
    ).toBeInTheDocument();
    expect(window.localStorage.getItem("operatingHistory.hideUsdAmounts")).toBe(
      "1",
    );

    unmount();
    render(<OperatingHistoryPage />);

    await waitFor(() => {
      expect(screen.getAllByText("••••").length).toBe(2);
    });
    expect(screen.queryByText("$7,239.00")).not.toBeInTheDocument();

    await user.click(screen.getAllByLabelText("Mostrar importes USD")[0]);
    await waitFor(() => {
      expect(screen.getByText("$7,239.00")).toBeInTheDocument();
    });
    expect(window.localStorage.getItem("operatingHistory.hideUsdAmounts")).toBe(
      "0",
    );
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

    vi.mocked(api.getDailyOperatingSeries).mockResolvedValue({ data: [] });

    render(<OperatingHistoryPage />);

    await waitFor(() =>
      expect(screen.getAllByText(/Dic 2025/i).length).toBeGreaterThan(0),
    );

    await user.click(screen.getByTitle("Meses anteriores"));
    await waitFor(() =>
      expect(api.getDailyOperatingMonthlySummary).toHaveBeenCalledWith({
        months: 3,
        offset: 3,
      }),
    );

    await user.click(screen.getByTitle("Meses siguientes"));
    await waitFor(() =>
      expect(api.getDailyOperatingMonthlySummary).toHaveBeenCalledWith({
        months: 3,
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
    vi.mocked(api.getDailyOperatingSeries).mockResolvedValue({ data: [] });
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValueOnce({
      data: [],
    });

    render(<OperatingHistoryPage />);

    await waitFor(() => {
      expect(screen.getByText("History failed")).toBeInTheDocument();
    });
  });

  it("exports excel for selected date range", async () => {
    const user = userEvent.setup();
    const { exportOperatingToExcel } = await import(
      "../lib/exportOperatingToExcel"
    );
    const { fireEvent } = await import("@testing-library/react");

    vi.mocked(api.getDailyOperatingResults).mockResolvedValue({
      data: [],
      meta: { page: 1, per_page: 10, total: 0, total_pages: 1 },
    } as never);
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValue({
      data: [],
    } as never);
    vi.mocked(api.getDailyOperatingSeries)
      .mockResolvedValueOnce({ data: [] })
      .mockResolvedValueOnce({
        data: [
          {
            date: "2026-03-01",
            percent: 0.5,
            amount_usd: 100,
            notes: "ok",
          },
        ],
      });

    render(<OperatingHistoryPage />);

    await waitFor(() =>
      expect(document.getElementById("export-from")).toBeInTheDocument(),
    );

    fireEvent.change(document.getElementById("export-from") as HTMLInputElement, {
      target: { value: "2026-03-01" },
    });
    fireEvent.change(document.getElementById("export-to") as HTMLInputElement, {
      target: { value: "2026-03-31" },
    });
    await user.click(screen.getByRole("button", { name: "Descargar Excel" }));

    await waitFor(() => {
      expect(api.getDailyOperatingSeries).toHaveBeenCalledWith({
        from: "2026-03-01",
        to: "2026-03-31",
      });
      expect(exportOperatingToExcel).toHaveBeenCalledWith(
        [
          {
            date: "2026-03-01",
            percent: 0.5,
            amount_usd: 100,
            notes: "ok",
          },
        ],
        "2026-03-01_2026-03-31",
      );
    });
  });

  it("filters chart range and shows strategy result counts", async () => {
    const user = userEvent.setup();
    const { fireEvent } = await import("@testing-library/react");

    vi.mocked(api.getDailyOperatingResults).mockResolvedValue({
      data: [],
      meta: { page: 1, per_page: 10, total: 0, total_pages: 1 },
    } as never);
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValue({
      data: [],
    } as never);
    vi.mocked(api.getDailyOperatingSeries)
      .mockResolvedValueOnce({ data: [] })
      .mockResolvedValueOnce({
        data: [{ date: "2026-07-01", percent: 0.2, amount_usd: 50 }],
      });
    vi.mocked(api.getStrategyOperations)
      .mockResolvedValueOnce({ data: [] })
      .mockResolvedValueOnce({
        data: [
          { resultLabel: "POSITIVO" },
          { resultLabel: "NEGATIVO" },
          { resultLabel: "BE+" },
          { resultLabel: "BE-" },
          { resultLabel: "BE-" },
        ],
      });

    render(<OperatingHistoryPage />);

    await waitFor(() =>
      expect(screen.getByText("Evolución diaria")).toBeInTheDocument(),
    );

    fireEvent.change(document.getElementById("chart-from") as HTMLInputElement, {
      target: { value: "2026-07-01" },
    });
    fireEvent.change(document.getElementById("chart-to") as HTMLInputElement, {
      target: { value: "2026-07-31" },
    });
    await user.click(screen.getByRole("button", { name: "Aplicar" }));

    await waitFor(() => {
      expect(api.getDailyOperatingSeries).toHaveBeenCalledWith({
        from: "2026-07-01",
        to: "2026-07-31",
      });
      expect(api.getStrategyOperations).toHaveBeenCalledWith({
        from: "2026-07-01",
        to: "2026-07-31",
        per_page: 200,
      });
      expect(screen.getByText("Positivos").parentElement).toHaveTextContent("1");
      expect(screen.getByText("Negativos").parentElement).toHaveTextContent("1");
      expect(screen.getByText("BE+").parentElement).toHaveTextContent("1");
      expect(screen.getByText("BE-").parentElement).toHaveTextContent("2");
    });
  });
});
