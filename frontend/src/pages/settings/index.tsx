import { useState, useEffect } from "react";
import { useSelector, useDispatch } from "react-redux";
import { RootState } from "@/store";
import { setCredentials } from "@/store/auth-slice";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Loader2 } from "lucide-react";
import toast from "react-hot-toast";
import request from "@/utils/request";

export function SettingsPage() {
  const dispatch = useDispatch();
  const { user, account, token } = useSelector((state: RootState) => state.auth);
  const [trackingDomain, setTrackingDomain] = useState(account?.tracking_domain || "");
  const [retentionDays, setRetentionDays] = useState(account?.message_retention_days ?? 180);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setTrackingDomain(account?.tracking_domain || "");
    setRetentionDays(account?.message_retention_days ?? 180);
  }, [account?.tracking_domain, account?.message_retention_days]);

  const handleSave = async () => {
    setSaving(true);
    try {
      const res = await request.patch(`/accounts/${account?.id}`, {
        account: {
          tracking_domain: trackingDomain.trim() || null,
          message_retention_days: retentionDays,
        },
      });
      dispatch(setCredentials({ user: user!, account: res.data, token: token! }));
      toast.success("Settings saved");
    } catch {
      toast.error("Failed to save settings");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="p-6 max-w-2xl">
      <h1 className="text-2xl font-bold mb-6">Account Settings</h1>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Custom Tracking Domain</CardTitle>
          <CardDescription>
            Serve tracking links (clicks, opens, unsubscribe) from your own domain to improve
            email deliverability. HTTPS is handled automatically by Cloudflare, with no certificate
            setup on your side.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="space-y-2 text-sm text-muted-foreground">
              <p className="font-medium text-foreground">Setup (Cloudflare)</p>
              <ol className="list-decimal pl-5 space-y-1">
                <li>
                  In your domain's Cloudflare dashboard, add a <strong>CNAME</strong> record:{" "}
                  <code className="bg-muted px-1 py-0.5 rounded">track</code> →{" "}
                  <code className="bg-muted px-1 py-0.5 rounded">api.messy.sh</code>
                </li>
                <li>
                  Set the record to <strong>Proxied</strong> (orange cloud). This is required. It
                  lets Cloudflare issue and serve the HTTPS certificate for your subdomain.
                </li>
                <li>
                  Under <strong>SSL/TLS → Overview</strong>, set the mode to <strong>Full</strong>{" "}
                  (not Flexible, which causes redirect loops).
                </li>
                <li>Enter your subdomain below and save.</li>
              </ol>
            </div>
            <div className="space-y-2">
              <Label htmlFor="tracking-domain">Tracking Domain</Label>
              <Input
                id="tracking-domain"
                placeholder="track.yourdomain.com"
                value={trackingDomain}
                onChange={(e) => setTrackingDomain(e.target.value)}
              />
              <p className="text-xs text-muted-foreground">
                Leave empty to use the default (api.messy.sh). Not on Cloudflare? Move your domain's
                DNS to Cloudflare's free plan, or contact us to provision a certificate directly.
              </p>
            </div>
            <Button onClick={handleSave} disabled={saving} size="sm">
              {saving ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" /> Saving...
                </>
              ) : (
                "Save"
              )}
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle className="text-base">Message Retention</CardTitle>
          <CardDescription>
            Messages older than the retention period will be automatically pruned along with their
            delivery logs and open tracking data. This applies to all environments in this account.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="retention-days">Retention Period</Label>
              <Select
                value={retentionDays.toString()}
                onValueChange={(v) => setRetentionDays(parseInt(v))}
              >
                <SelectTrigger id="retention-days" className="w-48">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="30">30 days</SelectItem>
                  <SelectItem value="60">60 days</SelectItem>
                  <SelectItem value="90">90 days</SelectItem>
                  <SelectItem value="180">180 days</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <Button onClick={handleSave} disabled={saving} size="sm">
              {saving ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" /> Saving...
                </>
              ) : (
                "Save"
              )}
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
