import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MonthlyReportPdfsPage } from "./MonthlyReportPdfsPage";
import { api } from "../lib/api";

vi.mock("../lib/api", () => ({
  api: {
    getMonthlyReportPdfs: vi.fn(),
    uploadMonthlyReportPdfs: vi.fn(),
    downloadMonthlyReportPdfFile: vi.fn(),
    deleteMonthlyReportPdf: vi.fn(),
    previewMonthlyReportEmail: vi.fn(),
    sendMonthlyReportEmailOne: vi.fn(),
    sendMonthlyReportEmailMass: vi.fn(),
  },
}));

const indexPayload = {
  data: {
    month: "2026-07",
    present: [
      {
        id: "pdf-1",
        month: "2026-07",
        originalFilename: "Reporte julio - TULIO CAPPARELLI.pdf",
        byteSize: 2048,
        investor: {
          id: "inv-1",
          name: "Tulio Capparelli",
          email: "tulio@test.com",
          status: "ACTIVE",
        },
      },
    ],
    missing: [
      {
        id: "inv-2",
        name: "Eugenio Carrió",
        email: "eugenio@test.com",
        status: "ACTIVE",
      },
    ],
    counts: { present: 1, missing: 1, missingActive: 1 },
  },
};

const previewPayload = {
  data: {
    preview: true,
    assignments: [
      {
        filename: "Reporte julio - EUGENIO CARRIO.pdf",
        parsedName: "EUGENIO CARRIO",
        status: "assign" as const,
        reason: null,
        alreadyHasPdf: false,
        investor: {
          id: "inv-2",
          name: "Eugenio Carrió",
          email: "eugenio@test.com",
          status: "ACTIVE",
        },
      },
      {
        filename: "Reporte julio - FULANO.pdf",
        parsedName: "FULANO",
        status: "skip" as const,
        reason: "investor_not_found",
        alreadyHasPdf: false,
        investor: null,
      },
    ],
    counts: { assign: 1, replace: 0, skip: 1 },
    uploaded_count: 0,
    replaced_count: 0,
  },
};

describe("MonthlyReportPdfsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getMonthlyReportPdfs).mockResolvedValue(indexPayload);
  });

  it("lists who has a PDF and who is missing", async () => {
    render(<MonthlyReportPdfsPage />);

    expect(await screen.findByText("Tulio Capparelli")).toBeInTheDocument();
    expect(screen.getByText("Eugenio Carrió")).toBeInTheDocument();
    expect(screen.getByText("Con PDF: 1")).toBeInTheDocument();
    expect(api.getMonthlyReportPdfs).toHaveBeenCalled();
  });

  it("previews assignments and only persists after confirm", async () => {
    const user = userEvent.setup();
    vi.mocked(api.uploadMonthlyReportPdfs)
      .mockResolvedValueOnce(previewPayload)
      .mockResolvedValueOnce({
        data: {
          preview: false,
          assignments: previewPayload.data.assignments,
          counts: { assign: 1, replace: 0, skip: 1 },
          uploaded_count: 1,
          replaced_count: 0,
        },
      });

    render(<MonthlyReportPdfsPage />);
    await screen.findByText("Tulio Capparelli");

    const file = new File(["%PDF-1.4"], "Reporte julio - EUGENIO CARRIO.pdf", {
      type: "application/pdf",
    });
    const input = document.querySelector(
      'input[type="file"][multiple]',
    ) as HTMLInputElement;
    await user.upload(input, file);

    await waitFor(() => {
      expect(api.uploadMonthlyReportPdfs).toHaveBeenCalledTimes(1);
    });
    expect(vi.mocked(api.uploadMonthlyReportPdfs).mock.calls[0][0].preview).toBe(
      true,
    );
    expect(
      await screen.findByText("Reporte julio - EUGENIO CARRIO.pdf"),
    ).toBeInTheDocument();
    expect(screen.getByText("Asignar")).toBeInTheDocument();
    expect(screen.getByText(/No hay inversor con ese nombre/)).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /Confirmar 1 PDF/i }));

    await waitFor(() => {
      expect(api.uploadMonthlyReportPdfs).toHaveBeenCalledTimes(2);
    });
    const confirmArgs = vi.mocked(api.uploadMonthlyReportPdfs).mock.calls[1][0];
    expect(confirmArgs.preview).toBe(false);
    expect(confirmArgs.confirm).toBe(true);
  });

  it("opens the email tab with the composer", async () => {
    const user = userEvent.setup();
    vi.mocked(api.previewMonthlyReportEmail).mockResolvedValue({
      data: {
        month: "2026-07",
        audienceCount: 0,
        variables: [],
        recipients: [],
        skipped: [],
      },
    });

    render(<MonthlyReportPdfsPage />);
    await screen.findByText("Tulio Capparelli");
    await user.click(screen.getByRole("button", { name: /Enviar emails/i }));
    expect(await screen.findByLabelText("Asunto del email")).toBeInTheDocument();
    expect(api.previewMonthlyReportEmail).toHaveBeenCalled();
  });
});
