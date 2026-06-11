/**
 * iOS ↔ worker chat wire-contract tests.
 *
 * The iOS client encodes bodies with plain camelCase keys (no snake_case
 * conversion) and lowercase UUID strings. These tests pin that contract on
 * the worker side so a drift on either end fails loudly here instead of as
 * an opaque 400 in the app.
 */
import { describe, expect, it } from "vitest";
import {
  ChatBody,
  accumulateToolCallDelta,
  friendlyToolLabel,
  type PendingToolCall,
} from "../src/routes/chat-stream";
import { ALL_TOOLS } from "../src/tools/registry";
import { SnapshotShape } from "../src/tools/getHealthSnapshot";

describe("ChatBody wire contract", () => {
  it("accepts the canonical iOS payload (camelCase keys, ISO snapshot date, lowercase uuid)", () => {
    const payload = {
      text: "I just ate 100g of grilled chicken",
      healthSnapshot: {
        rhr: 52,
        hrv: 61.5,
        sleepHours: 7.4,
        weightKg: 70.0,
        capturedAt: "2026-06-11T08:30:00Z",
      },
      attachments: [
        { fileId: "7f9c24e5-2c31-4b3a-9d6e-8a1f0b2c3d4e", kind: "image" },
      ],
    };
    const parsed = ChatBody.safeParse(payload);
    expect(parsed.success).toBe(true);
  });

  it("accepts a minimal payload with only text", () => {
    expect(ChatBody.safeParse({ text: "hi" }).success).toBe(true);
  });

  it("rejects legacy snake_case keys so contract drift is caught loudly", () => {
    const parsed = ChatBody.safeParse({
      text: "hi",
      health_snapshot: { rhr: 52 },
    });
    expect(parsed.success).toBe(false);
  });

  it("rejects uppercase attachment file ids only if not a valid uuid shape", () => {
    // Uppercase UUIDs are valid per RFC — lookups are the case-sensitive part,
    // which is why the client lowercases. The schema itself stays permissive.
    const parsed = ChatBody.safeParse({
      text: "hi",
      attachments: [{ fileId: "7F9C24E5-2C31-4B3A-9D6E-8A1F0B2C3D4E", kind: "pdf" }],
    });
    expect(parsed.success).toBe(true);
  });
});

describe("SnapshotShape health snapshot contract", () => {
  const canonicalSnapshot = {
    rhr: 52,
    hrv: 61.5,
    sleepHours: 7.4,
    steps: 8421,
    activeEnergyKcal: 412.3,
    weightKg: 70.0,
    heightCm: 178.0,
    respiratoryRate: 14.2,
    sleepCoreMinutes: 240.5,
    sleepDeepMinutes: 62.0,
    sleepRemMinutes: 88.5,
    hrvBaseline60d: 58.7,
    rhrBaseline60d: 54.1,
    capturedAt: "2026-06-11T08:30:00Z",
    missing: ["weightKg", "heightCm"],
  };

  it("parses the canonical iOS snapshot, retaining rhr (not heartRateAvg)", () => {
    const parsed = SnapshotShape.safeParse(canonicalSnapshot);
    expect(parsed.success).toBe(true);
    if (!parsed.success) return;
    expect(parsed.data.rhr).toBe(52);
    expect(parsed.data).not.toHaveProperty("heartRateAvg");
    expect(parsed.data.missing).toEqual(["weightKg", "heightCm"]);
    expect(parsed.data.hrvBaseline60d).toBe(58.7);
    expect(parsed.data.sleepDeepMinutes).toBe(62.0);
  });

  it("accepts a sparse snapshot and passes unknown keys through", () => {
    const parsed = SnapshotShape.safeParse({
      rhr: 49,
      capturedAt: "2026-06-11T08:30:00Z",
      missing: ["hrv", "sleepHours"],
      futureField: "kept",
    });
    expect(parsed.success).toBe(true);
    if (!parsed.success) return;
    expect(parsed.data.rhr).toBe(49);
    expect(parsed.data.futureField).toBe("kept");
  });
});

describe("accumulateToolCallDelta", () => {
  it("reassembles a tool call streamed across multiple chunks", () => {
    const map = new Map<number, PendingToolCall>();
    accumulateToolCallDelta(map, { index: 0, id: "call_1", name: "addFoodEntry" });
    accumulateToolCallDelta(map, { index: 0, argumentsDelta: '{"name":"chi' });
    accumulateToolCallDelta(map, { index: 0, argumentsDelta: 'cken","kcal":165}' });
    expect(map.get(0)).toEqual({
      id: "call_1",
      name: "addFoodEntry",
      arguments: '{"name":"chicken","kcal":165}',
    });
  });

  it("keeps parallel tool calls separate by index", () => {
    const map = new Map<number, PendingToolCall>();
    accumulateToolCallDelta(map, { index: 0, id: "a", name: "getDayLog", argumentsDelta: "{}" });
    accumulateToolCallDelta(map, { index: 1, id: "b", name: "getHealthSnapshot" });
    accumulateToolCallDelta(map, { index: 1, argumentsDelta: "{}" });
    expect(map.size).toBe(2);
    expect(map.get(1)).toEqual({ id: "b", name: "getHealthSnapshot", arguments: "{}" });
  });
});

describe("friendlyToolLabel", () => {
  it("has a human label for every registered tool (no drift)", () => {
    for (const tool of ALL_TOOLS) {
      const label = friendlyToolLabel(tool.name);
      expect(label, `missing friendly label for tool "${tool.name}"`).not.toBe(
        `Running ${tool.name}`
      );
    }
  });
});
