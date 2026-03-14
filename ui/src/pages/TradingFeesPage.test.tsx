import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { TradingFeesPage, type InvestorSummary } from "./TradingFeesPage";
import { api } from "../lib/api";

vi.mock("../lib/api", () => ({
  api: {
    getTradingFeesSummary: vi.fn(),
    calculateTradingFee: vi.fn(),
    applyTradingFee: vi.fn(),
    updateTradingFee: vi.fn(),
    deleteTradingFee: vi.fn(),
  },
}));

describe("TradingFeesPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const mockRows = [
    {
      investor_id: "inv-1",
      investor_name: "Investor One",
      investor_email: "one@test.com",
      trading_fee_frequency: "QUARTERLY",
      investor_trading_fee_percentage: 35,
      current_balance: 1080,
      period_start: "2025-10-01",
      period_end: "2025-12-31",
      profit_amount: 100,
      has_profit: true,
      already_applied: true,
      applied_fee_id: "fee-1",
      applied_fee_amount: 20,
      applied_fee_percentage: 20,
      monthly_profits: [{ month: "2025-10", amount: 10 }],
    },
    {
      investor_id: "inv-2",
      investor_name: "Investor Two",
      investor_email: "two@test.com",
      trading_fee_frequency: "ANNUAL",
      investor_trading_fee_percentage: 27.5,
      current_balance: 5000,
      period_start: "2025-01-01",
      period_end: "2025-12-31",
      profit_amount: 200,
      has_profit: true,
      already_applied: false,
      applied_fee_id: null,
      applied_fee_amount: null,
      applied_fee_percentage: null,
      monthly_profits: [{ month: "2025-12", amount: 200 }],
    },
  ] as InvestorSummary[];

  it("loads and renders investors summary", async () => {
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getByText("Comisiones")).toBeInTheDocument();
    });

    expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Investor Two").length).toBeGreaterThan(0);
  });

  it("filters by investor name/email", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0);
    });

    const filter = screen.getByPlaceholderText("Buscar por nombre o email...");
    await user.type(filter, "one@test.com");

    expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0);
    expect(screen.queryByText("Investor Two")).not.toBeInTheDocument();
  });

  it("uses investor default percentage on non-applied rows", async () => {
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Investor Two").length).toBeGreaterThan(0);
    });

    const pctInputs = screen.getAllByRole("spinbutton") as HTMLInputElement[];
    const investorTwoInput = pctInputs.find((el) => el.value === "27.5");
    expect(investorTwoInput).toBeDefined();
  });

  it("opens edit modal and calls update", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);
    vi.mocked(api.updateTradingFee).mockResolvedValueOnce({});

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0);
    });

    // Pencil icon button has title="Editar"
    const editBtn = screen.getAllByTitle("Editar")[0];
    await user.click(editBtn);

    const title = screen.getByText("Editar comisión aplicada");
    expect(title).toBeInTheDocument();

    const modal = title.closest("div")!;
    const pctInput = within(modal).getByRole("spinbutton") as HTMLInputElement;
    await user.clear(pctInput);
    await user.type(pctInput, "30");

    const saveBtn = screen.getByRole("button", { name: "Guardar" });
    await user.click(saveBtn);

    await waitFor(() => {
      expect(api.updateTradingFee).toHaveBeenCalledWith(
        "fee-1",
        expect.objectContaining({ fee_percentage: 30 }),
      );
    });
  });

  it("asks confirmation and calls delete", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);
    vi.mocked(api.deleteTradingFee).mockResolvedValueOnce({});

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0);
    });

    const trashBtn = screen.getAllByTitle("Eliminar")[0];
    await user.click(trashBtn);

    expect(screen.getByText("Eliminar comisión aplicada")).toBeInTheDocument();

    const confirmButtons = screen.getAllByRole("button", { name: "Eliminar" });
    const confirm = confirmButtons.find(
      (b) => (b.textContent || "").trim() === "Eliminar",
    );
    expect(confirm).toBeDefined();
    await user.click(confirm!);

    await waitFor(() => {
      expect(api.deleteTradingFee).toHaveBeenCalledWith("fee-1");
    });
  });

  it("applies fee: calculate, confirm and apply", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);
    vi.mocked(api.calculateTradingFee).mockResolvedValue({
      investor_id: "inv-2",
      investor_name: "Investor Two",
      period_start: "2025-01-01",
      period_end: "2025-12-31",
      profit_amount: 200,
      fee_percentage: 27.5,
      fee_amount: 55,
      current_balance: 5000,
      balance_after_fee: 4945,
    } as never);
    vi.mocked(api.applyTradingFee).mockResolvedValueOnce({});

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor Two").length).toBeGreaterThan(0),
    );

    const applyButtons = screen.getAllByRole("button", { name: "Aplicar" });
    await user.click(applyButtons[0]);

    await waitFor(() =>
      expect(screen.getByText("¿Aplicar comisión?")).toBeInTheDocument(),
    );

    await user.click(
      screen.getByRole("button", { name: /Confirmar y Aplicar/i }),
    );

    await waitFor(() => {
      expect(api.applyTradingFee).toHaveBeenCalledWith(
        expect.objectContaining({
          investor_id: "inv-2",
          fee_percentage: 27.5,
        }),
      );
    });
    expect(
      screen.getByText("Comisión aplicada exitosamente"),
    ).toBeInTheDocument();
  });

  it("shows error when percentage is invalid on apply", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor Two").length).toBeGreaterThan(0),
    );

    const pctInputs = screen.getAllByRole("spinbutton") as HTMLInputElement[];
    const investorTwoInput = pctInputs.find((el) => el.value === "27.5");
    await user.clear(investorTwoInput!);
    await user.type(investorTwoInput!, "150");

    const applyButtons = screen.getAllByRole("button", { name: "Aplicar" });
    await user.click(applyButtons[0]);

    await waitFor(() =>
      expect(
        screen.getByText("El porcentaje debe estar entre 0 y 100"),
      ).toBeInTheDocument(),
    );
    expect(api.calculateTradingFee).not.toHaveBeenCalled();
  });

  it("shows error when calculate fails", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);
    vi.mocked(api.calculateTradingFee).mockRejectedValue(
      new Error("Calculate failed"),
    );

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor Two").length).toBeGreaterThan(0),
    );

    const applyButtons = screen.getAllByRole("button", { name: "Aplicar" });
    await user.click(applyButtons[0]);

    await waitFor(() =>
      expect(screen.getByText("Calculate failed")).toBeInTheDocument(),
    );
  });

  it("clears filter when Limpiar is clicked", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0),
    );

    await user.type(
      screen.getByPlaceholderText("Buscar por nombre o email..."),
      "one",
    );
    expect(screen.getByRole("button", { name: "Limpiar" })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Limpiar" }));
    expect(
      screen.getByPlaceholderText("Buscar por nombre o email..."),
    ).toHaveValue("");
  });

  it("opens detail modal when Detalle is clicked", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0),
    );

    const detalleButtons = screen.getAllByRole("button", { name: /Detalle/i });
    await user.click(detalleButtons[0]);

    await waitFor(() =>
      expect(
        screen.getByText("Detalle de rentabilidad mensual"),
      ).toBeInTheDocument(),
    );
  });

  it("shows error when load fails", async () => {
    vi.mocked(api.getTradingFeesSummary).mockRejectedValue(
      new Error("Network error"),
    );

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getByText("Network error")).toBeInTheDocument(),
    );
  });

  it("shows error when delete fails", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);
    vi.mocked(api.deleteTradingFee).mockRejectedValueOnce(
      new Error("Delete failed"),
    );

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0),
    );

    await user.click(screen.getAllByTitle("Eliminar")[0]);
    const confirmBtn = screen
      .getAllByRole("button", { name: "Eliminar" })
      .find((b) => (b.textContent || "").trim() === "Eliminar");
    await user.click(confirmBtn!);

    await waitFor(() =>
      expect(screen.getByText("Delete failed")).toBeInTheDocument(),
    );
  });

  it("shows error when apply fails", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);
    vi.mocked(api.calculateTradingFee).mockResolvedValue({
      investor_id: "inv-2",
      investor_name: "Investor Two",
      period_start: "2025-01-01",
      period_end: "2025-12-31",
      profit_amount: 200,
      fee_percentage: 27.5,
      fee_amount: 55,
      current_balance: 5000,
      balance_after_fee: 4945,
    } as never);
    vi.mocked(api.applyTradingFee).mockRejectedValueOnce(
      new Error("Apply failed"),
    );

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor Two").length).toBeGreaterThan(0),
    );
    await user.click(screen.getAllByRole("button", { name: "Aplicar" })[0]);
    await waitFor(() =>
      expect(screen.getByText("¿Aplicar comisión?")).toBeInTheDocument(),
    );

    await user.click(
      screen.getByRole("button", { name: /Confirmar y Aplicar/i }),
    );

    await waitFor(
      () => expect(screen.getByText("Apply failed")).toBeInTheDocument(),
      { timeout: 3000 },
    );
  });

  it("closes detail modal when Cerrar is clicked", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0),
    );
    await user.click(screen.getAllByRole("button", { name: /Detalle/i })[0]);
    await waitFor(() =>
      expect(
        screen.getByText("Detalle de rentabilidad mensual"),
      ).toBeInTheDocument(),
    );

    await user.click(screen.getByRole("button", { name: "Cerrar" }));
    await waitFor(() =>
      expect(
        screen.queryByText("Detalle de rentabilidad mensual"),
      ).not.toBeInTheDocument(),
    );
  });

  it("closes flash when Cerrar is clicked", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);
    vi.mocked(api.updateTradingFee).mockResolvedValueOnce({});

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0),
    );
    await user.click(screen.getAllByTitle("Editar")[0]);
    const modal = screen.getByText("Editar comisión aplicada").closest("div")!;
    await user.clear(within(modal).getByRole("spinbutton"));
    await user.type(within(modal).getByRole("spinbutton"), "25");
    await user.click(screen.getByRole("button", { name: "Guardar" }));

    await waitFor(() =>
      expect(
        screen.getByText("Comisión actualizada exitosamente"),
      ).toBeInTheDocument(),
    );
    const cerrarButtons = screen.getAllByRole("button", { name: "Cerrar" });
    await user.click(cerrarButtons[cerrarButtons.length - 1]);
    await waitFor(() =>
      expect(
        screen.queryByText("Comisión actualizada exitosamente"),
      ).not.toBeInTheDocument(),
    );
  });

  it("navigates pagination with Siguiente and Anterior", async () => {
    const user = userEvent.setup({ delay: null });
    const manyRows = Array.from({ length: 25 }, (_, i) => ({
      ...mockRows[0],
      investor_id: `inv-${i}`,
      investor_name: `Investor ${i}`,
      investor_email: `inv${i}@test.com`,
    })) as InvestorSummary[];
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(manyRows);

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor 0").length).toBeGreaterThan(0),
    );

    expect(screen.getByText(/Filas por página/)).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Siguiente" }));
    await waitFor(() =>
      expect(screen.getAllByText("Investor 20").length).toBeGreaterThan(0),
    );

    await user.click(screen.getByRole("button", { name: "Anterior" }));
    await waitFor(() =>
      expect(screen.getAllByText("Investor 0").length).toBeGreaterThan(0),
    );
  }, 10000);

  it("deletes from edit modal", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);
    vi.mocked(api.deleteTradingFee).mockResolvedValueOnce({});

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0),
    );
    await user.click(screen.getAllByTitle("Editar")[0]);
    await waitFor(() =>
      expect(screen.getByText("Editar comisión aplicada")).toBeInTheDocument(),
    );

    const deleteBtnInEditModal = within(
      screen.getByText("Editar comisión aplicada").closest("div")!,
    ).getByRole("button", { name: "Eliminar" });
    await user.click(deleteBtnInEditModal);

    await waitFor(() =>
      expect(
        screen.getByText("Eliminar comisión aplicada"),
      ).toBeInTheDocument(),
    );
    const deleteConfirmModal = screen
      .getByText("Eliminar comisión aplicada")
      .closest(".relative")!;
    const confirmDelete = within(deleteConfirmModal).getByRole("button", {
      name: "Eliminar",
    });
    await user.click(confirmDelete);

    await waitFor(() =>
      expect(api.deleteTradingFee).toHaveBeenCalledWith("fee-1"),
    );
  });

  it("blurs percentage input on wheel to prevent accidental changes", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);

    render(<TradingFeesPage />);

    await waitFor(() =>
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0),
    );
    await user.click(screen.getAllByTitle("Editar")[0]);
    await waitFor(() =>
      expect(screen.getByText("Editar comisión aplicada")).toBeInTheDocument(),
    );

    const modal = screen.getByText("Editar comisión aplicada").closest("div")!;
    const pctInput = within(modal).getByRole("spinbutton");
    pctInput.focus();
    expect(document.activeElement).toBe(pctInput);

    pctInput.dispatchEvent(new WheelEvent("wheel", { bubbles: true }));
    expect(document.activeElement).not.toBe(pctInput);
  });

  it("covers frequency labels and no-profit branches in mobile and desktop", async () => {
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue([
      {
        investor_id: "inv-s",
        investor_name: "Investor Sem",
        investor_email: "sem@test.com",
        trading_fee_frequency: "SEMESTRAL",
        current_balance: 1000,
        period_start: "2025-07-01",
        period_end: "2025-12-31",
        profit_amount: 0,
        has_profit: false,
        already_applied: false,
        monthly_profits: [],
      },
      {
        investor_id: "inv-m",
        investor_name: "Investor Month",
        investor_email: "month@test.com",
        trading_fee_frequency: "MONTHLY",
        investor_trading_fee_percentage: 25,
        current_balance: 2000,
        period_start: "2025-08-01",
        period_end: "2025-08-31",
        profit_amount: -10,
        has_profit: false,
        already_applied: false,
      },
    ] as InvestorSummary[]);

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Investor Sem").length).toBeGreaterThan(0);
    });

    expect(screen.getAllByText("Semestral").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Mensual").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Sin ganancias").length).toBeGreaterThan(0);
    expect(screen.getAllByText("No corresponde").length).toBeGreaterThan(0);
    expect(screen.queryAllByRole("button", { name: /Detalle/i }).length).toBe(
      0,
    );
  });

  it("shows errors when editing or deleting an applied fee without id", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue([
      {
        investor_id: "inv-err",
        investor_name: "Investor Error",
        investor_email: "error@test.com",
        trading_fee_frequency: "QUARTERLY",
        investor_trading_fee_percentage: 20,
        current_balance: 1000,
        period_start: "2025-10-01",
        period_end: "2025-12-31",
        profit_amount: 100,
        has_profit: true,
        already_applied: true,
        applied_fee_percentage: 20,
      },
    ] as InvestorSummary[]);

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Investor Error").length).toBeGreaterThan(0);
    });

    // Mobile action branch
    await user.click(screen.getAllByTitle("Editar")[0]);
    await waitFor(() =>
      expect(
        screen.getByText("No se encontró el ID de la comisión aplicada"),
      ).toBeInTheDocument(),
    );

    // Mobile delete action branch
    await user.click(screen.getAllByTitle("Eliminar")[0]);
    expect(
      screen.getByText("No se encontró el ID de la comisión aplicada"),
    ).toBeInTheDocument();

    // Desktop delete action branch
    const desktopDelete = screen.getAllByTitle("Eliminar")[1];
    await user.click(desktopDelete);
    expect(
      screen.getByText("No se encontró el ID de la comisión aplicada"),
    ).toBeInTheDocument();
  });

  it("validates edit percentage and handles update error", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);
    vi.mocked(api.updateTradingFee).mockRejectedValueOnce(
      new Error("Update failed"),
    );

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0);
    });

    await user.click(screen.getAllByTitle("Editar")[0]);
    await waitFor(() =>
      expect(screen.getByText("Editar comisión aplicada")).toBeInTheDocument(),
    );

    const modal = screen.getByText("Editar comisión aplicada").closest("div")!;
    const pctInput = within(modal).getByRole("spinbutton");

    await user.clear(pctInput);
    await user.type(pctInput, "0");
    await user.click(screen.getByRole("button", { name: "Guardar" }));
    expect(
      screen.getByText("El porcentaje debe estar entre 0 y 100"),
    ).toBeInTheDocument();

    await user.clear(pctInput);
    await user.type(pctInput, "30");
    await user.click(screen.getByRole("button", { name: "Guardar" }));
    await waitFor(() =>
      expect(screen.getByText("Update failed")).toBeInTheDocument(),
    );
  });

  it("blurs number inputs on wheel in mobile and desktop lists", async () => {
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows);

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Investor One").length).toBeGreaterThan(0);
    });

    const enabledInputs = (
      screen.getAllByRole("spinbutton") as HTMLInputElement[]
    ).filter((el) => !el.disabled);
    const mobileInput = enabledInputs[0];
    const desktopInput = enabledInputs[1];

    mobileInput.focus();
    expect(document.activeElement).toBe(mobileInput);
    mobileInput.dispatchEvent(new WheelEvent("wheel", { bubbles: true }));
    expect(document.activeElement).not.toBe(mobileInput);

    desktopInput.focus();
    expect(document.activeElement).toBe(desktopInput);
    desktopInput.dispatchEvent(new WheelEvent("wheel", { bubbles: true }));
    expect(document.activeElement).not.toBe(desktopInput);
  });

  it("renders negative total style in monthly detail modal", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue([
      {
        investor_id: "inv-neg",
        investor_name: "Investor Negative",
        investor_email: "neg@test.com",
        trading_fee_frequency: "QUARTERLY",
        investor_trading_fee_percentage: 30,
        current_balance: 1500,
        period_start: "2025-10-01",
        period_end: "2025-12-31",
        profit_amount: -45,
        has_profit: false,
        already_applied: false,
        monthly_profits: [{ month: "2025-10", amount: -45 }],
      },
    ] as InvestorSummary[]);

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Investor Negative").length).toBeGreaterThan(
        0,
      );
    });

    await user.click(screen.getAllByRole("button", { name: /Detalle/i })[0]);
    await waitFor(() =>
      expect(
        screen.getByText("Detalle de rentabilidad mensual"),
      ).toBeInTheDocument(),
    );
    expect(screen.getAllByText("-$45.00").length).toBeGreaterThan(0);
  });

  it("uses desktop delete action with applied fee id and shows zero total in detail modal", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue([
      {
        investor_id: "inv-zero",
        investor_name: "Investor Zero",
        investor_email: "zero@test.com",
        trading_fee_frequency: "QUARTERLY",
        investor_trading_fee_percentage: 30,
        current_balance: 1500,
        period_start: "2025-10-01",
        period_end: "2025-12-31",
        profit_amount: 0,
        has_profit: false,
        already_applied: true,
        applied_fee_id: "fee-zero",
        applied_fee_amount: 0,
        applied_fee_percentage: 30,
        monthly_profits: [{ month: "2025-10", amount: 0 }],
      },
    ] as InvestorSummary[]);
    vi.mocked(api.deleteTradingFee).mockResolvedValueOnce({});

    render(<TradingFeesPage />);

    await waitFor(() => {
      expect(screen.getAllByText("Investor Zero").length).toBeGreaterThan(0);
    });

    const desktopDelete = screen.getAllByTitle("Eliminar")[1];
    await user.click(desktopDelete);
    await waitFor(() =>
      expect(
        screen.getByText("Eliminar comisión aplicada"),
      ).toBeInTheDocument(),
    );
    await user.click(
      screen.getAllByRole("button", { name: "Eliminar" }).at(-1)!,
    );
    await waitFor(() =>
      expect(api.deleteTradingFee).toHaveBeenCalledWith("fee-zero"),
    );

    await user.click(screen.getAllByRole("button", { name: /Detalle/i })[0]);
    await waitFor(() =>
      expect(
        screen.getByText("Detalle de rentabilidad mensual"),
      ).toBeInTheDocument(),
    );
    expect(screen.getAllByText("$0.00").length).toBeGreaterThan(0);
  });
});
