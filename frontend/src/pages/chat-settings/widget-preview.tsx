import { useState, useEffect } from "react";
import { Input } from "../../components/ui/input";
import { Label } from "../../components/ui/label";
import { Button } from "../../components/ui/button";
import { Upload, X } from "lucide-react";
import type { WidgetSettings } from "../../api/chat-settings";

/* ── ColorField ── */

export function ColorField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <div>
      <Label className="text-xs">{label}</Label>
      <div className="flex items-center gap-1.5 mt-1">
        <input
          type="color"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="w-7 h-7 rounded cursor-pointer border border-gray-200 p-0.5"
        />
        <Input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="h-7 text-xs font-mono px-1.5"
        />
      </div>
    </div>
  );
}

/* ── ImageUploadField ── */

export function ImageUploadField({
  label,
  description,
  currentUrl,
  inputRef,
  onUpload,
  onRemove,
}: {
  label: string;
  description: string;
  currentUrl: string | null;
  inputRef: React.RefObject<HTMLInputElement | null>;
  onUpload: (file: File) => void;
  onRemove: () => void;
}) {
  return (
    <div>
      <Label>{label}</Label>
      <p className="text-xs text-gray-400 mt-0.5 mb-2">{description}</p>
      {currentUrl ? (
        <div className="flex items-center gap-3">
          <img
            src={currentUrl}
            alt=""
            className="h-12 rounded border border-gray-200 object-contain"
          />
          <Button variant="outline" size="sm" onClick={onRemove}>
            <X className="h-3.5 w-3.5 mr-1" /> Remove
          </Button>
        </div>
      ) : (
        <div>
          <input
            ref={inputRef}
            type="file"
            accept="image/*"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) onUpload(file);
            }}
          />
          <Button variant="outline" size="sm" onClick={() => inputRef.current?.click()}>
            <Upload className="h-3.5 w-3.5 mr-1" /> Upload
          </Button>
        </div>
      )}
    </div>
  );
}

/* ── PreviewLogo ── */

function LogoPlaceholder({ color }: { color: string }) {
  return (
    <div className="w-7 h-7 rounded flex items-center justify-center bg-white/20">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
      </svg>
    </div>
  );
}

export function PreviewLogo({ url, textColor }: { url: string | null; textColor: string }) {
  const [error, setError] = useState(false);
  useEffect(() => setError(false), [url]);

  if (!url || error) return <LogoPlaceholder color={textColor} />;

  return (
    <img
      src={url}
      alt=""
      className="w-7 h-7 rounded object-contain"
      onError={() => setError(true)}
    />
  );
}

/* ── WidgetPreview ── */

interface Operator {
  id: number;
  name: string;
  avatar_url: string | null;
}

interface WidgetPreviewProps {
  settings: WidgetSettings;
  headerColor: string;
  headerTextColor: string;
  sendButtonColor: string;
  sendButtonTextColor: string;
  buttonColor: string;
  buttonTextColor: string;
  operators?: Operator[];
}

