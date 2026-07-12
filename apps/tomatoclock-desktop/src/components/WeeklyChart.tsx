import type { WeeklyDayData } from "../domain/sessions";

interface WeeklyChartProps {
  data: WeeklyDayData[];
}

export function WeeklyChart({ data }: WeeklyChartProps) {
  const maxValue = Math.max(1, ...data.map((day) => Math.max(day.count, day.goal)));
  return (
    <div className="weekly-chart" aria-label="七日统计">
      {data.map((day) => {
        const height = Math.max(6, (day.count / maxValue) * 112);
        const goalHeight = Math.max(6, (day.goal / maxValue) * 112);
        return (
          <div className="chart-day" key={day.date}>
            <div className="chart-bar-frame">
              <span className="goal-marker" style={{ bottom: goalHeight }} />
              <span className={day.isToday ? "chart-bar today" : "chart-bar"} style={{ height }} />
            </div>
            <strong>{day.count}</strong>
            <span>{day.label}</span>
          </div>
        );
      })}
    </div>
  );
}
