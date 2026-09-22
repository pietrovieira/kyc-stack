"use client"

import * as React from "react"
import { useRouter } from "next/navigation"
import { toast } from "sonner"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"

export function ClearAllButton() {
  const [open, setOpen] = React.useState(false)
  const [loading, setLoading] = React.useState(false)
  const router = useRouter()

  async function handleClear() {
    if (loading) return
    setLoading(true)
    try {
      const res = await fetch("/api/admin/clear", {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok || data.success === false) {
        throw new Error(data.error || "Falha ao limpar registros")
      }
      toast.success("Todos os registros foram excluídos")
      setOpen(false)
      // Refresh server component data
      router.refresh()
      // Also force reload to clear stale cache
      setTimeout(() => window.location.reload(), 300)
    } catch (e) {
      toast.error(e instanceof Error ? e.message : String(e))
    } finally {
      setLoading(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          <Button
            type="button"
            variant="destructive"
            className="h-10 px-4 bg-[#b71c1c] hover:bg-[#c62828] text-white border-transparent"
          >
            Limpar
          </Button>
        }
      />
      <DialogContent className="bg-[#161616] border border-[#7c4dff]/25 text-white sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="text-white">Excluir todos os registros?</DialogTitle>
          <DialogDescription className="text-white/60">
            Esta ação <span className="text-white font-semibold">não pode ser desfeita</span>. Todos os cadastros de clientes, sessões KYC e chaves de idempotência serão
            permanentemente excluídos do banco de dados.
            <br />
            <br />
            Deseja continuar?
          </DialogDescription>
        </DialogHeader>
        <div className="flex justify-end gap-3 pt-2">
          <Button variant="outline" onClick={() => setOpen(false)} disabled={loading} className="border-[#333] hover:bg-white/10">
            Cancelar
          </Button>
          <Button
            variant="destructive"
            onClick={handleClear}
            disabled={loading}
            className="bg-[#b71c1c] hover:bg-[#c62828] text-white"
          >
            {loading ? "Excluindo..." : "Excluir tudo"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  )
}
