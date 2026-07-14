import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Copy, Key, Mail, MessageSquare, Phone, Bell, Globe, Settings, FlaskConical, Edit, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Switch } from '@/components/ui/switch';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import {
  getEnvironments,
  createEnvironment,
  toggleChannel,
  Environment,
  CHANNEL_BACKEND_KEY,
  CHANNEL_ALLOW_FIELD,
} from '@/api/environments';
import { getIntegrations, Integration } from '@/api/integrations';
import { copyToClipboard } from '@/utils/clipboard';
import { formatDate } from '@/utils/format-date';
import toast from 'react-hot-toast';

// Map frontend channel keys to integration kind values
const CHANNEL_TO_INTEGRATION_KIND: Record<string, Integration['kind'] | null> = {
  email: 'email',
  sms: 'sms',
  whatsapp: 'whatsapp',
  push: 'mobile_push',
  webpush: 'web_push',
};

const CHANNEL_CONFIG = {
  email:    { icon: Mail,          label: 'Email',    color: 'text-blue-500',    bg: 'bg-blue-50 dark:bg-blue-500/10',       activeBg: 'bg-blue-100 dark:bg-blue-500/15',       border: 'border-blue-200 dark:border-blue-500/30' },
  sms:      { icon: MessageSquare, label: 'SMS',      color: 'text-emerald-500', bg: 'bg-emerald-50 dark:bg-emerald-500/10', activeBg: 'bg-emerald-100 dark:bg-emerald-500/15', border: 'border-emerald-200 dark:border-emerald-500/30' },
  whatsapp: { icon: Phone,         label: 'WhatsApp', color: 'text-green-500',   bg: 'bg-green-50 dark:bg-green-500/10',     activeBg: 'bg-green-100 dark:bg-green-500/15',     border: 'border-green-200 dark:border-green-500/30' },
  push:     { icon: Bell,          label: 'Push Notifications',     color: 'text-amber-500',   bg: 'bg-amber-50 dark:bg-amber-500/10',     activeBg: 'bg-amber-100 dark:bg-amber-500/15',     border: 'border-amber-200 dark:border-amber-500/30' },
  webpush:  { icon: Globe,         label: 'Web Push', color: 'text-purple-500',  bg: 'bg-purple-50 dark:bg-purple-500/10',   activeBg: 'bg-purple-100 dark:bg-purple-500/15',   border: 'border-purple-200 dark:border-purple-500/30' },
};

