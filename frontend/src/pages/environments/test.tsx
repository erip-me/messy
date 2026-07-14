import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  ArrowLeft, FlaskConical, Send, CheckCircle2, XCircle,
  Mail, MessageSquare, Phone, Bell, Loader2
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { getEnvironmentById, testEnvironment, Environment } from '@/api/environments';
import toast from 'react-hot-toast';

type Channel = 'email' | 'sms' | 'whatsapp' | 'push';

const CHANNEL_CONFIG: Record<Channel, {
  icon: React.ElementType;
  label: string;
  color: string;
  bg: string;
  border: string;
  placeholder: string;
  allowField: keyof Environment;
}> = {
  email: {
    icon: Mail,
    label: 'Email',
    color: 'text-blue-600',
    bg: 'bg-blue-50',
    border: 'border-blue-200',
    placeholder: 'recipient@example.com',
    allowField: 'allow_email',
  },
  sms: {
    icon: MessageSquare,
    label: 'SMS',
    color: 'text-emerald-600',
    bg: 'bg-emerald-50',
    border: 'border-emerald-200',
    placeholder: '+1234567890',
    allowField: 'allow_sms',
  },
  whatsapp: {
    icon: Phone,
    label: 'WhatsApp',
    color: 'text-green-600',
    bg: 'bg-green-50',
    border: 'border-green-200',
    placeholder: '+1234567890',
    allowField: 'allow_whatsapp',
  },
  push: {
    icon: Bell,
    label: 'Push',
    color: 'text-amber-600',
    bg: 'bg-amber-50',
    border: 'border-amber-200',
    placeholder: 'Device token or user ID',
    allowField: 'allow_mobile_push',
  },
};

type SendStatus = 'idle' | 'sending' | 'success' | 'error';

