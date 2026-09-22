export interface KycSession {
  id: number
  customer_id?: number
  external_database_ref_id?: string
  session_type: number
  status: number
  request_blob_digest?: string
  idempotency_key?: string
  liveness_proven?: boolean
  match_level?: number
  document_data?: string
  success?: boolean
  facetec_response?: string
  error_message?: string
  created_at: string
  updated_at: string
}

export interface Customer {
  id: number
  cpf: string
  nome: string
  sobrenome: string
  data_nascimento: string
  email?: string
  telefone?: string
  logradouro: string
  numero: string
  complemento?: string
  bairro: string
  cidade: string
  estado: string
  cep: string
  pais: string
  status: number
  external_database_ref_id: string
  created_at: string
  updated_at: string
  kyc_sessions?: KycSession[]
}
