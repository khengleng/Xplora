export default function LoginPage() {
  return (
    <div className="mx-auto max-w-md space-y-6">
      <div>
        <h2 className="text-lg font-semibold tracking-tight">Sign in</h2>
        <p className="text-xs text-slate-400">
          Use your employee credentials to access the dashboard.
        </p>
      </div>
      <form className="space-y-4">
        <div className="space-y-1.5">
          <label className="text-xs font-medium text-slate-200">
            Username
          </label>
          <input
            type="text"
            name="username"
            autoComplete="username"
            className="w-full rounded-lg border border-slate-800 bg-slate-900/60 px-3 py-2 text-sm text-slate-50 outline-none ring-0 placeholder:text-slate-500 focus:border-sky-500 focus:ring-2 focus:ring-sky-500/40"
            placeholder="alice.teller"
          />
        </div>
        <div className="space-y-1.5">
          <label className="text-xs font-medium text-slate-200">
            Password
          </label>
          <input
            type="password"
            name="password"
            autoComplete="current-password"
            className="w-full rounded-lg border border-slate-800 bg-slate-900/60 px-3 py-2 text-sm text-slate-50 outline-none ring-0 placeholder:text-slate-500 focus:border-sky-500 focus:ring-2 focus:ring-sky-500/40"
            placeholder="••••••••"
          />
        </div>
        <button
          type="submit"
          className="inline-flex w-full items-center justify-center rounded-lg bg-sky-500 px-3 py-2 text-sm font-medium text-slate-950 shadow-sm shadow-sky-500/40 transition hover:bg-sky-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-500 focus-visible:ring-offset-2 focus-visible:ring-offset-slate-950"
        >
          Continue
        </button>
      </form>
      <p className="text-[11px] leading-relaxed text-slate-500">
        This portal is for authorized employees only. All actions are logged in
        the PCI audit log and may be reviewed by security.
      </p>
    </div>
  );
}

