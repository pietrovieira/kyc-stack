"use client"

import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import type { Customer } from "@/lib/types"
import {
  formatCPF,
  formatDateBR,
  sessionStatusLabel,
  sessionTypeLabel,
  statusFromNumber,
  statusLabel,
} from "@/lib/utils"

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex justify-between gap-4 py-1.5 border-b border-white/5 last:border-0">
      <span className="text-white/45 text-xs shrink-0">{label}</span>
      <span className="text-white/90 text-xs text-right font-medium break-words">{value || "—"}</span>
    </div>
  )
}

function StatusBadge({ status }: { status: number }) {
  const s = statusFromNumber(status)
  const variant = s === "kyc_approved" || s === "account_active" ? "default" : s === "kyc_rejected" ? "destructive" : "secondary"
  const color =
    s === "kyc_approved" || s === "account_active"
      ? "bg-[#1b5e20] text-[#a5d6a7]"
      : s === "kyc_rejected"
        ? "bg-[#b71c1c]"
        : s === "kyc_pending"
          ? "bg-[#4a148c] text-[#ce93d8]"
          : ""
  return (
    <Badge variant={variant} className={color}>
      {statusLabel(s)}
    </Badge>
  )
}

export function CustomerDetailModal({ customer }: { customer: Customer }) {
  const fullAddress = [
    customer.logradouro,
    customer.numero && `nº ${customer.numero}`,
    customer.complemento,
    customer.bairro,
    `${customer.cidade}/${customer.estado}`,
    `CEP ${customer.cep}`,
    customer.pais,
  ]
    .filter(Boolean)
    .join(" • ")

  const sessions = customer.kyc_sessions || []
  const lastKyc = sessions[0]

  return (
    <Dialog>
      <DialogTrigger
        render={
          <Button variant="outline" size="sm" className="border-[#333] hover:bg-white/10">
            Ver
          </Button>
        }
      />
      <DialogContent className="max-h-[85vh] overflow-y-auto sm:max-w-lg bg-[#161616] border border-[#7c4dff]/25 text-white">
        <DialogHeader>
          <DialogTitle className="text-white text-lg">
            {customer.nome} {customer.sobrenome}
          </DialogTitle>
          <DialogDescription className="text-white/50">
            Detalhes do perfil e cadastro • ID #{customer.id}
          </DialogDescription>
        </DialogHeader>

        <div className="flex items-center gap-2">
          <StatusBadge status={customer.status} />
          <span className="text-[11px] text-white/40 font-mono">{formatCPF(customer.cpf)}</span>
        </div>

        <div className="space-y-5">
          <section>
            <h3 className="text-[11px] uppercase tracking-widest text-[#c9a6ff] font-bold mb-1">
              Dados pessoais
            </h3>
            <Row label="Nome" value={`${customer.nome} ${customer.sobrenome}`} />
            <Row label="CPF" value={<span className="font-mono">{formatCPF(customer.cpf)}</span>} />
            <Row label="Nascimento" value={formatDateBR(customer.data_nascimento)} />
            <Row label="Email" value={customer.email} />
            <Row label="Telefone" value={customer.telefone} />
          </section>

          <section>
            <h3 className="text-[11px] uppercase tracking-widest text-[#c9a6ff] font-bold mb-1">
              Endereço
            </h3>
            <Row label="Endereço completo" value={fullAddress} />
          </section>

          <section>
            <h3 className="text-[11px] uppercase tracking-widest text-[#c9a6ff] font-bold mb-1">
              Cadastro
            </h3>
            <Row label="Status" value={<StatusBadge status={customer.status} />} />
            <Row label="Criado em" value={formatDateBR(customer.created_at)} />
            <Row label="Atualizado em" value={formatDateBR(customer.updated_at)} />
            <Row label="Ref. externa" value={<span className="font-mono">{customer.external_database_ref_id}</span>} />
          </section>

          <section>
            <h3 className="text-[11px] uppercase tracking-widest text-[#c9a6ff] font-bold mb-1">
              KYC
            </h3>
            {lastKyc ? (
              <div className="space-y-1">
                <Row label="Tipo" value={sessionTypeLabel(lastKyc.session_type)} />
                <Row label="Resultado" value={sessionStatusLabel(lastKyc.status)} />
                <Row label="Liveness" value={lastKyc.liveness_proven ? "Provado" : lastKyc.liveness_proven === false ? "Não provado" : "—"} />
                <Row label="Match level" value={lastKyc.match_level ?? "—"} />
                <Row label="Documento" value={lastKyc.document_data ? (() => { try { return (JSON.parse(lastKyc.document_data) as { documentType?: string }).documentType ?? "—" } catch { return "—" } })() : "—"} />
                <Row label="Data" value={formatDateBR(lastKyc.created_at)} />
              </div>
            ) : (
              <p className="text-xs text-white/40 py-1">Nenhuma sessão de KYC.</p>
            )}
          </section>

          {sessions.length > 1 && (
            <p className="text-[11px] text-white/40">+ {sessions.length - 1} sessão(ões) anterior(es)</p>
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}
