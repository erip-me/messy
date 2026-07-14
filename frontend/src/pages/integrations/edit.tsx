import React, { useState, useEffect } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  CheckCircle,
  HelpCircle,
  Loader2,
  Send,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { VendorIcon } from "@/components/ui/vendor-icon";
import {
  createIntegration,
  updateIntegration,
  getIntegrationById,
  testIntegration,
} from "@/api/integrations";
import { getEnvironments } from "@/api/environments";
import toast from "react-hot-toast";

const VENDOR_META: Record<
  string,
  { type: string; kind: string; label: string; channel: string; description: string }
> = {
  ses: {
    type: "SesIntegration",
    kind: "email",
    label: "Amazon SES",
    channel: "Email",
    description: "AWS email at scale",
  },
  smtp: {
    type: "SmtpIntegration",
    kind: "email",
    label: "SMTP",
    channel: "Email",
    description: "Any email provider",
  },
  twilio: {
    type: "TwilioIntegration",
    kind: "sms",
    label: "Twilio SMS",
    channel: "SMS",
    description: "Global SMS delivery",
  },
  whatsapp: {
    type: "WhatsappIntegration",
    kind: "whatsapp",
    label: "WhatsApp",
    channel: "WhatsApp",
    description: "Business API",
  },
  meta_social: {
    type: "MetaSocialIntegration",
    kind: "social",
    label: "Meta (Facebook & Instagram)",
    channel: "Social",
    description: "Organic posting to a Page + linked Instagram",
  },
  fcm: {
    type: "FcmIntegration",
    kind: "mobile_push",
    label: "Firebase Cloud Messaging",
    channel: "Push",
    description: "Android & iOS push via Google",
  },
  apns: {
    type: "ApnsIntegration",
    kind: "mobile_push",
    label: "Apple Push Notification",
    channel: "Push",
    description: "Native iOS push notifications",
  },
  web_push: {
    type: "WebPushIntegration",
    kind: "web_push",
    label: "Web Push",
    channel: "Web Push",
    description: "Browser push via VAPID",
  },
};

const VENDOR_FIELDS: Record<
  string,
  { key: string; label: string; placeholder: string; type?: string }[]
> = {
  ses: [
    { key: "region", label: "AWS Region", placeholder: "us-east-1" },
    { key: "access_key", label: "Access Key ID", placeholder: "AKIA..." },
    {
      key: "secret_key",
      label: "Secret Access Key",
      placeholder: "••••••••",
      type: "password",
    },
    {
      key: "from_email",
      label: "From Email",
      placeholder: "noreply@example.com",
    },
  ],
  smtp: [
    { key: "host", label: "SMTP Host", placeholder: "smtp.example.com" },
    { key: "port", label: "Port", placeholder: "587" },
    { key: "username", label: "Username", placeholder: "user@example.com" },
    { key: "password", label: "Password", placeholder: "••••••••", type: "password" },
    {
      key: "from_email",
      label: "From Email",
      placeholder: "noreply@example.com",
    },
  ],
  twilio: [
    { key: "sid", label: "Account SID", placeholder: "ACxxxxxxxx..." },
    {
      key: "token",
      label: "Auth Token",
      placeholder: "••••••••",
      type: "password",
    },
    { key: "from", label: "From Number", placeholder: "+15551234567" },
  ],
  whatsapp: [
    { key: "phone_id", label: "Phone Number ID", placeholder: "e.g. 1234567890" },
    {
      key: "token",
      label: "Access Token",
      placeholder: "••••••••",
      type: "password",
    },
    {
      key: "business_account_id",
      label: "Business Account ID",
      placeholder: "e.g. 1234567890",
    },
  ],
  meta_social: [
    { key: "label", label: "Account label", placeholder: "e.g. Lalaaji Meta" },
    { key: "access_token", label: "System User Access Token", placeholder: "••••••••", type: "password" },
    { key: "app_secret", label: "App Secret", placeholder: "••••••••", type: "password" },
  ],
  fcm: [
    { key: "project_id", label: "Firebase Project ID", placeholder: "my-project-12345" },
    { key: "server_key", label: "Server Key (legacy)", placeholder: "AAAAx...", type: "password" },
    {
      key: "service_account_json",
      label: "Service Account JSON",
      placeholder: "Paste the full JSON from Firebase Console → Project Settings → Service Accounts",
      type: "textarea",
    },
  ],
  apns: [
    { key: "team_id", label: "Team ID", placeholder: "ABC123DEF4" },
    { key: "key_id", label: "Key ID", placeholder: "XYZ789GHI0" },
    {
      key: "private_key",
      label: "Private Key (.p8 contents)",
      placeholder: "Paste the contents of your .p8 key file downloaded from Apple Developer",
      type: "textarea",
    },
    { key: "bundle_id", label: "Bundle ID", placeholder: "com.example.myapp" },
    { key: "apns_environment", label: "Environment", placeholder: "production", type: "select" },
  ],
  web_push: [
    { key: "vapid_public_key", label: "VAPID Public Key", placeholder: "BNbx..." },
    { key: "vapid_private_key", label: "VAPID Private Key", placeholder: "••••••••", type: "password" },
    { key: "vapid_subject", label: "Contact URI", placeholder: "mailto:admin@example.com" },
  ],
};

