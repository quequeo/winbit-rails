import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { api } from "../lib/api";
import { OutgoingEmailsPage } from "./OutgoingEmailsPage";

vi.mock("../lib/api", () => ({
  api: {
    getOutgoingEmails: vi.fn(),
    getOutgoingEmail: vi.fn(),
    sendOutgoingEmail: vi.fn(),
    scheduleOutgoingEmail: vi.fn(),
    unscheduleOutgoingEmail: vi.fn(),
    regenerateOutgoingEmail: vi.fn(),
    discardOutgoingEmail: vi.fn(),
    downloadRequestReceipt: vi.fn(),
  },
}));

const email = {
  id: "e1",
  kind: "WITHDRAWAL_APPROVED",
  status: "DRAFT",
  to: "lisandro@example.com",
  subject: "Winbit | Retiro aprobado",
  requestId: "r1",
  hasReceipt: true,
  receiptFilename: "Retiro de capital - Lisandro.pdf",
  createdAt: "2026-10-10T12:00:00Z",
  investor: { id: "i1", name: "Lisandro Filardi" },
};

describe("OutgoingEmailsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getOutgoingEmails).mockResolvedValue({
      data: { emails: [email], pendingCount: 1 },
    });
    vi.mocked(api.getOutgoingEmail).mockResolvedValue({
      data: { ...email, bodyHtml: "<p>Hola</p>" },
    });
  });

  it("shows the empty state", async () => {
    vi.mocked(api.getOutgoingEmails).mockResolvedValue({
      data: { emails: [], pendingCount: 0 },
    });
    render(<OutgoingEmailsPage />);
    expect(
      await screen.findByText("No hay correos pendientes."),
    ).toBeInTheDocument();
  });

  it("shows the draft with recipient, subject and attachment", async () => {
    render(<OutgoingEmailsPage />);
    expect(await screen.findByText("lisandro@example.com")).toBeInTheDocument();
    expect(screen.getByText("Winbit | Retiro aprobado")).toBeInTheDocument();
    expect(
      screen.getByText("Retiro de capital - Lisandro.pdf"),
    ).toBeInTheDocument();
  });

  it("sends right away after confirming", async () => {
    vi.mocked(api.sendOutgoingEmail).mockResolvedValue(null as never);
    render(<OutgoingEmailsPage />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Enviar ahora" }),
    );
    const buttons = await screen.findAllByRole("button", {
      name: "Enviar ahora",
    });
    await userEvent.click(buttons[buttons.length - 1]);
    await waitFor(() =>
      expect(api.sendOutgoingEmail).toHaveBeenCalledWith("e1"),
    );
  });

  it("schedules the send after confirming and shows it as scheduled", async () => {
    const scheduled = {
      ...email,
      status: "SCHEDULED",
      scheduledFor: "2026-11-02T11:00:00Z",
    };
    vi.mocked(api.scheduleOutgoingEmail).mockResolvedValue({
      data: scheduled,
    } as never);
    render(<OutgoingEmailsPage />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Programar envío" }),
    );
    const buttons = await screen.findAllByRole("button", {
      name: "Programar",
    });
    await userEvent.click(buttons[buttons.length - 1]);
    await waitFor(() =>
      expect(api.scheduleOutgoingEmail).toHaveBeenCalledWith("e1", undefined),
    );
    expect(await screen.findByRole("status")).toHaveTextContent(
      "el correo quedó programado y sale el",
    );
    expect(api.getOutgoingEmail).toHaveBeenCalledTimes(2);
  });

  it("shows a scheduled email as scheduled", async () => {
    const scheduled = {
      ...email,
      status: "SCHEDULED",
      scheduledFor: "2026-11-02T11:00:00Z",
    };
    vi.mocked(api.getOutgoingEmails).mockResolvedValue({
      data: { emails: [scheduled], pendingCount: 1 },
    });
    vi.mocked(api.getOutgoingEmail).mockResolvedValue({
      data: { ...scheduled, bodyHtml: "<p>Hola</p>" },
    });
    render(<OutgoingEmailsPage />);
    expect(await screen.findByText("Programado.")).toBeInTheDocument();
    expect(
      screen.queryByRole("button", { name: "Programar envío" }),
    ).not.toBeInTheDocument();
  });

  it("schedules at a chosen date and time in Argentina time", async () => {
    vi.mocked(api.scheduleOutgoingEmail).mockResolvedValue({
      data: email,
    } as never);
    render(<OutgoingEmailsPage />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Modificar fecha y hora" }),
    );
    const input = screen.getByLabelText("Fecha y hora de envío");
    await userEvent.clear(input);
    await userEvent.type(input, "2026-11-02T10:30");
    await userEvent.click(screen.getByRole("button", { name: "Guardar" }));
    await waitFor(() =>
      expect(api.scheduleOutgoingEmail).toHaveBeenCalledWith(
        "e1",
        "2026-11-02T10:30:00-03:00",
      ),
    );
  });

  it("lets you cancel a scheduled email", async () => {
    vi.mocked(api.unscheduleOutgoingEmail).mockResolvedValue(null as never);
    const scheduled = {
      ...email,
      status: "SCHEDULED",
      scheduledFor: "2026-10-14T21:00:00Z",
    };
    vi.mocked(api.getOutgoingEmails).mockResolvedValue({
      data: { emails: [scheduled], pendingCount: 1 },
    });
    vi.mocked(api.getOutgoingEmail).mockResolvedValue({
      data: { ...scheduled, bodyHtml: "<p>Hola</p>" },
    });
    render(<OutgoingEmailsPage />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Cancelar programación" }),
    );
    await waitFor(() =>
      expect(api.unscheduleOutgoingEmail).toHaveBeenCalledWith("e1"),
    );
  });

  it("discards a draft", async () => {
    vi.mocked(api.discardOutgoingEmail).mockResolvedValue(null as never);
    render(<OutgoingEmailsPage />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Descartar" }),
    );
    await waitFor(() =>
      expect(api.discardOutgoingEmail).toHaveBeenCalledWith("e1"),
    );
  });
});
