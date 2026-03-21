import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface RequestBody {
  summary_date: string      // "YYYY-MM-DD"
  event_count: number
  busy_hours: number
  back_to_back_count: number
  late_night_events: number
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

    const required = ["summary_date", "event_count", "busy_hours", "back_to_back_count", "late_night_events"]
    for (const field of required) {
      if (body[field as keyof RequestBody] === undefined || body[field as keyof RequestBody] === null) {
        return new Response(
          JSON.stringify({ error: `${field} is required` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        )
      }
    }

    const { data, error } = await supabase
      .from("daily_schedule_summaries")
      .upsert(
        {
          user_id:            user.id,
          summary_date:       body.summary_date,
          event_count:        body.event_count,
          busy_hours:         body.busy_hours,
          back_to_back_count: body.back_to_back_count,
          late_night_events:  body.late_night_events,
        },
        { onConflict: "user_id,summary_date" }
      )
      .select("id, summary_date, event_count, busy_hours, back_to_back_count, late_night_events")
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
