"use client";

import Link from "next/link";
import { useSession, signOut } from "next-auth/react";
import { Button } from "@/components/ui/Button";

export function Navbar() {
  const { data: session } = useSession();

  return (
    <nav className="bg-gray-900 border-b border-gray-700">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex">
            <Link href="/dashboard" className="flex items-center px-2 py-2 text-xl font-bold text-white">
              Xplora
            </Link>
            <div className="hidden sm:ml-6 sm:flex sm:space-x-8">
              <Link
                href="/dashboard"
                className="border-transparent text-gray-300 hover:border-gray-300 hover:text-white inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
              >
                Dashboard
              </Link>
              <Link
                href="/dashboard/accounts"
                className="border-transparent text-gray-300 hover:border-gray-300 hover:text-white inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
              >
                Accounts
              </Link>
              <Link
                href="/dashboard/requests/pending"
                className="border-transparent text-gray-300 hover:border-gray-300 hover:text-white inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
              >
                Pending Requests
              </Link>
            </div>
          </div>
          <div className="flex items-center space-x-4">
            {session?.user && (
              <>
                <span className="text-gray-300 text-sm">
                  {(session.user as any).name} ({(session.user as any).role})
                </span>
                <Button variant="ghost" size="sm" onClick={() => signOut({ callbackUrl: "/login" })}>
                  Sign Out
                </Button>
              </>
            )}
          </div>
        </div>
      </div>
    </nav>
  );
}
