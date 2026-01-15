"use client";

import { useEffect, useState } from "react";
import { useSession } from "next-auth/react";
import { Card } from "@/components/ui/Card";
import { Table, TableHead, TableHeader, TableBody, TableRow, TableCell } from "@/components/ui/Table";
import { Button } from "@/components/ui/Button";
import type { PendingRequest } from "@/types";

export default function PendingRequestsPage() {
  const { data: session } = useSession();
  const [items, setItems] = useState<PendingRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [processing, setProcessing] = useState<Set<number>>(new Set());

  const canApprove = session?.user && ['SUPERVISOR', 'MANAGER', 'VVIP', 'ADMIN'].includes((session.user as any).role);

  useEffect(() => {
    loadRequests();
    const interval = setInterval(loadRequests, 30000); // Refresh every 30s
    return () => clearInterval(interval);
  }, []);

  async function loadRequests() {
    try {
      const res = await fetch("/api/requests/pending");
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

  async function handleApprove(id: number) {
    setProcessing(prev => new Set(prev).add(id));
    try {
      const res = await fetch(`/api/requests/${id}/approve`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ durationMinutes: 30 }),
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Failed to approve");
      }
      await loadRequests();
    } catch (e) {
      alert((e as Error).message);
    } finally {
      setProcessing(prev => {
        const next = new Set(prev);
        next.delete(id);
        return next;
      });
    }
  }

  async function handleReject(id: number) {
    const reason = prompt("Rejection reason:");
    if (!reason) return;

    setProcessing(prev => new Set(prev).add(id));
    try {
      const res = await fetch(`/api/requests/${id}/reject`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ reason }),
      });
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Failed to reject");
      }
      await loadRequests();
    } catch (e) {
      alert((e as Error).message);
    } finally {
      setProcessing(prev => {
        const next = new Set(prev);
        next.delete(id);
        return next;
      });
    }
  }

  return (
    <Card title="Pending Access Requests">
      {loading && <p className="text-gray-400">Loading pending requests…</p>}
      {error && <p className="text-red-400">Error: {error}</p>}
      {!loading && !error && (
        <>
          {items.length === 0 ? (
            <p className="text-gray-400">No pending requests.</p>
          ) : (
            <Table>
              <TableHead>
                <TableHeader>Ref</TableHeader>
                <TableHeader>Requester</TableHeader>
                <TableHeader>Branch</TableHeader>
                <TableHeader>Account</TableHeader>
                <TableHeader>Field</TableHeader>
                <TableHeader>Reason</TableHeader>
                <TableHeader>Waiting</TableHeader>
                {canApprove && <TableHeader>Actions</TableHeader>}
              </TableHead>
              <TableBody>
                {items.map((r) => (
                  <TableRow key={r.id}>
                    <TableCell className="font-mono text-xs">
                      {r.request_ref.slice(0, 8)}…
                    </TableCell>
                    <TableCell>{r.requester}</TableCell>
                    <TableCell>{r.branch_code || "—"}</TableCell>
                    <TableCell className="font-mono">{r.account}</TableCell>
                    <TableCell className="uppercase text-blue-400">{r.field_name}</TableCell>
                    <TableCell className="max-w-xs truncate">{r.reason}</TableCell>
                    <TableCell>{Math.round(r.mins_waiting)} min</TableCell>
                    {canApprove && (
                      <TableCell>
                        <div className="flex gap-2">
                          <Button
                            size="sm"
                            variant="primary"
                            onClick={() => handleApprove(r.id)}
                            disabled={processing.has(r.id)}
                          >
                            Approve
                          </Button>
                          <Button
                            size="sm"
                            variant="danger"
                            onClick={() => handleReject(r.id)}
                            disabled={processing.has(r.id)}
                          >
                            Reject
                          </Button>
                        </div>
                      </TableCell>
                    )}
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
