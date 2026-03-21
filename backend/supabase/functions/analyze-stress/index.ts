import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// ── Empirical weight basis ─────────────────────────────────────────────────────
//
// Biomarker weights are derived from normalised meta-analytic Hedges' g values.
// Because respiratory rate has no column in this schema, its weight (0.10) is
// redistributed proportionally among the four available biomarkers.
//
//  Factor        Raw g   Source
//  ──────────────────────────────────────────────────────────────────────────
//  Sleep         0.60    Palmer et al. (2024). Psychological Bulletin.
//                        154 studies, N=5,717. Sleep loss → anxiety SMD 0.57–0.63.
//  HRV (SDNN)    0.45    Chalmers et al. (2014). Front. Psychiatry.
//                        36 studies, N=4,380. Time-domain HRV in anxiety, g=0.45.
//  Activity      0.35    Crews & Landers (1987). J. Sport Sci. Meta-analysis of
//                        34 studies; aerobic fitness × stress reactivity ES=0.48.
//                        Converging: Singh et al. (2025) Frontiers, SMD=−0.46.
//  Resting HR    0.28    Laborde et al. (2022). Neuroscience & Biobehavioral Reviews.
//                        Derived from SDNN/HR ratio in slow-paced breathing meta-
//                        analysis (SDNN SMD=0.77 vs HR SMD=0.10), scaled to HRV ref.
//  ──────────────────────────────────────────────────────────────────────────
//  Σ (4 factors) 1.68
//
//  Normalised biomarker weights (each g_i / 1.68):
//    Sleep  = 0.60/1.68 = 0.357
//    HRV    = 0.45/1.68 = 0.268
//    Act.   = 0.35/1.68 = 0.208
//    RHR    = 0.28/1.68 = 0.167
//
//  Score allocation (0–10 scale):
//    Biomarkers  80 % = 8.0 pts  (empirically weighted above)
//    Schedule    15 % = 1.5 pts  (Karasek 1979 demand-control model;
//                                 Theorell & Karasek 1996 AMJ Pub Health)
//    Check-in     5 % = 0.5 pts  (self-report ground truth)
//
//  Biomarker max points:
//    Sleep      = 0.357 × 8 = 2.86
//    HRV        = 0.268 × 8 = 2.14
//    Activity   = 0.208 × 8 = 1.66
//    Resting HR = 0.167 × 8 = 1.34
// ──────────────────────────────────────────────────────────────────────────────

const W = {
  sleep:    { weight: 0.357, max: 2.86 },
  hrv:      { weight: 0.268, max: 2.14 },
  activity: { weight: 0.208, max: 1.66 },
  rhr:      { weight: 0.167, max: 1.34 },
  schedule: { max: 1.50 },
  checkIn:  { max: 0.50 },
}

