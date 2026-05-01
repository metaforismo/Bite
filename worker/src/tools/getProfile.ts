import { z } from "zod";
import { eq } from "drizzle-orm";
import { users } from "../db/schema";
import { defineTool } from "./types";

/**
 * Read the user's profile (goals + biometrics + preferences).
 *
 * The iOS app is the canonical owner of the profile and writes it via the
 * profile sync route (PATCH /v1/users/me — set up separately). Here we just
 * read whatever is on the row, returning a permissive shape so a missing
 * profile resolves to an empty object rather than a hard error.
 */

export const profileShape = z
  .object({
    name: z.string().optional(),
    email: z.string().optional(),
    calorieGoal: z.number().optional(),
    proteinGoal: z.number().optional(),
    carbsGoal: z.number().optional(),
    fatGoal: z.number().optional(),
    fiberGoal: z.number().nullable().optional(),
    sugarGoal: z.number().nullable().optional(),
    sodiumGoal: z.number().nullable().optional(),
    gender: z.string().nullable().optional(),
    age: z.number().nullable().optional(),
    heightCm: z.number().nullable().optional(),
    weightKg: z.number().nullable().optional(),
    targetWeightKg: z.number().nullable().optional(),
    activityLevel: z.string().nullable().optional(),
    calorieBias: z.string().nullable().optional(),
    weightGoalType: z.string().optional(),
    targetDate: z.string().nullable().optional(),
    dietaryPreferences: z.array(z.string()).optional(),
    dietaryNotes: z.string().optional(),
    coachPersonality: z.string().nullable().optional(),
  })
  .passthrough();

const Output = z.object({
  exists: z.boolean(),
  profile: profileShape,
  updatedAt: z.number().nullable(),
});

export const getProfileTool = defineTool({
  name: "getProfile",
  description:
    "Read the user's profile: name, calorie/macro goals, biometrics, dietary preferences, " +
    "activity level, and weight goal. Use this when the user asks about their goals, when " +
    "you need biometrics to compute estimates, or before suggesting changes to plans.",
  input: z.object({}).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {},
    additionalProperties: false,
  },
  async run(_args, ctx) {
    const rows = await ctx.db
      .select()
      .from(users)
      .where(eq(users.firebaseUid, ctx.uid))
      .limit(1);
    const row = rows[0];
    if (!row) {
      return { exists: false, profile: {}, updatedAt: null };
    }
    let profile: Record<string, unknown> = {};
    if (row.profileJSON) {
      try {
        const parsed = JSON.parse(row.profileJSON);
        if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
          profile = parsed as Record<string, unknown>;
        }
      } catch {
        // Corrupt JSON — surface an empty profile rather than failing the turn.
        profile = {};
      }
    }
    if (row.email && profile.email == null) profile.email = row.email;
    if (row.displayName && profile.name == null) profile.name = row.displayName;
    return {
      exists: true,
      profile,
      updatedAt: row.profileUpdatedAt ?? null,
    };
  },
});
