import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { MetricTile } from '@/components/metric-tile';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { Mail, Send, Globe, TrendingUp, ArrowRight } from 'lucide-react';
import { ChannelTypeIcon } from '@/components/channel-icons';
import emptyIntegrations from '@/assets/empty-integrations.svg';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, Cell } from 'recharts';

// Cool, blue-harmonized chart palette (sourced from the shared --chart-* tokens)
const CHART_COLORS = [
  'hsl(var(--chart-teal))',
  'hsl(var(--chart-sage))',
  'hsl(var(--chart-terracotta))',
  'hsl(var(--chart-sand))',
  'hsl(var(--chart-slate))',
  'hsl(var(--chart-plum))',
];
import request from '@/utils/request';
import { statusClass, statusLabel } from '@/lib/status-colors';
import toast from 'react-hot-toast';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';

interface DashboardStats {
  total_messages: number;
  messages_last_24h: number;
  total_environments: number;
  total_templates: number;
  success_rate: number;
  failed_messages: number;
}

interface MessageChart {
  date: string;
  messages: number;
}

interface ChannelStats {
  channel: string;
  count: number;
}

export function DashboardPage() {
  const navigate = useNavigate();
  const activeEnvId = useActiveEnvironment();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [messageChart, setMessageChart] = useState<MessageChart[]>([]);
  const [channelStats, setChannelStats] = useState<ChannelStats[]>([]);
  const [recentMessages, setRecentMessages] = useState<any[]>([]);
  const [integrationCount, setIntegrationCount] = useState<number | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchDashboardData();
  }, [activeEnvId]);

  const fetchDashboardData = async () => {
    try {
      const [statsRes, messagesRes, envsRes, integrationsRes] = await Promise.all([
        request.get('/dashboard/stats'),
        request.get('/messages', { params: { page: 1, per_page: 5 } }),
        request.get('/environments').catch(() => ({ data: [] })),
        request.get('/integrations').catch(() => ({ data: [] })),
      ]);
      const integrations = Array.isArray(integrationsRes.data) ? integrationsRes.data : integrationsRes.data?.integrations || [];
      setIntegrationCount(integrations.length);
      const raw = statsRes.data.stats || statsRes.data;
      // Map backend structure to frontend expectations
      const total = raw.messages?.total ?? raw.total_messages ?? 0;
      const sent = raw.deliveries?.total ?? 0;
      const rate = total > 0 ? Math.round((sent / total) * 100) : 0;
      const templateCount = raw.templates?.total ?? 0;
      const perDay = raw.messages_per_day || {};
      const todayCount = Object.values(perDay).length > 0 ? (Object.values(perDay).slice(-1)[0] as number || 0) : 0;
      setStats({
        total_messages: total,
        success_rate: rate,
        total_environments: (Array.isArray(envsRes.data) ? envsRes.data : envsRes.data?.environments || []).length,
        total_templates: templateCount,
        messages_last_24h: todayCount,
        messages_per_day: raw.messages_per_day || {},
        ...raw,
      });
      // Build chart data from backend response
      setMessageChart(Object.entries(perDay).map(([day, count]) => ({ date: day, messages: count as number })));
      
      const emailCount = raw.messages?.email_processed ?? 0;
      const smsCount = raw.messages?.sms_processed ?? 0;
      const whatsappCount = raw.messages?.whatsapp_processed ?? 0;
      const mobilePushCount = raw.messages?.mobile_push_processed ?? 0;
      const webPushCount = raw.messages?.web_push_processed ?? 0;
      const channelData = [
        ...(emailCount > 0 ? [{ channel: 'Email', count: emailCount }] : []),
        ...(smsCount > 0 ? [{ channel: 'SMS', count: smsCount }] : []),
        ...(whatsappCount > 0 ? [{ channel: 'WhatsApp', count: whatsappCount }] : []),
        ...(mobilePushCount > 0 ? [{ channel: 'Push', count: mobilePushCount }] : []),
        ...(webPushCount > 0 ? [{ channel: 'Web Push', count: webPushCount }] : []),
      ];
      setChannelStats(channelData.length > 0 ? channelData : [{ channel: 'Email', count: total }]);
      
      setRecentMessages((messagesRes.data.data || messagesRes.data.messages || []).slice(0, 5));
    } catch (error: any) {
      toast.error('Failed to load dashboard data');
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="p-6 space-y-6 bg-background min-h-screen animate-pulse">
        <div>
          <div className="h-9 w-48 bg-muted/60 rounded-lg" />
          <div className="h-4 w-64 bg-muted/40 rounded mt-2" />
        </div>
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          {[...Array(4)].map((_, i) => (
            <Card key={i} className="card-shadow bg-card">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <div className="h-4 w-24 bg-muted/50 rounded" />
                <div className="w-8 h-8 bg-muted/30 rounded-lg" />
              </CardHeader>
              <CardContent>
                <div className="h-7 w-16 bg-muted/60 rounded mt-1" />
                <div className="h-3 w-32 bg-muted/30 rounded mt-3" />
              </CardContent>
            </Card>
          ))}
        </div>
        <div className="grid gap-6 md:grid-cols-2">
          {[...Array(2)].map((_, i) => (
            <Card key={i} className="card-shadow bg-card">
              <CardHeader>
                <div className="h-5 w-36 bg-muted/50 rounded" />
                <div className="h-3 w-52 bg-muted/30 rounded mt-2" />
              </CardHeader>
              <CardContent>
                <div className="h-64 bg-muted/20 rounded-lg" />
              </CardContent>
            </Card>
          ))}
        </div>
        <Card className="card-shadow bg-card">
          <CardHeader>
            <div className="h-5 w-40 bg-muted/50 rounded" />
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="flex items-center gap-4">
                  <div className="h-4 w-full bg-muted/30 rounded" style={{ opacity: 1 - i * 0.15 }} />
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  // Empty state — no integrations set up yet
  if (!isLoading && integrationCount === 0) {
    return (
      <div className="p-6 bg-background min-h-screen flex flex-col">
        <div className="mb-8">
          <h1 className="page-heading">Overview</h1>
          <p className="page-subtitle">Your messaging activity at a glance</p>
        </div>
        <div className="flex flex-col items-center justify-center flex-1 text-center py-8">
          <img src={emptyIntegrations} alt="No integrations yet" className="w-80 h-auto mb-10 opacity-90" />
          <h2 className="text-xl font-semibold text-foreground mb-2">Add your first integration</h2>
          <p className="text-sm text-muted-foreground max-w-xs mb-6">
            Connect an email provider to start sending messages through Messy.
          </p>
          <Button className="gap-2" onClick={() => navigate('/integrations')}>
            Add integration <ArrowRight className="h-4 w-4" />
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6 bg-background min-h-screen">
      <div>
        <h1 className="page-heading">Overview</h1>
        <p className="page-subtitle">Your messaging activity at a glance</p>
      </div>

      {/* Stats Cards */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <MetricTile
          title="Total Messages"
          value={stats?.total_messages || 0}
          subtitle={`${stats?.messages_last_24h || 0} in the last 24 hours`}
          icon={Mail}
          iconWrapClassName="bg-blue-100"
          iconClassName="text-blue-600"
          onClick={() => navigate("/messages")}
        />
        <MetricTile
          title="Success Rate"
          value={`${stats?.success_rate || 0}%`}
          subtitle="Message delivery success"
          icon={TrendingUp}
          iconWrapClassName="bg-green-100"
          iconClassName="text-green-600"
          onClick={() => navigate("/messages")}
        />
        <MetricTile
          title="Environments"
          value={stats?.total_environments || 0}
          subtitle="Active environments"
          icon={Globe}
          iconWrapClassName="bg-sky-100"
          iconClassName="text-sky-600"
          onClick={() => navigate("/environments")}
        />
        <MetricTile
          title="Templates"
          value={stats?.total_templates || 0}
          subtitle="Message templates"
          icon={Send}
          iconWrapClassName="bg-indigo-100"
          iconClassName="text-indigo-600"
          onClick={() => navigate("/templates")}
        />
      </div>

      {/* Charts */}
      <div className="grid gap-6 md:grid-cols-2">
        <Card className="card-shadow bg-card">
          <CardHeader>
            <CardTitle className="text-foreground">Message Volume</CardTitle>
            <CardDescription>
              Messages sent over the last 7 days
            </CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={messageChart}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="date" tick={{ fontFamily: 'monospace', fontSize: 12 }} />
                <YAxis tick={{ fontFamily: 'monospace', fontSize: 12 }} />
                <Tooltip />
                <Line
                  type="monotone"
                  dataKey="messages"
                  stroke="hsl(var(--chart-plum))"
                  strokeWidth={3}
                  dot={{ fill: 'hsl(var(--chart-plum))', r: 4 }}
                  activeDot={{ fill: 'hsl(var(--chart-plum))', r: 6 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        <Card className="card-shadow bg-card">
          <CardHeader>
            <CardTitle className="text-foreground">Messages by Channel</CardTitle>
            <CardDescription>
              Distribution across different channels
            </CardDescription>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={channelStats}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="channel" tick={{ fontFamily: 'monospace', fontSize: 12 }} />
                <YAxis tick={{ fontFamily: 'monospace', fontSize: 12 }} />
                <Tooltip />
                <Bar dataKey="count" radius={[6, 6, 0, 0]}>
                  {channelStats.map((_, i) => (
                    <Cell key={i} fill={CHART_COLORS[i % CHART_COLORS.length]} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Recent Activity */}
      <Card className="card-shadow bg-card">
        <CardHeader>
          <CardTitle className="text-foreground">Recent Activity</CardTitle>
          <CardDescription>Latest messages and events</CardDescription>
        </CardHeader>
        <CardContent className="p-0">
          {recentMessages.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-8">No recent activity</p>
          ) : (
            <>
              {/* Mobile: stacked cards */}
              <div className="md:hidden divide-y divide-border">
                {recentMessages.map((msg: any) => {
                  const status = msg.status || 'pending';
                  return (
                    <button
                      key={msg.id}
                      onClick={() => navigate(`/messages/${msg.id}`)}
                      className="w-full text-left p-4 flex flex-col gap-2 hover:bg-muted/50 transition-colors"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="flex items-center gap-2 min-w-0">
                          <span className="shrink-0"><ChannelTypeIcon type={msg.channel} size={14} /></span>
                          <span className="font-medium truncate">{msg.subject || msg.to || 'Message'}</span>
                        </div>
                        <span className={`shrink-0 ${statusClass(status)}`}>{statusLabel(status)}</span>
                      </div>
                      <span className="text-xs text-muted-foreground font-mono">
                        {new Date(msg.created_at).toLocaleString()}
                      </span>
                    </button>
                  );
                })}
              </div>

              {/* Desktop: table */}
              <Table className="hidden md:table">
              <TableHeader>
                <TableRow>
                  <TableHead>Message</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead className="text-right">Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {recentMessages.map((msg: any) => {
                  const status = msg.status || 'pending';
                  return (
                    <TableRow key={msg.id} className="cursor-pointer" onClick={() => navigate(`/messages/${msg.id}`)}>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <span className="shrink-0"><ChannelTypeIcon type={msg.channel} size={14} /></span>
                          <p className="text-sm font-medium text-foreground truncate max-w-md">{msg.subject || msg.to || 'Message'}</p>
                        </div>
                      </TableCell>
                      <TableCell>
                        <span className="text-xs text-muted-foreground font-mono">
                          {new Date(msg.created_at).toLocaleString()}
                        </span>
                      </TableCell>
                      <TableCell className="text-right">
                        <span className={statusClass(status)}>{statusLabel(status)}</span>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
              </Table>
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}