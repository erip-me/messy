import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Mail, MessageSquare, Phone, Bell, Settings, Edit, Trash2, Power, ShieldCheck, ShieldOff, Send, Loader2 } from 'lucide-react';
import { VendorIcon } from '@/components/ui/vendor-icon';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Switch } from '@/components/ui/switch';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { Input } from '@/components/ui/input';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Dialog, DialogContent, DialogHeader, DialogFooter, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import { getIntegrations, updateIntegration, deleteIntegration, testIntegration, Integration } from '@/api/integrations';
import { getEnvironmentById, updateEnvironment, toggleChannel, Environment, BackendChannel } from '@/api/environments';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { HelpHint } from '@/components/ui/help-hint';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';

// Channel type icons now in @/components/channel-icons

const VENDOR_INFO: Record<string, { name: string; description: string }> = {
  // by STI type (primary key)
  SesIntegration:          { name: 'Amazon SES',          description: 'AWS email at scale' },
  SmtpIntegration:         { name: 'SMTP',                description: 'Any email provider' },
  TwilioIntegration:       { name: 'Twilio SMS',          description: 'Global SMS delivery' },
  WhatsappCloudIntegration:{ name: 'WhatsApp',            description: 'Business API' },
  WhatsappIntegration:     { name: 'WhatsApp',            description: 'Business API' },
  FcmIntegration:          { name: 'Firebase Push',       description: 'Android & iOS push' },
  ApnsIntegration:         { name: 'Apple Push',          description: 'iOS notifications' },
  WebPushIntegration:      { name: 'Web Push',            description: 'Browser push via VAPID' },
  MetaSocialIntegration:   { name: 'Meta Social',         description: 'Facebook & Instagram posting' },
  // by vendor slug (fallback)
  ses:            { name: 'Amazon SES',    description: 'AWS email at scale' },
  smtp:           { name: 'SMTP',         description: 'Any email provider' },
  twilio:         { name: 'Twilio SMS',   description: 'Global SMS delivery' },
  whatsapp_cloud: { name: 'WhatsApp',     description: 'Business API' },
  fcm:            { name: 'Firebase',     description: 'Push notifications' },
  apns:           { name: 'Apple Push',   description: 'iOS notifications' },
  web_push:       { name: 'Web Push',     description: 'Browser push via VAPID' },
  meta_social:    { name: 'Meta Social',  description: 'Facebook & Instagram posting' },
};

const KIND_TO_CHANNEL: Record<string, BackendChannel> = {
  email: 'email',
  sms: 'sms',
  whatsapp: 'whatsapp',
  mobile_push: 'mobile_push',
  web_push: 'web_push',
  push: 'mobile_push',
};

const TEST_RECIPIENT: Record<string, { label: string; placeholder: string }> = {
  email:       { label: 'To Email', placeholder: 'you@example.com' },
  sms:         { label: 'To Phone', placeholder: '+31647508676' },
  whatsapp:    { label: 'To Phone', placeholder: '+31647508676' },
  mobile_push: { label: 'Customer Email or Device Token', placeholder: 'user@example.com' },
  web_push:    { label: 'Customer Email', placeholder: 'user@example.com' },
};

const ALLOW_FIELD: Record<string, keyof Environment> = {
  email: 'allow_email',
  sms: 'allow_sms',
  whatsapp: 'allow_whatsapp',
  mobile_push: 'allow_mobile_push',
  web_push: 'allow_web_push',
  push: 'allow_mobile_push',
};

