import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import { StrategyOperationsPage } from "./StrategyOperationsPage";
import { api } from "../lib/api";

vi.mock("../lib/api", () => ({
  api: {
    getStrategyOperations: vi.fn(),
    getAdminSession: vi.fn(),
    createStrategyOperation: vi.fn(),
  },
}));

describe("StrategyOperationsPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getAdminSession).mockResolvedValue({
      data: { superadmin: true },
    });
    vi.mocked(api.getStrategyOperations).mockResolvedValue({
      data: [
        {
          id: "1",
          operationDate: "2026-05-04",
          asset: "NQ",
          resultLabel: "POSITIVO",
          resultUsd: 850,
          source: "import",
        },
      ],
    });
  });

  it("renders operations table and period filters", async () => {
    render(<StrategyOperationsPage />);

    expect(screen.getByText("Operaciones de estrategia")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Descargar Excel" })).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText("NQ")).toBeInTheDocument());
  });
});
