import { describe, it, expect } from "vitest";
import { deriveDefaultMapping, toEffectiveMapping } from "./csv-mapping";

describe("deriveDefaultMapping", () => {
  it("maps recognised headers case/space/underscore-insensitively", () => {
    expect(deriveDefaultMapping(["Email", "First Name", "lastname"])).toEqual({
      Email: "email",
      "First Name": "first_name",
      lastname: "last_name",
    });
  });

  it("defaults unknown columns to skip", () => {
    expect(deriveDefaultMapping(["phone", "notes"])).toEqual({
      phone: "skip",
      notes: "skip",
    });
  });
});

describe("toEffectiveMapping", () => {
  it("passes through standard fields unchanged", () => {
    expect(toEffectiveMapping({ Email: "email", Col: "skip" }, {})).toEqual({
      Email: "email",
      Col: "skip",
    });
  });

  it("emits custom:<name> for named custom columns", () => {
    expect(
      toEffectiveMapping({ Region: "custom" }, { Region: "  region  " })
    ).toEqual({ Region: "custom:region" });
  });

  it("drops custom columns that have no name", () => {
    expect(toEffectiveMapping({ Region: "custom" }, { Region: "  " })).toEqual({});
  });
});
