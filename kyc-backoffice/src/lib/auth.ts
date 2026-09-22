import { cookies } from "next/headers"

const API_URL = process.env.API_URL || process.env.NEXT_PUBLIC_API_URL || "http://localhost:3000"

export async function login(email: string, password: string) {
  const res = await fetch(`${API_URL}/api/admin/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  })
  const data = await res.json()
  if (!res.ok) throw new Error(data.error || "Falha no login")
  // armazena token em cookie httpOnly simulado via next cookies
  const cookieStore = await cookies()
  const isHttps = process.env.NEXT_PUBLIC_API_URL?.startsWith("https://") || process.env.COOKIE_SECURE === "true"
  cookieStore.set("admin_token", data.token, {
    httpOnly: true,
    secure: isHttps,
    sameSite: "lax",
    maxAge: 60 * 30,
    path: "/",
  })
  return data
}

export async function getCustomers(params?: { q?: string; status?: string; page?: string }) {
  const cookieStore = await cookies()
  const token = cookieStore.get("admin_token")?.value
  const url = new URL(`${API_URL}/api/admin/customers`)
  if (params?.q) url.searchParams.set("q", params.q)
  if (params?.status) url.searchParams.set("status", params.status)
  if (params?.page) url.searchParams.set("page", params.page)

  const res = await fetch(url.toString(), {
    headers: {
      Authorization: `Bearer ${token}`,
      Cookie: `admin_token=${token}`,
    },
    cache: "no-store",
  })
  if (!res.ok) {
    const err = await res.text()
    throw new Error(err)
  }
  return res.json()
}

export async function approveCustomer(id: string) {
  const cookieStore = await cookies()
  const token = cookieStore.get("admin_token")?.value
  const res = await fetch(`${API_URL}/api/admin/customers/${id}/approve`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
  })
  return res.json()
}

export async function rejectCustomer(id: string) {
  const cookieStore = await cookies()
  const token = cookieStore.get("admin_token")?.value
  const res = await fetch(`${API_URL}/api/admin/customers/${id}/reject`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
  })
  return res.json()
}
