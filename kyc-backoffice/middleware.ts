import { NextResponse } from "next/server"
import type { NextRequest } from "next/server"

export function middleware(req: NextRequest) {
  const token = req.cookies.get("admin_token")?.value
  const { pathname } = req.nextUrl

  const isPublic = pathname === "/login" || pathname.startsWith("/api/auth") || pathname === "/"
  const isProtected = pathname.startsWith("/dashboard")

  if (isProtected && !token) {
    return NextResponse.redirect(new URL("/login", req.url))
  }
  if (pathname === "/login" && token) {
    // opcional: validar JWT expiração aqui
    // return NextResponse.redirect(new URL("/dashboard", req.url))
  }

  // Security headers globais - complementa Go
  const res = NextResponse.next()
  res.headers.set("X-Frame-Options", "DENY")
  res.headers.set("X-Content-Type-Options", "nosniff")
  res.headers.set("Referrer-Policy", "strict-origin-when-cross-origin")
  res.headers.set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
  // CSP - HTTPS para IP (nginx TLS) + fallback http para compatibilidade
  res.headers.set(
    "Content-Security-Policy",
    "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' data:; connect-src 'self' https://191.252.204.221:* http://191.252.204.221:* https://191.252.204.221:3002 http://191.252.204.221:3002 http://localhost:* https://localhost:* http://kyc-go:*"
  )
  return res
}

export const config = {
  matcher: ["/dashboard/:path*", "/login"],
}
