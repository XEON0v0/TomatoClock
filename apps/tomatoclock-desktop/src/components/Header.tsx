import { Settings, Timer, Columns3 } from "lucide-react";

interface HeaderProps {
  viewMode: "main" | "workbench";
  loadError: string | null;
  onViewModeChange: (mode: "main" | "workbench") => void;
  onOpenSettings: () => void;
}

export function Header({ viewMode, loadError, onViewModeChange, onOpenSettings }: HeaderProps) {
  return (
    <header className="topbar">
      <button className="brand-button" type="button" onClick={() => onViewModeChange("main")}>
        <span className="brand-mark">T</span>
        <span>TomatoClock</span>
      </button>
      {loadError ? <span className="sync-warning">{loadError}</span> : null}
      <nav className="segmented" aria-label="视图">
        <button
          className={viewMode === "main" ? "active" : ""}
          type="button"
          onClick={() => onViewModeChange("main")}
          title="主计时器"
        >
          <Timer size={17} />
        </button>
        <button
          className={viewMode === "workbench" ? "active" : ""}
          type="button"
          onClick={() => onViewModeChange("workbench")}
          title="工作台"
        >
          <Columns3 size={17} />
        </button>
      </nav>
      <button className="icon-button" type="button" onClick={onOpenSettings} title="设置">
        <Settings size={17} />
      </button>
    </header>
  );
}