export function WidgetPreview({
  settings,
  headerColor,
  headerTextColor,
  sendButtonColor,
  sendButtonTextColor,
  buttonColor,
  buttonTextColor,
  operators = [],
}: WidgetPreviewProps) {
  const isOffline = settings.business_hours_enabled;
  const bg = (color: string) => ({ backgroundColor: color });
  const fg = (color: string) => ({ color });
  const bgFg = (bgC: string, fgC: string) => ({ backgroundColor: bgC, color: fgC });

  return (
    <div className="sticky top-6">
      <p className="text-xs font-medium text-gray-400 mb-3 uppercase tracking-wide">Preview</p>
      {isOffline && (
        <p className="text-[10px] text-gray-400 mb-2">Showing offline state (business hours enabled)</p>
      )}
      <div className="relative h-[520px]">
        {/* Chat window */}
        <div className="w-[280px] rounded-2xl overflow-hidden shadow-lg">
          {/* Header */}
          <div
            className="px-4 py-3 flex items-center gap-2 bg-cover bg-center"
            style={{
              ...bgFg(headerColor, headerTextColor),
              backgroundImage: settings.header_background_image_url
                ? `url(${settings.header_background_image_url})`
                : undefined,
            }}
          >
            <PreviewLogo url={settings.logo_url} textColor={headerTextColor} />
            <div className="flex-1">
              <div className="font-bold text-sm">{settings.title || "Chat with us"}</div>
              <div className="text-xs opacity-70">
                {isOffline
                  ? "We are currently offline"
                  : settings.show_operator_count
                    ? `${operators.length || 1} operator${(operators.length || 1) > 1 ? "s" : ""} online`
                    : "We're online"}
              </div>
            </div>
            <span className="opacity-70 text-sm">&#10005;</span>
          </div>
          {/* Body */}
          <div
            className="px-4 py-3 min-h-[240px] bg-cover bg-center"
            style={{
              ...bg(settings.secondary_color),
              backgroundImage: settings.chat_background_image_url
                ? `url(${settings.chat_background_image_url})`
                : undefined,
            }}
          >
            {isOffline ? (
              <div className="space-y-2">
                <p className="text-xs text-gray-500">
                  {settings.offline_message || "We're offline. Leave a message."}
                </p>
                <div className="rounded-lg border border-gray-300 px-2.5 py-1.5 text-xs text-gray-400">
                  Your name
                </div>
                <div className="rounded-lg border border-gray-300 px-2.5 py-1.5 text-xs text-gray-400">
                  Your email
                </div>
                <div className="rounded-lg border border-gray-300 px-2.5 py-1.5 text-xs text-gray-400 h-12">
                  Your message
                </div>
                <div
                  className="rounded-lg px-3 py-1.5 text-xs text-center flex items-center justify-center gap-1"
                  style={bgFg(sendButtonColor, sendButtonTextColor)}
                >
                  <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" />
                  </svg>
                  Send Message
                </div>
              </div>
            ) : settings.require_email_before_chat ? (
              <div className="space-y-2">
                {settings.show_operator_avatars && operators.length > 0 && (
                  <div className="flex items-center mb-1">
                    {operators.slice(0, 3).map((op, i) => (
                      <div
                        key={op.id}
                        className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold border-2 border-white overflow-hidden ${i > 0 ? "-ml-3" : ""}`}
                        style={bgFg(settings.primary_color, settings.text_color)}
                      >
                        {op.avatar_url
                          ? <img src={op.avatar_url} alt="" className="w-full h-full object-cover" />
                          : op.name.charAt(0).toUpperCase()}
                      </div>
                    ))}
                  </div>
                )}
                <p className="text-xs text-gray-700">
                  {settings.greeting_message || "Hi! How can we help?"}
                </p>
                <div className="rounded-lg border border-gray-300 px-2.5 py-1.5 text-xs text-gray-400">
                  Your email
                </div>
                <div className="rounded-lg border border-gray-300 px-2.5 py-1.5 text-xs text-gray-400 h-12">
                  Your message
                </div>
                <div
                  className="rounded-lg px-3 py-1.5 text-xs text-center flex items-center justify-center gap-1"
                  style={bgFg(sendButtonColor, sendButtonTextColor)}
                >
                  <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" />
                  </svg>
                  Start Chat
                </div>
              </div>
            ) : (
              <div className="space-y-2">
                <p className="text-xs text-gray-700">
                  {settings.greeting_message || "Hi! How can we help?"}
                </p>
                <div className="pt-1">
                  <div className="text-xs opacity-50 mb-0.5" style={fg(settings.primary_color)}>
                    Alex
                  </div>
                  <div
                    className="inline-block px-3 py-2 rounded-tr-xl rounded-br-xl rounded-bl-xl text-xs max-w-[200px]"
                    style={bgFg(settings.primary_color + "14", settings.primary_color)}
                  >
                    {settings.greeting_message || "Hi! How can we help?"}
                  </div>
                </div>
                <div className="text-right">
                  <div
                    className="inline-block px-3 py-2 rounded-tl-xl rounded-bl-xl rounded-br-xl text-xs"
                    style={bgFg(settings.primary_color, settings.text_color)}
                  >
                    I have a question
                  </div>
                </div>
              </div>
            )}
          </div>
          {/* Input — only when online and not requiring email */}
          {!isOffline && !settings.require_email_before_chat && (
            <div
              className="flex items-center gap-2 px-3 py-2 border-t border-gray-100"
              style={bg(settings.secondary_color)}
            >
              <div className="flex-1 rounded-full px-3 py-1.5 text-xs border border-gray-200 text-gray-400">
                Type a message...
              </div>
              <div
                className="w-7 h-7 rounded-full flex items-center justify-center"
                style={bg(sendButtonColor)}
              >
                <svg width="12" height="12" viewBox="0 0 24 24" fill={sendButtonTextColor}>
                  <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" />
                </svg>
              </div>
            </div>
          )}
        </div>

        {/* Chat bubble + operator avatars */}
        <div className="absolute bottom-0 right-0 flex items-center gap-1.5">
          {settings.show_operator_avatars && operators.length > 0 && (
            <div className="flex items-center -mr-1">
              {operators.slice(0, 3).map((op, i) => (
                <div
                  key={op.id}
                  className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold border-2 border-white overflow-hidden ${i > 0 ? "-ml-2" : ""}`}
                  style={bgFg(headerColor, headerTextColor)}
                >
                  {op.avatar_url
                    ? <img src={op.avatar_url} alt="" className="w-full h-full object-cover" />
                    : op.name.charAt(0).toUpperCase()}
                </div>
              ))}
            </div>
          )}
          <div
            className="w-12 h-12 rounded-full flex items-center justify-center shadow-lg"
            style={bgFg(buttonColor, buttonTextColor)}
          >
            <svg
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
            </svg>
          </div>
        </div>
      </div>
    </div>
  );
}
