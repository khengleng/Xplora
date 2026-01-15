import { getServerSession } from "next-auth";
import { authConfig } from "@/app/api/auth/[...nextauth]/route";
import type { SessionUser, UserRole } from "@/types";

export async function getSession() {
  return getServerSession(authConfig);
}

export async function getCurrentUser(): Promise<SessionUser | null> {
  const session = await getSession();
  return (session?.user as SessionUser) || null;
}

export async function requireAuth(): Promise<SessionUser> {
  const user = await getCurrentUser();
  if (!user) {
    throw new Error("Unauthorized");
  }
  return user;
}

export function canApprove(role?: string): boolean {
  return ['SUPERVISOR', 'MANAGER', 'VVIP', 'ADMIN'].includes(role || '');
}

export function requireApprover(user: SessionUser | null): void {
  if (!user || !canApprove(user.role)) {
    throw new Error("Insufficient permissions");
  }
}
