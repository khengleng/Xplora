import type { ReactNode } from "react";
import "./globals.css";

export const metadata = {
  title: "Xplora Portal",
  description: "Explore and manage sensitive data access",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className="h-full bg-slate-950">
      <body className="min-h-full text-slate-50">
        <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-slate-900 via-slate-950 to-slate-900">
          <div className="w-full max-w-5xl rounded-3xl border border-slate-800/60 bg-slate-950/70 p-6 shadow-2xl shadow-slate-900/70 backdrop-blur-xl">
            <header className="mb-6 flex items-center justify-between border-b border-slate-800/60 pb-4">
              <div>
                <h1 className="text-xl font-semibold tracking-tight">
                  Xplora Portal
                </h1>
                <p className="text-xs text-slate-400">
                  Secure access requests for sensitive account data
                </p>
              </div>
            </header>
            <main>{children}</main>
          </div>
        </div>
      </body>
    </html>
  );
}

