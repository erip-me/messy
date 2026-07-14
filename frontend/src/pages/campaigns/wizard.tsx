import React, { useState, useEffect, useReducer, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, ArrowRight, Check, Send, FileText, Users2, Loader2, Search, ChevronRight, Edit3, Eye, Mail, Pencil, X } from 'lucide-react';
import Editor from '@monaco-editor/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { getCampaign, createCampaign, updateCampaign, sendCampaign, sendTestCampaign, CampaignChannel } from '@/api/campaigns';
import { getCustomers, Customer } from '@/api/customers';
import { getSegments, Segment } from '@/api/segments';
import { getSendingIdentities, SendingIdentity } from '@/api/sending-identities';
import { listTemplates, Template } from '@/api/templates';
import { listFolders, Folder as FolderType } from '@/api/folders';
import { ChannelTypeIcon } from '@/components/channel-icons';
import { CampaignPreview, TemplatePicker } from './wizard-components';
import { createAuthenticatedConsumer } from '@/utils/cable';


type WizardStep = 0 | 1 | 2 | 3;

interface WizardState {
  step: WizardStep;
  channel: CampaignChannel | null;
  templateId: number | null;
  template: Template | null;
  segmentId: number | null;
  useAllCustomers: boolean;
  name: string;
  subject: string;
  fromEmail: string;
  sendingIdentityId: number | null;
  content: string;
  campaignId: number | null;
}

type WizardAction =
  | { type: 'SET_STEP'; step: WizardStep }
  | { type: 'SET_CHANNEL'; channel: CampaignChannel }
  | { type: 'SET_TEMPLATE'; template: Template | null; templateId: number | null }
  | { type: 'HYDRATE_TEMPLATE'; template: Template }
  | { type: 'SET_CUSTOM_CONTENT' }
  | { type: 'SET_SEGMENT'; segmentId: number | null; useAllCustomers: boolean }
  | { type: 'SET_FIELD'; field: string; value: string | number | null }
  | { type: 'LOAD_CAMPAIGN'; data: Partial<WizardState> };

function reducer(state: WizardState, action: WizardAction): WizardState {
  switch (action.type) {
    case 'SET_STEP':
      return { ...state, step: action.step };
    case 'SET_CHANNEL':
      return {
        ...state, channel: action.channel,
        templateId: null, template: null, content: '', subject: '',
      };
    case 'SET_TEMPLATE':
      return {
        ...state,
        templateId: action.templateId,
        template: action.template,
        subject: action.template?.subject || state.subject,
        content: action.template?.body || state.content,
      };
    case 'HYDRATE_TEMPLATE':
      // Enrich the template object with its full body (e.g. after loading a
      // campaign for edit, whose serialized template omits the body). Leaves the
      // campaign's own subject/content untouched — unlike SET_TEMPLATE.
      return { ...state, template: action.template };
    case 'SET_CUSTOM_CONTENT':
      return { ...state, templateId: null, template: null };
    case 'SET_SEGMENT':
      return { ...state, segmentId: action.segmentId, useAllCustomers: action.useAllCustomers };
    case 'SET_FIELD':
      return { ...state, [action.field]: action.value };
    case 'LOAD_CAMPAIGN':
      return { ...state, ...action.data };
    default:
      return state;
  }
}

const initialState: WizardState = {
  step: 0,
  channel: null,
  templateId: null,
  template: null,
  segmentId: null,
  useAllCustomers: false,
  name: '',
  subject: '',
  fromEmail: '',
  sendingIdentityId: null,
  content: '',
  campaignId: null,
};

const CHANNELS: { key: CampaignChannel; label: string; description: string }[] = [
  { key: 'email', label: 'Email', description: 'HTML emails with tracking' },
  { key: 'sms', label: 'SMS', description: 'Text messages via Twilio' },
  { key: 'whatsapp', label: 'WhatsApp', description: 'WhatsApp Business API' },
  { key: 'push', label: 'Push', description: 'Mobile push notifications' },
];

const STEPS = ['Channel', 'Template', 'Audience', 'Review'];

