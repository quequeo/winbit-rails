import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { StrategyOperationsPage } from "./StrategyOperationsPage";
import { api } from "../lib/api";
import * as copyHelper from "../lib/copyStrategyOperationsForGpt";

vi.mock("../lib/api", () => ({
  api: {
    getStrategyOperations: vi.fn(),
  },
}));

describe("StrategyOperationsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getStrategyOperations).mockResolvedValue({
      data: [
        {
          id: "1",
          operationDate: "2026-05-04",
          asset: "NQ",
          timeframe: "M5",
          openedAt: "09:30",
          closedAt: "10:15",
          resultLabel: "POSITIVO",
          resultUsd: 850,
          source: "import",
        },
      ],
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("renders operations table and period filters", async () => {
    render(<StrategyOperationsPage />);

    expect(screen.getByText("Operaciones de estrategia")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Descargar Excel" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Copiar para GPT" })).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText("NQ")).toBeInTheDocument());
  });

  it("copies filtered operations for GPT analysis", async () => {
    const user = userEvent.setup();
    const copySpy = vi
      .spyOn(copyHelper, "copyTextToClipboard")
      .mockResolvedValue();

    render(<StrategyOperationsPage />);
    await waitFor(() => expect(screen.getByText("NQ")).toBeInTheDocument());

    await user.click(screen.getByRole("button", { name: "Copiar para GPT" }));

    await waitFor(() => expect(copySpy).toHaveBeenCalledTimes(1));
    const text = copySpy.mock.calls[0][0];
    expect(text).toContain("# Operaciones de estrategia — 2026");
    expect(text).toContain("| 4 May 2026 | NQ | M5 | 09:30 | 10:15 | POSITIVO | 850.00 |");
    expect(
      await screen.findByRole("button", { name: "Copiado" }),
    ).toBeInTheDocument();
  });

  it("shows error when clipboard copy fails", async () => {
    const user = userEvent.setup();
    vi.spyOn(copyHelper, "copyTextToClipboard").mockRejectedValue(
      new Error("Clipboard blocked"),
    );

    render(<StrategyOperationsPage />);
    await waitFor(() => expect(screen.getByText("NQ")).toBeInTheDocument());

    await user.click(screen.getByRole("button", { name: "Copiar para GPT" }));

    expect(await screen.findByText("Clipboard blocked")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Copiar para GPT" })).toBeInTheDocument();
  });
});