const TEST_MESSAGE: Record<string, { channel: string; bodyLabel: string; recipientLabel: string; recipientPlaceholder: string }> = {
  ses: { channel: "email", bodyLabel: "Test email body", recipientLabel: "To Email", recipientPlaceholder: "you@example.com" },
  smtp: { channel: "email", bodyLabel: "Test email body", recipientLabel: "To Email", recipientPlaceholder: "you@example.com" },
  twilio: { channel: "sms", bodyLabel: "Test SMS body", recipientLabel: "To Phone", recipientPlaceholder: "+31647508676" },
  whatsapp: { channel: "whatsapp", bodyLabel: "Test message body", recipientLabel: "To Phone", recipientPlaceholder: "+31647508676" },
  fcm: { channel: "push", bodyLabel: "Notification body", recipientLabel: "Customer Email or Device Token", recipientPlaceholder: "user@example.com" },
  apns: { channel: "push", bodyLabel: "Notification body", recipientLabel: "Customer Email or Device Token", recipientPlaceholder: "user@example.com" },
  web_push: { channel: "web_push", bodyLabel: "Notification body", recipientLabel: "Customer Email", recipientPlaceholder: "user@example.com" },
};

// Map STI type to VENDOR_META key
const TYPE_TO_VENDOR: Record<string, string> = {
  SesIntegration: "ses",
  SmtpIntegration: "smtp",
  TwilioIntegration: "twilio",
  WhatsappIntegration: "whatsapp",
  WhatsappCloudIntegration: "whatsapp",
  FcmIntegration: "fcm",
  ApnsIntegration: "apns",
  WebPushIntegration: "web_push",
  MetaSocialIntegration: "meta_social",
};

