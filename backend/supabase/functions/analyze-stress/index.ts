import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface CalendarEvent {
  title: string
  start_time: string  // "HH:MM"
  end_time: string    // "HH:MM"
  is_back_to_back?: boolean
}

interface RequestBody {
  target_date: string  // "YYYY-MM-DD"
  calendar_events?: CalendarEvent[]
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
    const targetDate = body.target_date
    const calendarEvents = body.calendar_events ?? []

    // Fetch health summary for target date
    const { data: health } = await supabase
      .from("daily_health_summaries")
      .select("sleep_hours, steps, resting_heart_rate, heart_rate_variability")
      .eq("user_id", user.id)
      .eq("summary_date", targetDate)
      .maybeSingle()

    // Fetch schedule summary for target date
    const { data: schedule } = await supabase
      .from("daily_schedule_summaries")
      .select("event_count, busy_hours, back_to_back_count, late_night_events")
      .eq("user_id", user.id)
      .eq("summary_date", targetDate)
      .maybeSingle()

    // Fetch recent stress check-ins (last 3 days)
    const lookbackDate = new Date(targetDate)
    lookbackDate.setDate(lookbackDate.getDate() - 3)
    const { data: checkIns } = await supabase
      .from("stress_check_ins")
      .select("stress_level, energy_level")
      .eq("user_id", user.id)
      .gte("check_in_date", lookbackDate.toISOString().split("T")[0])
      .order("check_in_date", { ascending: false })

    // Fetch user profile for intervention style
    const { data: profile } = await supabase
      .from("profiles")
      .select("preferred_intervention_style")
      .eq("id", user.id)
      .maybeSingle()

    // ── Compute stress score (0–10) ──────────────────────────────────────────
    const sleepHours: number = health?.sleep_hours ?? 7
    const hrv: number | null = health?.heart_rate_variability ?? null
    const restingHR: number | null = health?.resting_heart_rate ?? null
    const busyHours: number = schedule?.busy_hours ?? 0
    const backToBack: number = schedule?.back_to_back_count ?? 0
    const lateNight: number = schedule?.late_night_events ?? 0
    const recentStressAvg: number =
      checkIns && checkIns.length > 0
        ? checkIns.reduce((sum: number, c: { stress_level: number }) => sum + c.stress_level, 0) / checkIns.length
        : 3

    // Sleep component (0–3): each hour below 8h target adds pressure
    const sleepScore = Math.min(Math.max((8 - sleepHours) / 3, 0), 1) * 3

    // Schedule component (0–4): busy hours + back-to-back + late night
    const scheduleScore =
      Math.min(busyHours / 8, 1) * 2 +
      Math.min(backToBack / 4, 1) * 1.5 +
      Math.min(lateNight / 2, 1) * 0.5

    // HRV component (0–2): lower HRV indicates higher stress
    const hrvScore = hrv === null ? 0 : hrv < 30 ? 2 : hrv < 50 ? 1 : 0

    // Resting HR component (0–0.5): elevated HR above 60 bpm baseline
    const hrScore =
      restingHR === null ? 0 : Math.min(Math.max((restingHR - 60) / 20, 0), 1) * 0.5

    // Recent self-reported stress component (0–0.5)
    const checkInScore = Math.min(Math.max((recentStressAvg - 1) / 4, 0), 1) * 0.5

    const rawScore = sleepScore + scheduleScore + hrvScore + hrScore + checkInScore
    const stressScore = Math.min(Math.round(rawScore * 10) / 10, 10)
    const riskLevel = stressScore >= 7 ? "high" : stressScore >= 4 ? "medium" : "low"

    // Build top contributing factors
    const topFactors: string[] = []
    if (sleepHours < 7) topFactors.push(`Sleep was ${sleepHours}h (below 7h baseline)`)
    if (backToBack >= 2) topFactors.push(`${backToBack} back-to-back calendar blocks`)
    if (busyHours > 5) topFactors.push(`${busyHours}h of scheduled busy time`)
    if (lateNight > 0) topFactors.push(`${lateNight} late-night event(s) on calendar`)
    if (hrv !== null && hrv < 40) topFactors.push(`HRV low at ${hrv}ms`)
    if (recentStressAvg > 3.5)
      topFactors.push(`Recent stress check-ins averaging ${recentStressAvg.toFixed(1)}/5`)

