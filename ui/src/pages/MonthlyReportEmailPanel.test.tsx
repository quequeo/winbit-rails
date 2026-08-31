import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MonthlyReportEmailPanel } from "../components/MonthlyReportEmailPanel";
import { api } from "../lib/api";

vi.mock("../lib/api", () => ({
  api: {
    previewMonthlyReportEmail: vi.fn(),
    sendMonthlyReportEmailOne: vi.fn(),
    sendMonthlyReportEmailMass: vi.fn(),
  },
}));

const previewPayload = {
  data: {
    month: "2026-07",
    audienceCount: 1,
    variables: ["nombre", "ganancia_usd", "ganancia_pct", "mes"],
    recipients: [
      {
        id: "inv-1",
        name: "Tulio Capparelli",
        email: "tulio@test.com",
        hasPdf: true,
        balance: 5000,
        pdfFilename: "Reporte julio 2026 - TULIO CAPPARELLI.pdf",
        gananciaUsd: "$100,00",
        gananciaPct: "2,00%",
      },
    ],
    skipped: [
      {
        id: "inv-2",
        name: "Jaime Empty",
        email: "monitoapps@gmail.com",
        hasPdf: true,
        balance: 0,
        skipReason: "zero_balance",
        skipMessage: "El balance actual es 0",
      },
    ],
    sampleSubject: "Winbit | Reporte 2026-07",
    sampleBodyHtml: "Hola Tulio Capparelli",
    sampleInvestor: {
      id: "inv-1",
      name: "Tulio Capparelli",
      email: "tulio@test.com",
    },
  },
};

describe("MonthlyReportEmailPanel", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.previewMonthlyReportEmail).mockResolvedValue(previewPayload);
  });

  it("previews recipients with name, email, PDF and balance", async () => {
    render(<MonthlyReportEmailPanel month="2026-07" />);

    expect(await screen.findByText("Tulio Capparelli")).toBeInTheDocument();
    expect(screen.getByText("tulio@test.com")).toBeInTheDocument();
    expect(screen.getByText("Hola Tulio Capparelli")).toBeInTheDocument();
    expect(screen.getByText("El balance actual es 0")).toBeInTheDocument();
    expect(api.previewMonthlyReportEmail).toHaveBeenCalledWith(
      expect.objectContaining({ month: "2026-07" }),
    );
  });

  it("sends to one selected investor", async () => {
    const user = userEvent.setup();
    vi.mocked(api.sendMonthlyReportEmailOne).mockResolvedValue({
      data: { queuedCount: 1, failureCount: 0 },
    });

    render(<MonthlyReportEmailPanel month="2026-07" />);
    await user.click(await screen.findByText("Tulio Capparelli"));
    await user.click(
      screen.getByRole("button", { name: /Enviar a este inversor/i }),
    );

    await waitFor(() => {
      expect(api.sendMonthlyReportEmailOne).toHaveBeenCalledWith(
        expect.objectContaining({
          month: "2026-07",
          investor_id: "inv-1",
        }),
      );
    });
  });

  it("asks for confirmation before mass send", async () => {
    const user = userEvent.setup();
    vi.mocked(api.sendMonthlyReportEmailMass).mockResolvedValue({
      data: { queuedCount: 1, skippedCount: 0, failureCount: 0 },
    });

    render(<MonthlyReportEmailPanel month="2026-07" />);
    await screen.findByText("Tulio Capparelli");
    await user.click(
      screen.getByRole("button", { name: /Enviar a todos los elegibles/i }),
    );
    expect(
      await screen.findByText(/Se enviará el reporte de 2026-07 a 1 inversor/),
    ).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Enviar ahora/i }));

    await waitFor(() => {
      expect(api.sendMonthlyReportEmailMass).toHaveBeenCalledWith({
        month: "2026-07",
        subject: expect.any(String),
        body: expect.any(String),
        confirm: true,
      });
    });
  });
});
