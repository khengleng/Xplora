"use client";

import { useEffect, useState } from "react";
import { useSession } from "next-auth/react";
import { Card } from "@/components/ui/Card";
import { Table, TableHead, TableHeader, TableBody, TableRow, TableCell } from "@/components/ui/Table";
import type { FieldAccessRequest, RequestStatus } from "@/types";

export default function MyRequestsPage() {
  const { data: session } = useSession();
  const [items, setItems] = useState<FieldAccessRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadRequests();
    const interval = setInterval(loadRequests, 30000); // Refresh every 30s
    return () => clearInterval(interval);
  }, []);

  async function loadRequests() {
    try {
      const res = await fetch("/api/requests/mine");
      if (!res.ok) throw new Error("Failed to load");
      const json = await res.json();
      setItems(json.requests || []);
      setError(null);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }

  function getStatusBadge(status: RequestStatus) {
    const styles = {
      PENDING: "bg-yellow-900 text-yellow-300 border-yellow-700",
      APPROVED: "bg-green-900 text-green-300 border-green-700",
      REJECTED: "bg-red-900 text-red-300 border-red-700",
      EXPIRED: "bg-gray-700 text-gray-300 border-gray-600",
    };

    return (
      <span className={`px-2 py-1 rounded text-xs border ${styles[status] || styles.PENDING}`}>
        {status}
      </span>
    );
  }

  function formatDate(dateString: string) {
    const date = new Date(dateString);
    return date.toLocaleString();
  }

  function getTimeRemaining(expiresAt: string | undefined) {
    if (!expiresAt) return null;
    const now = new Date();
    const expiry = new Date(expiresAt);
    const diff = expiry.getTime() - now.getTime();
    
    if (diff <= 0) return "Expired";
    
    const minutes = Math.floor(diff / 60000);
    if (minutes < 1) return "< 1 minute";
    if (minutes < 60) return `${minutes} min`;
    
    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    return `${hours}h ${remainingMinutes}m`;
  }

  return (
    <Card title="My Access Requests">
      {loading && <p className="text-gray-400">Loading your requests…</p>}
      {error && <p className="text-red-400">Error: {error}</p>}
      {!loading && !error && (
        <>
          {items.length === 0 ? (
            <p className="text-gray-400">No access requests found.</p>
          ) : (
            <Table>
              <TableHead>
                <TableHeader>Ref</TableHeader>
                <TableHeader>Account</TableHeader>
                <TableHeader>Field</TableHeader>
                <TableHeader>Status</TableHeader>
                <TableHeader>Requested</TableHeader>
                <TableHeader>Expires In</TableHeader>
                <TableHeader>Reviewed By</TableHeader>
              </TableHead>
              <TableBody>
                {items.map((r) => (
                  <TableRow key={r.id}>
                    <TableCell className="font-mono text-xs">
                      {r.request_ref.slice(0, 8)}…
                    </TableCell>
                    <TableCell className="font-mono text-sm">
                      ID: {r.account_id}
                    </TableCell>
                    <TableCell className="uppercase text-blue-400 text-sm">
                      {r.field_name}
                    </TableCell>
                    <TableCell>{getStatusBadge(r.status)}</TableCell>
                    <TableCell className="text-xs text-gray-400">
                      {formatDate(r.created_at)}
                    </TableCell>
                    <TableCell className="text-xs">
                      {r.status === 'APPROVED' && r.access_expires_at ? (
                        <span className="text-green-400">
                          {getTimeRemaining(r.access_expires_at)}
                        </span>
                      ) : r.status === 'EXPIRED' ? (
                        <span className="text-gray-400">
                          {r.access_expires_at ? formatDate(r.access_expires_at) : '—'}
                        </span>
                      ) : (
                        '—'
                      )}
                    </TableCell>
                    <TableCell className="text-xs text-gray-400">
                      {r.reviewed_at ? (
                        <div>
                          <div>{r.reviewed_by ? `User ID: ${r.reviewed_by}` : '—'}</div>
                          <div className="text-xs text-gray-500">
                            {formatDate(r.reviewed_at)}
                          </div>
                          {r.rejection_reason && (
                            <div className="text-xs text-red-400 mt-1">
                              Reason: {r.rejection_reason}
                            </div>
                          )}
                        </div>
                      ) : (
                        '—'
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </>
      )}
    </Card>
  );
}
