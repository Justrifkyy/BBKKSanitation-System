"use client";

import Image from "next/image";
import { FormEvent, useState } from "react";
import { signInWithEmailAndPassword, signOut } from "firebase/auth";
import { useRouter } from "next/navigation";
import { auth } from "@/lib/firebase";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrorMessage("");
    setIsLoading(true);

    try {
      const credential = await signInWithEmailAndPassword(auth, email.trim(), password);
      const tokenResult = await credential.user.getIdTokenResult(true);

      if (tokenResult.claims.role !== "validator_admin") {
        await signOut(auth);
        setErrorMessage(
          "Akun ini tidak memiliki akses Administrator ARJUNA. Akun Nahkoda, Pilot, atau Staf Verifikator harus menggunakan aplikasi mobile ARJUNA.",
        );
        return;
      }

      const response = await fetch("/api/auth/session", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${tokenResult.token}`,
        },
      });
      const result = (await response.json()) as { error?: string };

      if (!response.ok) {
        await signOut(auth);
        throw new Error(result.error ?? "Sesi login gagal dibuat.");
      }

      router.replace("/dashboard");
      router.refresh();
    } catch (error) {
      const msg = error instanceof Error ? error.message : "";
      if (
        msg.includes("auth/invalid-credential") ||
        msg.includes("auth/user-not-found") ||
        msg.includes("auth/wrong-password")
      ) {
        setErrorMessage("Email atau kata sandi tidak sesuai.");
      } else if (msg.includes("auth/too-many-requests")) {
        setErrorMessage(
          "Terlalu banyak percobaan masuk yang gagal. Silakan tunggu beberapa saat lagi.",
        );
      } else if (error instanceof Error) {
        setErrorMessage(error.message);
      } else {
        setErrorMessage("Terjadi kesalahan saat masuk. Silakan coba lagi.");
      }
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <main className="arjuna-login">
      {/* Decorative ambient glowing orbs */}
      <div className="arjuna-ambient arjuna-ambient--1" aria-hidden="true" />
      <div className="arjuna-ambient arjuna-ambient--2" aria-hidden="true" />
      <div className="arjuna-ambient arjuna-ambient--3" aria-hidden="true" />

      {/* Subtle modern geometric grid overlay */}
      <div className="arjuna-grid-pattern" aria-hidden="true" />

      <div className="arjuna-login__container">
        {/* ─── Kolom Kiri: Hero & Identitas Resmi BBKK ─── */}
        <section className="arjuna-hero" aria-label="Informasi Sistem ARJUNA">
          <header className="arjuna-hero__brand">
            <div className="arjuna-hero__logos">
              <Image
                src="/LOGOBBKK.png"
                alt="Logo Balai Besar Kekarantinaan Kesehatan Makassar"
                width={44}
                height={50}
                priority
                className="arjuna-logo-bbkk"
              />
              <div className="arjuna-hero__logos-divider" aria-hidden="true" />
              <Image
                src="/LOGOSISTEM.png"
                alt="Logo ARJUNA"
                width={48}
                height={48}
                priority
                className="arjuna-logo-system"
              />
            </div>

            <div className="arjuna-hero__titles">
              <span className="arjuna-badge">
                <span className="arjuna-badge__dot" />
                KEMENTERIAN KESEHATAN REPUBLIK INDONESIA
              </span>
              <h1 className="arjuna-title">ARJUNA</h1>
              <p className="arjuna-subtitle">
                Balai Besar Kekarantinaan Kesehatan Makassar
              </p>
            </div>
          </header>

          <div className="arjuna-hero__main">
            <h2 className="arjuna-tagline">
              Digitalisasi Karantina,
              <span className="arjuna-tagline__highlight">
                {" "}Integritas Sanitasi Transportasi.
              </span>
            </h2>
            <p className="arjuna-description">
              Satu portal terpadu untuk monitoring deklarasi mandiri kapal dan pesawat udara,
              verifikasi digital parameter kesehatan, dan penerbitan resmi dokumen PHQC &amp; Berkas Verifikasi.
            </p>

            <div className="arjuna-features">
              <div className="arjuna-feature-item">
                <div className="arjuna-feature-item__icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M2 20a2.4 2.4 0 0 0 2 1a2.4 2.4 0 0 0 2-1a2.4 2.4 0 0 1 2-1a2.4 2.4 0 0 1 2 1a2.4 2.4 0 0 0 2 1a2.4 2.4 0 0 0 2-1a2.4 2.4 0 0 1 2-1a2.4 2.4 0 0 1 2 1a2.4 2.4 0 0 0 2 1a2.4 2.4 0 0 0 2-1" />
                    <path d="M4 18L3 12h18l-1 6" />
                    <path d="M12 4v8m-4-4h8" />
                  </svg>
                </div>
                <div className="arjuna-feature-item__content">
                  <strong>Moda Laut (Kapal)</strong>
                  <span>34 Titik Pemeriksaan Higiene &amp; Vektor Penular (PMK 40/2015)</span>
                </div>
              </div>

              <div className="arjuna-feature-item">
                <div className="arjuna-feature-item__icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M17.8 19.2L16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1l3 2l2 3l1-1v-3l3-2l3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z" />
                  </svg>
                </div>
                <div className="arjuna-feature-item__content">
                  <strong>Moda Udara (Pesawat)</strong>
                  <span>37 Parameter Sanitasi Kabin, Toilet, Galley &amp; Air Bersih</span>
                </div>
              </div>

              <div className="arjuna-feature-item">
                <div className="arjuna-feature-item__icon">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                    <path d="m9 12 2 2 4-4" />
                  </svg>
                </div>
                <div className="arjuna-feature-item__content">
                  <strong>Validasi Elektronik &amp; Audit Trail</strong>
                  <span>Konfirmasi PIN TTD Digital &amp; Penerbitan Otomatis PHQC</span>
                </div>
              </div>
            </div>
          </div>

          <footer className="arjuna-hero__footer">
            <span className="arjuna-server-status">
              <span className="arjuna-status-beacon" />
              Sistem Operasional Online · Wilayah Kerja BBKK Makassar
            </span>
          </footer>
        </section>

        {/* ─── Kolom Kanan: Glassmorphic Login Card ─── */}
        <section className="arjuna-form-section" aria-labelledby="form-heading">
          <div className="arjuna-card">
            <div className="arjuna-card__header">
              <div className="arjuna-card__badge">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                  <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                </svg>
                <span>PORTAL ADMINISTRATOR</span>
              </div>
              <h3 id="form-heading" className="arjuna-card__title">
                Masuk ke Akun
              </h3>
              <p className="arjuna-card__subtitle">
                Gunakan kredensial akun Validator Admin untuk mengakses dashboard
              </p>
            </div>

            <form className="arjuna-form" onSubmit={handleSubmit}>
              <div className="arjuna-field">
                <label htmlFor="arjuna-email">Alamat Email</label>
                <div className="arjuna-input-box">
                  <span className="arjuna-input-icon" aria-hidden="true">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <rect x="2" y="4" width="20" height="16" rx="2" />
                      <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
                    </svg>
                  </span>
                  <input
                    id="arjuna-email"
                    type="email"
                    name="email"
                    autoComplete="username"
                    placeholder="nama@kemkes.go.id"
                    value={email}
                    onChange={(event) => setEmail(event.target.value)}
                    required
                  />
                </div>
              </div>

              <div className="arjuna-field">
                <div className="arjuna-field__header">
                  <label htmlFor="arjuna-password">Kata Sandi</label>
                </div>
                <div className="arjuna-input-box">
                  <span className="arjuna-input-icon" aria-hidden="true">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                      <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                    </svg>
                  </span>
                  <input
                    id="arjuna-password"
                    type={showPassword ? "text" : "password"}
                    name="password"
                    autoComplete="current-password"
                    placeholder="Masukkan kata sandi akun"
                    value={password}
                    onChange={(event) => setPassword(event.target.value)}
                    required
                  />
                  <button
                    className="arjuna-toggle-pwd"
                    type="button"
                    aria-label={showPassword ? "Sembunyikan kata sandi" : "Tampilkan kata sandi"}
                    onClick={() => setShowPassword((prev) => !prev)}
                  >
                    {showPassword ? (
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M9.88 9.88a3 3 0 1 0 4.24 4.24" />
                        <path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68" />
                        <path d="M6.61 6.61A13.526 13.526 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61" />
                        <line x1="2" y1="2" x2="22" y2="22" />
                      </svg>
                    ) : (
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z" />
                        <circle cx="12" cy="12" r="3" />
                      </svg>
                    )}
                  </button>
                </div>
              </div>

              {errorMessage && (
                <div className="arjuna-error-box" role="alert">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <circle cx="12" cy="12" r="10" />
                    <line x1="12" y1="8" x2="12" y2="12" />
                    <line x1="12" y1="16" x2="12.01" y2="16" />
                  </svg>
                  <span>{errorMessage}</span>
                </div>
              )}

              <button className="arjuna-btn-submit" type="submit" disabled={isLoading}>
                {isLoading ? (
                  <>
                    <span className="arjuna-spinner" />
                    <span>Memverifikasi Akun...</span>
                  </>
                ) : (
                  <>
                    <span>Masuk ke Dashboard</span>
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M5 12h14m-7-7 7 7-7 7" />
                    </svg>
                  </>
                )}
              </button>
            </form>

            <div className="arjuna-role-notice">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <path d="M12 16v-4m0-4h.01" />
              </svg>
              <div>
                <strong>Akses Pengguna Lapangan</strong>
                <p>
                  Nahkoda Kapal, Pilot, &amp; Petugas Verifikator silakan menggunakan aplikasi mobile <strong>ARJUNA</strong>
                </p>
              </div>
            </div>

            <footer className="arjuna-card__footer">
              <p>ARJUNA · Balai Besar Kekarantinaan Kesehatan Makassar</p>
            </footer>
          </div>
        </section>
      </div>
    </main>
  );
}
