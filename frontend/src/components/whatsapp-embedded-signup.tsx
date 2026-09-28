import { useState } from "react";
import { Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import request from "@/utils/request";

// Meta Embedded Signup for WhatsApp Business App coexistence: the business keeps
// using the WhatsApp Business app on its phone while Messy connects to the same
// number over the Cloud API. The code from FB.login is exchanged server-side
// (POST /whatsapp/embedded_signup); no Meta secret or token touches the browser.

declare global {
  interface Window {
    FB?: any;
    fbAsyncInit?: () => void;
  }
}

function loadFacebookSdk(appId: string, version: string): Promise<any> {
  if (window.FB) return Promise.resolve(window.FB);
  return new Promise((resolve) => {
    window.fbAsyncInit = () => {
      window.FB.init({ appId, autoLogAppEvents: true, xfbml: false, version });
      resolve(window.FB);
    };
    const s = document.createElement("script");
    s.src = "https://connect.facebook.net/en_US/sdk.js";
    s.async = true;
    s.crossOrigin = "anonymous";
    document.body.appendChild(s);
  });
}

export function WhatsappEmbeddedSignup({ onConnected }: { onConnected: () => void }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const start = async () => {
    setBusy(true);
    setError(null);
    try {
      const { data: cfg } = await request.get("/whatsapp/embedded_signup");
      if (!cfg.configured || !cfg.config_id) throw new Error("Embedded Signup isn't configured on the server yet.");
      const FB = await loadFacebookSdk(cfg.app_id, cfg.graph_api_version);

      let session: { waba_id?: string; phone_number_id?: string; business_id?: string } = {};
      const onMessage = (event: MessageEvent) => {
        if (!event.origin.endsWith("facebook.com")) return;
        try {
          const data = typeof event.data === "string" ? JSON.parse(event.data) : event.data;
          if (data?.type === "WA_EMBEDDED_SIGNUP" && String(data.event).startsWith("FINISH")) session = data.data || {};
        } catch {
          /* non-JSON messages from the SDK */
        }
      };
      window.addEventListener("message", onMessage);

      FB.login(
        (response: any) => {
          window.removeEventListener("message", onMessage);
          const code = response?.authResponse?.code;
          if (!code || !session.waba_id) {
            setBusy(false);
            setError("Signup was cancelled or didn't finish.");
            return;
          }
          request
            .post("/whatsapp/embedded_signup", { code, ...session })
            .then(() => onConnected())
            .catch((e) => setError(e?.response?.data?.error || "Connecting the number failed."))
            .finally(() => setBusy(false));
        },
        { config_id: cfg.config_id, response_type: "code", override_default_response_type: true, extras: cfg.extras },
      );
    } catch (e: any) {
      setBusy(false);
      setError(e?.response?.data?.error || e.message);
    }
  };

  return (
    <div className="space-y-2">
      <Button type="button" onClick={start} disabled={busy} className="w-full">
        {busy && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
        Connect WhatsApp Business App
      </Button>
      <p className="text-xs text-muted-foreground">
        Keeps the number working in the WhatsApp Business app; Messy receives and sends through the Cloud API.
      </p>
      {error && <p className="text-xs text-destructive">{error}</p>}
    </div>
  );
}
