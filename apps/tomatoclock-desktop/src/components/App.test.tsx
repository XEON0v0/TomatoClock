import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it } from "vitest";
import App from "../App";

describe("TomatoClock 前端流程", () => {
  beforeEach(() => localStorage.clear());

  it("主计时器可以开始和暂停", async () => {
    render(<App />);
    expect(await screen.findByText("25:00")).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: /开始/ }));
    expect(screen.getByRole("button", { name: /暂停/ })).toBeInTheDocument();
  });

  it("工作台可新建计划并切换任务完成状态", async () => {
    render(<App />);
    await userEvent.click(await screen.findByTitle("工作台"));
    await userEvent.click(screen.getByTitle("新建计划"));
    const titles = screen.getAllByDisplayValue("新的计划");
    expect(titles.length).toBeGreaterThan(0);
    await userEvent.click(screen.getAllByTitle("完成任务")[0]);
    expect(screen.getByTitle("标记未完成")).toBeInTheDocument();
  });
});
