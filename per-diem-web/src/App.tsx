import { useMemo, useState } from "react";
import { ExpenseRow } from "./components/ExpenseRow";
import { resolveRate } from "./services/rateResolver";
import { RetentionService, SessionStore } from "./services/storage";
import type { ExpenseRow as ExpenseRowType, RateResolution, StoredExpense } from "./types";
import { computeBudget } from "./utils/budget";
import { randomId, toAmount, toDateKey, toUsd } from "./utils/normalize";

const today = new Date();
const todayKey = toDateKey(today);
const todayLabel = today.toLocaleDateString(undefined, {
  weekday: "short",
  month: "short",
  day: "numeric",
  year: "numeric",
});

const defaultResolution: RateResolution = {
  mieRate: 0,
  state: "",
  matchType: "unresolved",
  message: "Enter a city to look up today's M&IE rate.",
};

const isEmptyRow = (row: ExpenseRowType) => !row.name.trim() && !row.amount.trim();

const toStoredExpenses = (rows: ExpenseRowType[]): StoredExpense[] =>
  rows
    .filter((row) => !isEmptyRow(row))
    .map((row) => ({ name: row.name.trim(), amount: toAmount(row.amount) }));

const hydrateRows = (expenses: StoredExpense[]): ExpenseRowType[] => {
  if (!expenses.length) return [{ id: randomId(), name: "", amount: "" }];
  return expenses.map((item) => ({
    id: randomId(),
    name: item.name,
    amount: item.amount.toString(),
  }));
};

function App() {
  const [existing] = useState(() => {
    RetentionService.prune();
    return SessionStore.getByDateKey(todayKey);
  });

  const [locationInput, setLocationInput] = useState(existing?.locationInput ?? "");
  const [stateInput, setStateInput] = useState(existing?.stateInput ?? "");
  const [resolution, setResolution] = useState<RateResolution>(existing?.resolution ?? defaultResolution);
  const [statusMessage, setStatusMessage] = useState(existing?.resolution.message ?? defaultResolution.message ?? "");
  const [rows, setRows] = useState<ExpenseRowType[]>(hydrateRows(existing?.expenses ?? []));
  const [busy, setBusy] = useState(false);

  const expenses = useMemo(() => toStoredExpenses(rows), [rows]);
  const budget = useMemo(() => computeBudget(resolution.mieRate, expenses), [resolution.mieRate, expenses]);

  const persist = (nextRows: ExpenseRowType[], nextResolution = resolution) => {
    SessionStore.save({
      dateKey: todayKey,
      locationInput,
      stateInput,
      resolution: nextResolution,
      expenses: toStoredExpenses(nextRows),
    });
  };

  const onResolve = async () => {
    setBusy(true);
    try {
      const result = await resolveRate(locationInput, stateInput, new Date());
      const message =
        result.matchType === "city_exact"
          ? `City match: ${result.city}, ${result.state}.`
          : result.matchType === "county_fallback"
            ? `City not listed. County fallback matched: ${result.county}, ${result.state}.`
            : result.message ?? "Using Standard CONUS M&IE.";
      const next = { ...result, message };
      setResolution(next);
      setStatusMessage(message);
      persist(rows, next);
    } catch {
      setStatusMessage("Lookup failed. Try city + state (example: Austin, TX).");
    } finally {
      setBusy(false);
    }
  };

  const onChangeRow = (id: string, next: ExpenseRowType) => {
    const updated = rows.map((row) => (row.id === id ? next : row));
    const empties = updated.filter(isEmptyRow);
    const normalized =
      empties.length <= 1
        ? updated
        : updated.filter((row, index) => !isEmptyRow(row) || index === updated.findIndex(isEmptyRow));
    setRows(normalized);
    persist(normalized);
  };

  const onRemoveRow = (id: string) => {
    const next = rows.filter((row) => row.id !== id);
    if (!next.length) {
      const reset = [{ id: randomId(), name: "", amount: "" }];
      setRows(reset);
      persist(reset);
      return;
    }
    setRows(next);
    persist(next);
  };

  const onAddAnother = () => {
    if (rows.some(isEmptyRow)) return;
    const next = [...rows, { id: randomId(), name: "", amount: "" }];
    setRows(next);
    persist(next);
  };

  const remainingGood = budget.remaining >= 0;

  return (
    <main className="app">
      <header className="hero">
        <h1 className="title">Per Diem Expense Tracker</h1>
        <p className="subtitle">{todayLabel}</p>
      </header>

      <section className="grid">
        <article className="card">
          <label className="label" htmlFor="city">
            Location (City)
          </label>
          <input
            id="city"
            className="input"
            placeholder="Chicago or Chicago, IL"
            value={locationInput}
            onChange={(e) => setLocationInput(e.target.value)}
          />

          <div className="state-row">
            <label className="label" htmlFor="state">
              State (optional)
            </label>
            <input
              id="state"
              className="input"
              placeholder="IL"
              maxLength={20}
              value={stateInput}
              onChange={(e) => setStateInput(e.target.value)}
            />
          </div>

          <button className="btn btn-primary" onClick={onResolve} type="button" disabled={busy}>
            {busy ? "Checking..." : "Find Today's Rate"}
          </button>
          <p className="status">{statusMessage}</p>
        </article>

        <article className="card">
          <div className="stat-label">Today M&IE</div>
          <div className="stat-strong">{toUsd(resolution.mieRate || 0)}</div>

          <div className="stat-label">Spent</div>
          <div className="stat-strong">{toUsd(budget.spent)}</div>

          <div className="stat-label">{remainingGood ? "Amount Left" : "Over Per Diem"}</div>
          <div className={`stat-strong ${remainingGood ? "good" : "bad"}`}>
            {toUsd(Math.abs(budget.remaining))}
          </div>
        </article>

        <article className="card full">
          <h2 className="section-title">Expenses</h2>
          {rows.map((row) => (
            <ExpenseRow
              key={row.id}
              row={row}
              removable={!isEmptyRow(row)}
              onChange={(next) => onChangeRow(row.id, next)}
              onRemove={() => onRemoveRow(row.id)}
            />
          ))}
          <button className="btn btn-secondary" type="button" onClick={onAddAnother}>
            + another expense
          </button>
        </article>
      </section>
    </main>
  );
}

export default App;
