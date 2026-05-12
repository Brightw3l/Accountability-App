import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type PreferredTimeOfDay =
  | "morning"
  | "afternoon"
  | "evening"
  | "night"
  | "anytime";

type AiVerificationType =
  | "manual"
  | "photo"
  | "partner"
  | "focus_auto"
  | "focus_partner";

type AiEvidenceType =
  | "none"
  | "photo"
  | "note"
  | "focus_session"
  | "focus_summary"
  | "focus_plus_note";

type ProgressionPolicy = {
  review_after_days: number;
  if_completion_rate_at_least: number;
  increase_duration_by_minutes: number;
  max_duration_minutes: number;
  if_completion_rate_below: number;
  adjustment_if_struggling: string;
};

type AiHabit = {
  title: string;
  description: string;
  target_frequency: "daily" | "weekdays" | "weekly" | "custom";
  duration_minutes: number;
  verification_type: AiVerificationType;
  evidence_type: AiEvidenceType;
  enforcement_level: 1 | 2 | 3;
  min_valid_minutes: number | null;
  min_completion_ratio: number | null;
  max_interruptions: number;
  grace_seconds: number;
  strict_fail_on_exit: boolean;
  requires_verifier: boolean;
  base_points: number;
  penalty_points: number;
  tier_weight: 1 | 2 | 3;
  preferred_time_of_day: PreferredTimeOfDay;
  preferred_days: number[];
  review_after_days: number;
  progression_policy: ProgressionPolicy;
};

type AiGoal = {
  title: string;
  description: string;
  category: string;
  why: string;
  success_metric: string;
  habits: AiHabit[];
};

