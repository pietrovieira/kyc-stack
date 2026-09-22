import { cookies } from "next/headers"
import { NextRequest, NextResponse } from "next/server"

const API_URL = process.env.API_URL || process.env.NEXT_PUBLIC_API_URL || "http://kyc-go:8080"

async function proxyDelete(token: string) {
  const res = await fetch(`${API_URL}/api/admin/customers`, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  })
  const data = await res.json().catch(() => ({}))
  return { res, data }
}

export async function DELETE(_req: NextRequest) {
  const cookieStore = await cookies()
  const token = cookieStore.get("admin_token")?.value
  if (!token) {
    return NextResponse.json({ success: false, error: "Não autenticado" }, { status: 401 })
  }
  try {
    const { res, data } = await proxyDelete(token)
    return NextResponse.json(data, { status: res.status })
  } catch (e) {
    return NextResponse.json({ success: false, error: String(e) }, { status: 500 })
  }
}

// Also support POST for form-based clients
export async function POST(req: NextRequest) {
  return DELETE(req)
}
