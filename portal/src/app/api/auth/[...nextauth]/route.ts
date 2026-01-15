import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import type { NextAuthConfig } from "next-auth";
import { query } from "@/lib/db";
import { compare } from "bcryptjs";

type DbUser = {
  id: number;
  username: string;
  full_name: string;
  role: string;
  is_active: boolean;
  is_locked: boolean;
};

const authConfig: NextAuthConfig = {
  providers: [
    Credentials({
      name: "Credentials",
      credentials: {
        username: { label: "Username", type: "text" },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        if (!credentials?.username || !credentials.password) return null;

        const { rows } = await query<DbUser & { password_hash?: string }>(
          "SELECT id, username, full_name, role, is_active, is_locked, NULL::text as password_hash FROM users WHERE username = $1",
          [credentials.username]
        );

        const user = rows[0];
        if (!user) return null;
        if (!user.is_active || user.is_locked) return null;

        // NOTE: hook up real password verification when password_hash exists.
        const passwordOk = await compare(
          credentials.password,
          process.env.DEMO_PASSWORD_HASH ??
            "$2a$10$Pp5t3H6zoDEMOu5e4z9kM.MOCKHASHkKfY1dYJQm4R6O3xFvYcJt8m"
        );
        if (!passwordOk) return null;

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
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.role = (user as any).role;
        token.username = (user as any).username;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        (session.user as any).role = token.role;
        (session.user as any).username = token.username;
      }
      return session;
    },
  },
};

const handler = NextAuth(authConfig);

export { handler as GET, handler as POST };