type AiPlan = {
  goals: AiGoal[];
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function clampNumber(value: unknown, min: number, max: number, fallback: number) {
  if (typeof value !== "number" || Number.isNaN(value)) return fallback;
  return Math.min(max, Math.max(min, Math.round(value)));
}

function cleanString(value: unknown, fallback = "", maxLength = 500) {
  return String(value || fallback).trim().slice(0, maxLength);
}

function containsAny(text: string, words: string[]) {
  return words.some((word) => text.includes(word));
}

function normalizePreferredDays(
  rawDays: unknown,
  fallbackDays: number[],
): number[] {
  const raw = Array.isArray(rawDays) ? rawDays : fallbackDays;

  const cleaned = raw
    .map((day) => clampNumber(day, 1, 7, 1))
    .filter((day, index, array) => array.indexOf(day) === index)
    .sort((a, b) => a - b);

  if (cleaned.length === 0) return fallbackDays;
  return cleaned.slice(0, 6);
}

function normalizeProgressionPolicy(
  rawPolicy: unknown,
  duration: number,
  isCoreGrowthHabit: boolean,
): ProgressionPolicy {
  const policy =
    rawPolicy && typeof rawPolicy === "object"
      ? (rawPolicy as Record<string, unknown>)
      : {};

  return {
    review_after_days: clampNumber(policy.review_after_days, 7, 28, 14),
    if_completion_rate_at_least: Math.min(
      0.95,
      Math.max(
        0.7,
        typeof policy.if_completion_rate_at_least === "number"
          ? policy.if_completion_rate_at_least
          : 0.85,
      ),
    ),
    increase_duration_by_minutes: clampNumber(
      policy.increase_duration_by_minutes,
      5,
      20,
      isCoreGrowthHabit ? 15 : 5,
    ),
    max_duration_minutes: clampNumber(
      policy.max_duration_minutes,
      duration,
      180,
      isCoreGrowthHabit ? Math.max(duration, 90) : Math.max(duration, 45),
    ),
    if_completion_rate_below: Math.min(
      0.8,
      Math.max(
        0.2,
        typeof policy.if_completion_rate_below === "number"
          ? policy.if_completion_rate_below
          : 0.55,
      ),
    ),
    adjustment_if_struggling: cleanString(
      policy.adjustment_if_struggling,
      "Review timing, reduce friction, or split the habit into a smaller step.",
      220,
    ),
  };
}

function normalizePlan(raw: AiPlan): AiPlan {
  const goals = Array.isArray(raw.goals) ? raw.goals.slice(0, 2) : [];

  return {
    goals: goals.map((goal) => {
      const habits = Array.isArray(goal.habits) ? goal.habits.slice(0, 3) : [];

      return {
        title: cleanString(goal.title, "New Goal", 80),
        description: cleanString(goal.description, "", 500),
        category: cleanString(goal.category, "General", 40),
        why: cleanString(goal.why, "", 500),
        success_metric: cleanString(goal.success_metric, "", 300),
        habits: habits.map((habit) => {
          const rawTitle = cleanString(habit.title, "New Habit", 120)
            .toLowerCase();
          const rawDescription = cleanString(habit.description, "", 500)
            .toLowerCase();
          const combinedText = `${rawTitle} ${rawDescription}`;

          const isWorkoutHabit = containsAny(combinedText, [
            "workout",
            "exercise",
            "training",
            "gym",
            "run",
            "running",
            "fitness",
            "strength",
            "cardio",
          ]);

          const isCoreGrowthHabit =
            isWorkoutHabit ||
            containsAny(combinedText, [
              "study",
              "studying",
              "coding",
              "code",
              "programming",
              "write",
              "writing",
              "reading",
              "deep work",
              "skill",
              "practice",
              "exam",
              "revision",
              "homework",
              "project",
              "business",
              "work session",
            ]);

          const isSupportHabit = containsAny(combinedText, [
            "planning",
            "plan",
            "shutdown",
            "journal",
            "journaling",
            "stretch",
            "stretching",
            "phone away",
            "prepare",
            "prep",
            "reset",
            "tidy",
            "clean",
            "sleep",
            "bed",
            "wake",
            "morning routine",
            "night routine",
          ]);

          const minimumDuration = isCoreGrowthHabit
            ? isWorkoutHabit
              ? 45
              : 60
            : 10;

          const fallbackDuration = isCoreGrowthHabit
            ? isWorkoutHabit
              ? 60
              : 60
            : isSupportHabit
              ? 15
              : 30;

          const duration = clampNumber(
            habit.duration_minutes,
            minimumDuration,
            180,
            fallbackDuration,
          );

          let verificationType: AiVerificationType = [
            "manual",
            "photo",
            "partner",
            "focus_auto",
            "focus_partner",
          ].includes(habit.verification_type)
            ? habit.verification_type
            : "manual";

          const shouldUseFocus = containsAny(combinedText, [
            "study",
            "studying",
            "coding",
            "code",
            "programming",
            "write",
            "writing",
            "reading",
            "deep work",
            "focus",
            "exam",
            "revision",
            "homework",
          ]);

          const shouldUsePhoto = containsAny(combinedText, [
            "workout",
            "exercise",
            "training",
            "gym",
            "room",
            "clean",
            "tidy",
            "meal",
            "prep",
          ]);

          if (shouldUseFocus && verificationType === "manual") {
            verificationType = "focus_auto";
          }

          if (shouldUsePhoto && verificationType === "manual") {
            verificationType = "photo";
          }

          let evidenceType: AiEvidenceType = "none";

          if (verificationType === "photo") evidenceType = "photo";
          if (verificationType === "partner") evidenceType = "note";
          if (verificationType === "focus_auto") evidenceType = "focus_session";
          if (verificationType === "focus_partner") {
            evidenceType = "focus_plus_note";
          }

          const minValid =
            verificationType === "focus_auto" ||
            verificationType === "focus_partner"
              ? Math.max(1, Math.round(duration * 0.8))
              : null;

          const preferredTime = [
            "morning",
            "afternoon",
            "evening",
            "night",
            "anytime",
          ].includes(habit.preferred_time_of_day)
            ? habit.preferred_time_of_day
            : isWorkoutHabit
              ? "morning"
              : shouldUseFocus
                ? "evening"
                : "anytime";

          const targetFrequency = isWorkoutHabit
            ? "custom"
            : isCoreGrowthHabit
              ? "weekdays"
              : [
                  "daily",
                  "weekdays",
                  "weekly",
                  "custom",
                ].includes(habit.target_frequency)
                ? habit.target_frequency
                : "daily";

          const fallbackDays = isWorkoutHabit
            ? [1, 3, 5]
            : isCoreGrowthHabit
              ? [1, 2, 3, 4, 5]
              : [1, 2, 3, 4, 5, 6];

          const preferredDays = normalizePreferredDays(
            habit.preferred_days,
            fallbackDays,
          );

          const enforcementLevel = clampNumber(
            habit.enforcement_level,
            1,
            3,
            isCoreGrowthHabit ? 2 : 1,
          ) as 1 | 2 | 3;

          const basePoints = clampNumber(
            habit.base_points,
            5,
            50,
            isCoreGrowthHabit ? 25 : 10,
          );

          const penaltyPoints = clampNumber(
            habit.penalty_points,
            0,
            50,
            Math.round(basePoints * 0.5),
          );

          const progressionPolicy = normalizeProgressionPolicy(
            habit.progression_policy,
            duration,
            isCoreGrowthHabit,
          );

          return {
            title: cleanString(habit.title, "New Habit", 80),
            description: cleanString(habit.description, "", 500),
            target_frequency: targetFrequency,
            duration_minutes: duration,
            verification_type: verificationType,
            evidence_type: evidenceType,
            enforcement_level: enforcementLevel,
            min_valid_minutes: minValid,
            min_completion_ratio:
              verificationType === "focus_auto" ||
              verificationType === "focus_partner"
                ? 0.8
                : null,
            max_interruptions: clampNumber(
              habit.max_interruptions,
              0,
              5,
              verificationType.includes("focus") ? 2 : 0,
            ),
            grace_seconds: clampNumber(habit.grace_seconds, 0, 300, 60),
            strict_fail_on_exit:
              verificationType.includes("focus") && enforcementLevel === 3,
            requires_verifier:
              verificationType === "partner" ||
              verificationType === "focus_partner",
            base_points: basePoints,
            penalty_points: penaltyPoints,
            tier_weight: clampNumber(
              habit.tier_weight,
              1,
              3,
              isCoreGrowthHabit ? 2 : 1,
            ) as 1 | 2 | 3,
            preferred_time_of_day: preferredTime as PreferredTimeOfDay,
            preferred_days: preferredDays,
            review_after_days: progressionPolicy.review_after_days,
            progression_policy: progressionPolicy,
          };
        }),
      };
    }),
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const openAiKey = Deno.env.get("OPENAI_API_KEY");
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

    if (!openAiKey || !supabaseUrl || !supabaseAnonKey) {
      return jsonResponse(
        { error: "Missing required environment variables." },
        500,
      );
    }

    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return jsonResponse({ error: "Missing authorization header." }, 401);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: "Unauthorized." }, 401);
    }

    const body = await req.json().catch(() => null);
    const desire = String(body?.desire ?? "").trim();

    if (desire.length < 10) {
      return jsonResponse(
        { error: "Please describe your goal in a little more detail." },
        400,
      );
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("wake_time, sleep_time, strict_mode_enabled, plan_tier, timezone")
      .eq("id", user.id)
      .maybeSingle();

    const schema = {
      type: "object",
      additionalProperties: false,
      properties: {
        goals: {
          type: "array",
          minItems: 1,
          maxItems: 2,
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              title: { type: "string" },
              description: { type: "string" },
              category: { type: "string" },
              why: { type: "string" },
              success_metric: { type: "string" },
              habits: {
                type: "array",
                minItems: 1,
                maxItems: 3,
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    title: { type: "string" },
                    description: { type: "string" },
                    target_frequency: {
                      type: "string",
                      enum: ["daily", "weekdays", "weekly", "custom"],
                    },
                    duration_minutes: {
                      type: "integer",
                      minimum: 10,
                      maximum: 180,
                    },
                    verification_type: {
                      type: "string",
                      enum: [
                        "manual",
                        "photo",
                        "partner",
                        "focus_auto",
                        "focus_partner",
                      ],
                    },
                    evidence_type: {
                      type: "string",
                      enum: [
                        "none",
                        "photo",
                        "note",
                        "focus_session",
                        "focus_summary",
                        "focus_plus_note",
                      ],
                    },
                    enforcement_level: {
                      type: "integer",
                      enum: [1, 2, 3],
                    },
                    min_valid_minutes: {
                      anyOf: [{ type: "integer" }, { type: "null" }],
                    },
                    min_completion_ratio: {
                      anyOf: [{ type: "number" }, { type: "null" }],
                    },
                    max_interruptions: { type: "integer" },
                    grace_seconds: { type: "integer" },
                    strict_fail_on_exit: { type: "boolean" },
                    requires_verifier: { type: "boolean" },
                    base_points: { type: "integer" },
                    penalty_points: { type: "integer" },
                    tier_weight: {
                      type: "integer",
                      enum: [1, 2, 3],
                    },
                    preferred_time_of_day: {
                      type: "string",
                      enum: [
                        "morning",
                        "afternoon",
                        "evening",
                        "night",
                        "anytime",
                      ],
                    },
                    preferred_days: {
                      type: "array",
                      minItems: 1,
                      maxItems: 6,
                      items: {
                        type: "integer",
                        minimum: 1,
                        maximum: 7,
                      },
                    },
                    review_after_days: {
                      type: "integer",
                      minimum: 7,
                      maximum: 28,
                    },
                    progression_policy: {
                      type: "object",
                      additionalProperties: false,
                      properties: {
                        review_after_days: {
                          type: "integer",
                          minimum: 7,
                          maximum: 28,
                        },
                        if_completion_rate_at_least: {
                          type: "number",
                          minimum: 0.7,
                          maximum: 0.95,
                        },
                        increase_duration_by_minutes: {
                          type: "integer",
                          minimum: 5,
                          maximum: 20,
                        },
                        max_duration_minutes: {
                          type: "integer",
                          minimum: 10,
                          maximum: 180,
                        },
                        if_completion_rate_below: {
                          type: "number",
                          minimum: 0.2,
                          maximum: 0.8,
                        },
                        adjustment_if_struggling: {
                          type: "string",
                        },
                      },
                      required: [
                        "review_after_days",
                        "if_completion_rate_at_least",
                        "increase_duration_by_minutes",
                        "max_duration_minutes",
                        "if_completion_rate_below",
                        "adjustment_if_struggling",
                      ],
                    },
                  },
                  required: [
                    "title",
                    "description",
                    "target_frequency",
                    "duration_minutes",
                    "verification_type",
                    "evidence_type",
                    "enforcement_level",
                    "min_valid_minutes",
                    "min_completion_ratio",
                    "max_interruptions",
                    "grace_seconds",
                    "strict_fail_on_exit",
                    "requires_verifier",
                    "base_points",
                    "penalty_points",
                    "tier_weight",
                    "preferred_time_of_day",
                    "preferred_days",
                    "review_after_days",
                    "progression_policy",
                  ],
                },
              },
            },
            required: [
              "title",
              "description",
              "category",
              "why",
              "success_metric",
              "habits",
            ],
          },
        },
      },
      required: ["goals"],
    };

    const systemPrompt = `
You are BRIGHT, the AI accountability planner for Achievr.

Your job is to convert the user's desire into a strict but realistic accountability plan.

You are not a motivational chatbot. You are an accountability planner.
Do not simply give the user what they want. Give them what they need:
clear, measurable, repeatable execution habits that create growth.

Planning philosophy:
- Be strict, but not impossible.
- Create a plan the user can actually execute for months.
- Prefer real growth over easy comfort.
- Do not overload the user with too many habits.
- Every goal must have at least one serious execution habit.
- A serious execution habit is usually 60 to 90 minutes.
- Support habits may be shorter if they only prepare or protect execution.

Goal rules:
- Create 1 to 2 goals only.
- Each goal should have 1 to 3 habits.
- Avoid vague goals.
- Avoid vague habits.
- Every habit must have a clear duration and verification method.

Frequency rules:
- Important growth habits should be scheduled at least 4 times per week.
- Use "weekdays" for most serious school, study, coding, and work habits.
- Be lighter on weekends unless the user explicitly asks for weekend intensity.
- If the user asks for fitness, prefer 3 to 4 workouts per week, not daily hard workouts.
- If the user asks for sleep or routine repair, use daily support habits but keep them short.
- preferred_days uses ISO weekday numbers: Monday=1, Tuesday=2, Wednesday=3, Thursday=4, Friday=5, Saturday=6, Sunday=7.
- For study, coding, and work, prefer [1,2,3,4,5].
- For workouts, prefer [1,3,5] or [1,3,5,6].
- Use Saturday lightly. Avoid Sunday unless the user explicitly wants Sunday work.

Duration rules:
- Study, coding, writing, deep work, reading, and serious skill practice should usually be 60 minutes.
- Workouts should usually be 45 to 75 minutes.
- Planning, shutdown, journaling, stretching, and preparation habits may be 10 to 30 minutes.
- Do not create 5 minute habits.
- Do not create extreme 2 to 3 hour habits during onboarding unless the user explicitly asks for that and has enough time.

Verification rules:
- Use focus_auto for study, coding, writing, reading, deep work, and phone-free work.
- Use focus_partner for high-stakes study/work when the user seems to need stronger accountability.
- Use photo when visual proof makes sense, such as workout completion, room reset, meal prep, or physical evidence.
- Use partner when another person should verify completion.
- Use manual only for low-risk support habits or habits that cannot be fairly verified.
- Do not use location habits in onboarding v1.
- Verification must be fair. Do not require proof that the user cannot reasonably provide.

Enforcement rules:
- enforcement_level: 1 = soft, 2 = normal, 3 = strict.
- Use enforcement_level 2 for most habits.
- Use enforcement_level 3 only when the habit is central and objectively verifiable.
- Avoid strict_fail_on_exit unless focus verification is used and the task requires real focus.

Points rules:
- Support habits: 5 to 10 base points.
- Normal habits: 10 to 20 base points.
- Serious 60+ minute execution habits: 20 to 35 base points.
- Penalty should usually be 40% to 60% of base points.

Progression rules:
- Every habit needs a progression_policy.
- Review serious habits after 14 days.
- If completion rate is at least 85%, increase duration by 10 to 15 minutes or add a weekly session.
- If completion rate is below 55%, recommend moving the time, reducing friction, or splitting the task.
- Never make the plan harder after poor consistency.
- Growth should be gradual.

Schedule preference rules:
- preferred_time_of_day should match the task.
- Study/deep work after school or work should usually be evening.
- Morning is good for planning, workouts, reading, or routine setup.
- Night is only for shutdown, sleep prep, or light reflection.
- Do not schedule exact times. Use preferred_time_of_day and preferred_days only.

Return only valid JSON matching the schema.
`;

    const userPrompt = {
      desire,
      profile_context: {
        wake_time: profile?.wake_time ?? null,
        sleep_time: profile?.sleep_time ?? null,
        strict_mode_enabled: profile?.strict_mode_enabled ?? true,
        plan_tier: profile?.plan_tier ?? "free",
        timezone: profile?.timezone ?? "UTC",
      },
    };

    const openAiResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openAiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        input: [
          {
            role: "system",
            content: systemPrompt,
          },
          {
            role: "user",
            content: JSON.stringify(userPrompt),
          },
        ],
        text: {
          format: {
            type: "json_schema",
            name: "achievr_ai_onboarding_plan",
            strict: true,
            schema,
          },
        },
      }),
    });

    if (!openAiResponse.ok) {
      const errorBody = await openAiResponse.text();
      console.error("OpenAI error:", errorBody);

      return jsonResponse(
        {
          error: "Failed to generate AI plan.",
          details: errorBody,
        },
        500,
      );
    }

    const openAiJson = await openAiResponse.json();

    const outputText =
      openAiJson.output_text ??
      openAiJson.output
        ?.flatMap((item: any) => item.content ?? [])
        ?.find((content: any) => content.type === "output_text")?.text;

    if (!outputText) {
      return jsonResponse(
        { error: "OpenAI returned no structured output." },
        500,
      );
    }

    const rawPlan = JSON.parse(outputText) as AiPlan;
    const plan = normalizePlan(rawPlan);

    if (!plan.goals.length) {
      return jsonResponse({ error: "AI did not create a usable plan." }, 500);
    }

    const { data: savedPlan, error: saveError } = await supabase
      .from("ai_onboarding_plans")
      .insert({
        user_id: user.id,
        user_desire: desire,
        plan_payload: plan,
        status: "draft",
        model_provider: "openai",
        model_name: "gpt-4o-mini",
      })
      .select("plan_id")
      .single();

    if (saveError) {
      console.error("Failed to save AI plan:", saveError);

      return jsonResponse(
        {
          error: "Generated plan, but failed to save it.",
          details: saveError.message,
        },
        500,
      );
    }

    return jsonResponse({
      plan_id: savedPlan.plan_id,
      plan,
    });
  } catch (error) {
    console.error(error);

    return jsonResponse(
      {
        error: "Unexpected server error.",
        details: String(error),
      },
      500,
    );
  }
});