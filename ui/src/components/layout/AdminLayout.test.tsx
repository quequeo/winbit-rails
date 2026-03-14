import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Routes, Route } from "react-router-dom";
import { AdminLayout } from "./AdminLayout";
import { api } from "../../lib/api";

vi.mock("../../lib/api", () => ({
  api: {
    getAdminSession: vi.fn(),
    signOut: vi.fn(),
  },
}));

const allRoutes = (
  <>
    <Route path="dashboard" element={<div>Dashboard content</div>} />
    <Route path="investors" element={<div>Investors content</div>} />
    <Route path="requests" element={<div>Requests content</div>} />
    <Route path="operativa" element={<div>Operativa content</div>} />
    <Route path="trading-fees" element={<div>Trading fees content</div>} />
    <Route path="admins" element={<div>Admins content</div>} />
    <Route path="activity" element={<div>Activity content</div>} />
  </>
);

const renderWithRouter = (initialPath = "/dashboard") =>
  render(
    <MemoryRouter initialEntries={[initialPath]}>
      <Routes>
        <Route path="/login" element={<div>Login page</div>} />
        <Route path="/" element={<AdminLayout />}>
          {allRoutes}
        </Route>
      </Routes>
    </MemoryRouter>,
  );

describe("AdminLayout", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("shows loading while checking session", () => {
    vi.mocked(api.getAdminSession).mockImplementation(
      () => new Promise(() => {}),
    );

    renderWithRouter();

    expect(screen.getByText("Cargando...")).toBeInTheDocument();
  });

  it("shows session email and nav when authenticated", async () => {
    vi.mocked(api.getAdminSession).mockResolvedValue({
      data: { email: "admin@test.com", superadmin: false },
    } as never);

    renderWithRouter();

    await waitFor(() =>
      expect(screen.getByText("admin@test.com")).toBeInTheDocument(),
    );
    expect(screen.getByText("Winbit Admin v1.0.0")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Dashboard" })).toBeInTheDocument();
    expect(
      screen.getByRole("link", { name: "Inversores" }),
    ).toBeInTheDocument();
    expect(screen.getByText("Dashboard content")).toBeInTheDocument();
  });

  it("navigates to login on Unauthorized", async () => {
    vi.mocked(api.getAdminSession).mockRejectedValue(new Error("Unauthorized"));

    render(
      <MemoryRouter initialEntries={["/dashboard"]}>
        <Routes>
          <Route path="/login" element={<div>Login page</div>} />
          <Route path="/" element={<AdminLayout />}>
            <Route path="dashboard" element={<div>Dashboard</div>} />
          </Route>
        </Routes>
      </MemoryRouter>,
    );

    await waitFor(() =>
      expect(screen.getByText("Login page")).toBeInTheDocument(),
    );
  });

  it("shows error on other session errors", async () => {
    vi.mocked(api.getAdminSession).mockRejectedValue(
      new Error("Network error"),
    );

    renderWithRouter();

    await waitFor(() =>
      expect(screen.getByText("Network error")).toBeInTheDocument(),
    );
  });

  it("calls signOut and navigates on logout", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getAdminSession).mockResolvedValue({
      data: { email: "admin@test.com", superadmin: false },
    } as never);
    vi.mocked(api.signOut).mockResolvedValue(null as never);

    renderWithRouter();

    await waitFor(() =>
      expect(screen.getByText("admin@test.com")).toBeInTheDocument(),
    );

    await user.click(screen.getByRole("button", { name: "Cerrar sesión" }));

    await waitFor(() => expect(api.signOut).toHaveBeenCalled());
    await waitFor(() =>
      expect(screen.getByText("Login page")).toBeInTheDocument(),
    );
  });

  it("opens mobile menu and shows nav links", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getAdminSession).mockResolvedValue({
      data: { email: "admin@test.com", superadmin: false },
    } as never);

    renderWithRouter();

    await waitFor(() =>
      expect(screen.getByText("admin@test.com")).toBeInTheDocument(),
    );

    const dashboardLinksBefore = screen.getAllByRole("link", {
      name: "Dashboard",
    });
    const hamburger = screen.getByRole("button", { name: "Abrir menú" });
    await user.click(hamburger);

    const dashboardLinksAfter = screen.getAllByRole("link", {
      name: "Dashboard",
    });
    expect(dashboardLinksAfter.length).toBeGreaterThan(
      dashboardLinksBefore.length,
    );
  });

  it("closes mobile menu when nav link is clicked", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getAdminSession).mockResolvedValue({
      data: { email: "admin@test.com", superadmin: false },
    } as never);

    renderWithRouter("/dashboard");

    await waitFor(() =>
      expect(screen.getByText("admin@test.com")).toBeInTheDocument(),
    );

    await user.click(screen.getByRole("button", { name: "Abrir menú" }));
    const investorsLinks = screen.getAllByRole("link", { name: "Inversores" });
    await user.click(investorsLinks[investorsLinks.length - 1]);

    await waitFor(() =>
      expect(screen.getByText("Investors content")).toBeInTheDocument(),
    );
  });

  it("shows active link styling in mobile menu when on matching route", async () => {
    const user = userEvent.setup();
    vi.mocked(api.getAdminSession).mockResolvedValue({
      data: { email: "admin@test.com", superadmin: false },
    } as never);

    renderWithRouter("/investors");

    await waitFor(() =>
      expect(screen.getByText("admin@test.com")).toBeInTheDocument(),
    );

    await user.click(screen.getByRole("button", { name: "Abrir menú" }));
    const mobileNav = document.querySelector('nav[class*="md:hidden"]');
    const mobileInvestorsLink = mobileNav?.querySelector(
      'a[href="/investors"]',
    );
    expect(mobileInvestorsLink).toBeInTheDocument();
    expect(mobileInvestorsLink).toHaveClass("bg-[#58b098]/10");
  });
});
