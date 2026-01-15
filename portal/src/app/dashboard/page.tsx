export default function DashboardHomePage() {
  return (
    <div className="space-y-4">
      <h2 className="text-lg font-semibold tracking-tight">
        Welcome to Xplora
      </h2>
      <p className="text-sm text-slate-300">
        This dashboard will surface pending access requests and account search.
      </p>
      <div className="grid gap-4 md:grid-cols-2">
        <section className="rounded-xl border border-slate-800 bg-slate-900/60 p-4">
          <h3 className="text-sm font-semibold text-slate-100">
            Pending requests
          </h3>
          <p className="mt-1 text-xs text-slate-400">
            Review and approve field access for tellers. This will connect to
            the{" "}
            <code className="rounded bg-slate-900 px-1 py-0.5 text-[10px]">
              pending_requests_dashboard
            </code>{" "}
            view.
          </p>
        </section>
        <section className="rounded-xl border border-slate-800 bg-slate-900/60 p-4">
          <h3 className="text-sm font-semibold text-slate-100">
            Account explorer
          </h3>
          <p className="mt-1 text-xs text-slate-400">
            Search for accounts by last4 and request access to sensitive
            fields. This will be backed by encrypted columns in{" "}
            <code className="rounded bg-slate-900 px-1 py-0.5 text-[10px]">
              accounts
            </code>
            .
          </p>
        </section>
      </div>
    </div>
  );
}

