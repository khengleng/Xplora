export default function AccountsPage() {
  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-lg font-semibold tracking-tight">Accounts</h2>
        <p className="text-sm text-slate-300">
          This screen will allow staff to search accounts and request access to
          sensitive fields.
        </p>
      </div>
      <div className="rounded-xl border border-dashed border-slate-800 bg-slate-900/40 p-6 text-center text-sm text-slate-500">
        UI shell in place. Next step: connect to Postgres and expose a safe
        search API that respects encryption and masking.
      </div>
    </div>
  );
}

