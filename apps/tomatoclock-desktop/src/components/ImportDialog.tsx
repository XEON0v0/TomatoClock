import { useState } from "react";
import { Clipboard, RefreshCw, Upload } from "lucide-react";
import { parsePlanImportPayload, summarizePlanImport } from "../domain/planImport";
import type { PlanImportSessionController } from "../domain/types";
import {
  cancelImportSession,
  copyText,
  markImportCommitted,
  refreshImportSession,
  stageFallbackPayload,
} from "../platform/desktop";

interface ImportDialogProps {
  session: PlanImportSessionController;
  onSessionChange: (session: PlanImportSessionController | null) => void;
  onClose: () => void;
  onCommit: (session: PlanImportSessionController) => Promise<void>;
}

export function ImportDialog({ session, onSessionChange, onClose, onCommit }: ImportDialogProps) {
  const [jsonText, setJsonText] = useState("");
  const [message, setMessage] = useState<string | null>(null);
  const summary = session.document.stagedPlan ? summarizePlanImport(session.document.stagedPlan) : null;

  const refresh = async () => {
    try {
      const next = await refreshImportSession(session);
      onSessionChange(next);
      setMessage("已刷新导入状态。");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : String(error));
    }
  };

  const pasteJson = async () => {
    try {
      const payload = parsePlanImportPayload(jsonText);
      const next = await stageFallbackPayload(session, payload);
      onSessionChange(next);
      setMessage("计划已暂存。");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : String(error));
    }
  };

  const commit = async () => {
    await onCommit(session);
    await markImportCommitted(session);
  };

  const cancel = async () => {
    const next = await cancelImportSession(session);
    onSessionChange(next);
    onClose();
  };

  return (
    <div className="modal-backdrop" role="presentation">
      <section className="modal import-modal" role="dialog" aria-modal="true" aria-label="MCP 导入计划">
        <div className="modal-heading">
          <h2>MCP 导入计划</h2>
          <button className="text-mini" type="button" onClick={onClose}>
            关闭
          </button>
        </div>

        <div className="session-status">
          <span>状态</span>
          <strong>{session.document.state}</strong>
        </div>

        <pre className="config-snippet">{session.configurationSnippet}</pre>
        <div className="plan-actions">
          <button className="text-button" type="button" onClick={() => copyText(session.configurationSnippet)}>
            <Clipboard size={16} />
            <span>复制配置</span>
          </button>
          <button className="text-button" type="button" onClick={refresh}>
            <RefreshCw size={16} />
            <span>刷新</span>
          </button>
        </div>

        {summary ? (
          <div className="import-summary">
            <h3>{summary.title}</h3>
            <p>
              {summary.sectionCount} 个分区，{summary.itemCount} 项任务
            </p>
            <ul>
              {summary.previewItems.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </div>
        ) : (
          <div className="json-import">
            <textarea
              value={jsonText}
              onChange={(event) => setJsonText(event.target.value)}
              placeholder="也可以直接粘贴 schemaVersion: 1 的计划 JSON"
              aria-label="计划 JSON"
            />
            <button className="text-button" type="button" onClick={pasteJson}>
              <Upload size={16} />
              <span>暂存 JSON</span>
            </button>
          </div>
        )}

        {message ? <p className="dialog-message">{message}</p> : null}

        <div className="modal-actions">
          <button className="control-button" type="button" onClick={cancel}>
            取消
          </button>
          <button className="control-button primary" type="button" disabled={!session.document.stagedPlan} onClick={commit}>
            导入
          </button>
        </div>
      </section>
    </div>
  );
}
