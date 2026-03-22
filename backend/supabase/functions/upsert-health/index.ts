import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface RequestBody {
  summary_date: string          // "YYYY-MM-DD"
  sleep_hours?: number | null   // null when no sleep tracking data
  steps: number
  resting_heart_rate?: number | null   // optional — requires Apple Watch
  heart_rate_variability?: number | null // optional — requires Apple Watch
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

    if (!body.summary_date) {
      return new Response(
        JSON.stringify({ error: "summary_date is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }
    if (body.steps === undefined || body.steps === null) {
      return new Response(
        JSON.stringify({ error: "steps is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { data, error } = await supabase
      .from("daily_health_summaries")
      .upsert(
        {
          user_id:                  user.id,
          summary_date:             body.summary_date,
          sleep_hours:              body.sleep_hours ?? null,
          steps:                    body.steps,
          resting_heart_rate:       body.resting_heart_rate   ?? null,
          heart_rate_variability:   body.heart_rate_variability ?? null,
        },
        { onConflict: "user_id,summary_date" }
      )
      .select("id, summary_date, sleep_hours, steps, resting_heart_rate, heart_rate_variability")
      .single()

    if (error) throw error

    return new Response(
      JSON.stringify({ data }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )

  } catch (err: unknown) {
    const message = err instanceof Error
      ? err.message
      : (typeof err === "object" && err !== null && "message" in err)
        ? String((err as Record<string, unknown>).message)
        : JSON.stringify(err)
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
x