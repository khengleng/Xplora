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

export const authConfig = {
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

                const passwordOk = await compare(
                    credentials.password as string,
                    user.password_hash
                );

                if (!passwordOk) {
                    // Increment failed login attempts and lock if threshold reached
                    const { rows: updated } = await query<{
                        failed_login_attempts: number;
                    }>(
                        "UPDATE users SET failed_login_attempts = failed_login_attempts + 1 WHERE id = $1 RETURNING failed_login_attempts",
                        [user.id]
                    );

                    const attempts =
                        updated[0]?.failed_login_attempts ?? user.failed_login_attempts + 1;
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
        strategy: "jwt" as const,
    },
    pages: {
        signIn: "/login",
    },
    callbacks: {
        async jwt({ token, user }: { token: any; user: any }) {
            if (user) {
                token.role = user.role;
                token.username = user.username;
                token.id = user.id;
            }
            return token;
        },
        async session({ session, token }: { session: any; token: any }) {
            if (session.user) {
                session.user.role = token.role;
                session.user.username = token.username;
                session.user.id = token.id;
            }
            return session;
        },
    },
} satisfies NextAuthConfig;