const VENDOR_HELP: Record<string, { title: string; steps: string[] }> = {
  ses: {
    title: "Setting up Amazon SES",
    steps: [
      "Sign in to the AWS Console and navigate to SES.",
      "Verify your sending domain or email address under Verified Identities.",
      "Go to IAM → Users → Create user with SES send permissions.",
      "Create an Access Key for the user and copy the Access Key ID and Secret.",
      "If you're in the SES sandbox, request production access to send to unverified addresses.",
      "Enter your AWS Region (e.g. us-east-1), the Access Key credentials, and the verified From Email.",
    ],
  },
  smtp: {
    title: "Setting up SMTP",
    steps: [
      "Get the SMTP credentials from your email provider (e.g. Gmail, Mailgun, Postmark, SendGrid).",
      "Find the SMTP host address (e.g. smtp.gmail.com, smtp.mailgun.org).",
      "Note the port, typically 587 (TLS) or 465 (SSL).",
      "Enter the username and password provided by your email service.",
      "Set the From Email to an address authorized by your provider.",
    ],
  },
  twilio: {
    title: "Setting up Twilio SMS",
    steps: [
      "Sign up or log in at twilio.com/console.",
      "Copy your Account SID and Auth Token from the dashboard.",
      "Buy or port a phone number under Phone Numbers → Manage → Buy a Number.",
      "Enter the Account SID, Auth Token, and the Twilio phone number (in E.164 format, e.g. +15551234567).",
    ],
  },
  whatsapp: {
    title: "Setting up WhatsApp Business API",
    steps: [
      "Go to developers.facebook.com and create or select your app.",
      "Add the WhatsApp product to your app.",
      "Under WhatsApp → Getting Started, find the Phone Number ID and temporary Access Token.",
      "For production, generate a permanent System User Token under Business Settings → System Users.",
      "Find your Business Account ID in Business Settings → Business Info.",
      "Enter the Phone Number ID, Access Token, and Business Account ID.",
    ],
  },
  fcm: {
    title: "Setting up Firebase Cloud Messaging",
    steps: [
      "Go to the Firebase Console (console.firebase.google.com) and select your project.",
      "Navigate to Project Settings → Service Accounts.",
      "Click 'Generate new private key' to download the Service Account JSON file.",
      "Copy the Project ID from the top of the Project Settings page.",
      "The Server Key (legacy) is optional. Find it under the Cloud Messaging tab if needed.",
      "Paste the entire contents of the downloaded JSON file into the Service Account JSON field.",
      "Make sure your Android/iOS app is registered in the Firebase project.",
    ],
  },
  apns: {
    title: "Setting up Apple Push Notifications",
    steps: [
      "Sign in to developer.apple.com and go to Certificates, Identifiers & Profiles.",
      "Navigate to Keys and click the + button to create a new key.",
      "Enable Apple Push Notifications Service (APNs) and give the key a name.",
      "Download the .p8 key file. This can only be downloaded once.",
      "Note the Key ID shown on the key details page.",
      "Find your Team ID at the top right of the developer portal or in Membership Details.",
      "Enter your app's Bundle ID (e.g. com.example.myapp). This must match your Xcode project.",
      "Use Production for App Store / TestFlight builds, Sandbox for Xcode debug builds.",
    ],
  },
  web_push: {
    title: "Setting up Web Push (VAPID)",
    steps: [
      "Generate a VAPID key pair using a tool like web-push-codelab.glitch.me or the web-push library.",
      "In your web app, use the VAPID public key to subscribe users via the Push API (pushManager.subscribe).",
      "Store each user's push subscription (endpoint + keys) by calling the Messy device token API.",
      "Enter the VAPID public key, private key, and a contact URI (mailto: address) for push service operators.",
      "Set up a service worker in your web app to handle incoming push events and display notifications.",
    ],
  },
  meta_social: {
    title: "Setting up a Meta (Facebook/Instagram) account",
    steps: [
      "In Meta Business Manager, open Settings → Users → System Users and create (or select) a system user.",
      "Click 'Generate new token', pick your app, and select a non-expiring token.",
      "Grant these permissions: pages_manage_posts, pages_read_engagement, pages_show_list, instagram_basic, instagram_content_publish, ads_management, business_management. Generate and copy the token into Access Token.",
      "Assign the system user to the Facebook Page (and Ad Account) with full control under Business Settings → Accounts.",
      "Find the Page ID under the Page's About/Settings; put it in Facebook Page ID.",
      "Link the Page to its Instagram Business/Creator account in Meta Business Suite so posts can mirror to Instagram.",
      "App Secret is under App Settings → Basic. Ad Account ID and IG Business Account ID are optional (IG is auto-resolved from the Page).",
    ],
  },
};

