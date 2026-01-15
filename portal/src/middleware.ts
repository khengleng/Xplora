import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Allow public routes
  if (
    pathname === "/login" ||
    pathname.startsWith("/api/auth") ||
    pathname.startsWith("/_next")
  ) {
    return NextResponse.next();
  }

  // Check for session token in cookies
  const sessionToken = request.cookies.get("next-auth.session-token") || 
                       request.cookies.get("__Secure-next-auth.session-token");

  // Redirect to login if no session
  if (!sessionToken && pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*", "/api/requests/:path*", "/api/accounts/:path*"],
};
