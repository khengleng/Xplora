"use client";

import { useEffect, useState } from "react";
import { useSession } from "next-auth/react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import type { Account, SensitiveField } from "@/types";

interface AccountDetail {
  account: Account;
  decryptedField?: string | null;
  fieldName?: string;
  requiresAccessRequest?: boolean;
}

export default function AccountDetailPage({ params }: { params: { id: string } }) {
  const router = useRouter();
  const { data: session } = useSession();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [accountDetail, setAccountDetail] = useState<AccountDetail | null>(null);
  const [selectedField, setSelectedField] = useState<SensitiveField | null>(null);
  const [showRequestModal, setShowRequestModal] = useState(false);
  const [requestReason, setRequestReason] = useState("");
  const [requesting, setRequesting] = useState(false);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  const sensitiveFields: { field: SensitiveField; label: string }[] = [
    { field: "account_number", label: "Account Number" },
    { field: "ssn", label: "Social Security Number" },
    { field: "balance", label: "Account Balance" },
    { field: "email", label: "Email Address" },
    { field: "phone", label: "Phone Number" },
    { field: "address", label: "Mailing Address" },
  ];

  useEffect(() => {
    loadAccountDetail();
  }, [params.id, refreshTrigger]);

  async function loadAccountDetail() {
    setLoading(true);
    setError(null);
    try {
      const url = selectedField 
        ? `/api/accounts/${params.id}?field=${selectedField}`
        : `/api/accounts/${params.id}`;
      
      const res = await fetch(url);
      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Failed to load account");
      }
      const data = await res.json();
      setAccountDetail(data);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }

  async function handleRequestAccess(field: SensitiveField) {
    setSelectedField(field);
    setShowRequestModal(true);
  }

  async function submitRequest() {
    if (!requestReason.trim()) {
      alert("Please provide a reason for this access request.");
      return;
    }

    setRequesting(true);
    try {
      const res = await fetch("/api/requests", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          accountId: Number(params.id),
          fieldName: selectedField,
          reason: requestReason,
        }),
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || "Failed to submit request");
      }

      setShowRequestModal(false);
      setRequestReason("");
      setSelectedField(null);
      alert("Access request submitted successfully!");
      setRefreshTrigger(prev => prev + 1);
    } catch (e) {
      alert((e as Error).message);
    } finally {
      setRequesting(false);
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-gray-400">Loading account details...</div>
      </div>
    );
  }

  if (error || !accountDetail) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-red-400">{error || "Account not found"}</div>
      </div>
    );
  }

  const { account, decryptedField, requiresAccessRequest } = accountDetail;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <div className="flex items-center gap-3">
            <Link href="/dashboard/accounts">
              <Button variant="secondary" size="sm">← Back to Search</Button>
            </Link>
            <h1 className="text-2xl font-bold text-white">Account Details</h1>
          </div>
          <p className="text-gray-400 mt-1">
            Account ID: <span className="font-mono text-blue-400">{account.id}</span>
          </p>
        </div>
        <span className={`px-3 py-1 rounded-full text-sm font-medium ${
          account.status === 'ACTIVE' 
            ? 'bg-green-900/50 text-green-400 border border-green-700' 
            : 'bg-gray-700 text-gray-300 border border-gray-600'
        }`}>
          {account.status}
        </span>
      </div>

      {/* Basic Information Card */}
      <Card title="Basic Information">
        <div className="grid grid-cols-2 gap-6">
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Account Number (Last 4)
            </label>
            <div className="font-mono text-lg text-white">
              ****{account.account_number_last4}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Account Status
            </label>
            <div className="text-lg text-white">{account.status}</div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Holder Name
            </label>
            <div className="text-lg text-white">{account.holder_name_search || "—"}</div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              SSN (Last 4)
            </label>
            <div className="font-mono text-lg text-white">
              ***-{account.ssn_last4 || "**"}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Email Hint
            </label>
            <div className="text-lg text-white">{account.email_hint || "—"}</div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Phone (Last 4)
            </label>
            <div className="font-mono text-lg text-white">
              ***-{account.phone_last4 || "**"}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-1">
              Created Date
            </label>
            <div className="text-lg text-white">
              {new Date(account.created_at).toLocaleDateString()}
            </div>
          </div>
        </div>
      </Card>

      {/* Decrypted Field Display */}
      {selectedField && decryptedField && (
        <Card title={`${sensitiveFields.find(f => f.field === selectedField)?.label}`} className="border-green-700 bg-green-950/20">
          <div className="space-y-4">
            <div className="flex items-center gap-2 text-sm text-green-400">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
              </svg>
              <span>Access Granted - This data is visible for your session only</span>
            </div>
            <div className="bg-gray-900 rounded-lg p-4 border border-gray-700">
              <div className="text-lg font-mono text-white break-all">
                {decryptedField}
              </div>
            </div>
            <div className="flex gap-2">
              <Button 
                variant="secondary" 
                size="sm"
                onClick={() => setSelectedField(null)}
              >
                Close
              </Button>
              <Link href="/dashboard/requests/mine">
                <Button variant="primary" size="sm">View My Requests</Button>
              </Link>
            </div>
          </div>
        </Card>
      )}

      {/* Request Required Notice */}
      {requiresAccessRequest && selectedField && !decryptedField && (
        <Card title="Access Required" className="border-yellow-700 bg-yellow-950/20">
          <div className="space-y-4">
            <p className="text-sm text-yellow-200">
              You need to request access to view this sensitive field. 
              Click the button below to submit an access request.
            </p>
            <Button 
              variant="primary"
              onClick={() => handleRequestAccess(selectedField)}
            >
              Request Access to {sensitiveFields.find(f => f.field === selectedField)?.label}
            </Button>
          </div>
        </Card>
      )}

      {/* Sensitive Fields Grid */}
      <Card title="Sensitive Information">
        <p className="text-sm text-gray-400 mb-4">
          Access to sensitive fields requires approval from a supervisor or manager.
          All requests are logged in the PCI audit log.
        </p>
        <div className="grid gap-4 md:grid-cols-2">
          {sensitiveFields.map(({ field, label }) => (
            <div
              key={field}
              className={`rounded-lg border p-4 transition-all ${
                selectedField === field
                  ? "border-blue-500 bg-blue-950/20"
                  : "border-gray-700 bg-gray-900 hover:border-gray-600"
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <h3 className="font-medium text-white">{label}</h3>
                <span className="text-xs text-gray-500 uppercase">{field}</span>
              </div>
              {selectedField === field && decryptedField ? (
                <div className="text-sm text-green-400">
                  ✓ Access Granted
                </div>
              ) : selectedField === field ? (
                <div className="text-sm text-yellow-400">
                  ⚠ Access Required
                </div>
              ) : (
                <div className="text-sm text-gray-400 mb-3">
                  Request access to view this field
                </div>
              )}
              {selectedField !== field && (
                <Button
                  size="sm"
                  variant="secondary"
                  onClick={() => {
                    setSelectedField(field);
                    setRefreshTrigger(prev => prev + 1);
                  }}
                  className="w-full"
                >
                  View {label}
                </Button>
              )}
            </div>
          ))}
        </div>
      </Card>

      {/* Request Access Modal */}
      {showRequestModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <Card title="Request Access" className="max-w-md w-full">
            <div className="space-y-4">
              <div>
                <p className="text-sm text-gray-400 mb-2">
                  You are requesting access to view:
                </p>
                <p className="font-medium text-white">
                  {sensitiveFields.find(f => f.field === selectedField)?.label}
                </p>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-300 mb-1">
                  Reason for Access Request
                </label>
                <textarea
                  value={requestReason}
                  onChange={(e) => setRequestReason(e.target.value)}
                  placeholder="Explain why you need access to this information..."
                  rows={4}
                  className="w-full rounded-lg border border-gray-700 bg-gray-900 px-4 py-2 text-white placeholder-gray-500 focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
                />
              </div>
              <div className="flex gap-2">
                <Button
                  variant="secondary"
                  onClick={() => {
                    setShowRequestModal(false);
                    setRequestReason("");
                    setSelectedField(null);
                  }}
                  disabled={requesting}
                >
                  Cancel
                </Button>
                <Button
                  variant="primary"
                  onClick={submitRequest}
                  disabled={requesting || !requestReason.trim()}
                >
                  {requesting ? "Submitting..." : "Submit Request"}
                </Button>
              </div>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
