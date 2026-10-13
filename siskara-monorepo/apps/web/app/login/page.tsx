"use client";

import { FormEvent, useState } from "react";
import { signInWithEmailAndPassword, signOut } from "firebase/auth";
import { useRouter } from "next/navigation";
import { auth } from "@/lib/firebase";

function BrandMark({ className = "" }: { className?: string }) {
  return (
    <span className={`brand-mark ${className}`} aria-hidden="true">
      <svg viewBox="0 0 32 32" fill="none">
        <path
          d="M16 3.5 25 7v7.2c0 6.1-3.7 11.3-9 14.3-5.3-3-9-8.2-9-14.3V7l9-3.5Z"
          stroke="currentColor"
          strokeWidth="1.8"
        />
        <path
          d="M10.5 16.2h11M16 10.7v11M12 12l8 8m0-8-8 8"
          stroke="currentColor"
          strokeWidth="1.5"
          strokeLinecap="round"
        />
      </svg>
    </span>
  );
}

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
      const credential = await signInWithEmailAndPassword(auth, email, password);
      const tokenResult = await credential.user.getIdTokenResult(true);

      if (tokenResult.claims.role !== "validator_admin") {
        await signOut(auth);
        setErrorMessage("Akun ini tidak memiliki akses Admin SISKARA.");
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
      setErrorMessage(
        error instanceof Error
          ? error.message === "Firebase: Error (auth/invalid-credential)."
            ? "Email atau kata sandi tidak sesuai."
            : error.message
          : "Terjadi kesalahan saat masuk. Silakan coba lagi.",
      );
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <main className="login-page">
      <section className="login-story" aria-label="Tentang SISKARA">
        <div className="login-story__glow login-story__glow--top" />
        <div className="login-story__glow login-story__glow--bottom" />
        <div className="login-story__content">
          <div className="login-brand">
            <BrandMark className="brand-mark--light" />
            <span>
              <strong>SISKARA</strong>
              <small>BBKK Makassar</small>
            </span>
          </div>

          <div className="login-story__message">
            <span className="eyebrow eyebrow--light">PORTAL ADMINISTRATOR</span>
            <h1>
              Pengawasan
              <br />
              sanitasi, lebih
              <br />
              <span>terintegrasi.</span>
            </h1>
            <p>
              Satu ruang kerja untuk memantau pemeriksaan sanitasi kapal dan
              pesawat di wilayah kerja BBKK Makassar.
            </p>
          </div>

          <div className="login-assurance">
            <span className="login-assurance__icon" aria-hidden="true">
              <svg viewBox="0 0 20 20" fill="none">
                <path
                  d="M10 2.2 16 4.5v4.8c0 4.1-2.5 7.5-6 9.5-3.5-2-6-5.4-6-9.5V4.5l6-2.3Z"
                  stroke="currentColor"
                  strokeWidth="1.5"
                />
                <path
                  d="m7 10 2 2 4-4"
                  stroke="currentColor"
                  strokeWidth="1.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </span>
            <span>
              <strong>Akses khusus petugas berwenang</strong>
              <small>Data dan aktivitas terlindungi dalam satu sistem.</small>
            </span>
          </div>
        </div>
        <span className="login-story__watermark" aria-hidden="true">
          S
        </span>
        <p className="login-story__footer">
          BBKK Makassar · Kementerian Kesehatan RI
        </p>
      </section>

      <section className="login-panel" aria-labelledby="login-heading">
        <div className="login-panel__top">
          <BrandMark className="brand-mark--mobile" />
          <span>Portal Internal</span>
        </div>

        <div className="login-form-wrap">
          <div className="login-heading">
            <span className="eyebrow">SELAMAT DATANG KEMBALI</span>
            <h2 id="login-heading">Masuk ke akun Anda</h2>
            <p>Gunakan akun Admin BBKK Makassar untuk melanjutkan.</p>
          </div>

          <form className="login-form" onSubmit={handleSubmit}>
            <label className="form-field">
              <span>Email</span>
              <span className="input-wrap">
                <svg viewBox="0 0 20 20" fill="none" aria-hidden="true">
                  <rect
                    x="2.5"
                    y="4"
                    width="15"
                    height="12"
                    rx="2"
                    stroke="currentColor"
                    strokeWidth="1.5"
                  />
                  <path
                    d="m3.5 5.5 6.5 5 6.5-5"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
                <input
                  type="email"
                  name="email"
                  autoComplete="username"
                  placeholder="nama@kemkes.go.id"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  required
                />
              </span>
            </label>

            <label className="form-field">
              <span>Kata sandi</span>
              <span className="input-wrap">
                <svg viewBox="0 0 20 20" fill="none" aria-hidden="true">
                  <rect
                    x="3.5"
                    y="8"
                    width="13"
                    height="9"
                    rx="2"
                    stroke="currentColor"
                    strokeWidth="1.5"
                  />
                  <path
                    d="M6.5 8V6a3.5 3.5 0 1 1 7 0v2m-3.5 4v2"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    strokeLinecap="round"
                  />
                </svg>
                <input
                  type={showPassword ? "text" : "password"}
                  name="password"
                  autoComplete="current-password"
                  placeholder="Masukkan kata sandi"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  required
                />
                <button
                  className="password-toggle"
                  type="button"
                  aria-label={showPassword ? "Sembunyikan kata sandi" : "Tampilkan kata sandi"}
                  onClick={() => setShowPassword((visible) => !visible)}
                >
                  {showPassword ? "Sembunyikan" : "Lihat"}
                </button>
              </span>
            </label>

            {errorMessage && (
              <p className="form-error" role="alert">
                <svg viewBox="0 0 20 20" fill="none" aria-hidden="true">
                  <circle
                    cx="10"
                    cy="10"
                    r="7.5"
                    stroke="currentColor"
                    strokeWidth="1.5"
                  />
                  <path
                    d="M10 6.5v4m0 3h.01"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    strokeLinecap="round"
                  />
                </svg>
                {errorMessage}
              </p>
            )}

            <button className="login-submit" type="submit" disabled={isLoading}>
              {isLoading ? (
                <>
                  <span className="button-spinner" />
                  Memeriksa akun...
                </>
              ) : (
                <>
                  Masuk ke dashboard
                  <svg viewBox="0 0 20 20" fill="none" aria-hidden="true">
                    <path
                      d="M4 10h12m-5-5 5 5-5 5"
                      stroke="currentColor"
                      strokeWidth="1.6"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                </>
              )}
            </button>
          </form>

          <p className="login-help">
            Mengalami kendala saat masuk?{" "}
            <span>Hubungi administrator sistem.</span>
          </p>
        </div>

        <p className="login-panel__footer">
          Sistem Informasi Sanitasi dan Karantina
        </p>
      </section>
    </main>
  );
}
