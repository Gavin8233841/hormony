import { describe, expect, it } from "vitest";

import { localDateKey } from "./client-date";

class LocalMidnightBoundaryDate extends Date {
  getFullYear(): number {
    return 2026;
  }

  getMonth(): number {
    return 6;
  }

  getDate(): number {
    return 17;
  }

  toISOString(): string {
    return "2026-07-16T16:30:00.000Z";
  }
}

describe("localDateKey", () => {
  it("uses local calendar fields across a UTC day boundary", () => {
    expect(localDateKey(new LocalMidnightBoundaryDate(0))).toBe("2026-07-17");
  });
});
