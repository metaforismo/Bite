import { and, eq, sql } from "drizzle-orm";
import { z } from "zod";
import { artifacts, strengthSessions, strengthSets } from "../db/schema";
import { defineTool } from "./types";

const SetIn = z.object({
  exerciseName: z.string().min(1).max(80),
  setIndex: z.number().int().nonnegative(),
  weightLb: z.number().nonnegative().max(2000),
  reps: z.number().int().nonnegative().max(200),
  completedAt: z.number().optional(),
});

const Output = z.object({
  sessionId: z.string(),
  workoutArtifactId: z.string().nullable(),
  artifactVersion: z.number().int().nullable(),
  setsLogged: z.number().int(),
});

export const completeWorkoutTool = defineTool({
  name: "completeWorkout",
  description:
    "Record a finished strength session. Persists every (exercise, set) row " +
    "and bumps the originating workout artifact's version so the chat UI " +
    "morphs the card to its completed state.",
  input: z.object({
    workoutArtifactId: z.string().uuid().optional(),
    title: z.string().min(1).max(120),
    startedAt: z.number(),
    completedAt: z.number().optional(),
    sets: z.array(SetIn).min(1).max(200),
  }).strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      workoutArtifactId: { type: "string", description: "UUID of the originating workout artifact" },
      title: { type: "string" },
      startedAt: { type: "number" },
      completedAt: { type: "number" },
      sets: {
        type: "array",
        items: {
          type: "object",
          properties: {
            exerciseName: { type: "string" },
            setIndex: { type: "integer" },
            weightLb: { type: "number" },
            reps: { type: "integer" },
            completedAt: { type: "number" },
          },
          required: ["exerciseName", "setIndex", "weightLb", "reps"],
        },
      },
    },
    required: ["title", "startedAt", "sets"],
    additionalProperties: false,
  },
  async run(args, ctx) {
    const sessionId = crypto.randomUUID();
    const completedAt = args.completedAt ?? Date.now();
    await ctx.db.insert(strengthSessions).values({
      id: sessionId,
      firebaseUid: ctx.uid,
      workoutArtifactId: args.workoutArtifactId ?? null,
      title: args.title,
      startedAt: args.startedAt,
      completedAt,
    });

    for (const set of args.sets) {
      await ctx.db.insert(strengthSets).values({
        id: crypto.randomUUID(),
        firebaseUid: ctx.uid,
        sessionId,
        exerciseName: set.exerciseName,
        setIndex: set.setIndex,
        weightLb: set.weightLb,
        reps: set.reps,
        completedAt: set.completedAt ?? completedAt,
      });
    }

    let artifactVersion: number | null = null;
    if (args.workoutArtifactId) {
      const updated = await ctx.db
        .update(artifacts)
        .set({ version: sql`${artifacts.version} + 1` })
        .where(
          and(
            eq(artifacts.id, args.workoutArtifactId),
            eq(artifacts.firebaseUid, ctx.uid)
          )
        )
        .returning({ version: artifacts.version });
      artifactVersion = updated[0]?.version ?? null;
    }

    return {
      sessionId,
      workoutArtifactId: args.workoutArtifactId ?? null,
      artifactVersion,
      setsLogged: args.sets.length,
    };
  },
});
