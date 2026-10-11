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

  it("sends after confirming", async () => {
    vi.mocked(api.sendOutgoingEmail).mockResolvedValue(null as never);
    render(<OutgoingEmailsPage />);
    await userEvent.click(
      await screen.findByRole("button", { name: "Enviar" }),
    );
    const buttons = await screen.findAllByRole("button", { name: "Enviar" });
    await userEvent.click(buttons[buttons.length - 1]);
    await waitFor(() =>
      expect(api.sendOutgoingEmail).toHaveBeenCalledWith("e1"),
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
