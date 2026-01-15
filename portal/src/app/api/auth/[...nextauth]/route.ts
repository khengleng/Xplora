import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import type { NextAuthConfig } from "next-auth";
import { query } from "@/lib/db";
import { compare } from "bcryptjs";
import type { UserRole } from "@/types";

type DbUser = {
  id: number;
  username: string;
  full_name: string;
  role: UserRole;
  is_active: boolean;
  is_locked: boolean;
  failed_login_attempts: number;
  password_hash: string | null;
};

export const authConfig: NextAuthConfig = {
  providers: [
    Credentials({
      name: "Credentials",
      credentials: {
        username: { label: "Username", type: "text" },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        if (!credentials?.username || !credentials.password) return null;

        const { rows } = await query<DbUser>(
          "SELECT id, username, full_name, role, is_active, is_locked, failed_login_attempts, password_hash FROM users WHERE username = $1",
          [credentials.username]
        );

        const user = rows[0];
        if (!user) return null;

        // Enforce basic status flags
        if (!user.is_active || user.is_locked) {
          return null;
        }

        // Enforce lockout after too many failed attempts
        if (user.failed_login_attempts >= 5) {
          await query(
            "UPDATE users SET is_locked = true WHERE id = $1 AND is_locked = false",
            [user.id]
          );
          return null;
        }

        // Require a real password hash in production data
        if (!user.password_hash) {
          return null;
        }

        const passwordOk = await compare(credentials.password, user.password_hash);

        if (!passwordOk) {
          // Increment failed login attempts and lock if threshold reached
          const { rows: updated } = await query<{
            failed_login_attempts: number;
          }>(
            "UPDATE users SET failed_login_attempts = failed_login_attempts + 1 WHERE id = $1 RETURNING failed_login_attempts",
            [user.id]
          );

          const attempts = updated[0]?.failed_login_attempts ?? user.failed_login_attempts + 1;
          if (attempts >= 5) {
            await query(
              "UPDATE users SET is_locked = true WHERE id = $1 AND is_locked = false",
              [user.id]
            );
          }

          return null;
        }

        // Successful login: reset failed attempts
        await query(
          "UPDATE users SET failed_login_attempts = 0 WHERE id = $1",
          [user.id]
        );

        return {
          id: String(user.id),
          name: user.full_name,
          username: user.username,
          role: user.role,
        };
      },
    }),
  ],
  session: {
    strategy: "jwt",
  },
  pages: {
    signIn: "/login",
  },
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.role = (user as any).role;
        token.username = (user as any).username;
        token.id = user.id;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        (session.user as any).role = token.role;
        (session.user as any).username = token.username;
        (session.user as any).id = token.id;
      }
      return session;
    },
  },
};

const handler = NextAuth(authConfig);

export { handler as GET, handler as POST };

