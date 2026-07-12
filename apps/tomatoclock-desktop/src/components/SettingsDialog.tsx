import type { AppSettings } from "../domain/types";

interface SettingsDialogProps {
  open: boolean;
  settings: AppSettings;
  onClose: () => void;
  onChange: (patch: Partial<AppSettings>) => void;
}

export function SettingsDialog({ open, settings, onClose, onChange }: SettingsDialogProps) {
  if (!open) return null;

  return (
    <div className="modal-backdrop" role="presentation">
      <section className="modal" role="dialog" aria-modal="true" aria-label="设置">
        <div className="modal-heading">
          <h2>设置</h2>
          <button className="text-mini" type="button" onClick={onClose}>
            关闭
          </button>
        </div>
        <label className="setting-row">
          <span>
            <strong>每日目标</strong>
            <small>用于七日统计目标线</small>
          </span>
          <input
            type="number"
            min={1}
            max={24}
            value={settings.dailyGoal}
            onChange={(event) => onChange({ dailyGoal: Number(event.target.value) || 1 })}
          />
        </label>
        <ToggleRow
          title="自动衔接下一阶段"
          detail="阶段结束后自动开始休息或下一轮专注"
          checked={settings.autoContinue}
          onChange={(autoContinue) => onChange({ autoContinue })}
        />
        <ToggleRow
          title="阶段音效"
          detail="切换阶段时播放轻提示音"
          checked={settings.soundEnabled}
          onChange={(soundEnabled) => onChange({ soundEnabled })}
        />
        <ToggleRow
          title="桌面通知"
          detail="阶段切换时发送系统通知"
          checked={settings.notificationsEnabled}
          onChange={(notificationsEnabled) => onChange({ notificationsEnabled })}
        />
      </section>
    </div>
  );
}

function ToggleRow({
  title,
  detail,
  checked,
  onChange,
}: {
  title: string;
  detail: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label className="setting-row">
      <span>
        <strong>{title}</strong>
        <small>{detail}</small>
      </span>
      <input type="checkbox" checked={checked} onChange={(event) => onChange(event.target.checked)} />
    </label>
  );
}
