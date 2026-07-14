import { describe, it, expect } from "vitest";
import { getTagColor, tagStyle } from "./tag-colors";

describe("getTagColor", () => {
  it("returns a stable color for the same name", () => {
    expect(getTagColor("vip")).toBe(getTagColor("vip"));
  });

  it("returns different colors for names that hash to different buckets", () => {
    const colors = new Set(
      ["vip", "urgent", "spam", "lead", "billing", "support"].map(getTagColor)
    );
    // Not all identical — the stub returned one constant color for everything.
    expect(colors.size).toBeGreaterThan(1);
  });

  it("never returns the old hardcoded gray stub value", () => {
    expect(getTagColor("anything")).not.toBe("#6B7280");
  });
});

describe("tagStyle", () => {
  it("returns a stable bg/text pair for the same name", () => {
    expect(tagStyle("vip")).toEqual(tagStyle("vip"));
  });

  it("varies backgroundColor across different names", () => {
    const bgs = new Set(
      ["vip", "urgent", "spam", "lead", "billing", "support"].map(
        (n) => tagStyle(n).backgroundColor
      )
    );
    expect(bgs.size).toBeGreaterThan(1);
  });

  it("does not return the old hardcoded stub pair", () => {
    expect(tagStyle("anything")).not.toEqual({
      backgroundColor: "#F3F4F6",
      color: "#6B7280",
    });
  });
});
