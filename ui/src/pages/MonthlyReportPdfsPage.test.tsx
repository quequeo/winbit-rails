import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MonthlyReportPdfsPage } from "./MonthlyReportPdfsPage";
import { api } from "../lib/api";
import { lastClosedMonth } from "../lib/lastClosedMonth";

vi.mock("../lib/api", () => ({
  api: {
    getMonthlyReportPdfs: vi.fn(),
    uploadMonthlyReportPdfs: vi.fn(),
    generateMonthlyReportPdfs: vi.fn(),
    previewMonthlyReportPdf: vi.fn(),
    downloadMonthlyReportPdfsZip: vi.fn(),
    downloadMonthlyReportPdfFile: vi.fn(),
    deleteMonthlyReportPdf: vi.fn(),
    previewMonthlyReportEmail: vi.fn(),
    getMonthlyReportEmailSchedules: vi.fn().mockResolvedValue({ data: [] }),
    scheduleMonthlyReportEmailMass: vi.fn(),
    cancelMonthlyReportEmailSchedule: vi.fn(),
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

  it("enqueues bulk generation and shows a background-processing notice", async () => {
    const user = userEvent.setup();
    vi.mocked(api.generateMonthlyReportPdfs).mockResolvedValue({
      data: { enqueued: true, month: lastClosedMonth() },
    });

    render(<MonthlyReportPdfsPage />);
    await screen.findByText("Tulio Capparelli");

    await user.click(
      screen.getByRole("button", { name: /Generar automáticamente/i }),
    );

    expect(api.generateMonthlyReportPdfs).toHaveBeenCalledWith({
      month: lastClosedMonth(),
    });
    expect(
      await screen.findByText(/Generando en el fondo/),
    ).toBeInTheDocument();
  });

  it("shows a notice instead of polling when a bulk generation is already running", async () => {
    const user = userEvent.setup();
    vi.mocked(api.generateMonthlyReportPdfs).mockResolvedValue({
      data: { enqueued: false, already_running: true, month: lastClosedMonth() },
    });

    render(<MonthlyReportPdfsPage />);
    await screen.findByText("Tulio Capparelli");

    await user.click(
      screen.getByRole("button", { name: /Generar automáticamente/i }),
    );

    expect(
      await screen.findByText(/Ya hay una generación en curso/),
    ).toBeInTheDocument();
  });

  const withGeneration = (generation: Record<string, unknown>) => ({
    data: {
      ...indexPayload.data,
      generation: {
        month: lastClosedMonth(),
        running: true,
        stalled: false,
        processed: 3,
        total: 10,
        generated: 2,
        failed: [],
        aborted: false,
        startedAt: "2026-10-01T10:00:00Z",
        finishedAt: null,
        ...generation,
      },
    },
  });

  it("shows the progress of a running bulk generation and keeps refreshing until it finishes", async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    try {
      vi.mocked(api.getMonthlyReportPdfs)
        .mockResolvedValueOnce(withGeneration({}))
        .mockResolvedValue(
          withGeneration({
            running: false,
            processed: 10,
            generated: 9,
            failed: ["Eugenio Carrió"],
            finishedAt: "2026-10-01T10:05:00Z",
          }),
        );

      render(<MonthlyReportPdfsPage />);

      expect(await screen.findByText("Generando PDFs… 3 de 10")).toBeInTheDocument();
      expect(
        screen.getByRole("button", { name: "Generando..." }),
      ).toBeDisabled();

      await vi.advanceTimersByTimeAsync(5000);

      expect(
        await screen.findByText(/9 PDFs generados/),
      ).toBeInTheDocument();
      expect(
        screen.getByText("No se pudieron generar: Eugenio Carrió."),
      ).toBeInTheDocument();
      expect(api.getMonthlyReportPdfs).toHaveBeenCalledTimes(2);

      await vi.advanceTimersByTimeAsync(10000);
      expect(api.getMonthlyReportPdfs).toHaveBeenCalledTimes(2);
    } finally {
      vi.useRealTimers();
    }
  });

  it("flags outdated PDFs and counts them in the automatic generation", async () => {
    vi.mocked(api.getMonthlyReportPdfs).mockResolvedValue({
      data: {
        ...indexPayload.data,
        present: [{ ...indexPayload.data.present[0], outdated: true }],
        counts: { ...indexPayload.data.counts, outdatedActive: 1 },
      },
    });

    render(<MonthlyReportPdfsPage />);

    expect(await screen.findByText("Desactualizado")).toBeInTheDocument();
    expect(screen.getByText("Desactualizados: 1")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Generar automáticamente (2)" }),
    ).toBeEnabled();
  });

  it("tells the admin a cut-off generation resumes on its own", async () => {
    vi.mocked(api.getMonthlyReportPdfs).mockResolvedValue(
      withGeneration({ running: false, stalled: true }),
    );

    render(<MonthlyReportPdfsPage />);

    expect(
      await screen.findByText(/Se retoma sola en un minuto/),
    ).toBeInTheDocument();
  });

  it("shows the report preview with validation warnings in a modal", async () => {
    const user = userEvent.setup();
    vi.mocked(api.previewMonthlyReportPdf).mockResolvedValue({
      data: {
        html: "<html><body>Reporte de Tulio</body></html>",
        warnings: ["El último valor del historial no coincide con el valor actual del portafolio."],
      },
    });

    render(<MonthlyReportPdfsPage />);
    await screen.findByText("Tulio Capparelli");

    await user.click(screen.getAllByRole("button", { name: "Vista previa" })[0]);

    expect(api.previewMonthlyReportPdf).toHaveBeenCalledWith({
      month: lastClosedMonth(),
      investorId: "inv-1",
    });
    expect(await screen.findByText("Avisos (1)")).toBeInTheDocument();
    expect(
      screen.getByText(/último valor del historial no coincide/),
    ).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Cerrar" }));
    expect(screen.queryByText("Avisos (1)")).not.toBeInTheDocument();
  });

  it("downloads a ZIP with every PDF for the month", async () => {
    const user = userEvent.setup();
    vi.mocked(api.downloadMonthlyReportPdfsZip).mockResolvedValue(undefined);

    render(<MonthlyReportPdfsPage />);
    await screen.findByText("Tulio Capparelli");

    await user.click(
      screen.getByRole("button", { name: /Descargar todos \(ZIP\)/i }),
    );

    await waitFor(() => {
      expect(api.downloadMonthlyReportPdfsZip).toHaveBeenCalledWith(
        lastClosedMonth(),
      );
    });
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
