import { describe, it, expect } from "vitest";
import { formatDate, timeAgo } from "./format-date";

describe("formatDate", () => {
  it("returns empty string for null/undefined/empty", () => {
    expect(formatDate(null)).toBe("");
    expect(formatDate(undefined)).toBe("");
    expect(formatDate("")).toBe("");
  });

  it("returns empty string for invalid dates", () => {
    expect(formatDate("not-a-date")).toBe("");
  });

  it("formats a valid ISO date the same as toLocaleDateString", () => {
    const iso = "2026-06-29T10:00:00.000Z";
    expect(formatDate(iso)).toBe(new Date(iso).toLocaleDateString());
  });
});

describe("timeAgo", () => {
  const now = new Date("2026-06-29T12:00:00.000Z").getTime();

  it("returns empty string for falsy input", () => {
    expect(timeAgo(null, now)).toBe("");
  });

  it("returns 'now' for under a minute", () => {
    expect(timeAgo(new Date(now - 30 * 1000).toISOString(), now)).toBe("now");
  });

  it("returns minutes for under an hour", () => {
    expect(timeAgo(new Date(now - 5 * 60 * 1000).toISOString(), now)).toBe("5m");
  });

  it("returns hours for under a day", () => {
    expect(timeAgo(new Date(now - 3 * 60 * 60 * 1000).toISOString(), now)).toBe("3h");
  });

  it("falls back to a date for older than a day", () => {
    const old = new Date(now - 3 * 24 * 60 * 60 * 1000);
    expect(timeAgo(old.toISOString(), now)).toBe(old.toLocaleDateString());
  });
});
