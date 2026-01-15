export default function PendingRequestsPage() {
  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-lg font-semibold tracking-tight">
          Pending field access requests
        </h2>
        <p className="text-sm text-slate-300">
          This view will soon be powered by the{" "}
          <code className="rounded bg-slate-900 px-1 py-0.5 text-[10px]">
            pending_requests_dashboard
          </code>{" "}
          database view.
        </p>
      </div>
      <div className="rounded-xl border border-dashed border-slate-800 bg-slate-900/40 p-6 text-center text-sm text-slate-500">
        Data wiring not implemented yet. Once connected, supervisors and managers
        will be able to approve or reject requests directly from here.
      </div>
    </div>
  );
}

