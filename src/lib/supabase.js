import { createClient } from '@supabase/supabase-js'

const normalizeSupabaseUrl=value=>String(value||'').trim().replace('.supabase.com','.supabase.co').replace(/\/+$/,'')
const url = normalizeSupabaseUrl(import.meta.env.VITE_SUPABASE_URL)
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY

export const secureBackendConfigured = Boolean(url && key)
export const supabase = secureBackendConfigured
  ? createClient(url, key, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
        storageKey: 'mkg-secure-session',
      },
    })
  : null