// --- Campaign Preview (reuses template edit preview logic) ---
// --- Main Wizard ---
export function CampaignWizardPage() {
  const { id } = useParams<{ id: string }>();
  const isEdit = !!id;
  const navigate = useNavigate();

  const [state, dispatch] = useReducer(reducer, initialState);
  const [loading, setLoading] = useState(isEdit);
  const [saving, setSaving] = useState(false);
  const [sending, setSending] = useState(false);
  const [segments, setSegments] = useState<Segment[]>([]);
  const [identities, setIdentities] = useState<SendingIdentity[]>([]);
  const [templates, setTemplates] = useState<Template[]>([]);
  const [folders, setFolders] = useState<FolderType[]>([]);
  const [templatePickerOpen, setTemplatePickerOpen] = useState(false);
  const [segmentPickerOpen, setSegmentPickerOpen] = useState(false);
  const [testCustomerQuery, setTestCustomerQuery] = useState('');
  const [testSearchResults, setTestSearchResults] = useState<Customer[]>([]);
  const [selectedTestCustomers, setSelectedTestCustomers] = useState<Customer[]>([]);
  const [testSearching, setTestSearching] = useState(false);
  const [sendingTest, setSendingTest] = useState(false);
  const [editingSubject, setEditingSubject] = useState(false);
  const [testMessageMap, setTestMessageMap] = useState<Record<number, number>>({}); // customerId → messageId
  const [openedMessageIds, setOpenedMessageIds] = useState<Set<number>>(new Set());
  const cableRef = useRef<ReturnType<typeof createAuthenticatedConsumer> | null>(null);
  const subscriptionRef = useRef<any>(null);
  const { confirm, ConfirmDialog } = useConfirm();

  useEffect(() => {
    let cancelled = false;
    getSegments().then(s => { if (!cancelled) setSegments(s); }).catch(() => { if (!cancelled) toast.error('Failed to load segments'); });
    getSendingIdentities().then(i => { if (!cancelled) setIdentities(i); }).catch(() => {});
    if (isEdit) {
      getCampaign(Number(id))
        .then(c => {
          if (cancelled) return;
          dispatch({
            type: 'LOAD_CAMPAIGN',
            data: {
              campaignId: c.id,
              channel: c.channel || 'email',
              templateId: c.template_id,
              template: c.template ? { id: c.template.id, name: c.template.name, channel: c.template.channel as CampaignChannel } as unknown as Template : null,
              segmentId: c.segment_id,
              useAllCustomers: !c.segment_id,
              name: c.name,
              subject: c.subject,
              fromEmail: c.from_email,
              sendingIdentityId: c.sending_identity_id,
              content: c.content || '',
              step: 3,
            }
          });
        })
        .catch(() => { if (!cancelled) toast.error('Failed to load campaign'); })
        .finally(() => { if (!cancelled) setLoading(false); });
    }
    return () => { cancelled = true; };
  }, [id, isEdit]);

  useEffect(() => {
    Promise.all([
      listTemplates({ scope: 'account' }),
      listFolders(),
    ])
      .then(([t, f]) => { setTemplates(t); setFolders(f); })
      .catch(e => {
        console.error('Failed to load templates/folders', e);
        toast.error('Failed to load templates');
      });
  }, []);

  // When editing, the campaign's serialized template carries no body (see
  // campaign_json), so the live preview would render "No content to preview".
  // Once the full templates list loads, swap in the complete template.
  useEffect(() => {
    if (!state.templateId || templates.length === 0) return;
    if (state.template?.body) return;
    const full = templates.find(t => t.id === state.templateId);
    if (full?.body) dispatch({ type: 'HYDRATE_TEMPLATE', template: full });
  }, [state.templateId, state.template, templates]);

  useEffect(() => {
    if (!testCustomerQuery.trim()) { setTestSearchResults([]); return; }
    const timeout = setTimeout(() => {
      setTestSearching(true);
      getCustomers({ q: testCustomerQuery, per_page: 8 })
        .then(r => setTestSearchResults(r.customers))
        .catch(() => {})
        .finally(() => setTestSearching(false));
    }, 300);
    return () => clearTimeout(timeout);
  }, [testCustomerQuery]);

  // WebSocket: listen for message opens to update test email badges
  useEffect(() => {
    const trackedIds = Object.values(testMessageMap);
    if (trackedIds.length === 0) return;

    cableRef.current = createAuthenticatedConsumer();
    if (!cableRef.current) return;
    subscriptionRef.current = cableRef.current.subscriptions.create(
      { channel: "MessagesChannel" },
      {
        received(data: { action: string; message?: { id: number; open_count?: number } }) {
          if (data.action === "update" && data.message && trackedIds.includes(data.message.id)) {
            if (data.message.open_count && data.message.open_count > 0) {
              setOpenedMessageIds(prev => new Set([...prev, data.message!.id]));
            }
          }
        },
      }
    );

    return () => {
      if (subscriptionRef.current) subscriptionRef.current.unsubscribe();
      if (cableRef.current) cableRef.current.disconnect();
    };
  }, [testMessageMap]);

  const handleSendTest = async () => {
    if (selectedTestCustomers.length === 0) { toast.error('Select at least one customer'); return; }
    if (!state.name.trim()) { toast.error('Campaign name is required'); return; }
    if (state.channel === 'email' && !state.subject.trim()) {
      toast.error('Subject is required'); return;
    }

    const content = state.template?.body || state.content;
    const uniqueTags = [...new Set(
      [...content.matchAll(/\{\{\s*([\w.]+)\s*\}\}/g)].map(m => m[1])
    )];
    const customersWithMissing = selectedTestCustomers.filter(customer => {
      const availableKeys = new Set([
        'first_name', 'last_name', 'email', 'unsubscribe_url',
        ...Object.keys(customer.custom_attributes || {}),
      ]);
      return uniqueTags.some(tag => {
        if (availableKeys.has(tag)) {
          const val = tag === 'first_name' ? customer.first_name
            : tag === 'last_name' ? customer.last_name
            : tag === 'email' ? customer.email
            : tag === 'unsubscribe_url' ? 'always set'
            : (customer.custom_attributes || {})[tag];
          return !val;
        }
        return true;
      });
    });

    if (customersWithMissing.length > 0) {
      const names = customersWithMissing.map(c => c.email).join(', ');
      const confirmed = await confirm({
        title: 'Missing Merge Tags',
        description: `Some customers (${names}) are missing merge tag values. These will render as empty in the test email. Send anyway?`,
        confirmLabel: 'Send Anyway',
      });
      if (!confirmed) return;
    }

    setSendingTest(true);
    try {
      let campaignId = state.campaignId;
      if (isEdit) {
        await updateCampaign(Number(id), buildPayload());
      } else if (!campaignId) {
        const created = await createCampaign(buildPayload());
        campaignId = created.id;
        navigate(`/campaigns/${created.id}/edit`, { replace: true });
      }
      const results = await Promise.all(
        selectedTestCustomers.map(c => sendTestCampaign(campaignId!, c.id))
      );
      const newMap: Record<number, number> = {};
      selectedTestCustomers.forEach((c, i) => {
        if (results[i]?.message_id) newMap[c.id] = results[i].message_id;
      });
      setTestMessageMap(prev => ({ ...prev, ...newMap }));
      setOpenedMessageIds(prev => {
        const next = new Set(prev);
        Object.values(newMap).forEach(id => next.delete(id));
        return next;
      });
      toast.success(`Test email sent to ${results.length} recipient${results.length > 1 ? 's' : ''}`);
    } catch (e: unknown) {
      const err = e as { response?: { data?: { error?: string } } };
      toast.error(err.response?.data?.error || 'Failed to send test');
    } finally { setSendingTest(false); }
  };

  const buildPayload = () => ({
    name: state.name,
    subject: state.subject,
    content: state.content,
    channel: state.channel,
    template_id: state.templateId,
    segment_id: state.useAllCustomers ? null : state.segmentId,
    sending_identity_id: state.sendingIdentityId,
  });

  const handleSave = async () => {
    if (!state.name.trim()) { toast.error('Campaign name is required'); return; }
    if (state.channel === 'email' && !state.subject.trim()) {
      toast.error('Subject is required for email campaigns'); return;
    }
    setSaving(true);
    try {
      if (isEdit) {
        await updateCampaign(Number(id), buildPayload());
        toast.success('Campaign saved');
      } else {
        const created = await createCampaign(buildPayload());
        toast.success('Campaign created');
        navigate(`/campaigns/${created.id}/edit`);
      }
    } catch (e: unknown) {
      const err = e as { response?: { data?: { errors?: string[] } } };
      toast.error(err.response?.data?.errors?.[0] || 'Failed to save');
    } finally { setSaving(false); }
  };

  const handleSend = async () => {
    if (!state.name.trim()) { toast.error('Campaign name is required'); return; }
    if (state.channel === 'email' && !state.subject.trim()) {
      toast.error('Subject line is required for email campaigns'); return;
    }
    if (!state.useAllCustomers && !state.segmentId) { toast.error('Please select an audience'); return; }
    if (!state.templateId && !state.content.trim()) { toast.error('Campaign content is required'); return; }
    const confirmed = await confirm({
      title: 'Send Campaign',
      description: 'Send this campaign? This cannot be undone.',
      confirmLabel: 'Send',
      variant: 'destructive',
    });
    if (!confirmed) return;
    setSending(true);
    try {
      if (isEdit) {
        await updateCampaign(Number(id), buildPayload());
        await sendCampaign(Number(id));
        navigate(`/campaigns/${id}`);
      } else {
        const created = await createCampaign(buildPayload());
        await sendCampaign(created.id);
        navigate(`/campaigns/${created.id}`);
      }
      toast.success('Campaign is now sending!');
    } catch (e: unknown) {
      const err = e as { response?: { data?: { error?: string; errors?: string[] } } };
      toast.error(err.response?.data?.error || err.response?.data?.errors?.[0] || 'Failed to send');
    } finally { setSending(false); }
  };

  const handleTemplateSelect = (template: Template) => {
    dispatch({ type: 'SET_TEMPLATE', template, templateId: template.id });
    dispatch({ type: 'SET_STEP', step: 2 });
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

  return (
    <div className={`p-6 ${state.step === 3 ? '' : 'max-w-2xl'}`}>
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <Button variant="ghost" size="sm" onClick={() => navigate('/campaigns')}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div>
          <h1 className="page-heading">{isEdit ? 'Edit Campaign' : 'New Campaign'}</h1>
          <p className="page-subtitle">
            {isEdit ? 'Update your campaign settings' : 'Create a new campaign to reach your audience'}
          </p>
        </div>
      </div>

      {/* Step indicator */}
      <div className="flex items-center gap-1 mb-8">
        {STEPS.map((label, i) => (
          <React.Fragment key={label}>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => i < state.step && dispatch({ type: 'SET_STEP', step: i as WizardStep })}
                disabled={i > state.step}
                className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-medium border-2 transition-colors ${
                  i < state.step
                    ? 'bg-primary border-primary text-primary-foreground cursor-pointer'
                    : i === state.step
                      ? 'border-primary text-primary'
                      : 'border-muted-foreground/30 text-muted-foreground/50 cursor-not-allowed'
                }`}
              >
                {i < state.step ? <Check className="h-3.5 w-3.5" /> : i + 1}
              </button>
              <span
                className={`text-sm hidden sm:inline ${
                  i <= state.step ? 'text-foreground font-medium' : 'text-muted-foreground'
                }`}
              >
                {label}
              </span>
            </div>
            {i < STEPS.length - 1 && (
              <div
                className={`flex-1 h-0.5 mx-2 rounded ${
                  i < state.step ? 'bg-primary' : 'bg-muted-foreground/20'
                }`}
              />
            )}
          </React.Fragment>
        ))}
      </div>

      {/* Step 0: Channel Selection */}
      {state.step === 0 && (
        <div className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Select a channel</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 gap-3">
                {CHANNELS.map(({ key, label, description }) => (
                  <button
                    key={key}
                    type="button"
                    onClick={() => dispatch({ type: 'SET_CHANNEL', channel: key })}
                    className={`flex items-center gap-3 p-4 rounded-lg border-2 text-left transition-colors ${
                      state.channel === key
                        ? 'border-primary bg-primary/5'
                        : 'border-muted hover:border-muted-foreground/30'
                    }`}
                  >
                    <ChannelTypeIcon type={key} size={28} />
                    <div>
                      <p className="font-medium text-sm">{label}</p>
                      <p className="text-xs text-muted-foreground">{description}</p>
                    </div>
                  </button>
                ))}
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="pt-4">
              <div className="space-y-2">
                <Label>Campaign Name</Label>
                <Input
                  placeholder="e.g. March Newsletter"
                  value={state.name}
                  onChange={e => dispatch({ type: 'SET_FIELD', field: 'name', value: e.target.value })}
                />
              </div>
              {state.channel === 'email' && (
                <div className="space-y-2 mt-4">
                  <Label>From</Label>
                  <Select
                    value={state.sendingIdentityId ? String(state.sendingIdentityId) : 'default'}
                    onValueChange={v => dispatch({ type: 'SET_FIELD', field: 'sendingIdentityId', value: v === 'default' ? null : Number(v) })}
                  >
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="default">Default (channel from address)</SelectItem>
                      {identities.map(i => (
                        <SelectItem key={i.id} value={String(i.id)}>{i.from_name ? `${i.from_name} <${i.from_email}>` : i.from_email}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              )}
            </CardContent>
          </Card>

          <div className="flex justify-end">
            <Button
              onClick={() => {
                if (!state.channel) { toast.error('Select a channel'); return; }
                if (!state.name.trim()) { toast.error('Enter a campaign name'); return; }
                dispatch({ type: 'SET_STEP', step: 1 });
              }}
            >
              Next <ArrowRight className="h-4 w-4 ml-2" />
            </Button>
          </div>
        </div>
      )}

      {/* Step 1: Template or Raw — two choices */}
      {state.step === 1 && (
        <div className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Choose content source</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {/* Select Template */}
                <button
                  type="button"
                  onClick={() => setTemplatePickerOpen(true)}
                  className={`flex items-center gap-3 p-4 rounded-lg border-2 text-left transition-colors w-full ${
                    state.templateId
                      ? 'border-primary bg-primary/5'
                      : 'border-muted hover:border-muted-foreground/30'
                  }`}
                >
                  <FileText className="h-5 w-5 text-muted-foreground shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="font-medium text-sm">Select Template</p>
                    {state.template ? (
                      <p className="text-xs text-primary truncate">{state.template.name}</p>
                    ) : (
                      <p className="text-xs text-muted-foreground">Browse and choose from your saved templates</p>
                    )}
                  </div>
                  <ChevronRight className="h-4 w-4 text-muted-foreground shrink-0" />
                </button>

                {/* Write Raw Content */}
                <button
                  type="button"
                  onClick={() => {
                    dispatch({ type: 'SET_CUSTOM_CONTENT' });
                    dispatch({ type: 'SET_STEP', step: 2 });
                  }}
                  className="flex items-center gap-3 p-4 rounded-lg border-2 text-left transition-colors w-full border-muted hover:border-muted-foreground/30"
                >
                  <Edit3 className="h-5 w-5 text-muted-foreground shrink-0" />
                  <div className="flex-1">
                    <p className="font-medium text-sm">Write Raw Content</p>
                    <p className="text-xs text-muted-foreground">Create content from scratch using the editor</p>
                  </div>
                  <ArrowRight className="h-4 w-4 text-muted-foreground shrink-0" />
                </button>
              </div>
            </CardContent>
          </Card>

          <div className="flex justify-between">
            <Button variant="outline" onClick={() => dispatch({ type: 'SET_STEP', step: 0 })}>
              <ArrowLeft className="h-4 w-4 mr-2" /> Back
            </Button>
          </div>

          {/* Template Picker Dialog */}
          <TemplatePicker
            open={templatePickerOpen}
            onOpenChange={setTemplatePickerOpen}
            templates={templates}
            folders={folders}
            channel={state.channel!}
            onSelect={handleTemplateSelect}
          />
        </div>
      )}

      {/* Step 2: Audience Selection */}
      {state.step === 2 && (
        <div className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Select audience</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <button
                  type="button"
                  onClick={() => dispatch({ type: 'SET_SEGMENT', segmentId: null, useAllCustomers: true })}
                  className={`flex items-center gap-3 p-4 rounded-lg border-2 text-left transition-colors w-full ${
                    state.useAllCustomers
                      ? 'border-primary bg-primary/5'
                      : 'border-muted hover:border-muted-foreground/30'
                  }`}
                >
                  <Users2 className="h-5 w-5 text-muted-foreground" />
                  <div className="flex-1">
                    <p className="font-medium text-sm">All Contacts</p>
                    <p className="text-xs text-muted-foreground">Send to everyone in your account</p>
                  </div>
                </button>

                {/* Specific Segment */}
                <button
                  type="button"
                  onClick={() => setSegmentPickerOpen(true)}
                  className={`flex items-center gap-3 p-4 rounded-lg border-2 text-left transition-colors w-full ${
                    !state.useAllCustomers && state.segmentId
                      ? 'border-primary bg-primary/5'
                      : 'border-muted hover:border-muted-foreground/30'
                  }`}
                >
                  <Users2 className="h-5 w-5 text-muted-foreground shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="font-medium text-sm">Specific Segment</p>
                    {!state.useAllCustomers && state.segmentId ? (() => {
                      const seg = segments.find(s => s.id === state.segmentId);
                      return (
                        <p className="text-xs text-primary truncate">
                          {seg?.name}
                          <span className="text-muted-foreground ml-1">
                            ({seg?.customer_count.toLocaleString()} customers)
                          </span>
                        </p>
                      );
                    })() : (
                      <p className="text-xs text-muted-foreground">Target a specific group of customers</p>
                    )}
                  </div>
                  <ChevronRight className="h-4 w-4 text-muted-foreground shrink-0" />
                </button>
              </div>
            </CardContent>
          </Card>

          <div className="flex justify-between">
            <Button variant="outline" onClick={() => dispatch({ type: 'SET_STEP', step: 1 })}>
              <ArrowLeft className="h-4 w-4 mr-2" /> Back
            </Button>
            <Button
              onClick={() => {
                if (!state.useAllCustomers && !state.segmentId) {
                  toast.error('Select an audience');
                  return;
                }
                dispatch({ type: 'SET_STEP', step: 3 });
              }}
            >
              Next <ArrowRight className="h-4 w-4 ml-2" />
            </Button>
          </div>

          {/* Segment Picker Dialog */}
          <Dialog open={segmentPickerOpen} onOpenChange={setSegmentPickerOpen}>
            <DialogContent className="max-w-lg">
              <DialogHeader>
                <DialogTitle>Select a segment</DialogTitle>
              </DialogHeader>
              {segments.length === 0 ? (
                <div className="text-center py-12 text-muted-foreground">
                  <Users2 className="h-8 w-8 mx-auto mb-2 opacity-40" />
                  <p className="text-sm">No segments created yet</p>
                  <p className="text-xs mt-1">
                    <a href="/segments/new" className="text-primary hover:underline">Create a segment</a> to target specific customers.
                  </p>
                </div>
              ) : (
                <div className="space-y-1">
                  {segments.map(s => (
                    <button
                      key={s.id}
                      type="button"
                      onClick={() => {
                        dispatch({ type: 'SET_SEGMENT', segmentId: s.id, useAllCustomers: false });
                        setSegmentPickerOpen(false);
                      }}
                      className="flex items-center gap-3 p-3 rounded-lg w-full text-left hover:bg-muted/50 transition-colors"
                    >
                      <Users2 className="h-5 w-5 text-muted-foreground shrink-0" />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium">{s.name}</p>
                        {s.description && <p className="text-xs text-muted-foreground truncate">{s.description}</p>}
                      </div>
                      <Badge variant="secondary" className="text-xs shrink-0">
                        {s.customer_count.toLocaleString()}
                      </Badge>
                    </button>
                  ))}
                </div>
              )}
            </DialogContent>
          </Dialog>
        </div>
      )}

      {/* Step 3: Review & Send */}
      {state.step === 3 && (
        <div className="space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
            {/* Left: Settings */}
            <div className="space-y-4">
              {/* Summary */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-base">Campaign Summary</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div className="grid grid-cols-2 gap-4 text-sm">
                    <div>
                      <p className="text-muted-foreground">Channel</p>
                      <div className="flex items-center gap-2 mt-1">
                        <ChannelTypeIcon type={state.channel || 'email'} size={16} />
                        <span className="capitalize font-medium">{state.channel}</span>
                      </div>
                    </div>
                    <div>
                      <p className="text-muted-foreground">Template</p>
                      <p className="mt-1 font-medium">{state.template?.name || 'Raw content'}</p>
                    </div>
                    <div>
                      <p className="text-muted-foreground">Audience</p>
                      <p className="mt-1 font-medium">
                        {state.useAllCustomers
                          ? 'All customers'
                          : segments.find(s => s.id === state.segmentId)?.name || '—'}
                      </p>
                    </div>
                    {!state.useAllCustomers && state.segmentId && (
                      <div>
                        <p className="text-muted-foreground">Est. Recipients</p>
                        <p className="mt-1 font-medium">
                          {segments.find(s => s.id === state.segmentId)?.customer_count.toLocaleString() || '—'}
                        </p>
                      </div>
                    )}
                  </div>
                  {state.channel === 'email' && (
                    <div className="pt-3 border-t text-sm">
                      <p className="text-muted-foreground mb-1">Subject Line</p>
                      {editingSubject ? (
                        <Input
                          autoFocus
                          value={state.subject}
                          onChange={e => dispatch({ type: 'SET_FIELD', field: 'subject', value: e.target.value })}
                          onBlur={() => setEditingSubject(false)}
                          onKeyDown={e => { if (e.key === 'Enter') setEditingSubject(false); }}
                          placeholder="Your email subject…"
                        />
                      ) : (
                        <button
                          type="button"
                          onClick={() => setEditingSubject(true)}
                          className="flex items-center gap-2 group w-full text-left"
                        >
                          <span className="font-medium truncate">
                            {state.subject || <span className="text-muted-foreground italic">No subject</span>}
                          </span>
                          <Pencil className="h-3.5 w-3.5 text-muted-foreground opacity-0 group-hover:opacity-100 transition-opacity shrink-0" />
                        </button>
                      )}
                    </div>
                  )}
                </CardContent>
              </Card>

              {/* Send test email */}
              {state.channel === 'email' && (
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base flex items-center gap-2">
                      <Mail className="h-4 w-4" />
                      Send Test Email
                    </CardTitle>
                    <CardDescription>
                      Send a preview to one or more customers. Subject will be prefixed with [TEST]. Delivery rules are bypassed for test sends.
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-3">
                      {selectedTestCustomers.length > 0 && (
                        <div className="flex flex-wrap gap-1.5">
                          {selectedTestCustomers.map(c => {
                            const msgId = testMessageMap[c.id];
                            const opened = msgId ? openedMessageIds.has(msgId) : false;
                            return (
                            <Badge key={c.id} variant={opened ? "success" : "secondary"} className="gap-1 pr-1">
                              {c.email}
                              {opened && <Check className="h-3 w-3" />}
                              <button
                                type="button"
                                onClick={() => setSelectedTestCustomers(prev =>
                                  prev.filter(p => p.id !== c.id)
                                )}
                                className="ml-0.5 rounded-sm hover:bg-muted-foreground/20 p-0.5"
                              >
                                <X className="h-3 w-3" />
                              </button>
                            </Badge>
                            );
                          })}
                        </div>
                      )}
                      <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                        <Input
                          placeholder="Search customers by name or email…"
                          value={testCustomerQuery}
                          onChange={e => setTestCustomerQuery(e.target.value)}
                          className="pl-10"
                        />
                      </div>
                      {testCustomerQuery.trim() && (
                        <div className="border rounded-md max-h-48 overflow-y-auto">
                          {testSearching ? (
                            <div className="p-3 text-sm text-muted-foreground flex items-center gap-2">
                              <Loader2 className="h-3 w-3 animate-spin" /> Searching…
                            </div>
                          ) : testSearchResults.length === 0 ? (
                            <div className="p-3 text-sm text-muted-foreground">No customers found</div>
                          ) : (
                            testSearchResults
                              .filter(c => !selectedTestCustomers.some(s => s.id === c.id))
                              .map(c => (
                                <button
                                  key={c.id}
                                  type="button"
                                  onClick={() => {
                                    setSelectedTestCustomers(prev => [...prev, c]);
                                    setTestCustomerQuery('');
                                    setTestSearchResults([]);
                                  }}
                                  className="flex items-center gap-3 w-full text-left px-3 py-2 hover:bg-muted/50 transition-colors text-sm"
                                >
                                  <div className="flex-1 min-w-0">
                                    <p className="font-medium truncate">
                                      {[c.first_name, c.last_name].filter(Boolean).join(' ') || c.email}
                                    </p>
                                    {(c.first_name || c.last_name) && (
                                      <p className="text-xs text-muted-foreground truncate">{c.email}</p>
                                    )}
                                  </div>
                                </button>
                              ))
                          )}
                        </div>
                      )}
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={handleSendTest}
                        disabled={selectedTestCustomers.length === 0 || sendingTest}
                        className="w-full"
                      >
                        {sendingTest ? (
                          <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Sending…</>
                        ) : (
                          <><Mail className="h-4 w-4 mr-2" /> Send Test{selectedTestCustomers.length > 1 ? ` (${selectedTestCustomers.length})` : ''}</>
                        )}
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              )}
            </div>

            {/* Right: Content editor / preview */}
            <div className="space-y-4">
              {state.channel === 'email' && !state.templateId ? (
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base flex items-center gap-2">
                      <Edit3 className="h-5 w-5" />
                      Email Content
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <Tabs defaultValue="editor">
                      <TabsList className="grid w-full grid-cols-2">
                        <TabsTrigger value="editor">HTML Editor</TabsTrigger>
                        <TabsTrigger value="preview">Preview</TabsTrigger>
                      </TabsList>
                      <TabsContent value="editor" className="mt-4">
                        <div className="rounded-lg border overflow-hidden">
                          <Editor
                            height="500px"
                            language="html"
                            value={state.content}
                            onChange={v => dispatch({ type: 'SET_FIELD', field: 'content', value: v || '' })}
                            theme="vs-dark"
                            options={{
                              minimap: { enabled: false },
                              fontSize: 13,
                              wordWrap: 'on',
                              lineNumbers: 'on',
                              scrollBeyondLastLine: false,
                            }}
                          />
                        </div>
                      </TabsContent>
                      <TabsContent value="preview" className="mt-4">
                        <div className="border rounded-md min-h-[500px] bg-card">
                          <CampaignPreview content={state.content} template={null} channel={state.channel} />
                        </div>
                      </TabsContent>
                    </Tabs>
                  </CardContent>
                </Card>
              ) : (
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base flex items-center gap-2">
                      <Eye className="h-5 w-5" />
                      Live Preview
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="border rounded-md min-h-[400px] bg-card">
                      <CampaignPreview content={state.content} template={state.template} channel={state.channel} />
                    </div>
                  </CardContent>
                </Card>
              )}
              {state.channel === 'email' && !state.templateId && (
                <Card>
                  <CardContent className="p-4">
                    <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide mb-2">Template Variables</p>
                    <div className="space-y-1 text-xs text-muted-foreground">
                      <p><code className="bg-muted px-1 rounded">{'{{first_name}}'}</code>: Customer first name</p>
                      <p><code className="bg-muted px-1 rounded">{'{{last_name}}'}</code>: Customer last name</p>
                      <p><code className="bg-muted px-1 rounded">{'{{email}}'}</code>: Customer email</p>
                      <p><code className="bg-muted px-1 rounded">{'{{unsubscribe_url}}'}</code>: Unsubscribe link</p>
                    </div>
                  </CardContent>
                </Card>
              )}
            </div>
          </div>

          {/* Actions */}
          <div className="flex justify-between gap-2 flex-wrap">
            <Button variant="outline" onClick={() => dispatch({ type: 'SET_STEP', step: 2 })}>
              <ArrowLeft className="h-4 w-4 mr-2" /> Back
            </Button>
            <div className="flex gap-2 flex-wrap">
              <Button variant="outline" onClick={handleSave} disabled={saving}>
                {saving ? (
                  <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Saving...</>
                ) : 'Save Draft'}
              </Button>
              <Button onClick={handleSend} disabled={sending}>
                {sending ? (
                  <><Loader2 className="h-4 w-4 mr-2 animate-spin" /> Sending...</>
                ) : (
                  <><Send className="h-4 w-4 mr-2" /> Send Campaign</>
                )}
              </Button>
            </div>
          </div>
        </div>
      )}

      {ConfirmDialog}
    </div>
  );
}
