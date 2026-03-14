import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ReferralCommissionsPage } from "./ReferralCommissionsPage";
import { api } from "../lib/api";

vi.mock("../lib/api", () => ({
  api: {
    getAdminInvestors: vi.fn(),
    getReferralCommissions: vi.fn(),
    applyReferralCommission: vi.fn(),
  },
}));

describe("ReferralCommissionsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getAdminInvestors).mockResolvedValue({
      data: [
        { id: "1", email: "inv@test.com", name: "Investor One" },
        { id: "2", email: "inv2@test.com", name: "Investor Two" },
      ],
    } as { data?: unknown[] });
    vi.mocked(api.getReferralCommissions).mockResolvedValue({
      data: [],
      pagination: { page: 1, per_page: 20, total: 0, total_pages: 0 },
    } as { data?: unknown[]; pagination?: unknown });
  });

  it("renders page title and loads investors", async () => {
    render(<ReferralCommissionsPage />);

    expect(screen.getByText("Comisiones por referido")).toBeInTheDocument();
    expect(
      screen.getByText(/Cargá un monto puntual al balance/),
    ).toBeInTheDocument();

    await waitFor(() => {
      expect(api.getAdminInvestors).toHaveBeenCalled();
      expect(api.getReferralCommissions).toHaveBeenCalled();
    });
  });

  it("shows apply button and history section", async () => {
    render(<ReferralCommissionsPage />);

    await waitFor(() => expect(api.getAdminInvestors).toHaveBeenCalled());

    expect(
      screen.getByRole("button", { name: /Aplicar comisión/i }),
    ).toBeInTheDocument();
    expect(screen.getByText("Historial")).toBeInTheDocument();
  });

  it("shows error when applying without investor", async () => {
    const user = userEvent.setup();
    render(<ReferralCommissionsPage />);

    await waitFor(() => expect(api.getAdminInvestors).toHaveBeenCalled());

    await user.click(screen.getByRole("button", { name: /Aplicar comisión/i }));

    await waitFor(() =>
      expect(screen.getByText("Seleccioná un inversor")).toBeInTheDocument(),
    );
    expect(api.applyReferralCommission).not.toHaveBeenCalled();
  });

  it("shows error when applying with invalid amount", async () => {
    const user = userEvent.setup();
    render(<ReferralCommissionsPage />);

    await waitFor(() => expect(api.getAdminInvestors).toHaveBeenCalled());

    await user.click(screen.getByRole("button", { name: /Seleccionar/i }));
    await user.click(screen.getByRole("option", { name: /Investor One/ }));
    await user.type(screen.getByPlaceholderText("Ej: 50"), "0");

    await user.click(screen.getByRole("button", { name: /Aplicar comisión/i }));

    await waitFor(() =>
      expect(
        screen.getByText(/Ingresá un monto mayor a 0/),
      ).toBeInTheDocument(),
    );
    expect(api.applyReferralCommission).not.toHaveBeenCalled();
  });

  it("applies commission successfully and shows success message", async () => {
    const user = userEvent.setup();
    vi.mocked(api.applyReferralCommission).mockResolvedValue({} as never);

    render(<ReferralCommissionsPage />);

    await waitFor(() => expect(api.getAdminInvestors).toHaveBeenCalled());

    await user.click(screen.getByRole("button", { name: /Seleccionar/i }));
    await user.click(screen.getByRole("option", { name: /Investor One/ }));
    await user.type(screen.getByPlaceholderText("Ej: 50"), "100");

    await user.click(screen.getByRole("button", { name: /Aplicar comisión/i }));

    await waitFor(() =>
      expect(api.applyReferralCommission).toHaveBeenCalledWith("1", {
        amount: 100,
      }),
    );
    expect(
      screen.getByText("Comisión por referido aplicada correctamente"),
    ).toBeInTheDocument();
  });

  it("shows error when apply fails", async () => {
    const user = userEvent.setup();
    vi.mocked(api.applyReferralCommission).mockRejectedValue(
      new Error("Server error"),
    );

    render(<ReferralCommissionsPage />);

    await waitFor(() => expect(api.getAdminInvestors).toHaveBeenCalled());

    await user.click(screen.getByRole("button", { name: /Seleccionar/i }));
    await user.click(screen.getByRole("option", { name: /Investor One/ }));
    await user.type(screen.getByPlaceholderText("Ej: 50"), "100");

    await user.click(screen.getByRole("button", { name: /Aplicar comisión/i }));

    await waitFor(() =>
      expect(screen.getByText("Server error")).toBeInTheDocument(),
    );
  });

  it("shows history rows when data exists", async () => {
    vi.mocked(api.getReferralCommissions).mockResolvedValue({
      data: [
        {
          id: "1",
          investor_id: "inv-1",
          investor_name: "Juan",
          investor_email: "juan@test.com",
          amount: 50,
          date: "2025-01-15T12:00:00Z",
        },
      ],
      pagination: { page: 1, per_page: 20, total: 1, total_pages: 1 },
    } as never);

    render(<ReferralCommissionsPage />);

    await waitFor(() => expect(screen.getByText("Juan")).toBeInTheDocument());
    expect(screen.getByText("juan@test.com")).toBeInTheDocument();
    expect(screen.getByText(/\$50\.00/)).toBeInTheDocument();
  });

  it("shows empty state when no history", async () => {
    render(<ReferralCommissionsPage />);

    await waitFor(() => expect(api.getReferralCommissions).toHaveBeenCalled());

    expect(
      screen.getByText("No hay comisiones por referido registradas."),
    ).toBeInTheDocument();
  });

  it("shows pagination when history has multiple pages", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getReferralCommissions).mockResolvedValue({
      data: [
        {
          id: "1",
          investor_id: "inv-1",
          investor_name: "Juan",
          investor_email: "juan@test.com",
          amount: 50,
          date: "2025-01-15T12:00:00Z",
        },
      ],
      pagination: { page: 1, per_page: 20, total: 25, total_pages: 2 },
    } as never);

    render(<ReferralCommissionsPage />);

    await waitFor(() => expect(screen.getByText("Juan")).toBeInTheDocument());

    expect(screen.getByText(/Página/)).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Siguiente" }),
    ).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Siguiente" }));
    await waitFor(() =>
      expect(api.getReferralCommissions).toHaveBeenCalledWith({ page: 2 }),
    );
  });
});
