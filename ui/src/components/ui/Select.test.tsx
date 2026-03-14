import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Select } from "./Select";

describe("Select", () => {
  const options = [
    { value: "", label: "Seleccionar..." },
    { value: "a", label: "Option A" },
    { value: "b", label: "Option B" },
  ];

  it("renders with selected value", () => {
    const onChange = vi.fn();
    render(<Select value="a" options={options} onChange={onChange} />);

    expect(
      screen.getByRole("button", { name: "Option A" }),
    ).toBeInTheDocument();
  });

  it("opens menu and calls onChange when option is selected", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<Select value="" options={options} onChange={onChange} />);

    await user.click(screen.getByRole("button", { name: "Seleccionar..." }));
    await user.click(screen.getByRole("option", { name: "Option B" }));

    expect(onChange).toHaveBeenCalledWith("b");
  });

  it("closes on Escape", async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<Select value="" options={options} onChange={onChange} />);

    await user.click(screen.getByRole("button"));
    expect(
      screen.getByRole("option", { name: "Option A" }),
    ).toBeInTheDocument();

    await user.keyboard("{Escape}");
    expect(screen.queryByRole("option")).not.toBeInTheDocument();
  });

  it("renders disabled state", () => {
    const onChange = vi.fn();
    render(<Select value="a" options={options} onChange={onChange} disabled />);

    expect(screen.getByRole("button")).toBeDisabled();
  });
});
