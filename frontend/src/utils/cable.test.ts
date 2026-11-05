import { describe, it, expect, vi, beforeEach } from "vitest";

vi.mock("./constants", () => ({ appSettings: { apiBaseUrl: "http://api.test" } }));
vi.mock("@rails/actioncable", () => ({
  createConsumer: () => {
    const subs: any[] = [];
    return {
      subs,
      subscriptions: { create: (_channel: any, mixin: any) => (subs.push(mixin), mixin) },
      disconnect: vi.fn(),
    };
  },
}));

import { createAuthenticatedConsumer } from "./cable";

describe("createAuthenticatedConsumer catch-up", () => {
  const doc = new EventTarget() as EventTarget & { visibilityState: string };

  beforeEach(() => {
    vi.useFakeTimers();
    vi.stubGlobal("localStorage", { getItem: () => "tok" });
    doc.visibilityState = "visible";
    vi.stubGlobal("document", doc);
  });

  it("resyncs after a reconnect and on refocus, never on the first connect", () => {
    const onResync = vi.fn();
    const connected = vi.fn();
    const consumer: any = createAuthenticatedConsumer(onResync);
    consumer.subscriptions.create({ channel: "A" }, { connected });
    consumer.subscriptions.create({ channel: "B" }, {});
    const [a, b] = consumer.subs;

    a.connected();
    b.connected();
    vi.runAllTimers();
    expect(onResync).not.toHaveBeenCalled();
    expect(connected).toHaveBeenCalledTimes(1);

    a.connected();
    b.connected();
    vi.runAllTimers();
    expect(onResync).toHaveBeenCalledTimes(1); // both subscriptions coalesce into one refetch

    doc.dispatchEvent(new Event("visibilitychange"));
    vi.runAllTimers();
    expect(onResync).toHaveBeenCalledTimes(2);

    consumer.disconnect();
    doc.dispatchEvent(new Event("visibilitychange"));
    vi.runAllTimers();
    expect(onResync).toHaveBeenCalledTimes(2);
  });
});