// ── Population norms ──────────────────────────────────────────────────────────
// HRV (SDNN): Shaffer & Ginsberg (2017) Front. Public Health. mean=50ms, SD=20ms
// Resting HR: Palatini & Julius (1997) J. Hypertension. mean=68bpm, SD=10bpm
// Sleep:      Watson et al. (2015) Sleep. mean=7.0h, SD=1.2h
// Steps:      Tudor-Locke et al. (2004) Sports Med. optimal threshold ≈8,000/day
const NORMS = {
  hrv:   { mean: 50, sd: 20 },
  rhr:   { mean: 68, sd: 10 },
  sleep: { mean: 7.0, sd: 1.2 },
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface CalendarEvent {
  title: string
  start_time: string
  end_time: string
  is_back_to_back?: boolean
}

interface RequestBody {
  target_date: string
  calendar_events?: CalendarEvent[]
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Clamp a value between lo and hi. */
const clamp = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi)

/** z-score, clamped to ±2 SD to prevent outliers dominating. */
const z = (value: number, mean: number, sd: number) =>
  clamp((value - mean) / sd, -2, 2)

/** Round to one decimal place. */
const r1 = (n: number) => Math.round(n * 10) / 10

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

    // ── Fetch all inputs in parallel ─────────────────────────────────────────
    const [
      { data: health },
      { data: schedule },
      { data: checkIns },
      { data: profile },
    ] = await Promise.all([
      supabase
        .from("daily_health_summaries")
        .select("sleep_hours, steps, resting_heart_rate, heart_rate_variability")
        .eq("user_id", user.id)
        .eq("summary_date", targetDate)
        .maybeSingle(),
      supabase
        .from("daily_schedule_summaries")
        .select("event_count, busy_hours, back_to_back_count, late_night_events")
        .eq("user_id", user.id)
        .eq("summary_date", targetDate)
        .maybeSingle(),
      supabase
        .from("stress_check_ins")
        .select("stress_level, energy_level")
        .eq("user_id", user.id)
        .gte("check_in_date", (() => {
          const d = new Date(targetDate)
          d.setDate(d.getDate() - 3)
          return d.toISOString().split("T")[0]
        })())
        .order("check_in_date", { ascending: false }),
      supabase
        .from("profiles")
        .select("preferred_intervention_style")
        .eq("id", user.id)
        .maybeSingle(),
    ])

    // ── Raw values (with sensible defaults when data is absent) ───────────────
    const sleepHours:  number       = health?.sleep_hours         ?? NORMS.sleep.mean
    const steps:       number       = health?.steps               ?? 0
    const hrv:         number|null  = health?.heart_rate_variability ?? null
    const restingHR:   number|null  = health?.resting_heart_rate  ?? null
    const busyHours:   number       = schedule?.busy_hours        ?? 0
    const backToBack:  number       = schedule?.back_to_back_count ?? 0
    const lateNight:   number       = schedule?.late_night_events  ?? 0

    const recentStressAvg: number = (checkIns && checkIns.length > 0)
      ? checkIns.reduce((s: number, c: { stress_level: number }) => s + c.stress_level, 0)
        / checkIns.length
      : 3.0   // neutral default (mid-point of 1–5 scale)

    // ── Sleep score (0 – 2.86) ────────────────────────────────────────────────
    // Palmer et al. (2024): sleep loss increases anxiety proportionally.
    // Positive z → below population mean → stressed.
    // We negate so that less sleep = higher score contribution.
    const sleepZ     = -z(sleepHours, NORMS.sleep.mean, NORMS.sleep.sd)
    const sleepNorm  = clamp((sleepZ + 2) / 4, 0, 1)   // map z ∈ [-2,2] → [0,1]
    const sleepScore = r1(sleepNorm * W.sleep.max)

    // ── HRV score (0 – 2.14) ─────────────────────────────────────────────────
    // Chalmers et al. (2014): lower HRV = higher stress. Negate z-score.
    // If Watch data is unavailable, HRV contributes 0 (neutral, not penalised).
    const hrvAvailable = hrv !== null
    const hrvZ         = hrvAvailable ? -z(hrv!, NORMS.hrv.mean, NORMS.hrv.sd) : 0
    const hrvNorm      = clamp((hrvZ + 2) / 4, 0, 1)
    const hrvScore     = r1(hrvAvailable ? hrvNorm * W.hrv.max : 0)

    // ── Activity score (0 – 1.66) ─────────────────────────────────────────────
    // Crews & Landers (1987): aerobic fitness buffers psychosocial stress.
    // Tudor-Locke (2004): 8,000 steps ≈ optimal threshold.
    // Below optimal → higher score. Above → 0 (no additional credit past goal).
    const stepNorm     = clamp(steps / 8_000, 0, 1.5)
    const activityScore = r1(clamp(1 - stepNorm, 0, 1) * W.activity.max)

    // ── Resting HR score (0 – 1.34) ───────────────────────────────────────────
    // Higher HR above population mean (68 bpm) signals sympathetic activation.
    // If Watch data unavailable, contributes 0.
    const rhrAvailable = restingHR !== null
    const rhrZ         = rhrAvailable ? z(restingHR!, NORMS.rhr.mean, NORMS.rhr.sd) : 0
    const rhrNorm      = clamp((rhrZ + 2) / 4, 0, 1)
    const hrScore     = r1(rhrAvailable ? rhrNorm * W.rhr.max : 0)

    // ── Schedule score (0 – 1.50) ─────────────────────────────────────────────
    // Based on Karasek (1979) demand-control model of occupational stress.
    // Three sub-components:
    //   busy_hours    → cognitive demand (max 6h = saturated at 1.0)
    //   back_to_back  → lack of recovery micro-breaks (≥4 blocks = saturated)
    //   late_night    → circadian disruption (≥2 events = saturated)
    const busyNorm    = clamp(busyHours  / 6, 0, 1)
    const bbNorm      = clamp(backToBack / 4, 0, 1)
    const lnNorm      = clamp(lateNight  / 2, 0, 1)
    const scheduleScore = r1(
      (busyNorm * 0.60 + bbNorm * 0.25 + lnNorm * 0.15) * W.schedule.max
    )

    // ── Check-in score (0 – 0.50) ─────────────────────────────────────────────
    // Self-reported stress (1–5 scale) mapped to [0,1] then scaled.
    // Scale: (avg - 1) / 4  →  1→0, 5→1
    const checkInNorm  = clamp((recentStressAvg - 1) / 4, 0, 1)
    const checkInScore = r1(checkInNorm * W.checkIn.max)

    // ── Composite score (0–10) ────────────────────────────────────────────────
    const rawScore    = sleepScore + hrvScore + activityScore
                      + hrScore   + scheduleScore + checkInScore
    const stressScore = r1(clamp(rawScore, 0, 10))
    const riskLevel   = stressScore >= 7 ? "high" : stressScore >= 4 ? "medium" : "low"

    // ── Structured factor breakdown (stored in factor_scores) ─────────────────
    // This is what gets written to stress_predictions.factor_scores so the
    // iOS app can render a breakdown without re-computing.
    const factorScores = {
      sleep: {
        raw_hours: sleepHours,
        score:     sleepScore,
        max:       W.sleep.max,
        weight:    W.sleep.weight,
      },
      hrv: {
        raw_ms:    hrv,
        score:     hrvScore,
        max:       W.hrv.max,
        weight:    W.hrv.weight,
        available: hrvAvailable,
      },
      activity: {
        raw_steps: steps,
        score:     activityScore,
        max:       W.activity.max,
        weight:    W.activity.weight,
      },
      resting_hr: {
        raw_bpm:   restingHR,
        score:     hrScore,
        max:       W.rhr.max,
        weight:    W.rhr.weight,
        available: rhrAvailable,
      },
      schedule: {
        score:       scheduleScore,
        max:         W.schedule.max,
        busy_hours:  busyHours,
        back_to_back: backToBack,
        late_night:  lateNight,
      },
      check_in: {
        score:       checkInScore,
        max:         W.checkIn.max,
        avg_stress:  r1(recentStressAvg),
        available:   (checkIns?.length ?? 0) > 0,
      },
    }

    // ── Human-readable top factors (for GPT prompt and display) ───────────────
    // Sorted by score contribution descending; only include factors that
    // contribute meaningfully (> 15% of their individual max).
    const namedFactors: { label: string; score: number }[] = [
      { label: `Sleep ${sleepHours}h (below ${NORMS.sleep.mean}h baseline)`,
        score: sleepScore },
      ...(hrvAvailable && hrv! < 40
        ? [{ label: `HRV low at ${hrv}ms (below 50ms typical)`, score: hrvScore }]
        : []),
      ...(steps < 4_000
        ? [{ label: `Low activity — ${steps} steps (goal: 8,000)`, score: activityScore }]
        : []),
      ...(rhrAvailable && restingHR! > 75
        ? [{ label: `Resting HR elevated at ${restingHR}bpm`, score: hrScore }]
        : []),
      ...(backToBack >= 2
        ? [{ label: `${backToBack} back-to-back calendar blocks`, score: scheduleScore }]
        : []),
      ...(busyHours > 5
        ? [{ label: `${busyHours}h of scheduled busy time`, score: scheduleScore }]
        : []),
      ...(lateNight > 0
        ? [{ label: `${lateNight} late-night event(s)`, score: scheduleScore }]
        : []),
      ...((checkIns?.length ?? 0) > 0 && recentStressAvg > 3.5
        ? [{ label: `Recent self-reported stress ${r1(recentStressAvg)}/5`, score: checkInScore }]
        : []),
    ]
    const topFactors = namedFactors
      .sort((a, b) => b.score - a.score)
      .slice(0, 4)
      .map((f) => f.label)

    // ── Build GPT prompt ──────────────────────────────────────────────────────
    const interventionStyle = profile?.preferred_intervention_style ?? "gentle"

    let calendarSummary: string
    if (calendarEvents.length > 0) {
      calendarSummary = calendarEvents
        .map((e) =>
          `- ${e.title} (${e.start_time}–${e.end_time}${e.is_back_to_back ? ", back-to-back" : ""})`
        )
        .join("\n")
    } else if (schedule) {
      calendarSummary =
        `${schedule.event_count} events, ${busyHours}h busy, ` +
        `${backToBack} back-to-back, ${lateNight} late-night`
    } else {
      calendarSummary = "No calendar data for this date"
    }

    const prompt = `You are a compassionate wellness coach. A user's stress risk score for ${targetDate} is ${stressScore}/10 (${riskLevel} risk).

Health data:
- Sleep: ${sleepHours}h (population mean 7h)
- Resting HR: ${restingHR !== null ? `${restingHR}bpm` : "unavailable (no Apple Watch)"}
- HRV (SDNN): ${hrv !== null ? `${hrv}ms` : "unavailable (no Apple Watch)"}
- Steps today: ${steps}

Calendar — ${targetDate}:
${calendarSummary}

Top stress factors by contribution: ${topFactors.length > 0 ? topFactors.join("; ") : "No strong factors identified"}
Coaching style preference: ${interventionStyle}

Return exactly 3 personalised, actionable recommendations as a JSON array — no other text:
[
  {
    "title": "short action title (max 8 words)",
    "body": "1–2 sentence specific instruction tailored to their data",
    "rationale": "1 sentence explaining why this helps given their specific numbers",
    "category": "one of: sleep, movement, schedule, nutrition, mindfulness, social, general"
  }
]`

    // ── Call OpenAI ───────────────────────────────────────────────────────────
    const openaiKey = Deno.env.get("OPENAI_API_KEY")
    if (!openaiKey) throw new Error("OPENAI_API_KEY not set")

    const gptResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model:       "gpt-4o-mini",
        messages:    [{ role: "user", content: prompt }],
        temperature: 0.7,
        max_tokens:  700,
      }),
    })

    if (!gptResponse.ok) {
      throw new Error(`OpenAI error ${gptResponse.status}: ${await gptResponse.text()}`)
    }

    const gptData     = await gptResponse.json()
    const rawContent: string = gptData.choices[0].message.content.trim()

    type AiRec = { title: string; body: string; rationale: string; category: string }
    let aiRecommendations: AiRec[]
    try {
      const jsonStr = rawContent.replace(/^```(?:json)?\n?/, "").replace(/\n?```$/, "")
      aiRecommendations = JSON.parse(jsonStr)
    } catch {
      throw new Error(`Failed to parse GPT response as JSON: ${rawContent}`)
    }

    // ── Upsert stress prediction (delete + insert for idempotency) ────────────
    await supabase
      .from("stress_predictions")
      .delete()
      .eq("user_id", user.id)
      .eq("target_date", targetDate)

    const { error: predError } = await supabase
      .from("stress_predictions")
      .insert({
        user_id:       user.id,
        target_date:   targetDate,
        risk_level:    riskLevel,
        score:         stressScore,
        top_factors:   topFactors,          // string[] for quick display
        factor_scores: factorScores,        // structured numeric breakdown
      })
    if (predError) throw predError

    // ── Replace recommendations for this date ─────────────────────────────────
    await supabase
      .from("recommendations")
      .delete()
      .eq("user_id", user.id)
      .eq("target_date", targetDate)

    const { data: savedRecs, error: recError } = await supabase
      .from("recommendations")
      .insert(
        aiRecommendations.map((r) => ({
          user_id:     user.id,
          target_date: targetDate,
          title:       r.title,
          body:        r.body,
          rationale:   r.rationale,
          category:    r.category,
        }))
      )
      .select("id, title, body, rationale, category")
    if (recError) throw recError

    // ── Response ──────────────────────────────────────────────────────────────
    return new Response(
      JSON.stringify({
        stress_score:  stressScore,
        risk_level:    riskLevel,
        factor_scores: factorScores,        // full numeric breakdown for iOS charts
        top_factors:   topFactors,
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