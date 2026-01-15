import type { ReactNode } from "react";
import { SessionProvider } from "@/components/providers/SessionProvider";
import { Navbar } from "@/components/layout/Navbar";
import "./globals.css";

export const metadata = {
  title: "Xplora Portal",
  description: "Explore and manage sensitive data access",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className="h-full bg-gray-900">
      <body className="min-h-full text-gray-100">
        <SessionProvider>
          <div className="min-h-screen bg-gray-900">
            <Navbar />
            <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
              {children}
            </main>
          </div>
        </SessionProvider>
      </body>
    </html>
  );
}