export function EnvironmentsIndexPage() {
  const navigate = useNavigate();
  const [environments, setEnvironments] = useState<Environment[]>([]);
  const [integrations, setIntegrations] = useState<Integration[]>([]);
  const [loading, setLoading] = useState(true);

  // New environment dialog
  const [createOpen, setCreateOpen] = useState(false);
  const [newName, setNewName] = useState('');
  const [creating, setCreating] = useState(false);

  useEffect(() => {
    loadEnvironments();
  }, []);

  const loadEnvironments = async () => {
    try {
      setLoading(true);
      const [envData, intData] = await Promise.all([getEnvironments(), getIntegrations()]);
      setEnvironments(envData);
      setIntegrations(intData);
    } catch (error) {
      toast.error('Failed to load environments');
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const hasIntegration = (envId: number, channel: string): boolean => {
    const kind = CHANNEL_TO_INTEGRATION_KIND[channel];
    if (kind === null) return false; // no integration support for this channel
    return integrations.some(i => (i.environment_id === envId || i.environment_id === null) && i.kind === kind && i.active);
  };

  const handleToggleChannel = async (envId: number, channel: string) => {
    const allowField = CHANNEL_ALLOW_FIELD[channel] as keyof Environment;
    const backendKey = CHANNEL_BACKEND_KEY[channel];

    // Optimistic update
    setEnvironments(prev => prev.map(env =>
      env.id === envId
        ? { ...env, [allowField]: !env[allowField] }
        : env
    ));

    try {
      await toggleChannel(envId, backendKey);
      const label = CHANNEL_CONFIG[channel as keyof typeof CHANNEL_CONFIG]?.label ?? channel;
      toast.success(`${label} toggled`);
    } catch (error) {
      // Revert on failure
      setEnvironments(prev => prev.map(env =>
        env.id === envId
          ? { ...env, [allowField]: !env[allowField] }
          : env
      ));
      toast.error(`Failed to toggle ${channel}`);
    }
  };

  const handleCreate = async () => {
    if (!newName.trim()) {
      toast.error('Name is required');
      return;
    }
    try {
      setCreating(true);
      const env = await createEnvironment({ name: newName.trim() });
      setEnvironments(prev => [...prev, env]);
      setNewName('');
      setCreateOpen(false);
      toast.success('Environment created');
    } catch {
      toast.error('Failed to create environment');
    } finally {
      setCreating(false);
    }
  };

  const copyApiKey = (apiKey: string) => {
    copyToClipboard(apiKey)
      .then(() => toast.success('API key copied to clipboard'))
      .catch(() => toast.error('Copy failed. Please copy manually.'));
  };

  const maskApiKey = (apiKey: string) => {
    return apiKey.substring(0, 8) + '...' + apiKey.substring(apiKey.length - 4);
  };

  if (loading) {
    return <PageSkeleton variant="cards" cards={6} cols={3} actions={1} />;
  }

  return (
    <div className="p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div>
          <h1 className="page-heading">Environments</h1>
          <p className="page-subtitle">
            Manage your messaging environments and API keys
          </p>
        </div>

        <Button onClick={() => setCreateOpen(true)}>
          <Plus className="h-4 w-4 mr-2" />
          New Environment
        </Button>

        <Dialog open={createOpen} onOpenChange={setCreateOpen}>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>New Environment</DialogTitle>
              <DialogDescription>Create a new messaging environment with its own API key and channel settings.</DialogDescription>
            </DialogHeader>
            <div className="space-y-4 py-2">
              <div className="space-y-2">
                <Label htmlFor="env-name">Name</Label>
                <Input
                  id="env-name"
                  placeholder="e.g. Production"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleCreate()}
                  autoFocus
                />
              </div>
            </div>
            <DialogFooter>
              <Button variant="outline" onClick={() => setCreateOpen(false)}>Cancel</Button>
              <Button onClick={handleCreate} disabled={creating || !newName.trim()}>
                {creating ? 'Creating...' : 'Create Environment'}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {environments.map((env) => (
          <Card key={env.id} className="relative">
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle className="flex items-center gap-2">
                    <Settings className="h-5 w-5" />
                    {env.name}
                  </CardTitle>
                </div>

                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="sm">
                      <Settings className="h-4 w-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem onClick={() => navigate(`/environments/${env.id}/edit`)}>
                      <Edit className="h-4 w-4 mr-2" />
                      Edit
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={() => navigate(`/environments/${env.id}/test`)}>
                      <FlaskConical className="h-4 w-4 mr-2" />
                      Test
                    </DropdownMenuItem>
                    <DropdownMenuItem className="text-destructive">
                      <Trash2 className="h-4 w-4 mr-2" />
                      Delete
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            </CardHeader>

            <CardContent className="space-y-4">
              {/* API Key */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-medium">API Key</span>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => copyApiKey(env.api_key)}
                  >
                    <Copy className="h-4 w-4" />
                  </Button>
                </div>
                <div className="flex items-center gap-2">
                  <Key className="h-4 w-4 text-muted-foreground" />
                  <code className="text-xs bg-muted px-2 py-1 rounded font-mono">
                    {maskApiKey(env.api_key)}
                  </code>
                </div>
              </div>

              {/* Channel Toggles */}
              <div>
                <span className="text-sm font-medium mb-3 block">Channels</span>
                <div className="space-y-2">
                  {Object.entries(CHANNEL_CONFIG).map(([channel, config]) => {
                    const Icon = config.icon;
                    const isActive = env[CHANNEL_ALLOW_FIELD[channel] as keyof Environment] as boolean;
                    const integrated = hasIntegration(env.id, channel);
                    return (
                      <div
                        key={channel}
                        className={`flex items-center justify-between p-2.5 rounded-lg border transition-all ${
                          !integrated
                            ? 'bg-muted border-border opacity-40 cursor-not-allowed'
                            : isActive
                              ? `${config.activeBg} ${config.border} cursor-pointer`
                              : 'bg-muted border-border opacity-60 cursor-pointer'
                        }`}
                        onClick={() => integrated && handleToggleChannel(env.id, channel)}
                        title={!integrated ? 'No active integration configured for this channel' : undefined}
                      >
                        <div className="flex items-center gap-2.5">
                          <div className={`p-1.5 rounded-md ${isActive && integrated ? config.bg : 'bg-muted'}`}>
                            <Icon className={`h-4 w-4 ${isActive && integrated ? config.color : 'text-muted-foreground'}`} />
                          </div>
                          <div className="flex flex-col">
                            <span className={`text-sm font-medium ${isActive && integrated ? 'text-foreground' : 'text-muted-foreground'}`}>
                              {config.label}
                            </span>
                            {!integrated && (
                              <span className="text-[10px] text-muted-foreground">No integration</span>
                            )}
                          </div>
                        </div>
                        <Switch
                          checked={isActive && integrated}
                          disabled={!integrated}
                          onCheckedChange={() => integrated && handleToggleChannel(env.id, channel)}
                          onClick={(e) => e.stopPropagation()}
                        />
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Environment Stats */}
              <div className="pt-3 border-t">
                <div className="text-xs text-muted-foreground font-mono">
                  Created {formatDate(env.created_at)}
                </div>
              </div>
            </CardContent>
          </Card>
        ))}

        {/* Empty State */}
        {environments.length === 0 && (
          <div className="col-span-full text-center py-12">
            <Settings className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
            <h3 className="text-lg font-medium mb-2">No environments found</h3>
            <p className="text-muted-foreground mb-4">
              Create your first environment to start sending messages.
            </p>
            <Button onClick={() => setCreateOpen(true)}>
              <Plus className="h-4 w-4 mr-2" />
              Create Environment
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}
