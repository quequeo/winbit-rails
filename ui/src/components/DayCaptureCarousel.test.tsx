import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { DayCaptureCarousel } from "./DayCaptureCarousel";

describe("DayCaptureCarousel", () => {
  const captures = [
    {
      id: "1",
      captureDate: "2026-05-04",
      asset: "MNQ",
      resultLabel: "POSITIVO",
      originalFilename: "NQ_04.05.26_POSITIVO.png",
      imageUrl: "/img/1.png",
    },
    {
      id: "2",
      captureDate: "2026-05-04",
      asset: "MBT",
      resultLabel: "NEGATIVO",
      originalFilename: "BTC_04.05.26_NEGATIVO.png",
      imageUrl: "/img/2.png",
    },
  ];

  it("navigates with next/prev arrows", async () => {
    const user = userEvent.setup();
    const onClose = vi.fn();
    render(
      <DayCaptureCarousel
        open
        date="2026-05-04"
        captures={captures}
        onClose={onClose}
      />,
    );

    expect(screen.getByText("1 / 2 · MNQ · POSITIVO")).toBeInTheDocument();
    expect(screen.getByAltText("NQ_04.05.26_POSITIVO.png")).toBeInTheDocument();

    await user.click(screen.getByLabelText("Captura siguiente"));
    expect(screen.getByText("2 / 2 · MBT · NEGATIVO")).toBeInTheDocument();
    expect(screen.getByAltText("BTC_04.05.26_NEGATIVO.png")).toBeInTheDocument();

    await user.click(screen.getByLabelText("Captura anterior"));
    expect(screen.getByText("1 / 2 · MNQ · POSITIVO")).toBeInTheDocument();
  });
});
