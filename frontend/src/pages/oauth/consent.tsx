import { useState, useEffect, useMemo } from "react";
import { useSearchParams, Navigate } from "react-router-dom";
import { useSelector } from "react-redux";
import { RootState } from "@/store";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Loader2, Plug, ShieldCheck } from "lucide-react";
import request from "@/utils/request";
import { submitOauthConsent } from "@/api/mcp";
import toast from "react-hot-toast";

interface EnvOption {
  id: number;
  name: string;
}

// OAuth consent screen. /oauth/authorize (backend) redirects the browser here
// with the validated request in the query string; the user picks an environment
// and approves, and we hand back the redirect that carries the auth code.
export function OauthConsentPage() {
  const [searchParams] = useSearchParams();
  const { isAuthenticated, account } = useSelector((state: RootState) => state.auth);

  const params = useMemo(
    () => ({
      client_id: searchParams.get("client_id") || "",
      redirect_uri: searchParams.get("redirect_uri") || "",
      scope: searchParams.get("scope") || "",
      state: searchParams.get("state") || "",
      code_challenge: searchParams.get("code_challenge") || "",
      code_challenge_method: searchParams.get("code_challenge_method") || "S256",
      resource: searchParams.get("resource") || undefined,
    }),
    [searchParams]
  );

  const scopes = useMemo(() => params.scope.split(/\s+/).filter(Boolean), [params.scope]);

  const [environments, setEnvironments] = useState<EnvOption[]>([]);
  const [environmentId, setEnvironmentId] = useState<string>("");
  const [submitting, setSubmitting] = useState<false | "approve" | "deny">(false);

  useEffect(() => {
    if (!isAuthenticated) return;
    request
      .get("/environments")
      .then((res) => {
        const envs: EnvOption[] = res.data || [];
        setEnvironments(envs);
        if (envs.length > 0) setEnvironmentId(String(envs[0].id));
      })
      .catch(() => toast.error("Failed to load environments"));
  }, [isAuthenticated]);

  // Preserve the full consent URL so login can bring the user back here.
  if (!isAuthenticated) {
    const returnTo = encodeURIComponent(window.location.pathname + window.location.search);
    return <Navigate to={`/login?return=${returnTo}`} replace />;
  }

  const invalid = !params.client_id || !params.redirect_uri || !params.code_challenge;

  const decide = async (approved: boolean) => {
    setSubmitting(approved ? "approve" : "deny");
    try {
      const { redirect_to } = await submitOauthConsent({
        ...params,
        environment_id: Number(environmentId),
        approved,
      });
      window.location.href = redirect_to;
    } catch {
      toast.error("Could not complete the authorization");
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-6">
      <Card className="w-full max-w-md">
        <CardHeader>
          <div className="flex items-center gap-2">
            <Plug className="h-5 w-5 text-primary" />
            <CardTitle className="text-lg">Authorize access</CardTitle>
          </div>
          <CardDescription>
            An application wants to connect to <span className="font-medium">{account?.name}</span>{" "}
            on Messy using the Model Context Protocol.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {invalid ? (
            <p className="text-sm text-destructive">
              This authorization request is missing required parameters. Please restart the
              connection from your agent.
            </p>
          ) : (
            <div className="space-y-5">
              <div className="space-y-2">
                <Label htmlFor="env">Environment</Label>
                <Select value={environmentId} onValueChange={setEnvironmentId}>
                  <SelectTrigger id="env">
                    <SelectValue placeholder="Select an environment" />
                  </SelectTrigger>
                  <SelectContent>
                    {environments.map((env) => (
                      <SelectItem key={env.id} value={String(env.id)}>
                        {env.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <p className="text-xs text-muted-foreground">
                  The agent will only be able to act within the environment you choose.
                </p>
              </div>

              <div className="space-y-2">
                <div className="flex items-center gap-1.5 text-sm font-medium">
                  <ShieldCheck className="h-4 w-4 text-muted-foreground" />
                  Requested access
                </div>
                <div className="flex flex-wrap gap-1.5">
                  {scopes.map((s) => (
                    <Badge key={s} variant="secondary">
                      {s}
                    </Badge>
                  ))}
                </div>
              </div>

              <div className="flex gap-3 pt-2">
                <Button
                  variant="outline"
                  className="flex-1"
                  disabled={!!submitting}
                  onClick={() => decide(false)}
                >
                  {submitting === "deny" ? <Loader2 className="h-4 w-4 animate-spin" /> : "Deny"}
                </Button>
                <Button
                  className="flex-1"
                  disabled={!!submitting || !environmentId}
                  onClick={() => decide(true)}
                >
                  {submitting === "approve" ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    "Approve"
                  )}
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
