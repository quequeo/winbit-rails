import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
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
});