// The first real request to make once a provider is connected, per channel.
// Social has no outbound /messages send, so it has no example.
const EXAMPLE_SEND: Record<string, string> = {
  email: `curl https://api.messy.sh/messages \\
  -H "Authorization: Bearer $MESSY_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "type": "email",
    "to": "ada@example.com",
    "subject": "Welcome to Acme",
    "body": "<p>Thanks for signing up.</p>"
  }'`,
  sms: `curl https://api.messy.sh/messages \\
  -H "Authorization: Bearer $MESSY_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{ "type": "sms", "to": "+15551234567", "body": "Your code is 481920" }'`,
  whatsapp: `curl https://api.messy.sh/messages \\
  -H "Authorization: Bearer $MESSY_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{ "type": "whatsapp", "to": "+15551234567", "body": "Your order has shipped." }'`,
  mobile_push: `curl https://api.messy.sh/messages \\
  -H "Authorization: Bearer $MESSY_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{ "type": "mobile_push", "to": "ada@example.com", "subject": "Order shipped", "body": "It is on its way." }'`,
  web_push: `curl https://api.messy.sh/messages \\
  -H "Authorization: Bearer $MESSY_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{ "type": "web_push", "to": "ada@example.com", "subject": "Order shipped", "body": "It is on its way." }'`,
};

const STEPS = ["Provider", "Configuration", "Test", "Done"];

