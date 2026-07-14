import React, { useState, useEffect, KeyboardEvent } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  ArrowLeft, Save, Shield, Mail, MessageSquare,
  Phone, Bell, X, CheckCircle2, Ban, ArrowRight,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Switch } from '@/components/ui/switch';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { getDeliveryRuleById, createDeliveryRule, updateDeliveryRule } from '@/api/rules';
import { getEnvironments, Environment } from '@/api/environments';
import { RequiredAsterisk } from '@/components/ui/required-asterisk';
import { HelpHint } from '@/components/ui/help-hint';
import toast from 'react-hot-toast';

// ── Config ────────────────────────────────────────────────────────────────────

const CHANNELS = [
  { value: 'email',    label: 'Email',     Icon: Mail },
  { value: 'sms',      label: 'SMS',       Icon: MessageSquare },
  { value: 'whatsapp', label: 'WhatsApp',  Icon: Phone },
  { value: 'push',     label: 'Push',      Icon: Bell },
];

const OUTCOMES = [
  { value: 'deliver',  label: 'Deliver',  Icon: CheckCircle2, desc: 'Allow message through',           color: 'text-emerald-600', border: 'border-emerald-500 bg-emerald-50' },
  { value: 'block',    label: 'Block',    Icon: Ban,          desc: 'Stop message from sending',       color: 'text-red-500',     border: 'border-red-500 bg-red-50' },
  { value: 'redirect', label: 'Redirect', Icon: ArrowRight,   desc: 'Send to a different destination', color: 'text-blue-600',    border: 'border-blue-500 bg-blue-50' },
];

// A condition is a plain substring of the recipient, not an expression.
// See Rule#passes? — `rcpt.downcase.include?(condition.downcase)`.
const CONDITION_EXAMPLES = [
  '@acme.com',
  'tempmail.com',
  'qa@example.com',
  '+1555',
];

// ── Tag input ─────────────────────────────────────────────────────────────────