export function EnvironmentsTestPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const [env, setEnv] = useState<Environment | null>(null);
  const [loading, setLoading] = useState(true);

  const [selectedChannel, setSelectedChannel] = useState<Channel>('email');
  const [to, setTo] = useState('');
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('Hello! This is a test message from Messy.');
  const [status, setStatus] = useState<SendStatus>('idle');
  const [resultMessage, setResultMessage] = useState('');

  useEffect(() => {
    if (!id) return;
    getEnvironmentById(Number(id))
      .then(data => {
        setEnv(data);
        // Auto-select first enabled channel
        const firstEnabled = (Object.keys(CHANNEL_CONFIG) as Channel[]).find(
          ch => data[CHANNEL_CONFIG[ch].allowField]
        );
        if (firstEnabled) setSelectedChannel(firstEnabled);
      })
      .catch(() => toast.error('Failed to load environment'))
      .finally(() => setLoading(false));
  }, [id]);

  const enabledChannels = env
    ? (Object.keys(CHANNEL_CONFIG) as Channel[]).filter(ch => env[CHANNEL_CONFIG[ch].allowField])
    : [];

  const handleSend = async () => {
    if (!to.trim() || !body.trim()) {
      toast.error('Recipient and message body are required');
      return;
    }
    setStatus('sending');
    setResultMessage('');
    try {
      await testEnvironment(Number(id), {
        channel: selectedChannel,
        to: to.trim(),
        subject: subject.trim() || undefined,
        body: body.trim(),
      });
      setStatus('success');
      setResultMessage('Test message queued successfully!');
      toast.success('Test message sent!');
    } catch (err: any) {
      const msg = err?.response?.data?.error || 'Failed to send test message';
      setStatus('error');
      setResultMessage(msg);
      toast.error(msg);
    }
  };

  const cfg = CHANNEL_CONFIG[selectedChannel];
  const Icon = cfg.icon;

  if (loading) {
    return (
      <div className="p-6 flex items-center justify-center min-h-[400px]">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (!env) {
    return (
      <div className="p-6 text-center">
        <p className="text-muted-foreground">Environment not found.</p>
        <Button variant="outline" className="mt-4" onClick={() => navigate('/environments')}>
          Back to Environments
        </Button>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <Button variant="ghost" size="sm" onClick={() => navigate('/environments')}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div>
          <div className="flex items-center gap-2">
            <FlaskConical className="h-5 w-5 text-muted-foreground" />
            <h1 className="page-heading">Test Environment</h1>
          </div>
          <p className="page-subtitle">
            Send a test message via <span className="font-medium">{env.name}</span>
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Send Test Message</CardTitle>
          <CardDescription>
            Choose a channel, enter a recipient, and fire a test delivery.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-5">

          {/* Channel Selector */}
          <div className="space-y-2">
            <Label>Channel</Label>
            {enabledChannels.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                No channels are enabled for this environment.
                <Button variant="link" className="px-1 h-auto" onClick={() => navigate(`/environments/${id}/edit`)}>
                  Enable channels →
                </Button>
              </p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {enabledChannels.map(ch => {
                  const c = CHANNEL_CONFIG[ch];
                  const ChIcon = c.icon;
                  const isSelected = selectedChannel === ch;
                  return (
                    <button
                      key={ch}
                      onClick={() => { setSelectedChannel(ch); setStatus('idle'); setResultMessage(''); }}
                      className={`flex items-center gap-2 px-3 py-2 rounded-lg border text-sm font-medium transition-all ${
                        isSelected
                          ? `${c.bg} ${c.border} ${c.color}`
                          : 'bg-muted border-border text-muted-foreground hover:bg-muted'
                      }`}
                    >
                      <ChIcon className="h-4 w-4" />
                      {c.label}
                    </button>
                  );
                })}
                {/* Show disabled channels greyed out */}
                {(Object.keys(CHANNEL_CONFIG) as Channel[])
                  .filter(ch => !env[CHANNEL_CONFIG[ch].allowField])
                  .map(ch => {
                    const c = CHANNEL_CONFIG[ch];
                    const ChIcon = c.icon;
                    return (
                      <button key={ch} disabled className="flex items-center gap-2 px-3 py-2 rounded-lg border text-sm font-medium bg-muted border-border text-gray-300 cursor-not-allowed opacity-50">
                        <ChIcon className="h-4 w-4" />
                        {c.label}
                      </button>
                    );
                  })}
              </div>
            )}
          </div>

          {enabledChannels.length > 0 && (
            <>
              {/* To */}
              <div className="space-y-1.5">
                <Label htmlFor="test-to">
                  {selectedChannel === 'email' ? 'Email Address' : selectedChannel === 'push' ? 'Device / User Token' : 'Phone Number'}
                </Label>
                <div className="relative">
                  <Icon className={`absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 ${cfg.color}`} />
                  <Input
                    id="test-to"
                    className="pl-9"
                    placeholder={cfg.placeholder}
                    value={to}
                    onChange={e => setTo(e.target.value)}
                  />
                </div>
              </div>

              {/* Subject (email only) */}
              {selectedChannel === 'email' && (
                <div className="space-y-1.5">
                  <Label htmlFor="test-subject">Subject <span className="text-muted-foreground font-normal">(optional)</span></Label>
                  <Input
                    id="test-subject"
                    placeholder="[Test] Hello from Messy"
                    value={subject}
                    onChange={e => setSubject(e.target.value)}
                  />
                </div>
              )}

              {/* Body */}
              <div className="space-y-1.5">
                <Label htmlFor="test-body">Message</Label>
                <Textarea
                  id="test-body"
                  rows={4}
                  placeholder="Enter your test message..."
                  value={body}
                  onChange={e => setBody(e.target.value)}
                />
              </div>

              {/* Result */}
              {status !== 'idle' && (
                <div className={`flex items-start gap-3 p-3 rounded-lg text-sm ${
                  status === 'success'  ? 'bg-green-50 text-green-700 border border-green-200' :
                  status === 'error'    ? 'bg-red-50 text-red-700 border border-red-200' :
                  'bg-muted text-muted-foreground'
                }`}>
                  {status === 'sending' && <Loader2 className="h-4 w-4 animate-spin shrink-0 mt-0.5" />}
                  {status === 'success' && <CheckCircle2 className="h-4 w-4 shrink-0 mt-0.5" />}
                  {status === 'error'   && <XCircle className="h-4 w-4 shrink-0 mt-0.5" />}
                  <span>{status === 'sending' ? 'Sending…' : resultMessage}</span>
                </div>
              )}

              {/* Actions */}
              <div className="flex justify-end gap-2 pt-2">
                <Button variant="outline" onClick={() => navigate('/environments')}>Cancel</Button>
                <Button
                  onClick={handleSend}
                  disabled={status === 'sending' || enabledChannels.length === 0}
                  className={cfg.bg.replace('bg-', 'bg-') /* keeps it readable */}
                >
                  {status === 'sending' ? (
                    <><Loader2 className="h-4 w-4 mr-2 animate-spin" />Sending…</>
                  ) : (
                    <><Send className="h-4 w-4 mr-2" />Send Test</>
                  )}
                </Button>
              </div>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
