import { Mail } from 'lucide-react';
import ses from '@/assets/vendors/ses.svg';
import twilio from '@/assets/vendors/twilio.svg';
import whatsapp from '@/assets/vendors/whatsapp.svg';
import fcm from '@/assets/vendors/fcm.svg';
import apns from '@/assets/vendors/apns.svg';
import webPush from '@/assets/vendors/web-push.svg';
import meta from '@/assets/vendors/meta.svg';

// Vendor logos live as .svg assets in src/assets/vendors/, keyed by STI type
// (preferred) and by vendor slug (fallback). SMTP has no brand mark — lucide Mail.
const vendorIcons: Record<string, React.ReactNode> = {
  // ── by STI type (preferred) ──────────────────────────────────────
  SesIntegration: ses,
  SmtpIntegration: <Mail size={28} strokeWidth={1.5} />,
  TwilioIntegration: twilio,
  WhatsappCloudIntegration: whatsapp,
  WhatsappIntegration: whatsapp,
  FcmIntegration: fcm,
  ApnsIntegration: apns,
  WebPushIntegration: webPush,
  MetaSocialIntegration: meta,

  // ── by vendor slug (fallback) ─────────────────────────────────────
  whatsapp_cloud: whatsapp,
  twilio,
  smtp: <Mail size={28} strokeWidth={1.5} />,
  ses,
  fcm,
  web_push: webPush,
  apns,
  meta_social: meta,
};

export function VendorIcon({ vendor, type, size = 28 }: { vendor?: string; type?: string; size?: number }) {
  // Prefer STI type name, fall back to vendor slug
  const icon = (type && vendorIcons[type]) || (vendor && vendorIcons[vendor?.toLowerCase()]);
  if (!icon) return null;
  return (
    <div
      style={{ width: size, height: size }}
      className="flex items-center justify-center shrink-0 [&>svg]:w-full [&>svg]:h-full"
    >
      {typeof icon === 'string' ? <img src={icon} alt="" className="h-full w-full" /> : icon}
    </div>
  );
}
