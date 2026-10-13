"use client";

import type { User } from "firebase/auth";
import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { AdminShell, useAdmin } from "./admin-shell";
import { adminFetch } from "@/lib/admin-api";

type TransportMode = "kapal" | "pesawat";
type SubmissionStatus =
  | "draft"
  | "ditolak_otomatis"
  | "menunggu_verifikasi_staf"
  | "ditolak_staf"
  | "final";

interface Submission {
  id: string;
  moda_transportasi?: TransportMode;
  status?: SubmissionStatus;
  created_at?: string | number | Date | { seconds?: number; _seconds?: number };
  data_umum?: Record<string, unknown>;
}

type IconName =
  | "grid"
  | "file"
  | "users"
  | "checklist"
  | "database"
  | "history"
  | "search"
  | "bell"
  | "ship"
  | "plane"
  | "clock"
  | "check"
  | "refresh"
  | "download"
  | "chevron"
  | "logout"
  | "calendar";

function Icon({ name, size = 18 }: { name: IconName; size?: number }) {
  const paths: Record<IconName, ReactNode> = {
    grid: (
      <>
        <rect x="3" y="3" width="7" height="7" rx="1.5" />
        <rect x="14" y="3" width="7" height="7" rx="1.5" />
        <rect x="3" y="14" width="7" height="7" rx="1.5" />
        <rect x="14" y="14" width="7" height="7" rx="1.5" />
      </>
    ),
    file: (
      <>
        <path d="M13 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V10z" />
        <path d="M13 3v7h7M8 14h8M8 18h8" />
      </>
    ),
    users: (
      <>
        <path d="M16 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
        <circle cx="10" cy="7" r="4" />
        <path d="M20 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
      </>
    ),
    checklist: (
      <>
        <path d="M9 6h11M9 12h11M9 18h11" />
        <path d="m3 6 1.5 1.5L7 5m-4 7 1.5 1.5L7 11m-4 7 1.5 1.5L7 17" />
      </>
    ),
    database: (
      <>
        <ellipse cx="12" cy="5" rx="8" ry="3" />
        <path d="M4 5v14c0 1.66 3.58 3 8 3s8-1.34 8-3V5M4 12c0 1.66 3.58 3 8 3s8-1.34 8-3" />
      </>
    ),
    history: (
      <>
        <path d="M3 12a9 9 0 1 0 2.64-6.36L3 8" />
        <path d="M3 3v5h5m4-1v5l3 2" />
      </>
    ),
    search: (
      <>
        <circle cx="11" cy="11" r="7" />
        <path d="m20 20-4-4" />
      </>
    ),
    bell: (
      <>
        <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9m-8 12a2 2 0 0 0 4 0" />
      </>
    ),
    ship: (
      <>
        <path d="m3 17 2-7h14l2 7-9 4-9-4Z" />
        <path d="M8 10V5h8v5m-4-5V3M2 21c1.3-1 2.7-1 4 0s2.7 1 4 0 2.7-1 4 0 2.7 1 4 0 2.7-1 4 0" />
      </>
    ),
    plane: (
      <path d="m22 2-7 20-4-9-9-4 20-7ZM22 2 11 13" />
    ),
    clock: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3 2" />
      </>
    ),
    check: <path d="m5 12 4 4L19 6" />,
    refresh: (
      <>
        <path d="M20 7v5h-5M4 17v-5h5" />
        <path d="M5.6 9a7 7 0 0 1 11.55-2.6L20 12M4 12l2.85 5.6A7 7 0 0 0 18.4 15" />
      </>
    ),
    download: (
      <>
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4m4-5 5 5 5-5m-5 5V3" />
      </>
    ),
    chevron: <path d="m9 18 6-6-6-6" />,
    logout: (
      <>
        <path d="M10 17l5-5-5-5m5 5H3" />
        <path d="M12 3h6a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-6" />
      </>
    ),
    calendar: (
      <>
        <rect x="3" y="5" width="18" height="16" rx="2" />
        <path d="M16 3v4M8 3v4M3 11h18" />
      </>
    ),
  };

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name]}
    </svg>
  );
}

