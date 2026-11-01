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
    getMonthlyReportEmailSchedules: vi.fn(),
    scheduleMonthlyReportEmailMass: vi.fn(),
    cancelMonthlyReportEmailSchedule: vi.fn(),
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
    vi.mocked(api.getMonthlyReportEmailSchedules).mockResolvedValue({ data: [] });
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

  it("sends a test to another address without choosing an investor first", async () => {
    const user = userEvent.setup();
    vi.mocked(api.sendMonthlyReportEmailOne).mockResolvedValue({
      data: { queuedCount: 1, failureCount: 0 },
    });

    render(<MonthlyReportEmailPanel month="2026-07" />);
    expect(await screen.findByText("Enviar una prueba")).toBeInTheDocument();
    await screen.findByText(/con el PDF de Tulio Capparelli/);
    await user.type(
      screen.getByLabelText("Correo de prueba"),
      "contacto@winbit.com.ar",
    );
    await user.click(screen.getByRole("button", { name: "Enviar prueba" }));

    await waitFor(() => {
      expect(api.sendMonthlyReportEmailOne).toHaveBeenCalledWith(
        expect.objectContaining({
          investor_id: "inv-1",
          test_email: "contacto@winbit.com.ar",
        }),
      );
    });
    expect(
      await screen.findByText(/Prueba enviada a contacto@winbit.com.ar/),
    ).toBeInTheDocument();
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

  it("schedules the mass send for a chosen date and time", async () => {
    const user = userEvent.setup();
    vi.mocked(api.scheduleMonthlyReportEmailMass).mockResolvedValue({ data: {} });
    vi.mocked(api.getMonthlyReportEmailSchedules)
      .mockResolvedValueOnce({ data: [] })
      .mockResolvedValue({
        data: [
          {
            id: "s-1",
            month: "2026-07",
            subject: "Winbit | Reporte {{mes}}",
            scheduledFor: new Date(2026, 10, 2, 8, 0).toISOString(),
            status: "SCHEDULED",
            scheduledBy: "Admin",
          },
        ],
      });

    render(<MonthlyReportEmailPanel month="2026-07" />);
    await screen.findByText("Tulio Capparelli");

    const input = screen.getByLabelText("Fecha y hora de envío");
    await user.clear(input);
    await user.type(input, "2026-11-02T08:00");
    await user.click(screen.getByRole("button", { name: "Programar envío" }));
    await user.click(await screen.findByRole("button", { name: "Programar" }));

    await waitFor(() => {
      expect(api.scheduleMonthlyReportEmailMass).toHaveBeenCalledWith(
        expect.objectContaining({
          month: "2026-07",
          scheduled_for: new Date(2026, 10, 2, 8, 0).toISOString(),
        }),
      );
    });
    expect(
      await screen.findByText(/Programado para el lunes 02\/11 a las 08:00/),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /Enviar a todos los elegibles/i }),
    ).toBeDisabled();
  });

  it("cancels a pending scheduled send", async () => {
    const user = userEvent.setup();
    vi.mocked(api.cancelMonthlyReportEmailSchedule).mockResolvedValue({ data: {} });
    vi.mocked(api.getMonthlyReportEmailSchedules)
      .mockResolvedValueOnce({
        data: [
          {
            id: "s-1",
            month: "2026-07",
            subject: "Asunto",
            scheduledFor: new Date(2026, 10, 2, 8, 0).toISOString(),
            status: "SCHEDULED",
          },
        ],
      })
      .mockResolvedValue({ data: [] });

    render(<MonthlyReportEmailPanel month="2026-07" />);
    await user.click(
      await screen.findByRole("button", { name: "Cancelar programación" }),
    );

    expect(api.cancelMonthlyReportEmailSchedule).toHaveBeenCalledWith("s-1");
    expect(
      await screen.findByText("Envío programado cancelado."),
    ).toBeInTheDocument();
  });
});
