"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { toast } from "sonner"

export default function LoginPage() {
  const router = useRouter()
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || "Falha no login")
      toast.success("Bem-vindo ao Banco Obsidian")
      router.push("/dashboard")
      router.refresh()
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Erro"
      toast.error(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a] p-4 relative overflow-hidden">
      <div className="absolute inset-0 obsidian-gradient opacity-30" />
      <div className="absolute -top-40 -right-40 w-96 h-96 bg-[#7c4dff]/20 rounded-full blur-[120px]" />
      <div className="absolute -bottom-40 -left-40 w-96 h-96 bg-[#4a148c]/30 rounded-full blur-[120px]" />

      <Card className="w-full max-w-md relative z-10 border-[#7c4dff]/20 bg-[#1a1a1a]/80 backdrop-blur-xl">
        <CardHeader className="text-center space-y-4">
          <div className="mx-auto w-14 h-14 rounded-2xl obsidian-gradient flex items-center justify-center text-2xl font-black text-white shadow-lg shadow-[#7c4dff]/30">
            ◈
          </div>
          <div>
            <CardTitle className="text-2xl font-black tracking-tight">
              BANCO <span className="text-[#7c4dff]">OBSIDIAN</span>
            </CardTitle>
            <CardDescription className="text-[#e1b0ff]/70">Backoffice • Acesso restrito</CardDescription>
          </div>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@obsidian.com"
                required
                autoComplete="email"
                className="bg-[#0f0f0f] border-[#333] focus:border-[#7c4dff]"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">Senha</Label>
              <Input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                autoComplete="current-password"
                className="bg-[#0f0f0f] border-[#333] focus:border-[#7c4dff]"
              />
            </div>
            <Button
              type="submit"
              disabled={loading}
              className="w-full bg-gradient-to-r from-[#7c4dff] to-[#4a148c] hover:opacity-90 text-white font-semibold shadow-lg shadow-[#7c4dff]/20"
            >
              {loading ? "Entrando..." : "Entrar"}
            </Button>
            <p className="text-xs text-center text-muted-foreground">
              Protegido com CSRF • HttpOnly • SameSite Strict • XSS escaped
            </p>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
