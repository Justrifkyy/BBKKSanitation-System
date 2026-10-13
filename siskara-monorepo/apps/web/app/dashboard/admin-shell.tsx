'use client';

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { onAuthStateChanged, signOut, type User } from 'firebase/auth';
import { usePathname, useRouter } from 'next/navigation';
import { auth } from '@/lib/firebase';

type AdminContextValue = { user: User; name: string };
const AdminContext = createContext<AdminContextValue | null>(null);

const linkGroups = [
  {
    label: 'Menu utama',
    links: [
      { href: '/dashboard', label: 'Ringkasan', icon: 'overview' },
      { href: '/dashboard/submissions', label: 'Pengajuan', icon: 'submissions' },
    ],
  },
  {
    label: 'Administrasi',
    links: [
      { href: '/dashboard/users', label: 'Pengguna', icon: 'users' },
      { href: '/dashboard/checklists', label: 'Checklist', icon: 'checklist' },
      { href: '/dashboard/master-data', label: 'Data master', icon: 'master' },
      { href: '/dashboard/documents', label: 'Dokumen', icon: 'documents' },
      { href: '/dashboard/exports', label: 'Ekspor data', icon: 'exports' },
      { href: '/dashboard/audit-log', label: 'Log aktivitas', icon: 'activity' },
    ],
  },
] as const;

type SidebarIconName =
  | 'overview'
  | 'submissions'
  | 'users'
  | 'checklist'
  | 'master'
  | 'documents'
  | 'exports'
  | 'activity'
  | 'logout';

function SidebarIcon({ name }: { name: SidebarIconName }) {
  const paths: Record<SidebarIconName, ReactNode> = {
    overview: <><rect x="3.5" y="3.5" width="7" height="7" rx="1.5" /><rect x="13.5" y="3.5" width="7" height="7" rx="1.5" /><rect x="3.5" y="13.5" width="7" height="7" rx="1.5" /><rect x="13.5" y="13.5" width="7" height="7" rx="1.5" /></>,
    submissions: <><path d="M7 3.5h7l4 4v13H7a2 2 0 0 1-2-2v-13a2 2 0 0 1 2-2Z" /><path d="M14 3.5v5h5M9 13h6M9 16.5h6" /></>,
    users: <><path d="M16 20v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 18.5V20" /><circle cx="10" cy="7.5" r="3.5" /><path d="M17 4.5a3.5 3.5 0 0 1 0 6.8M20 20v-1.5a3.5 3.5 0 0 0-2.5-3.35" /></>,
    checklist: <><path d="m4 6 1.5 1.5L8 5M11 6h9M4 12l1.5 1.5L8 11m3 1h9M4 18l1.5 1.5L8 17m3 1h9" /></>,
    master: <><ellipse cx="12" cy="5" rx="8" ry="3" /><path d="M4 5v14c0 1.7 3.6 3 8 3s8-1.3 8-3V5M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3" /></>,
    documents: <><path d="M7 3.5h7l4 4v13H7a2 2 0 0 1-2-2v-13a2 2 0 0 1 2-2Z" /><path d="M14 3.5v5h5M9 13h6M9 16.5h6" /></>,
    exports: <><path d="M12 3v12m0 0 4-4m-4 4-4-4" /><path d="M5 16v4h14v-4" /></>,
    activity: <><path d="M3 12a9 9 0 1 0 2.6-6.4L3 8" /><path d="M3 3v5h5m4-1v5l3 2" /></>,
    logout: <><path d="M10 17l5-5-5-5m5 5H3" /><path d="M12 3h6a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-6" /></>,
  };

  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {paths[name]}
    </svg>
  );
}

export function useAdmin() {
  const context = useContext(AdminContext);
  if (!context) throw new Error('useAdmin harus digunakan di dalam AdminShell.');
  return context;
}

export function AdminShell({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  const pathname = usePathname();
  const router = useRouter();
  const [context, setContext] = useState<AdminContextValue | null>(null);
  const [checking, setChecking] = useState(true);
  const [error, setError] = useState('');
  const [signingOut, setSigningOut] = useState(false);

  useEffect(() => onAuthStateChanged(auth, async (user) => {
    if (!user) {
      router.replace('/login');
      return;
    }
    try {
      const token = await user.getIdTokenResult();
      if (token.claims.role !== 'validator_admin') {
        await signOut(auth);
        router.replace('/login');
        return;
      }
      setContext({
        user,
        name: user.displayName?.trim() || user.email?.split('@')[0] || 'Admin',
      });
    } catch {
      setError('Sesi tidak dapat diverifikasi. Silakan masuk kembali.');
      await signOut(auth);
      router.replace('/login');
    } finally {
      setChecking(false);
    }
  }), [router]);

  const value = useMemo(() => context, [context]);

  async function handleSignOut() {
    setSigningOut(true);
    setError('');
    try {
      const response = await fetch('/api/auth/session', { method: 'DELETE' });
      if (!response.ok) throw new Error('Sesi server gagal diakhiri.');
      await signOut(auth);
      router.replace('/login');
      router.refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Gagal keluar dari akun.');
      setSigningOut(false);
    }
  }

  return (
    <main className="dashboard-shell">
      <aside className="dashboard-sidebar">
        <a className="sidebar-brand" href="/dashboard" aria-label="SISKARA Dashboard">
          <span className="brand-mark brand-mark--sidebar" aria-hidden="true">S</span>
          <span><strong>SISKARA</strong><small>BBKK Makassar</small></span>
        </a>
        <div className="sidebar-menu">
          {linkGroups.map((group) => (
            <section className="sidebar-menu-group" key={group.label}>
              <h2 className="sidebar-section-label">{group.label}</h2>
              <nav className="sidebar-nav admin-sidebar-nav" aria-label={group.label}>
                {group.links.map((link) => {
                  const active = link.href === '/dashboard'
                    ? pathname === link.href
                    : pathname === link.href || pathname.startsWith(`${link.href}/`);
                  return (
                    <a
                      className={`sidebar-link${active ? ' is-active' : ''}`}
                      href={link.href}
                      aria-current={active ? 'page' : undefined}
                      key={link.href}
                    >
                      <span className="admin-nav-icon"><SidebarIcon name={link.icon} /></span>
                      <span className="sidebar-link__label">{link.label}</span>
                    </a>
                  );
                })}
              </nav>
            </section>
          ))}
        </div>
        <div className="sidebar-bottom">
          {context && (
            <button className="sidebar-profile" type="button" onClick={handleSignOut} disabled={signingOut}>
              <span className="profile-avatar">{context.name[0]?.toUpperCase() || 'A'}</span>
              <span className="sidebar-profile__identity">
                <strong>{context.name}</strong><small>Administrator</small>
              </span>
              <span className="sidebar-profile__logout"><SidebarIcon name="logout" /><span>Keluar</span></span>
            </button>
          )}
        </div>
      </aside>
      <div className="dashboard-main">
        <header className="dashboard-topbar">
          <div className="breadcrumb"><span>Portal Admin</span><span aria-hidden="true">/</span><strong>{title}</strong></div>
          <span className="topbar-date">Portal administrasi internal</span>
        </header>
        <div className="dashboard-content admin-page-content">
          {error && <div className="dashboard-alert" role="alert">{error}</div>}
          {checking || !value
            ? <div className="admin-loading" role="status">Memverifikasi sesi Admin…</div>
            : <AdminContext.Provider value={value}>{children}</AdminContext.Provider>}
        </div>
      </div>
    </main>
  );
}
