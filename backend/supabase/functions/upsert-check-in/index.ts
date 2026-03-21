import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface RequestBody {
  check_in_date: string       // "YYYY-MM-DD"
  stress_level: number        // 1–5
  energy_level: number        // 1–5
  caffeine_servings?: number  // optional, defaults to 0
  notes?: string              // optional
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const body: RequestBody = await req.json()

    if (!body.check_in_date) {
      return new Response(
        JSON.stringify({ error: "check_in_date is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }
    if (body.stress_level === undefined || body.stress_level < 1 || body.stress_level > 5) {
      return new Response(
        JSON.stringify({ error: "stress_level is required and must be between 1 and 5" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }
    if (body.energy_level === undefined || body.energy_level < 1 || body.energy_level > 5) {
      return new Response(
        JSON.stringify({ error: "energy_level is required and must be between 1 and 5" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { data, error } = await supabase
      .from("stress_check_ins")
      .insert({
        user_id:            user.id,
        check_in_date:      body.check_in_date,
        stress_level:       body.stress_level,
        energy_level:       body.energy_level,
        caffeine_servings:  body.caffeine_servings ?? 0,
        notes:              body.notes ?? null,
      })
      .select("id, check_in_date, stress_level, energy_level, caffeine_servings, notes")
      .single()

    if (error) throw error

    return new Response(
      JSON.stringify({ data }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
