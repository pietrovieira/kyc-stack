import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatCPF(cpf: string) {
  const d = cpf.replace(/\D/g, "")
  if (d.length !== 11) return cpf
  return d.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, "$1.$2.$3-$4")
}

export function statusLabel(status: string) {
  const map: Record<string, string> = {
    draft: "Rascunho",
    profile_completed: "Perfil OK",
    kyc_pending: "KYC Pendente",
    kyc_approved: "Aprovado",
    kyc_rejected: "Rejeitado",
    account_active: "Conta Ativa",
  }
  return map[status] || status
}

export function statusVariant(status: string): "default" | "secondary" | "destructive" | "outline" {
  switch (status) {
    case "kyc_approved":
    case "account_active":
      return "default"
    case "kyc_pending":
    case "profile_completed":
      return "secondary"
    case "kyc_rejected":
      return "destructive"
    default:
      return "outline"
  }
}

export function statusFromNumber(n: number): string {
  const map: Record<number, string> = {
    0: "draft",
    1: "profile_completed",
    2: "kyc_pending",
    3: "kyc_approved",
    4: "kyc_rejected",
    5: "account_active",
  }
  return map[n] || "draft"
}

export function sessionTypeLabel(n: number): string {
  const map: Record<number, string> = {
    0: "Liveness",
    1: "Enrollment",
    2: "Verification",
    3: "Photo ID Match",
    4: "ID Scan",
  }
  return map[n] ?? String(n)
}

export function sessionStatusLabel(n: number): string {
  return n === 1 ? "Sucesso" : n === 2 ? "Falha" : "Pendente"
}

export function formatDateBR(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return "—"
  return d.toLocaleDateString("pt-BR")
}