function getErrorMessage(value: unknown) {
  if (typeof value === "object" && value !== null && "error" in value) {
    const error = value.error;
    if (typeof error === "string") return error;
  }
  return "Tidak dapat memuat data pengajuan.";
}

function readDate(value: Submission["created_at"]): Date | null {
  if (value instanceof Date) return value;
  if (typeof value === "string" || typeof value === "number") {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }
  if (value && typeof value === "object") {
    const seconds = value.seconds ?? value._seconds;
    if (typeof seconds === "number") return new Date(seconds * 1000);
  }
  return null;
}

function formatDate(value: Submission["created_at"]) {
  const date = readDate(value);
  if (!date) return "—";
  return new Intl.DateTimeFormat("id-ID", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function recordName(submission: Submission) {
  const data = submission.data_umum ?? {};
  const name =
    submission.moda_transportasi === "kapal"
      ? data.nama_kapal
      : data.nomor_penerbangan;
  return typeof name === "string" && name.trim() ? name : "Data belum tersedia";
}

function recordDetail(submission: Submission) {
  const data = submission.data_umum ?? {};
  const detail =
    submission.moda_transportasi === "kapal"
      ? data.pelabuhan_asal
      : data.berangkat_dari;
  return typeof detail === "string" && detail.trim() ? detail : "—";
}

function statusLabel(status?: SubmissionStatus) {
  switch (status) {
    case "menunggu_verifikasi_staf":
      return "Menunggu verifikasi";
    case "ditolak_otomatis":
      return "Ditolak otomatis";
    case "ditolak_staf":
      return "Ditolak staf";
    case "final":
      return "Selesai";
    case "draft":
      return "Draft";
    default:
      return "Status tidak diketahui";
  }
}

function SubmissionStatusBadge({ status }: { status?: SubmissionStatus }) {
  const style =
    status === "final"
      ? "status-badge--success"
      : status === "menunggu_verifikasi_staf"
        ? "status-badge--pending"
        : status === "ditolak_otomatis" || status === "ditolak_staf"
          ? "status-badge--rejected"
          : "status-badge--draft";

  return <span className={`status-badge ${style}`}>{statusLabel(status)}</span>;
}

function TrendChart({
  submissions,
  today,
}: {
  submissions: Submission[];
  today: Date | null;
}) {
  const data = useMemo(() => {
    if (!today) return [];
    const chartDate = new Date(today);
    chartDate.setHours(0, 0, 0, 0);
    return Array.from({ length: 7 }, (_, index) => {
      const day = new Date(chartDate);
      day.setDate(chartDate.getDate() - (6 - index));
      const count = submissions.filter((submission) => {
        const created = readDate(submission.created_at);
        return created?.toDateString() === day.toDateString();
      }).length;
      return {
        label: new Intl.DateTimeFormat("id-ID", { weekday: "short" })
          .format(day)
          .replace(".", ""),
        count,
        isToday: index === 6,
      };
    });
  }, [submissions, today]);

  const maxValue = Math.max(...data.map((day) => day.count), 4);

  return (
    <div className="trend-chart" aria-label="Grafik jumlah pengajuan tujuh hari terakhir">
      {data.map((day) => (
        <div className="trend-chart__day" key={day.label}>
          <div className="trend-chart__bar-wrap">
            <span className="trend-chart__count">{day.count || ""}</span>
            <span
              className={`trend-chart__bar${day.isToday ? " trend-chart__bar--today" : ""}`}
              style={{ height: `${Math.max((day.count / maxValue) * 100, 5)}%` }}
              title={`${day.count} pengajuan`}
            />
          </div>
          <span className={day.isToday ? "trend-chart__label is-today" : "trend-chart__label"}>
            {day.label}
          </span>
        </div>
      ))}
    </div>
  );
}

async function fetchSubmissions(user: User): Promise<Submission[]> {
  const result = await adminFetch<{ submissions?: unknown }>(user, "/api/submissions");
  if (!Array.isArray(result.submissions)) {
    throw new Error("Respons daftar pengajuan tidak memiliki format yang benar.");
  }
  return result.submissions as Submission[];
}

function DashboardContent() {
  const { user, name: adminName } = useAdmin();
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [today, setToday] = useState<Date | null>(null);
  const [pageError, setPageError] = useState("");
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("semua");
  const [modeFilter, setModeFilter] = useState("semua");
  const [periodFilter, setPeriodFilter] = useState("30");
  const [selectedSubmission, setSelectedSubmission] = useState<Submission | null>(null);

  const loadSubmissions = useCallback(async (user: User) => {
    const token = await user.getIdToken();
    const response = await fetch("/api/submissions", {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    const result = (await response.json()) as { submissions?: unknown; error?: unknown };

    if (!response.ok) throw new Error(getErrorMessage(result));
    if (!Array.isArray(result.submissions)) {
      throw new Error("Respons daftar pengajuan tidak memiliki format yang benar.");
    }

    setSubmissions(result.submissions as Submission[]);
    setToday(new Date());
    setPageError("");
  }, []);

  useEffect(() => {
    let active = true;
    void fetchSubmissions(user)
      .then((items) => {
        if (!active) return;
        setSubmissions(items);
        setToday(new Date());
        setPageError("");
      })
      .catch((error: unknown) => {
        if (active) {
          setPageError(
            error instanceof Error ? error.message : "Terjadi kesalahan saat memuat dashboard.",
          );
        }
      })
      .finally(() => {
        if (active) setIsLoading(false);
      });
    return () => {
      active = false;
    };
  }, [user]);

  const visibleSubmissions = useMemo(() => {
    const query = search.trim().toLocaleLowerCase("id-ID");
    const cutoff = today ? new Date(today) : null;
    if (periodFilter !== "semua" && cutoff) {
      cutoff.setDate(cutoff.getDate() - Number(periodFilter));
      cutoff.setHours(0, 0, 0, 0);
    }

    return submissions.filter((submission) => {
      const created = readDate(submission.created_at);
      const matchesPeriod =
        periodFilter === "semua" ||
        (created !== null && cutoff !== null && created >= cutoff);
      const matchesMode =
        modeFilter === "semua" || submission.moda_transportasi === modeFilter;
      const matchesStatus =
        statusFilter === "semua" || submission.status === statusFilter;
      const matchesSearch =
        !query ||
        [
          recordName(submission),
          recordDetail(submission),
          submission.id,
          submission.moda_transportasi,
        ]
          .filter(Boolean)
          .some((value) => String(value).toLocaleLowerCase("id-ID").includes(query));

      return matchesPeriod && matchesMode && matchesStatus && matchesSearch;
    });
  }, [modeFilter, periodFilter, search, statusFilter, submissions, today]);

  const pendingCount = submissions.filter(
    (submission) => submission.status === "menunggu_verifikasi_staf",
  ).length;
  const completedCount = submissions.filter(
    (submission) => submission.status === "final",
  ).length;
  const rejectedCount = submissions.filter(
    (submission) =>
      submission.status === "ditolak_otomatis" ||
      submission.status === "ditolak_staf",
  ).length;
  const recentCount = submissions.filter((submission) => {
    const created = readDate(submission.created_at);
    return (
      today !== null &&
      created !== null &&
      today.getTime() - created.getTime() <= 7 * 24 * 60 * 60 * 1000
    );
  }).length;

  async function handleRefresh() {
    setIsRefreshing(true);
    try {
      await loadSubmissions(user);
    } catch (error) {
      setPageError(
        error instanceof Error ? error.message : "Tidak dapat memperbarui daftar pengajuan.",
      );
    } finally {
      setIsRefreshing(false);
    }
  }

  function handleExport() {
    const escapeCsv = (value: string) => `"${value.replaceAll('"', '""')}"`;
    const rows = [
      ["ID", "Moda transportasi", "Identitas", "Asal", "Tanggal masuk", "Status"],
      ...visibleSubmissions.map((submission) => [
        submission.id,
        submission.moda_transportasi === "kapal"
          ? "Kapal"
          : submission.moda_transportasi === "pesawat"
            ? "Pesawat"
            : "",
        recordName(submission),
        recordDetail(submission),
        formatDate(submission.created_at),
        statusLabel(submission.status),
      ]),
    ];
    const csv = `\uFEFF${rows.map((row) => row.map(escapeCsv).join(",")).join("\r\n")}`;
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
    const link = document.createElement("a");
    link.href = url;
    link.download = `siskara-pengajuan-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  }

  const greetingName = adminName.split(/\s+/)[0];

  return (
    <>
      <div className="dashboard-overview" id="ringkasan">
          <section className="welcome-row">
            <div>
              <span className="eyebrow">DASHBOARD ADMINISTRATOR</span>
              <h1>Selamat datang, {greetingName} <span aria-hidden="true">✦</span></h1>
              <p>Pantau pemeriksaan sanitasi dan aktivitas operasional hari ini.</p>
            </div>
            <div className="welcome-actions">
              <button
                className="button button--secondary"
                type="button"
                onClick={handleRefresh}
                disabled={isRefreshing || isLoading}
              >
                <Icon name="refresh" size={16} />
                {isRefreshing ? "Memuat..." : "Perbarui"}
              </button>
            </div>
          </section>

          {pageError && (
            <div className="dashboard-alert" role="alert">
              <span>{pageError}</span>
              <button type="button" onClick={handleRefresh}>Coba lagi</button>
            </div>
          )}

          <section className="metric-grid" aria-label="Statistik pengajuan">
            <article className="metric-card">
              <div className="metric-card__top">
                <span className="metric-card__label">Total pengajuan</span>
                <span className="metric-icon metric-icon--blue"><Icon name="file" /></span>
              </div>
              <strong className="metric-card__value">{isLoading ? "—" : submissions.length}</strong>
              <span className="metric-card__note">
                <span className="metric-note--blue">{recentCount} pengajuan</span> dalam 7 hari terakhir
              </span>
            </article>
            <article className="metric-card">
              <div className="metric-card__top">
                <span className="metric-card__label">Menunggu verifikasi</span>
                <span className="metric-icon metric-icon--amber"><Icon name="clock" /></span>
              </div>
              <strong className="metric-card__value">{isLoading ? "—" : pendingCount}</strong>
              <span className="metric-card__note">Perlu ditindaklanjuti petugas verifikator</span>
            </article>
            <article className="metric-card">
              <div className="metric-card__top">
                <span className="metric-card__label">Dokumen selesai</span>
                <span className="metric-icon metric-icon--green"><Icon name="check" /></span>
              </div>
              <strong className="metric-card__value">{isLoading ? "—" : completedCount}</strong>
              <span className="metric-card__note">PHQC kapal dan berkas verifikasi pesawat</span>
            </article>
            <article className="metric-card">
              <div className="metric-card__top">
                <span className="metric-card__label">Temuan / penolakan</span>
                <span className="metric-icon metric-icon--rose"><Icon name="history" /></span>
              </div>
              <strong className="metric-card__value">{isLoading ? "—" : rejectedCount}</strong>
              <span className="metric-card__note">Pengajuan ditolak otomatis atau oleh staf</span>
            </article>
          </section>

          <section className="insights-grid">
            <article className="panel trend-panel">
              <div className="panel-heading">
                <div>
                  <h2>Aktivitas pengajuan</h2>
                  <p>Pengajuan masuk dalam 7 hari terakhir</p>
                </div>
                <span className="chart-legend"><i /> Pengajuan</span>
              </div>
              {isLoading ? (
                <div className="chart-loading">Memuat aktivitas...</div>
              ) : (
                <TrendChart submissions={submissions} today={today} />
              )}
            </article>

            <article className="panel transport-panel">
              <div className="panel-heading">
                <div>
                  <h2>Moda transportasi</h2>
                  <p>Distribusi pengajuan terkini</p>
                </div>
              </div>
              <div className="transport-summary">
                <div className="transport-summary__item">
                  <span className="transport-icon transport-icon--ship"><Icon name="ship" size={19} /></span>
                  <span><strong>Kapal</strong><small>PHQC</small></span>
                  <b>{submissions.filter((item) => item.moda_transportasi === "kapal").length}</b>
                </div>
                <div className="transport-summary__item">
                  <span className="transport-icon transport-icon--plane"><Icon name="plane" size={19} /></span>
                  <span><strong>Pesawat</strong><small>Berkas verifikasi</small></span>
                  <b>{submissions.filter((item) => item.moda_transportasi === "pesawat").length}</b>
                </div>
              </div>
              <div className="transport-note">
                <span className="live-indicator" /> Data dari 50 pengajuan terbaru
              </div>
            </article>
          </section>

          <section className="panel submissions-panel" id="pengajuan">
            <div className="submissions-heading">
              <div>
                <div className="panel-title-row">
                  <h2>Pengajuan terbaru</h2>
                  <span className="table-count">{visibleSubmissions.length}</span>
                </div>
                <p>Pantau status deklarasi sanitasi kapal dan pesawat.</p>
              </div>
              <button className="button button--secondary button--export" type="button" onClick={handleExport}>
                <Icon name="download" size={16} />
                Ekspor data
              </button>
            </div>

            <div className="table-toolbar">
              <label className="table-search">
                <Icon name="search" size={17} />
                <input
                  type="search"
                  placeholder="Cari nama kapal, nomor penerbangan..."
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  aria-label="Cari pengajuan"
                />
              </label>
              <div className="table-filters">
                <label className="filter-select">
                  <span className="sr-only">Rentang waktu</span>
                  <select value={periodFilter} onChange={(event) => setPeriodFilter(event.target.value)}>
                    <option value="7">7 hari terakhir</option>
                    <option value="30">30 hari terakhir</option>
                    <option value="90">90 hari terakhir</option>
                    <option value="semua">Semua waktu</option>
                  </select>
                </label>
                <label className="filter-select">
                  <span className="sr-only">Moda transportasi</span>
                  <select value={modeFilter} onChange={(event) => setModeFilter(event.target.value)}>
                    <option value="semua">Semua moda</option>
                    <option value="kapal">Kapal</option>
                    <option value="pesawat">Pesawat</option>
                  </select>
                </label>
                <label className="filter-select">
                  <span className="sr-only">Status pengajuan</span>
                  <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
                    <option value="semua">Semua status</option>
                    <option value="menunggu_verifikasi_staf">Menunggu verifikasi</option>
                    <option value="final">Selesai</option>
                    <option value="ditolak_otomatis">Ditolak otomatis</option>
                    <option value="ditolak_staf">Ditolak staf</option>
                    <option value="draft">Draft</option>
                  </select>
                </label>
              </div>
            </div>

            <div className="table-scroll">
              <table className="submissions-table">
                <thead>
                  <tr>
                    <th>IDENTITAS</th>
                    <th>MODA</th>
                    <th>ASAL</th>
                    <th>TANGGAL MASUK</th>
                    <th>STATUS</th>
                    <th><span className="sr-only">Detail</span></th>
                  </tr>
                </thead>
                <tbody>
                  {isLoading ? (
                    <tr><td className="table-message" colSpan={6}>Memuat daftar pengajuan...</td></tr>
                  ) : visibleSubmissions.length ? (
                    visibleSubmissions.map((submission) => (
                      <tr key={submission.id}>
                        <td>
                          <span className={`transport-row-icon ${submission.moda_transportasi === "kapal" ? "transport-row-icon--ship" : "transport-row-icon--plane"}`}>
                            <Icon name={submission.moda_transportasi === "kapal" ? "ship" : "plane"} size={16} />
                          </span>
                          <span className="record-identity">
                            <strong>{recordName(submission)}</strong>
                            <small>#{submission.id.slice(0, 8).toUpperCase()}</small>
                          </span>
                        </td>
                        <td>{submission.moda_transportasi === "kapal" ? "Kapal" : submission.moda_transportasi === "pesawat" ? "Pesawat" : "—"}</td>
                        <td>{recordDetail(submission)}</td>
                        <td>{formatDate(submission.created_at)}</td>
                        <td><SubmissionStatusBadge status={submission.status} /></td>
                        <td><button className="row-action" type="button" aria-label={`Detail ${recordName(submission)}`} onClick={() => setSelectedSubmission(submission)}><Icon name="chevron" size={17} /></button></td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td className="table-message" colSpan={6}>
                        Tidak ada pengajuan yang sesuai dengan filter.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
            <div className="table-footnote">
              Menampilkan hingga 50 pengajuan terbaru. Keputusan verifikasi dan persetujuan dilakukan oleh staf BBKK.
            </div>
          </section>

          <section className="admin-scope-note" id="administrasi">
            <span className="admin-scope-note__icon"><Icon name="bell" size={17} /></span>
            <p>
              Dashboard Admin bersifat <strong>read-only</strong> untuk keputusan verifikasi.
              Persetujuan atau penolakan pengajuan hanya dapat dilakukan oleh staf BBKK.
            </p>
          </section>
          <footer className="dashboard-footer">
            <span>© {today?.getFullYear() ?? ""} BBKK Makassar · SISKARA</span>
            <span>Portal administrasi internal</span>
          </footer>
        </div>
      {selectedSubmission && (
        <div
          className="detail-backdrop"
          onClick={(event) => {
            if (event.target === event.currentTarget) setSelectedSubmission(null);
          }}
        >
          <section
            className="detail-dialog"
            role="dialog"
            aria-modal="true"
            aria-labelledby="submission-detail-title"
          >
            <div className="detail-dialog__heading">
              <div>
                <span className="eyebrow">RINGKASAN PENGAJUAN</span>
                <h2 id="submission-detail-title">{recordName(selectedSubmission)}</h2>
                <p>#{selectedSubmission.id}</p>
              </div>
              <button
                className="detail-dialog__close"
                type="button"
                onClick={() => setSelectedSubmission(null)}
                aria-label="Tutup detail pengajuan"
              >
                ×
              </button>
            </div>
            <div className="detail-dialog__status">
              <SubmissionStatusBadge status={selectedSubmission.status} />
              <span>{formatDate(selectedSubmission.created_at)}</span>
            </div>
            <dl className="detail-list">
              <div>
                <dt>Moda transportasi</dt>
                <dd>{selectedSubmission.moda_transportasi === "kapal" ? "Kapal" : "Pesawat"}</dd>
              </div>
              <div>
                <dt>Asal perjalanan</dt>
                <dd>{recordDetail(selectedSubmission)}</dd>
              </div>
              {Object.entries(selectedSubmission.data_umum ?? {}).map(([key, value]) => (
                <div key={key}>
                  <dt>{key.replaceAll("_", " ")}</dt>
                  <dd>{typeof value === "string" || typeof value === "number" ? String(value) : "—"}</dd>
                </div>
              ))}
            </dl>
            <p className="detail-dialog__note">
              Dashboard Admin hanya menampilkan informasi. Keputusan akhir pengajuan berada pada staf BBKK.
            </p>
          </section>
        </div>
      )}
    </>
  );
}

export default function DashboardPage() {
  return (
    <AdminShell title="Ringkasan">
      <DashboardContent />
    </AdminShell>
  );
}
