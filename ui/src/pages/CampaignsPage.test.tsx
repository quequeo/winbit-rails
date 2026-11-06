import { describe, it, expect, vi, beforeEach } from "vitest";
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { CampaignsPage } from "./CampaignsPage";
import { api } from "../lib/api";
import { downloadMonthlyReportExcel } from "../lib/monthlyReportExcel";

vi.mock("../lib/api", () => ({
  api: {
    previewEmailCampaign: vi.fn(),
    sendEmailCampaignOne: vi.fn(),
    sendEmailCampaignMass: vi.fn(),
    getEmailCampaignSchedules: vi.fn(),
    scheduleEmailCampaign: vi.fn(),
    cancelEmailCampaignSchedule: vi.fn(),
    getInvestorMonthlyReport: vi.fn(),
  },
}));

vi.mock("../lib/monthlyReportExcel", () => ({
  downloadMonthlyReportExcel: vi.fn(),
}));

const previewPayload = {
  data: {
    month: "2026-06",
    audienceCount: 1,
    variables: ["nombre", "ganancia_usd"],
    recipients: [
      {
        id: 42,
        name: "Mariano Krokante",
        email: "mariano.kr@gmail.com",
        gananciaUsd: "+100,00",
        gananciaPct: "+2,00%",
      },
    ],
    sampleSubject: "Asunto",
    sampleBodyHtml: "<p>Hola</p>",
    sampleInvestor: {
      id: 42,
      name: "Mariano Krokante",
      email: "mariano.kr@gmail.com",
    },
  },
};

const sampleReport = {
  investor: {
    id: "42",
    name: "Mariano Krokante",
    email: "mariano.kr@gmail.com",
  },
  reportMonth: "2026-06",
  summary: {
    portfolioValue: 1000,
    monthlyReturnPercent: 2,
    monthlyReturnUsd: 100,
    accumulatedReturnPercent: 10,
    accumulatedReturnUsd: 200,
    ytd2026ReturnPercent: 5,
    ytd2026ReturnUsd: 50,
  },
  annexRows: [],
};

describe("CampaignsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.previewEmailCampaign).mockResolvedValue(previewPayload);
    vi.mocked(api.getEmailCampaignSchedules).mockResolvedValue({ data: [] });
  });

  it("shows ↓ download next to each recipient and downloads that Excel", async () => {
    vi.mocked(api.getInvestorMonthlyReport).mockResolvedValue({
      data: sampleReport,
    });

    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <CampaignsPage />
      </MemoryRouter>,
    );

    const downloadBtn = await screen.findByRole("button", {
      name: /Descargar Excel de Mariano Krokante/i,
    });

    await user.click(downloadBtn);

    await waitFor(() => {
      expect(api.getInvestorMonthlyReport).toHaveBeenCalledWith(
        "42",
        expect.stringMatching(/^\d{4}-\d{2}$/),
      );
    });

    expect(downloadMonthlyReportExcel).toHaveBeenCalledWith(sampleReport);
  });

  it("sends a test to a chosen address, without the app button by default", async () => {
    vi.mocked(api.sendEmailCampaignOne).mockResolvedValue({
      data: { queuedCount: 1, failureCount: 0 },
    });

    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <CampaignsPage />
      </MemoryRouter>,
    );
    await screen.findByText("Preview (Mariano Krokante)");

    await user.type(
      screen.getByLabelText(/Enviar una prueba a/i),
      "flor@example.com",
    );
    await user.click(screen.getByRole("button", { name: "Enviar prueba" }));

    await waitFor(() => {
      expect(api.sendEmailCampaignOne).toHaveBeenCalledWith(
        expect.objectContaining({
          investor_id: "42",
          test_email: "flor@example.com",
          app_button: false,
        }),
      );
    });
    expect(await screen.findByText(/Prueba enviada a/)).toBeInTheDocument();
  });

  it("schedules for everyone in Argentina time", async () => {
    vi.mocked(api.scheduleEmailCampaign).mockResolvedValue({ data: {} });

    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <CampaignsPage />
      </MemoryRouter>,
    );
    await screen.findByText("Preview (Mariano Krokante)");

    fireEvent.change(screen.getByLabelText(/Programar para/i), {
      target: { value: "2026-11-09T08:00" },
    });
    await user.click(screen.getByRole("button", { name: "Programar" }));
    const buttons = await screen.findAllByRole("button", { name: "Programar" });
    await user.click(buttons[buttons.length - 1]);

    await waitFor(() => {
      expect(api.scheduleEmailCampaign).toHaveBeenCalledWith(
        expect.objectContaining({
          scheduled_for: "2026-11-09T08:00:00-03:00",
          investor_ids: undefined,
        }),
      );
    });
  });

  it("does not offer to send when no investor is chosen", async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <CampaignsPage />
      </MemoryRouter>,
    );
    await screen.findByText("Preview (Mariano Krokante)");

    await user.click(screen.getByLabelText("Elegir inversores"));
    expect(screen.getByRole("button", { name: "Enviar ahora" })).toBeDisabled();

    await user.click(screen.getByLabelText("Elegir a Mariano Krokante"));
    expect(screen.getByRole("button", { name: "Enviar ahora" })).toBeEnabled();
  });

  it("lists scheduled sends and lets you cancel one", async () => {
    vi.mocked(api.getEmailCampaignSchedules).mockResolvedValue({
      data: [
        {
          id: "s1",
          subject: "Winbit | Dónde está tu capital",
          scheduledFor: "2026-11-09T11:00:00Z",
          status: "SCHEDULED",
          audienceCount: null,
        },
      ],
    });
    vi.mocked(api.cancelEmailCampaignSchedule).mockResolvedValue({ data: {} });

    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <CampaignsPage />
      </MemoryRouter>,
    );

    expect(
      await screen.findByText("Winbit | Dónde está tu capital"),
    ).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Cancelar" }));
    await waitFor(() => {
      expect(api.cancelEmailCampaignSchedule).toHaveBeenCalledWith("s1");
    });
  });

  it("lets upload a per-investor attachment and sends it to the chosen investor", async () => {
    vi.mocked(api.sendEmailCampaignMass).mockResolvedValue({
      data: { queuedCount: 1, failureCount: 0 },
    });

    const user = userEvent.setup();
    render(
      <MemoryRouter initialEntries={["/campanas?investorId=42"]}>
        <CampaignsPage />
      </MemoryRouter>,
    );

    const fileInput = await screen.findByLabelText(
      /Adjuntar archivo para Mariano Krokante/i,
    );
    const file = new File(["%PDF-1.4"], "mariano.pdf", {
      type: "application/pdf",
    });
    await user.upload(fileInput, file);

    expect(await screen.findByText("mariano.pdf")).toBeInTheDocument();

    await user.click(screen.getByLabelText(/Confirmo envío a 1 inversores/i));
    await user.click(screen.getByRole("button", { name: "Enviar ahora" }));
    const buttons = await screen.findAllByRole("button", {
      name: "Enviar ahora",
    });
    await user.click(buttons[buttons.length - 1]);

    await waitFor(() => {
      expect(api.sendEmailCampaignMass).toHaveBeenCalledWith(
        expect.objectContaining({
          investor_ids: ["42"],
          attachmentsByInvestorId: { "42": expect.any(File) },
        }),
      );
    });
  });
});
