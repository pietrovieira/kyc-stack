import { NextRequest, NextResponse } from "next/server"

const API_URL = process.env.API_URL || process.env.NEXT_PUBLIC_API_URL || "http://kyc-go:8080"

export async function POST(req: NextRequest) {
  const { email, password } = await req.json()

  // Server-side fetch to Go API - não expõe segredo ao client
  const res = await fetch(`${API_URL}/api/admin/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
    cache: "no-store",
  })

  const data = await res.json()

  if (!res.ok) {
    return NextResponse.json({ success: false, error: data.error || "Credenciais inválidas" }, { status: res.status })
  }

  const response = NextResponse.json({ success: true, admin: data.admin })

  // Set httpOnly cookie - anti session hijacking
  // VPS via IP http://191.252.204.221 não tem TLS -> Secure=true bloqueia cookie. Só ativa Secure se for HTTPS.
  const isHttps = req.url.startsWith("https://") || req.headers.get("x-forwarded-proto") === "https" || process.env.NEXT_PUBLIC_API_URL?.startsWith("https://")
  const secure = process.env.COOKIE_SECURE ? process.env.COOKIE_SECURE === "true" : isHttps
  response.cookies.set("admin_token", data.token, {
    httpOnly: true,
    secure,
    sameSite: "lax",
    maxAge: 60 * 30, // 30 min - expira rápido
    path: "/",
  })

  // CSRF token (double submit)
  const csrf = crypto.randomUUID()
  response.cookies.set("csrf_token", csrf, {
    httpOnly: false, // precisa ser lido por JS para enviar no header
    secure,
    sameSite: "lax",
    maxAge: 60 * 30,
    path: "/",
  })

  return response
}

export async function DELETE() {
  const response = NextResponse.json({ success: true })
  response.cookies.delete("admin_token")
  response.cookies.delete("csrf_token")
  return response
}
