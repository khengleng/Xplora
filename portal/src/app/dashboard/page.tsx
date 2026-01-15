"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useSession } from "next-auth/react";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";

interface Stats {
  pendingRequests: number;
  myRequests: number;
  activeAccess: number;
}

export default function DashboardHomePage() {
  const { data: session } = useSession();
  const [stats, setStats] = useState<Stats>({
    pendingRequests: 0,
    myRequests: 0,
    activeAccess: 0,
  });
  const [loading, setLoading] = useState(true);

  const canApprove = session?.user && ['SUPERVISOR', 'MANAGER', 'VVIP', 'ADMIN'].includes((session?.user as any)?.role);

  useEffect(() => {
    loadStats();
    const interval = setInterval(loadStats, 30000);
    return () => clearInterval(interval);
  }, []);

  async function loadStats() {
    try {
      let pendingCount = 0;
      let myCount = 0;
      let activeCount = 0;

      // Load pending requests if user can approve
      if (canApprove) {
        try {
          const pendingRes = await fetch("/api/requests/pending");
          if (pendingRes.ok) {
            const pendingData = await pendingRes.json();
            pendingCount = pendingData.requests?.length || 0;
          }
        } catch (e) {
          console.error("Failed to load pending requests:", e);
        }
      }

      // Load my requests
      try {
        const mineRes = await fetch("/api/requests/mine");
        if (mineRes.ok) {
          const mineData = await mineRes.json();
          myCount = mineData.requests?.length || 0;
          activeCount = mineData.requests?.filter((r: any) => 
            r.status === 'APPROVED' && new Date(r.access_expires_at) > new Date()
          ).length || 0;
        }
      } catch (e) {
        console.error("Failed to load my requests:", e);
      }

      setStats({
        pendingRequests: pendingCount,
        myRequests: myCount,
        activeAccess: activeCount,
      });
    } catch (error) {
      console.error("Failed to load stats:", error);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">
          Welcome{(session?.user && (session.user as any).name) ? `, ${(session.user as any).name}` : ""}
        </h1>
        <p className="text-gray-400 mt-2">
          Role: <span className="text-blue-400 font-medium">{(session?.user && (session.user as any)?.role) || "Unknown"}</span>
        </p>
      </div>

      <Card title="Quick Stats">
        <div className="grid grid-cols-3 gap-4 text-center">
          <div className="rounded-lg bg-gray-900 p-4 border border-gray-700">
            <div className={`text-3xl font-bold ${loading ? 'text-gray-500' : 'text-blue-400'}`}>
              {loading ? '—' : stats.pendingRequests}
            </div>
            <div className="text-xs text-gray-400 mt-1">Pending Requests</div>
          </div>
          <div className="rounded-lg bg-gray-900 p-4 border border-gray-700">
            <div className={`text-3xl font-bold ${loading ? 'text-gray-500' : 'text-green-400'}`}>
              {loading ? '—' : stats.myRequests}
            </div>
            <div className="text-xs text-gray-400 mt-1">My Requests</div>
          </div>
          <div className="rounded-lg bg-gray-900 p-4 border border-gray-700">
            <div className={`text-3xl font-bold ${loading ? 'text-gray-500' : 'text-purple-400'}`}>
              {loading ? '—' : stats.activeAccess}
            </div>
            <div className="text-xs text-gray-400 mt-1">Active Access</div>
          </div>
        </div>
      </Card>

      <div className="grid gap-6 md:grid-cols-2">
        <Card title="Account Search">
          <p className="text-sm text-gray-400 mb-4">
            Search for accounts by last 4 digits. Sensitive fields are encrypted and require access requests.
          </p>
          <Link href="/dashboard/accounts">
            <Button variant="primary" className="w-full">Search Accounts</Button>
          </Link>
        </Card>

        {canApprove && (
          <Card title="Pending Requests">
            <p className="text-sm text-gray-400 mb-4">
              Review and approve field access requests from tellers. All actions are logged for audit.
            </p>
            <Link href="/dashboard/requests/pending">
              <Button variant="primary" className="w-full">
                View Pending ({stats.pendingRequests})
              </Button>
            </Link>
          </Card>
        )}

        <Card title="My Requests">
          <p className="text-sm text-gray-400 mb-4">
            View the status of your access requests and manage active grants.
          </p>
          <Link href="/dashboard/requests/mine">
            <Button variant="secondary" className="w-full">
              My Requests ({stats.myRequests})
            </Button>
          </Link>
        </Card>

        <Card title="Security Information">
          <div className="space-y-2 text-sm text-gray-400">
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
              <span>PCI-DSS Compliant Encryption</span>
            </div>
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
              <span>Immutable Audit Trail</span>
            </div>
            <div className="flex items-center gap-2">
              <svg className="w-4 h-4 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
              <span>Role-Based Access Control</span>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
