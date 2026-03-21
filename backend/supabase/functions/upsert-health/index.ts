import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface RequestBody {
  summary_date: string          // "YYYY-MM-DD"
  sleep_hours: number
  steps: number
  resting_heart_rate?: number   // optional — requires Apple Watch
  heart_rate_variability?: number // optional — requires Apple Watch
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
    if (body.sleep_hours === undefined || body.sleep_hours === null) {
      return new Response(
        JSON.stringify({ error: "sleep_hours is required" }),
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
          sleep_hours:              body.sleep_hours,
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

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
