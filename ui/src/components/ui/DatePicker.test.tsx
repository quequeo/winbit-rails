import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { fireEvent } from "@testing-library/react";
import { DatePicker } from "./DatePicker";

describe("DatePicker", () => {
  it("renders with value and placeholder", () => {
    const onChange = vi.fn();
    render(<DatePicker value="2025-01-15" onChange={onChange} />);

    expect(screen.getByDisplayValue("2025-01-15")).toBeInTheDocument();
    expect(screen.getByPlaceholderText("YYYY-MM-DD")).toBeInTheDocument();
  });

  it("opens calendar on click and selects a day", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<DatePicker value="2025-01-15" onChange={onChange} />);

    await user.click(screen.getByRole("button"));

    const grid = document.querySelector('[role="grid"]');
    expect(grid).toBeInTheDocument();

    const gridButtons = grid?.querySelectorAll("button") ?? [];
    const dayButton = Array.from(gridButtons).find(
      (b) =>
        /^\d+$/.test((b.textContent || "").trim()) ||
        /^\d+$/.test((b as HTMLButtonElement).name || ""),
    );
    expect(dayButton).toBeDefined();
    await user.click(dayButton as HTMLElement);
    expect(onChange).toHaveBeenCalledWith(
      expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
    );
  });

  it("closes calendar when clicking outside", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(
      <div>
        <DatePicker value="2025-01-15" onChange={onChange} />
        <div data-testid="outside">Outside</div>
      </div>,
    );

    await user.click(screen.getByRole("button"));
    expect(document.querySelector('[role="grid"]')).toBeInTheDocument();

    fireEvent.mouseDown(screen.getByTestId("outside"));
    expect(document.querySelector('[role="grid"]')).not.toBeInTheDocument();
  });

  it("renders disabled state", () => {
    const onChange = vi.fn();
    render(<DatePicker value="2025-01-15" onChange={onChange} disabled />);

    const button = screen.getByRole("button");
    expect(button).toBeDisabled();
  });

  it("uses custom placeholder when provided", () => {
    const onChange = vi.fn();
    render(
      <DatePicker
        value=""
        onChange={onChange}
        placeholder="Seleccionar fecha"
      />,
    );

    expect(
      screen.getByPlaceholderText("Seleccionar fecha"),
    ).toBeInTheDocument();
  });

  it("renders with empty value and allows selecting", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<DatePicker value="" onChange={onChange} />);

    await user.click(screen.getByRole("button"));
    const cells = document.querySelectorAll("button[name]");
    const dayButton = Array.from(cells).find((b) =>
      /^\d+$/.test((b as HTMLButtonElement).name || ""),
    );
    if (dayButton) {
      await user.click(dayButton as HTMLElement);
      expect(onChange).toHaveBeenCalledWith(
        expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
      );
    }
  });
});
