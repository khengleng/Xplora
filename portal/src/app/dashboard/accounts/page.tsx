"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Card } from "@/components/ui/Card";
import { Table, TableHead, TableHeader, TableBody, TableRow, TableCell } from "@/components/ui/Table";
import type { Account } from "@/types";

export default function AccountsPage() {
  const [q, setQ] = useState("");
  const [items, setItems] = useState<Account[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!q || q.length < 4) {
      setItems([]);
      return;
    }
    const timeout = setTimeout(async () => {
      setLoading(true);
      setError(null);
      try {
        const res = await fetch(`/api/accounts?q=${encodeURIComponent(q)}`);
        if (!res.ok) {
          const data = await res.json();
          throw new Error(data.error || "Failed to search");
        }
        const json = await res.json();
        setItems(json.accounts || []);
      } catch (e) {
        setError((e as Error).message);
      } finally {
        setLoading(false);
      }
    }, 300);
    return () => clearTimeout(timeout);
  }, [q]);

  return (
    <Card title="Account Search">
      <div className="space-y-4">
        <p className="text-sm text-gray-400">
          Search accounts by last 4 digits. Sensitive fields are encrypted and require access requests.
        </p>
        <input
          type="text"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Enter last 4 digits of account number..."
          maxLength={4}
          className="w-full rounded-lg border border-gray-700 bg-gray-900 px-4 py-2 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
        />
        {loading && <p className="text-gray-400">Searching...</p>}
        {error && <p className="text-red-400">Error: {error}</p>}
        {!loading && !error && items.length > 0 && (
          <Table>
            <TableHead>
              <TableHeader>Account</TableHeader>
              <TableHeader>Holder</TableHeader>
              <TableHeader>Status</TableHeader>
              <TableHeader>Created</TableHeader>
            </TableHead>
            <TableBody>
              {items.map((a) => (
                <TableRow key={a.id}>
                  <TableCell className="font-mono">
                    <Link href={`/dashboard/accounts/${a.id}`} className="hover:text-blue-400 transition-colors">
                      ****{a.account_number_last4}
                    </Link>
                  </TableCell>
                  <TableCell>
                    <Link href={`/dashboard/accounts/${a.id}`} className="hover:text-blue-400 transition-colors">
                      {a.holder_name_search || "—"}
                    </Link>
                  </TableCell>
                  <TableCell>
                    <span className={`px-2 py-1 rounded text-xs ${
                      a.status === 'ACTIVE' ? 'bg-green-900 text-green-300' : 'bg-gray-700 text-gray-300'
                    }`}>
                      {a.status}
                    </span>
                  </TableCell>
                  <TableCell className="text-xs text-gray-400">
                    {new Date(a.created_at).toLocaleDateString()}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
        {!loading && !error && q.length >= 4 && items.length === 0 && (
          <p className="text-gray-400">No accounts found.</p>
        )}
      </div>
    </Card>
  );
}
