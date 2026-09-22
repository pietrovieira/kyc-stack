import { cookies } from "next/headers"
import { redirect } from "next/navigation"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import Link from "next/link"
import { formatCPF, formatDateBR, statusFromNumber, statusLabel } from "@/lib/utils"
import { CustomerDetailModal } from "@/components/customer-detail-modal"
import { ClearAllButton } from "@/components/clear-all-button"
import type { Customer } from "@/lib/types"

const API_URL = process.env.API_URL || process.env.NEXT_PUBLIC_API_URL || "http://kyc-go:8080"

async function fetchCustomers(searchParams: { q?: string; status?: string }) {
  const cookieStore = await cookies()
  const token = cookieStore.get("admin_token")?.value
  if (!token) redirect("/login")

  const url = new URL(`${API_URL}/api/admin/customers`)
  if (searchParams.q) url.searchParams.set("q", searchParams.q)
  if (searchParams.status) url.searchParams.set("status", searchParams.status)

  const res = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  })
  if (res.status === 401) redirect("/login")
  if (!res.ok) throw new Error("Falha ao buscar cadastros")
  return res.json()
}

export default async function DashboardPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string }>
}) {
  const params = await searchParams
  let data: {
    customers: Customer[]
    stats: Record<string, number>
    pagination: { total: number }
  }
  try {
    data = await fetchCustomers(params)
  } catch {
    return <div className="p-8">Erro ao carregar. Verifique se o Go API está rodando em {API_URL}.</div>
  }

  return (
    <div className="min-h-screen bg-[#0a0a0a] text-white">
      <nav className="obsidian-gradient border-b border-[#7c4dff]/30 sticky top-0 z-50 backdrop-blur">
        <div className="max-w-7xl mx-auto px-6 py-4 flex justify-between items-center">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-white/10 flex items-center justify-center font-black">◈</div>
            <div>
              <div className="font-black tracking-wider">
                BANCO <span className="text-[#e1b0ff]">OBSIDIAN</span>
              </div>
              <div className="text-xs text-white/60 -mt-1">BACKOFFICE • KYC</div>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-sm text-white/60 hidden sm:inline">admin@obsidian.com</span>
            <Link
              href="/login"
              className="inline-flex h-8 items-center justify-center rounded-lg px-3 text-sm text-white/80 hover:text-white hover:bg-white/10"
            >
              Sair
            </Link>
          </div>
        </div>
      </nav>

      <div className="max-w-7xl mx-auto p-6 space-y-6">
        <div>
          <h1 className="text-2xl font-black">Cadastros & KYC</h1>
          <p className="text-sm text-white/60">Listagem completa de clientes — simulação conta bancária Banco Obsidian</p>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
          {[
            { label: "Total", value: data.stats.total, color: "from-[#1a0033] to-[#2d0b4a]" },
            { label: "Perfil OK", value: data.stats.profile_completed, color: "from-[#1a237e] to-[#283593]" },
            { label: "KYC Pendente", value: data.stats.kyc_pending, color: "from-[#4a148c] to-[#6a1b9a]" },
            { label: "Aprovados", value: data.stats.kyc_approved, color: "from-[#1b5e20] to-[#2e7d32]" },
            { label: "Rejeitados", value: data.stats.kyc_rejected, color: "from-[#b71c1c] to-[#c62828]" },
            { label: "Contas Ativas", value: data.stats.account_active, color: "from-[#004d40] to-[#00695c]" },
          ].map((s) => (
            <Card key={s.label} className={`bg-gradient-to-br ${s.color} border-white/10 text-white`}>
              <CardContent className="p-4 text-center">
                <div className="text-2xl font-black">{s.value ?? 0}</div>
                <div className="text-xs uppercase tracking-widest opacity-70">{s.label}</div>
              </CardContent>
            </Card>
          ))}
        </div>

        <Card className="bg-[#1a1a1a] border-[#2a2a2a]">
          <CardHeader>
            <div className="flex flex-col gap-3">
              <form className="flex flex-col sm:flex-row gap-3" action="/dashboard" method="get">
                <Input
                  name="q"
                  placeholder="Buscar por CPF, nome, email..."
                  defaultValue={params.q}
                  className="flex-1 bg-[#0f0f0f] border-[#333]"
                />
                <select
                  name="status"
                  defaultValue={params.status || ""}
                  className="h-10 rounded-md border border-[#333] bg-[#0f0f0f] px-3 text-sm"
                >
                  <option value="">Todos status</option>
                  <option value="profile_completed">Perfil OK</option>
                  <option value="kyc_pending">KYC Pendente</option>
                  <option value="kyc_approved">Aprovado</option>
                  <option value="kyc_rejected">Rejeitado</option>
                  <option value="account_active">Conta Ativa</option>
                </select>
                <Button type="submit" className="bg-[#7c4dff] hover:bg-[#6a3de8]">
                  Buscar
                </Button>
                <Link
                  href="/dashboard"
                  className="inline-flex h-10 items-center justify-center rounded-md border border-[#333] px-4 text-sm hover:bg-white/10"
                >
                  Limpar filtros
                </Link>
              </form>
              <div className="flex justify-end">
                <ClearAllButton />
              </div>
            </div>
          </CardHeader>
          <CardContent className="p-0 overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="border-[#2a2a2a] hover:bg-transparent">
                  <TableHead className="text-[#c9a6ff]">Cliente</TableHead>
                  <TableHead className="text-[#c9a6ff]">CPF</TableHead>
                  <TableHead className="text-[#c9a6ff]">Nascimento</TableHead>
                  <TableHead className="text-[#c9a6ff]">Endereço</TableHead>
                  <TableHead className="text-[#c9a6ff]">Status</TableHead>
                  <TableHead className="text-[#c9a6ff]">KYC</TableHead>
                  <TableHead className="text-[#c9a6ff]">Ações</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.customers.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} className="text-center py-10 text-white/50">
                      Nenhum cadastro encontrado
                    </TableCell>
                  </TableRow>
                ) : (
                  data.customers.map((c) => {
                    const lastKyc = c.kyc_sessions?.[0]
                    const statusStr = statusFromNumber(c.status)
                    return (
                      <TableRow key={c.id} className="border-[#222] hover:bg-[#1f1f1f]">
                        <TableCell>
                          <div className="font-semibold">
                            {c.nome} {c.sobrenome}
                          </div>
                          <div className="text-xs text-white/50">
                            {c.email || "—"} {c.telefone ? `• ${c.telefone}` : ""}
                          </div>
                        </TableCell>
                        <TableCell className="font-mono text-xs">{formatCPF(c.cpf)}</TableCell>
                        <TableCell className="text-xs">{formatDateBR(c.data_nascimento)}</TableCell>
                        <TableCell className="text-xs max-w-[180px] truncate" title={`${c.cidade}/${c.estado} • ${c.cep}`}>
                          {c.cidade}/{c.estado} • {c.cep}
                        </TableCell>
                        <TableCell>
                          <Badge
                            variant={statusStr === "kyc_approved" ? "default" : statusStr === "kyc_rejected" ? "destructive" : "secondary"}
                            className={
                              statusStr === "kyc_approved"
                                ? "bg-[#1b5e20] text-[#a5d6a7]"
                                : statusStr === "kyc_rejected"
                                  ? "bg-[#b71c1c]"
                                  : statusStr === "kyc_pending"
                                    ? "bg-[#4a148c] text-[#ce93d8]"
                                    : ""
                            }
                          >
                            {statusLabel(statusStr)}
                          </Badge>
                        </TableCell>
                        <TableCell>
                          {lastKyc ? (
                            <div className="text-xs">
                              <Badge variant={lastKyc.success ? "default" : "destructive"} className="text-[10px]">
                                {lastKyc.success ? "Liveness OK" : "Falhou"} • M:{lastKyc.match_level ?? "-"}
                              </Badge>
                              <div className="text-[11px] text-white/40">
                                {formatDateBR(lastKyc.created_at)}
                              </div>
                            </div>
                          ) : (
                            <span className="text-white/40 text-xs">—</span>
                          )}
                        </TableCell>
                        <TableCell>
                          <div className="flex gap-1">
                            <CustomerDetailModal customer={c} />
                          </div>
                        </TableCell>
                      </TableRow>
                    )
                  })
                )}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        <p className="text-[11px] text-white/30">
          * Dados sanitizados contra XSS (React auto-escape) • Queries com placeholders (anti SQLi) • Tabela limitada a 50/pg • HMAC só app •
          Backoffice síncrono (sem FaceTec async)
        </p>
      </div>
    </div>
  )
}