export function IntegrationsEditPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const isNew = !id || id === "new";

  const [step, setStep] = useState(isNew ? 0 : 1);
  const [vendor, setVendor] = useState("ses");
  const [environmentId, setEnvironmentId] = useState<string>("none");
  const [config, setConfig] = useState<Record<string, string>>({});
  const [active, setActive] = useState(true);
  const [environments, setEnvironments] = useState<{ id: number; name: string }[]>([]);
  const [loading, setLoading] = useState(!isNew);
  const [saving, setSaving] = useState(false);
  const [createdId, setCreatedId] = useState<number | null>(null);

  // Test step state
  const [testRecipient, setTestRecipient] = useState("");
  const [testSending, setTestSending] = useState(false);
  const [testResult, setTestResult] = useState<"success" | "error" | null>(null);
  const [testError, setTestError] = useState("");

  useEffect(() => {
    getEnvironments().then(setEnvironments).catch(() => {});

    if (!isNew) {
      getIntegrationById(Number(id))
        .then((data) => {
          const v = TYPE_TO_VENDOR[data.type] || data.vendor || "ses";
          setVendor(v);
          setEnvironmentId(data.environment_id ? String(data.environment_id) : "none");
          setConfig((data.config as Record<string, string>) || {});
          setActive(data.active ?? true);
          setCreatedId(data.id);
        })
        .catch(() => {
          toast.error("Failed to load integration");
          navigate("/integrations");
        })
        .finally(() => setLoading(false));
    }
  }, [id]);

  const handleConfigChange = (key: string, value: string) => {
    setConfig((prev) => ({ ...prev, [key]: value }));
  };

  const handleSaveConfig = async () => {
    const meta = VENDOR_META[vendor];
    try {
      setSaving(true);
      if (isNew && !createdId) {
        const result = await createIntegration({
          vendor,
          type: meta.type,
          kind: meta.kind as any,
          environment_id:
            environmentId && environmentId !== "none"
              ? Number(environmentId)
              : (undefined as any),
          config,
        } as any);
        setCreatedId(result.id);
        toast.success("Integration created");
      } else {
        await updateIntegration(createdId || Number(id), { config, active });
        toast.success("Integration saved");
      }
      // Channels without an outbound test skip straight past the Test step.
      if (!TEST_MESSAGE[vendor]) {
        if (isNew) setStep(3);
        else navigate("/integrations");
      } else {
        setStep(2);
      }
    } catch (error: any) {
      toast.error(
        error.response?.data?.message ||
          `Failed to ${isNew ? "create" : "update"} integration`
      );
    } finally {
      setSaving(false);
    }
  };

  const handleTestSend = async () => {
    if (!testRecipient.trim()) {
      toast.error("Enter a recipient");
      return;
    }
    if (!createdId) {
      toast.error("Save the integration first");
      return;
    }
    try {
      setTestSending(true);
      setTestResult(null);
      const result = await testIntegration(createdId, testRecipient);
      if (result.success) {
        setTestResult("success");
      } else {
        setTestResult("error");
        setTestError(result.error || "Send failed");
      }
    } catch (error: any) {
      setTestResult("error");
      setTestError(error.response?.data?.error || error.message || "Send failed");
    } finally {
      setTestSending(false);
    }
  };

  if (loading) {
    return (
      <div className="p-6 max-w-2xl">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-muted rounded w-48" />
          <div className="h-64 bg-muted rounded" />
        </div>
      </div>
    );
  }

  const fields = VENDOR_FIELDS[vendor] || [];
  const meta = VENDOR_META[vendor] || { type: vendor, kind: vendor, label: vendor, channel: vendor, description: "" };
  const testInfo = TEST_MESSAGE[vendor] || { channel: vendor, bodyLabel: "Test body", recipientLabel: "To", recipientPlaceholder: "" };

  const helpInfo = VENDOR_HELP[vendor];

  // Some channels (e.g. Meta social publishing) have no outbound "send to a
  // recipient" test, so the Test step is skipped for them.
  const supportsTest = !!TEST_MESSAGE[vendor];
  const visibleSteps = supportsTest ? STEPS : STEPS.filter((s) => s !== "Test");
  const currentStepIndex = visibleSteps.indexOf(STEPS[step]);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <Button variant="ghost" size="sm" onClick={() => navigate("/integrations")}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div>
          <h1 className="page-heading">
            {isNew ? "Add Integration" : "Edit Integration"}
          </h1>
          <p className="page-subtitle">
            {isNew ? "Connect a new channel provider" : `Editing ${meta?.label}`}
          </p>
        </div>
      </div>

      {/* Progress steps - only for new */}
      {isNew && (
        <div className="flex items-center gap-1 mb-8">
          {visibleSteps.map((label, i) => (
            <React.Fragment key={label}>
              <div className="flex items-center gap-2">
                <div
                  className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-medium border-2 transition-colors ${
                    i < currentStepIndex
                      ? "bg-primary border-primary text-primary-foreground"
                      : i === currentStepIndex
                        ? "border-primary text-primary"
                        : "border-muted-foreground/30 text-muted-foreground/50"
                  }`}
                >
                  {i < currentStepIndex ? <Check className="h-3.5 w-3.5" /> : i + 1}
                </div>
                <span
                  className={`text-sm hidden sm:inline ${
                    i <= currentStepIndex ? "text-foreground font-medium" : "text-muted-foreground"
                  }`}
                >
                  {label}
                </span>
              </div>
              {i < visibleSteps.length - 1 && (
                <div
                  className={`flex-1 h-0.5 mx-2 rounded ${
                    i < currentStepIndex ? "bg-primary" : "bg-muted-foreground/20"
                  }`}
                />
              )}
            </React.Fragment>
          ))}
        </div>
      )}

      {/* Step 0: Provider selection */}
      {step === 0 && isNew && (
        <div className="space-y-4 max-w-2xl">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Select a provider</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 gap-3">
                {Object.entries(VENDOR_META).map(([key, v]) => (
                  <button
                    key={key}
                    type="button"
                    onClick={() => {
                      setVendor(key);
                      setConfig({});
                    }}
                    className={`flex items-center gap-3 p-4 rounded-lg border-2 text-left transition-colors ${
                      vendor === key
                        ? "border-primary bg-primary/5"
                        : "border-muted hover:border-muted-foreground/30"
                    }`}
                  >
                    <VendorIcon type={v.type} vendor={key} size={32} />
                    <div>
                      <p className="font-medium text-sm">{v.label}</p>
                      <p className="text-xs text-muted-foreground">{v.description}</p>
                    </div>
                  </button>
                ))}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="pt-4">
              <div className="space-y-2">
                <Label>
                  Environment{" "}
                  <span className="text-muted-foreground text-xs">(optional)</span>
                </Label>
                <Select value={environmentId} onValueChange={setEnvironmentId}>
                  <SelectTrigger>
                    <SelectValue placeholder="All environments" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none">All environments</SelectItem>
                    {environments.map((env) => (
                      <SelectItem key={env.id} value={String(env.id)}>
                        {env.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </CardContent>
          </Card>

          <div className="flex justify-end">
            <Button onClick={() => setStep(1)}>
              Next <ArrowRight className="h-4 w-4 ml-2" />
            </Button>
          </div>
        </div>
      )}

      {/* Step 1: Configuration */}
      {step === 1 && (
        <div className="space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Left: config form */}
            <div className="space-y-4">
              <Card>
                <CardHeader>
                  <CardTitle className="text-base flex items-center gap-2">
                    <VendorIcon type={meta.type} vendor={vendor} size={24} />
                    {meta.label} Configuration
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  {fields.map((field) => (
                    <div key={field.key} className="space-y-2">
                      <Label htmlFor={field.key}>{field.label}</Label>
                      {field.type === "textarea" ? (
                        <Textarea
                          id={field.key}
                          placeholder={field.placeholder}
                          value={config[field.key] || ""}
                          onChange={(e) => handleConfigChange(field.key, e.target.value)}
                          rows={6}
                          className="font-mono text-xs"
                        />
                      ) : field.type === "select" ? (
                        <Select
                          value={config[field.key] || "production"}
                          onValueChange={(v) => handleConfigChange(field.key, v)}
                        >
                          <SelectTrigger>
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            <SelectItem value="production">Production</SelectItem>
                            <SelectItem value="sandbox">Sandbox (Development)</SelectItem>
                          </SelectContent>
                        </Select>
                      ) : (
                        <Input
                          id={field.key}
                          type={field.type || "text"}
                          placeholder={field.placeholder}
                          value={config[field.key] || ""}
                          onChange={(e) => handleConfigChange(field.key, e.target.value)}
                          autoComplete="off"
                        />
                      )}
                    </div>
                  ))}
                </CardContent>
              </Card>

              {/* Active toggle - only for edit */}
              {!isNew && (
                <Card>
                  <CardContent className="pt-4">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="font-medium text-sm">Active</p>
                        <p className="text-xs text-muted-foreground">
                          Enable or disable this integration
                        </p>
                      </div>
                      <Switch checked={active} onCheckedChange={setActive} />
                    </div>
                  </CardContent>
                </Card>
              )}
            </div>

            {/* Right: setup guide */}
            {helpInfo && (
              <div className="lg:sticky lg:top-6">
                <Card className="h-fit">
                  <CardHeader>
                    <CardTitle className="text-sm flex items-center gap-2">
                      <HelpCircle className="h-5 w-5" />
                      {helpInfo.title}
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <ol className="space-y-3">
                      {helpInfo.steps.map((text, i) => (
                        <li key={i} className="flex gap-2.5 text-sm leading-relaxed text-muted-foreground">
                          <span className="flex-shrink-0 w-5 h-5 rounded-full bg-muted text-muted-foreground flex items-center justify-center text-[10px] font-semibold mt-0.5">
                            {i + 1}
                          </span>
                          <span>{text}</span>
                        </li>
                      ))}
                    </ol>
                  </CardContent>
                </Card>
              </div>
            )}
          </div>

          <div className="flex justify-between">
            {isNew ? (
              <Button variant="outline" onClick={() => setStep(0)}>
                <ArrowLeft className="h-4 w-4 mr-2" /> Back
              </Button>
            ) : (
              <Button variant="outline" onClick={() => navigate("/integrations")}>
                Cancel
              </Button>
            )}
            <Button onClick={handleSaveConfig} disabled={saving}>
              {saving ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" /> Saving...
                </>
              ) : isNew ? (
                <>
                  {supportsTest ? "Save & Test" : "Save"}{" "}
                  <ArrowRight className="h-4 w-4 ml-2" />
                </>
              ) : (
                "Save Changes"
              )}
            </Button>
          </div>
        </div>
      )}

      {/* Step 2: Test */}
      {step === 2 && supportsTest && (
        <div className="space-y-4 max-w-2xl">
          <Card>
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-2">
                <Send className="h-5 w-5" />
                Send a test message
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm text-muted-foreground">
                Verify your {meta.label} integration is working by sending a test message.
              </p>

              <div className="space-y-2">
                <Label>{testInfo.recipientLabel}</Label>
                <Input
                  value={testRecipient}
                  onChange={(e) => setTestRecipient(e.target.value)}
                  placeholder={testInfo.recipientPlaceholder}
                />
              </div>

              {testResult === "success" && (
                <div className="rounded-lg border border-green-200 bg-green-50 p-3 flex items-center gap-2">
                  <CheckCircle className="h-4 w-4 text-green-600" />
                  <span className="text-sm text-green-800">
                    Test message sent successfully!
                  </span>
                </div>
              )}

              {testResult === "error" && (
                <div className="rounded-lg border border-red-200 bg-red-50 p-3">
                  <p className="text-sm text-red-800 font-medium">Send failed</p>
                  <p className="text-xs text-red-600 mt-1">{testError}</p>
                </div>
              )}

              <Button
                onClick={handleTestSend}
                disabled={testSending}
                variant="outline"
                className="w-full"
              >
                {testSending ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" /> Sending...
                  </>
                ) : (
                  <>
                    <Send className="h-4 w-4 mr-2" /> Send Test
                  </>
                )}
              </Button>
            </CardContent>
          </Card>

          <div className="flex justify-between">
            <Button variant="outline" onClick={() => setStep(1)}>
              <ArrowLeft className="h-4 w-4 mr-2" /> Back
            </Button>
            <Button onClick={() => (isNew ? setStep(3) : navigate("/integrations"))}>
              {testResult === "success" ? "Finish" : "Skip"}{" "}
              <ArrowRight className="h-4 w-4 ml-2" />
            </Button>
          </div>
        </div>
      )}

      {/* Step 3: Success */}
      {step === 3 && (
        <div className="py-12 max-w-2xl">
          <div className="text-center">
            <div className="w-16 h-16 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-4">
              <CheckCircle className="h-8 w-8 text-green-600" />
            </div>
            <h2 className="text-xl font-semibold mb-2">Integration added!</h2>
            <p className="text-muted-foreground mb-6">
              Your {meta.label} integration is ready to use.
            </p>
          </div>

          {EXAMPLE_SEND[meta.kind] && (
            <Card className="mb-6 text-left">
              <CardHeader>
                <CardTitle className="text-sm">Send your first {meta.channel.toLowerCase()} message</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <pre className="bg-muted rounded-lg p-3 text-xs font-mono overflow-x-auto">
                  {EXAMPLE_SEND[meta.kind]}
                </pre>
                <p className="text-xs text-muted-foreground">
                  Use an environment API key as the bearer token. The response returns the message{" "}
                  <code className="font-mono">id</code> and a{" "}
                  <code className="font-mono">status</code> of{" "}
                  <code className="font-mono">pending</code>. More recipes in the{" "}
                  <a
                    href="https://messy.sh/docs/examples"
                    target="_blank"
                    rel="noreferrer"
                    className="text-primary hover:underline"
                  >
                    docs
                  </a>
                  .
                </p>
              </CardContent>
            </Card>
          )}

          <div className="text-center">
            <Button onClick={() => navigate("/integrations")}>Go to Integrations</Button>
          </div>
        </div>
      )}
    </div>
  );
}