export function IntegrationsIndexPage() {
  const navigate = useNavigate();
  const activeEnvId = useActiveEnvironment();
  const { confirm, ConfirmDialog } = useConfirm();
  const [integrations, setIntegrations] = useState<Integration[]>([]);
  const [environment, setEnvironment] = useState<Environment | null>(null);
  const [loading, setLoading] = useState(true);
  const [testTarget, setTestTarget] = useState<Integration | null>(null);
  const [testRecipient, setTestRecipient] = useState('');
  const [testSending, setTestSending] = useState(false);

  useEffect(() => {
    loadIntegrations();
    if (activeEnvId) {
      getEnvironmentById(activeEnvId).then(setEnvironment).catch(() => {});
    }
  }, [activeEnvId]);

  const loadIntegrations = async () => {
    try {
      setLoading(true);
      const data = await getIntegrations();
      setIntegrations(data);
    } catch (error) {
      toast.error('Failed to load integrations');
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleToggleDefaultPermission = async (kind: string) => {
    if (!activeEnvId || !environment) return;
    const channel = KIND_TO_CHANNEL[kind];
    if (!channel) return;
    try {
      const updated = await toggleChannel(activeEnvId, channel);
      setEnvironment(updated);
      const field = ALLOW_FIELD[kind] as keyof Environment;
      toast.success(`Default ${kind} permission ${updated[field] ? 'set to allow' : 'set to block'}`);
    } catch {
      toast.error('Failed to update default permission');
    }
  };

  const handleToggleActive = async (id: number, active: boolean) => {
    try {
      await updateIntegration(id, { active });
      setIntegrations(prev => prev.map(int =>
        int.id === id ? { ...int, active } : int
      ));
      toast.success(`Integration ${active ? 'activated' : 'deactivated'}`);
    } catch (error) {
      toast.error('Failed to update integration');
    }
  };

  const handleDelete = async (id: number, name: string) => {
    const confirmed = await confirm({ title: 'Delete Integration', description: `Are you sure you want to delete the integration "${name}"?`, confirmLabel: 'Delete', variant: 'destructive' });
    if (!confirmed) return;

    try {
      await deleteIntegration(id);
      setIntegrations(prev => prev.filter(int => int.id !== id));
      toast.success('Integration deleted successfully');
    } catch (error) {
      toast.error('Failed to delete integration');
    }
  };

  const handleSendTest = async () => {
    if (!testTarget) return;
    if (!testRecipient.trim()) {
      toast.error('Enter a recipient');
      return;
    }
    try {
      setTestSending(true);
      const result = await testIntegration(testTarget.id, testRecipient.trim());
      if (result.success) {
        toast.success('Test message sent');
        setTestTarget(null);
        setTestRecipient('');
      } else {
        toast.error(result.error || 'Send failed');
      }
    } catch (error: any) {
      toast.error(error.response?.data?.error || error.message || 'Send failed');
    } finally {
      setTestSending(false);
    }
  };

  const handleEmailPreferenceChange = async (field: 'notification_email_integration_id' | 'campaign_email_integration_id', value: string) => {
    if (!environment) return;
    try {
      const updated = await updateEnvironment(environment.id, { [field]: value === 'none' ? null : Number(value) });
      setEnvironment(updated);
      toast.success('Email preference updated');
    } catch {
      toast.error('Failed to update preference');
    }
  };

  const emailIntegrations = integrations.filter(i => i.kind === 'email' && (i.environment_id === activeEnvId || !i.environment_id));

  useEffect(() => {
    if (!environment || !activeEnvId) return;
    const needsNotification = !environment.notification_email_integration_id;
    const needsCampaign = !environment.campaign_email_integration_id;
    if (!needsNotification && !needsCampaign) return;

    const activeEmail = emailIntegrations.find(i => i.active);
    if (!activeEmail) return;

    const updates: Record<string, number> = {};
    if (needsNotification) updates.notification_email_integration_id = activeEmail.id;
    if (needsCampaign) updates.campaign_email_integration_id = activeEmail.id;

    updateEnvironment(environment.id, updates).then(setEnvironment).catch(() => {});
  }, [environment?.id, environment?.notification_email_integration_id, environment?.campaign_email_integration_id, integrations, activeEnvId]);

  // Group integrations by type
  const groupedIntegrations = integrations.reduce((acc, integration) => {
    const kind = integration.kind;
    if (!acc[kind]) acc[kind] = [];
    acc[kind].push(integration);
    return acc;
  }, {} as Record<string, Integration[]>);

  const ChannelIcon = ({ kind }: { kind: string }) => {
    switch (kind) {
      case 'email': return <Mail className="h-5 w-5 text-blue-500" />;
      case 'sms': return <MessageSquare className="h-5 w-5 text-green-500" />;
      case 'whatsapp': return <Phone className="h-5 w-5 text-emerald-500" />;
      case 'push': return <Bell className="h-5 w-5 text-orange-500" />;
      case 'mobile_push': return <Bell className="h-5 w-5 text-orange-500" />;
      case 'web_push': return <Bell className="h-5 w-5 text-purple-500" />;
      default: return <Settings className="h-5 w-5 text-muted-foreground" />;
    }
  };

  if (loading) {
    return <PageSkeleton variant="cards" cards={9} cols={3} actions={1} />;
  }

  return (
    <div className="p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div>
          <h1 className="page-heading">Integrations</h1>
          <p className="page-subtitle">
            Configure your messaging service providers
          </p>
        </div>

        <Button onClick={() => navigate('/integrations/create')}>
          <Plus className="h-4 w-4 mr-2" />
          Add Integration
        </Button>
      </div>

      {emailIntegrations.length >= 1 && environment && (
        <Card className="mb-6">
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-1.5">
              Email Integration Preferences
              <HelpHint label="Notification versus campaign email">
                <strong className="text-foreground">Notification</strong> covers transactional sends
                (<code className="font-mono">POST /messages</code> and template triggers).{' '}
                <strong className="text-foreground">Campaign</strong> covers broadcasts and drips.
                <span className="block mt-1.5">
                  Point them at different providers to keep bulk sending off your transactional
                  reputation. Campaign falls back to the notification integration when unset; if
                  neither is active, the first active email integration is used.
                </span>
              </HelpHint>
            </CardTitle>
            <CardDescription>Choose which email integration to use for notifications and campaigns</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label>Notification Emails</Label>
                <Select
                  value={String(environment.notification_email_integration_id || 'none')}
                  onValueChange={v => handleEmailPreferenceChange('notification_email_integration_id', v)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {emailIntegrations.map(i => {
                      const info = VENDOR_INFO[i.type] || VENDOR_INFO[i.vendor] || { name: i.vendor };
                      return (
                        <SelectItem key={i.id} value={String(i.id)}>
                          {info.name}
                        </SelectItem>
                      );
                    })}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Campaign Emails</Label>
                <Select
                  value={String(environment.campaign_email_integration_id || 'none')}
                  onValueChange={v => handleEmailPreferenceChange('campaign_email_integration_id', v)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {emailIntegrations.map(i => {
                      const info = VENDOR_INFO[i.type] || VENDOR_INFO[i.vendor] || { name: i.vendor };
                      return (
                        <SelectItem key={i.id} value={String(i.id)}>
                          {info.name}
                        </SelectItem>
                      );
                    })}
                  </SelectContent>
                </Select>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {Object.entries(groupedIntegrations).length === 0 ? (
        <div className="text-center py-12">
          <Settings className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
          <h3 className="text-lg font-medium mb-2">No integrations configured</h3>
          <p className="text-muted-foreground mb-4">
            Add your first integration to start sending messages through external services.
          </p>
          <Button onClick={() => navigate('/integrations/create')}>
            <Plus className="h-4 w-4 mr-2" />
            Add Integration
          </Button>
        </div>
      ) : (
        <div className="space-y-8">
          {Object.entries(groupedIntegrations).map(([kind, kindIntegrations]) => (
            <div key={kind}>
              <div className="flex items-center gap-3 mb-4">
                <ChannelIcon kind={kind} />
                <h2 className="text-xl font-semibold capitalize">{kind} Integrations</h2>
                <Badge variant="outline">
                  {kindIntegrations.length} configured
                </Badge>
              </div>

              {environment && ALLOW_FIELD[kind] && (() => {
                const allowed = !!environment[ALLOW_FIELD[kind] as keyof Environment];
                return (
                  <div className={`flex items-center gap-3 mb-4 px-4 py-2.5 rounded-lg border max-w-xl ${
                    allowed
                      ? 'border-amber-200 bg-amber-50 dark:border-amber-500/30 dark:bg-amber-500/10'
                      : 'border-muted bg-muted/30'
                  }`}>
                    {allowed ? (
                      <ShieldCheck className="h-4 w-4 text-amber-600 shrink-0" />
                    ) : (
                      <ShieldOff className="h-4 w-4 text-muted-foreground shrink-0" />
                    )}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium leading-tight flex items-center gap-1.5">
                        {allowed ? 'Unmatched recipients are delivered' : 'Unmatched recipients are blocked'}
                        <HelpHint label="When the default permission applies">
                          This is the fallback, not an override. Messy checks every active delivery
                          rule for the recipient first. Only when no rule matches does this default
                          decide whether the message is sent or rejected.
                        </HelpHint>
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {allowed
                          ? `When no delivery rule matches, ${kind} messages are still sent. Turn off to block by default.`
                          : `When no delivery rule matches, ${kind} messages are blocked. Only explicitly allowed recipients receive messages.`}
                      </p>
                    </div>
                    <Switch
                      checked={allowed}
                      onCheckedChange={() => handleToggleDefaultPermission(kind)}
                      className="shrink-0 data-[state=checked]:bg-amber-500"
                    />
                  </div>
                );
              })()}

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {kindIntegrations.map((integration) => {
                  const info = VENDOR_INFO[integration.type] || VENDOR_INFO[integration.vendor] || { name: integration.vendor, description: '' };
                  const vendorName = info.name;
                  const vendorDescription = info.description;
                  return (
                    <Card key={integration.id} className="relative group hover:shadow-md transition-shadow">
                      {/* Top-right actions */}
                      <div className="absolute top-3 right-3">
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="sm" className="h-7 w-7 p-0 opacity-0 group-hover:opacity-100 transition-opacity">
                              <Settings className="h-3.5 w-3.5" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem onClick={() => navigate(`/integrations/${integration.id}/edit`)}>
                              <Edit className="h-4 w-4 mr-2" />Edit
                            </DropdownMenuItem>
                            <DropdownMenuItem onClick={() => { setTestTarget(integration); setTestRecipient(''); }}>
                              <Send className="h-4 w-4 mr-2" />Send test
                            </DropdownMenuItem>
                            <DropdownMenuItem onClick={() => handleToggleActive(integration.id, !integration.active)}>
                              <Power className="h-4 w-4 mr-2" />
                              {integration.active ? 'Deactivate' : 'Activate'}
                            </DropdownMenuItem>
                            <DropdownMenuItem className="text-destructive" onClick={() => handleDelete(integration.id, integration.name)}>
                              <Trash2 className="h-4 w-4 mr-2" />Delete
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </div>

                      <CardContent className="pt-6 pb-5">
                        {/* Vendor icon */}
                        <div className="mb-4">
                          <VendorIcon type={integration.type} vendor={integration.vendor} size={36} />
                        </div>

                        {/* Name + description */}
                        <p className="font-semibold text-sm text-foreground leading-tight">{vendorName}</p>
                        <p className="text-xs text-muted-foreground mt-0.5">{vendorDescription}</p>

                        {/* Environment */}
                        {integration.environment_name && (
                          <Badge variant="outline" className="mt-2 text-xs font-normal">
                            {integration.environment_name}
                          </Badge>
                        )}

                        {/* Footer: status + toggle */}
                        <div className="flex items-center justify-between mt-4 pt-3 border-t">
                          <Badge className={integration.active ? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-100' : 'bg-red-100 text-red-600 hover:bg-red-100'}>
                            {integration.active ? 'Active' : 'Inactive'}
                          </Badge>
                          <Switch
                            checked={integration.active}
                            onCheckedChange={(checked) => handleToggleActive(integration.id, checked)}
                          />
                        </div>
                      </CardContent>
                    </Card>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}

      <Dialog open={!!testTarget} onOpenChange={(open) => { if (!open) { setTestTarget(null); setTestRecipient(''); } }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Send test message</DialogTitle>
            <DialogDescription>
              Verify {testTarget?.name} is working by sending a test message.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <Label>{(testTarget && TEST_RECIPIENT[testTarget.kind]?.label) || 'To'}</Label>
            <Input
              value={testRecipient}
              onChange={(e) => setTestRecipient(e.target.value)}
              placeholder={(testTarget && TEST_RECIPIENT[testTarget.kind]?.placeholder) || ''}
              onKeyDown={(e) => { if (e.key === 'Enter' && !testSending) handleSendTest(); }}
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setTestTarget(null)} disabled={testSending}>Cancel</Button>
            <Button onClick={handleSendTest} disabled={testSending}>
              {testSending
                ? <><Loader2 className="h-4 w-4 mr-2 animate-spin" />Sending...</>
                : <><Send className="h-4 w-4 mr-2" />Send test</>}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {ConfirmDialog}
    </div>
  );
}