    // ── Build GPT prompt ─────────────────────────────────────────────────────
    const interventionStyle = profile?.preferred_intervention_style ?? "gentle"

    let calendarSummary: string
    if (calendarEvents.length > 0) {
      calendarSummary = calendarEvents
        .map(
          (e) =>
            `- ${e.title} (${e.start_time}–${e.end_time}${e.is_back_to_back ? ", back-to-back" : ""})`
        )
        .join("\n")
    } else if (schedule) {
      calendarSummary = `${schedule.event_count} events total, ${schedule.busy_hours}h busy, ${schedule.back_to_back_count} back-to-back blocks, ${schedule.late_night_events} late-night`
    } else {
      calendarSummary = "No calendar data available for this date"
    }

    const prompt = `You are a compassionate wellness coach. A user's stress risk score for ${targetDate} is ${stressScore}/10 (${riskLevel} risk).

Health data:
- Sleep: ${sleepHours}h
- Resting HR: ${restingHR !== null ? `${restingHR} bpm` : "N/A"}
- HRV: ${hrv !== null ? `${hrv}ms` : "N/A"}
- Steps: ${health?.steps ?? "N/A"}

Calendar for ${targetDate}:
${calendarSummary}

Top stress factors: ${topFactors.length > 0 ? topFactors.join("; ") : "No strong factors identified"}
User's preferred coaching style: ${interventionStyle}

Return exactly 3 personalized, actionable recommendations as a JSON array with this exact structure (no other text):
[
  {
    "title": "short action title (max 8 words)",
    "body": "1–2 sentence specific instruction tailored to their schedule",
    "rationale": "1 sentence explaining why this helps given their specific data",
    "category": "one of: sleep, movement, schedule, nutrition, mindfulness, social, general"
  }
]`

    // ── Call OpenAI ──────────────────────────────────────────────────────────
    const openaiKey = Deno.env.get("OPENAI_API_KEY")
    if (!openaiKey) throw new Error("OPENAI_API_KEY environment variable is not set")

    const gptResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.7,
        max_tokens: 700,
      }),
    })

    if (!gptResponse.ok) {
      const errText = await gptResponse.text()
      throw new Error(`OpenAI API error ${gptResponse.status}: ${errText}`)
    }

    const gptData = await gptResponse.json()
    const rawContent: string = gptData.choices[0].message.content.trim()

    type AiRec = { title: string; body: string; rationale: string; category: string }
    let aiRecommendations: AiRec[]
    try {
      // Strip markdown code fences if GPT wraps in ```json ... ```
      const jsonStr = rawContent.replace(/^```(?:json)?\n?/, "").replace(/\n?```$/, "")
      aiRecommendations = JSON.parse(jsonStr)
    } catch {
      throw new Error(`Failed to parse GPT response as JSON. Raw: ${rawContent}`)
    }

    // ── Upsert stress prediction ─────────────────────────────────────────────
    await supabase
      .from("stress_predictions")
      .delete()
      .eq("user_id", user.id)
      .eq("target_date", targetDate)

    const { error: predError } = await supabase.from("stress_predictions").insert({
      user_id: user.id,
      target_date: targetDate,
      risk_level: riskLevel,
      score: stressScore,
      top_factors: topFactors,
    })
    if (predError) throw predError

    // ── Replace recommendations for this date ────────────────────────────────
    await supabase
      .from("recommendations")
      .delete()
      .eq("user_id", user.id)
      .eq("target_date", targetDate)

    const recRows = aiRecommendations.map((r) => ({
      user_id: user.id,
      target_date: targetDate,
      title: r.title,
      body: r.body,
      rationale: r.rationale,
      category: r.category,
    }))

    const { data: savedRecs, error: recError } = await supabase
      .from("recommendations")
      .insert(recRows)
      .select("id, title, body, rationale, category")
    if (recError) throw recError

    return new Response(
      JSON.stringify({
        stress_score: stressScore,
        risk_level: riskLevel,
        top_factors: topFactors,
        recommendations: savedRecs,
      }),
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