function TagInput({ tags, onChange }: { tags: string[]; onChange: (t: string[]) => void }) {
  const [input, setInput] = useState('');

  const addTag = (raw: string) => {
    const tag = raw.trim().toLowerCase().replace(/\s+/g, '-');
    if (tag && !tags.includes(tag)) onChange([...tags, tag]);
    setInput('');
  };

  const handleKey = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' || e.key === ',') { e.preventDefault(); addTag(input); }
    if (e.key === 'Backspace' && !input && tags.length) onChange(tags.slice(0, -1));
  };

  return (
    <div className="flex flex-wrap gap-1.5 p-2 border rounded-md bg-background min-h-[42px] focus-within:ring-2 focus-within:ring-ring focus-within:ring-offset-2">
      {tags.map(tag => (
        <Badge key={tag} variant="secondary" className="gap-1 pr-1 font-normal">
          {tag}
          <button type="button" onClick={() => onChange(tags.filter(t => t !== tag))} className="hover:text-destructive">
            <X className="h-2.5 w-2.5" />
          </button>
        </Badge>
      ))}
      <input
        value={input}
        onChange={e => setInput(e.target.value)}
        onKeyDown={handleKey}
        onBlur={() => input && addTag(input)}
        placeholder={tags.length === 0 ? 'Add tags (press Enter or comma)…' : ''}
        className="flex-1 min-w-[120px] bg-transparent text-sm outline-none placeholder:text-muted-foreground"
      />
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export function RulesEditPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const isEdit = !!id && id !== 'create';

  const [loading, setLoading] = useState(isEdit);
  const [saving, setSaving] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [environments, setEnvironments] = useState<Environment[]>([]);

  const [form, setForm] = useState({
    name:           '',
    type:           'email',
    condition:      '',
    outcome:        'deliver',
    redirect_to:    '',
    tags:           [] as string[],
    environment_id: '',
    active:         true,
  });

  useEffect(() => {
    const init = async () => {
      try {
        const envs = await getEnvironments();
        setEnvironments(envs);

        if (isEdit) {
          setLoading(true);
          const rule = await getDeliveryRuleById(Number(id));
          setForm({
            name:           rule.name || '',
            type:           rule.type,
            condition:      rule.condition,
            outcome:        rule.outcome,
            redirect_to:    rule.redirect_to || '',
            tags:           rule.tags || [],
            environment_id: String(rule.environment_id || ''),
            active:         rule.active,
          });
        } else if (envs.length > 0) {
          setForm(f => ({ ...f, environment_id: String(envs[0].id) }));
        }
      } catch (err) {
        toast.error('Failed to load data');
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    init();
  }, [id]);

  const set = (k: keyof typeof form, v: unknown) =>
    setForm(f => ({ ...f, [k]: v }));

  const handleSave = async () => {
    setSubmitted(true);
    if (!form.name.trim())      return toast.error('Name is required');
    if (!form.condition.trim()) return toast.error('Condition is required');
    if (!form.environment_id)   return toast.error('Please select an environment');
    if (form.outcome === 'redirect' && !form.redirect_to.trim())
      return toast.error('Redirect destination is required');

    try {
      setSaving(true);
      const payload = {
        name:           form.name,
        type:           form.type as 'email' | 'sms' | 'whatsapp' | 'push',
        condition:      form.condition,
        outcome:        form.outcome as 'deliver' | 'block' | 'redirect',
        tags:           form.tags,
        environment_id: Number(form.environment_id),
        redirect_to:    form.outcome === 'redirect' ? form.redirect_to : undefined,
      };

      if (isEdit) {
        await updateDeliveryRule(Number(id), { ...payload, active: form.active });
        toast.success('Rule updated');
      } else {
        await createDeliveryRule(payload);
        toast.success('Rule created');
      }
      navigate('/rules');
    } catch (err) {
      toast.error(`Failed to ${isEdit ? 'update' : 'create'} rule`);
      console.error(err);
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="h-8 w-48 bg-muted animate-pulse rounded mb-6" />
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-4">
            <div className="h-40 bg-muted animate-pulse rounded-lg" />
            <div className="h-48 bg-muted animate-pulse rounded-lg" />
          </div>
          <div className="h-64 bg-muted animate-pulse rounded-lg" />
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-5xl">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="sm" onClick={() => navigate('/rules')}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div>
            <h1 className="page-heading">{isEdit ? 'Edit Rule' : 'Create Rule'}</h1>
            <p className="page-subtitle">
              {isEdit ? `Editing: ${form.name || '—'}` : 'Define a new delivery rule for your account'}
            </p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* ── Left: main form ── */}
        <div className="lg:col-span-2 space-y-5">

          {/* Basic info */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-base">
                <Shield className="h-4 w-4" />
                Rule Details
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Name */}
              <div>
                <Label htmlFor="name">Name <RequiredAsterisk error={submitted && !form.name.trim()} /></Label>
                <Input
                  id="name"
                  value={form.name}
                  onChange={e => set('name', e.target.value)}
                  placeholder="Block disposable email domains"
                  className="mt-1"
                  onKeyDown={e => e.key === 'Enter' && handleSave()}
                />
              </div>

              {/* Channel */}
              <div>
                <Label>Channel <RequiredAsterisk /></Label>
                <div className="grid grid-cols-4 gap-2 mt-1">
                  {CHANNELS.map(({ value, label, Icon }) => (
                    <button
                      key={value}
                      type="button"
                      onClick={() => set('type', value)}
                      className={`flex flex-col items-center gap-1.5 p-3 rounded-lg border text-xs font-medium transition-colors ${
                        form.type === value
                          ? 'border-primary bg-primary/5 text-primary'
                          : 'border-border text-muted-foreground hover:border-foreground/30 hover:text-foreground'
                      }`}
                    >
                      <Icon className="h-4 w-4" />
                      {label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Environment */}
              <div>
                <Label>Environment <RequiredAsterisk error={submitted && !form.environment_id} /></Label>
                <Select value={form.environment_id} onValueChange={v => set('environment_id', v)}>
                  <SelectTrigger className="mt-1">
                    <SelectValue placeholder="Select environment…" />
                  </SelectTrigger>
                  <SelectContent>
                    {environments.map(env => (
                      <SelectItem key={env.id} value={String(env.id)}>
                        {env.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              {/* Tags */}
              <div>
                <Label className="flex items-center gap-1.5">
                  Tags
                  <HelpHint label="What tags do">
                    Labels for organising and filtering rules in the list. They have no effect on
                    whether a message is delivered.
                  </HelpHint>
                </Label>
                <div className="mt-1">
                  <TagInput tags={form.tags} onChange={t => set('tags', t)} />
                  <p className="text-xs text-muted-foreground mt-1">Press Enter or comma to add a tag</p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Condition */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base flex items-center gap-1.5">
                Condition
                <span className="text-sm font-normal"><RequiredAsterisk error={submitted && !form.condition.trim()} /></span>
                <HelpHint label="How conditions are matched">
                  The condition is a plain, case-insensitive <strong className="text-foreground">substring</strong> of
                  the recipient&rsquo;s email address or phone number. It is not an expression, so
                  comparisons like <code className="font-mono">recipient == '…'</code> never match.
                  <span className="block mt-1.5">
                    <code className="font-mono">@acme.com</code> matches ada@acme.com.{' '}
                    <code className="font-mono">+1555</code> matches +15551234567.
                  </span>
                </HelpHint>
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <Textarea
                value={form.condition}
                onChange={e => set('condition', e.target.value)}
                placeholder="tempmail.com"
                className="font-mono text-sm min-h-[96px] resize-y"
                spellCheck={false}
              />
              <p className="text-xs text-muted-foreground">
                Matched as a case-insensitive substring of the recipient address or phone number.
              </p>
              <div>
                <p className="text-xs text-muted-foreground mb-2 font-medium">Examples</p>
                <div className="grid grid-cols-1 gap-1">
                  {CONDITION_EXAMPLES.map((ex, i) => (
                    <button
                      key={i}
                      type="button"
                      onClick={() => set('condition', ex)}
                      className="text-left text-xs font-mono bg-muted/50 hover:bg-muted px-2.5 py-1.5 rounded transition-colors text-muted-foreground hover:text-foreground"
                    >
                      {ex}
                    </button>
                  ))}
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Outcome */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Outcome <span className="text-sm font-normal ml-1"><RequiredAsterisk /></span></CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                {OUTCOMES.map(({ value, label, Icon, desc, color, border }) => (
                  <button
                    key={value}
                    type="button"
                    onClick={() => set('outcome', value)}
                    className={`flex flex-col items-start gap-1 p-3.5 rounded-lg border-2 text-left transition-colors ${
                      form.outcome === value ? border : 'border-border hover:border-foreground/20'
                    }`}
                  >
                    <Icon className={`h-4 w-4 ${form.outcome === value ? color : 'text-muted-foreground'}`} />
                    <span className={`text-sm font-semibold ${form.outcome === value ? color : 'text-foreground'}`}>{label}</span>
                    <span className="text-xs text-muted-foreground leading-tight">{desc}</span>
                  </button>
                ))}
              </div>

              {/* Redirect target */}
              {form.outcome === 'redirect' && (
                <div>
                  <Label htmlFor="redirect_to">Redirect destination <RequiredAsterisk error={submitted && !form.redirect_to.trim()} /></Label>
                  <Input
                    id="redirect_to"
                    value={form.redirect_to}
                    onChange={e => set('redirect_to', e.target.value)}
                    placeholder="backup@company.com or +15550001234"
                    className="mt-1 font-mono text-sm"
                  />
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* ── Right: sidebar ── */}
        <div className="space-y-5">

          {/* Active toggle */}
          <Card>
            <CardContent className="pt-5">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium">Rule Status</p>
                  <p className="text-xs text-muted-foreground mt-0.5">
                    {form.active ? 'Rule is active and will be evaluated' : 'Rule is inactive and will be skipped'}
                  </p>
                </div>
                <Switch
                  checked={form.active}
                  onCheckedChange={v => set('active', v)}
                />
              </div>
            </CardContent>
          </Card>

          {/* Live preview */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Preview</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="text-xs space-y-2">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Name</span>
                  <span className="font-medium truncate ml-2 max-w-[140px]">{form.name || '—'}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Channel</span>
                  <Badge variant="outline" className="text-xs capitalize">{form.type}</Badge>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Outcome</span>
                  {(() => {
                    const o = OUTCOMES.find(o => o.value === form.outcome);
                    return o ? (
                      <span className={`text-xs font-semibold ${o.color}`}>{o.label}</span>
                    ) : null;
                  })()}
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Status</span>
                  <Badge className={form.active ? 'bg-emerald-100 text-emerald-700 hover:bg-emerald-100' : 'bg-muted text-muted-foreground'}>
                    {form.active ? 'Active' : 'Inactive'}
                  </Badge>
                </div>
                {form.tags.length > 0 && (
                  <div>
                    <span className="text-muted-foreground block mb-1">Tags</span>
                    <div className="flex flex-wrap gap-1">
                      {form.tags.map(t => <Badge key={t} variant="secondary" className="text-xs">{t}</Badge>)}
                    </div>
                  </div>
                )}
                {form.condition && (
                  <div>
                    <span className="text-muted-foreground block mb-1">Condition</span>
                    <code className="text-xs bg-muted px-2 py-1 rounded block font-mono break-all">{form.condition}</code>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Help */}
          <Card>
            <CardHeader>
              <CardTitle className="text-base">How rules work</CardTitle>
            </CardHeader>
            <CardContent>
              <ul className="text-xs text-muted-foreground space-y-2 leading-relaxed">
                <li>• Every active rule in this environment is checked, once per recipient</li>
                <li>• The condition is a case-insensitive substring of the recipient address</li>
                <li>• The first rule whose condition matches decides the outcome; the rest are skipped</li>
                <li>• <strong className="text-foreground">Deliver</strong>: forces the message through</li>
                <li>• <strong className="text-foreground">Block</strong>: drops the message silently</li>
                <li>• <strong className="text-foreground">Redirect</strong>: routes to a different recipient</li>
                <li>• If no rule matches, the channel&rsquo;s default permission applies (set on Integrations)</li>
                <li>• Inactive rules are stored but never evaluated</li>
              </ul>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Actions */}
      <div className="flex justify-end gap-2 mt-6">
        <Button variant="outline" onClick={() => navigate('/rules')} disabled={saving}>
          Cancel
        </Button>
        <Button onClick={handleSave} disabled={saving}>
          <Save className="h-4 w-4 mr-2" />
          {saving ? 'Saving…' : isEdit ? 'Update Rule' : 'Create Rule'}
        </Button>
      </div>
    </div>
  );
}
