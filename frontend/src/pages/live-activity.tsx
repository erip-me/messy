import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import { useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import {
  Activity, Mail, MessageSquare, Phone, Bell, Filter, Download, ChevronDown,
} from 'lucide-react';
import { ChannelTypeIcon } from '@/components/channel-icons';
import { statusClass } from '@/lib/status-colors';
import { activityConfig, dedupeLatest } from '@/lib/activity-config';
import { format } from 'date-fns';
import { FormattedRecipients } from '@/utils/recipients';
import { createAuthenticatedConsumer } from '@/utils/cable';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Switch } from '@/components/ui/switch';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  DropdownMenu, DropdownMenuCheckboxItem, DropdownMenuContent, DropdownMenuTrigger,
  DropdownMenuSeparator,
} from '@/components/ui/dropdown-menu';
import { RootState } from '@/store';
import { Environment } from '@/store/environment-slice';

import request from '@/utils/request';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';

interface LiveMessage {
  id: number;
  to: string;
  subject?: string;
  channel: 'email' | 'sms' | 'whatsapp' | 'push';
  status: 'pending' | 'sent' | 'delivered' | 'failed' | 'bounced';
  environment: string;
  created_at: string;
  updated_at: string;
}

interface LiveCustomerActivity {
  id: number;
  activity_type: string;
  customer: {
    id: number;
    email: string;
    first_name?: string;
    last_name?: string;
  };
  environment: string;
  properties: Record<string, unknown>;
  created_at: string;
}

type FeedItem =
  | { type: 'message'; data: LiveMessage }
  | { type: 'customer_activity'; data: LiveCustomerActivity };


export function LiveActivityPage() {
  const navigate = useNavigate();
  const currentUser = useSelector((state: RootState) => state.auth.user);
  const [feedItems, setFeedItems] = useState<FeedItem[]>([]);
  const [isConnected, setIsConnected] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [autoScroll, setAutoScroll] = useState(true);
  const [channelFilter, setChannelFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [selectedEnvNames, setSelectedEnvNames] = useState<Set<string> | null>(null);

  const activeEnvId = useActiveEnvironment();
  const environments: Environment[] = useSelector(
    (state: RootState) => state.environment.environments
  );

  // Initialize environment filter to the active environment once environments load
  useEffect(() => {
    if (selectedEnvNames !== null) return;
    if (environments.length === 0) return;
    const activeEnv = environments.find((e) => e.id === activeEnvId);
    if (activeEnv) {
      setSelectedEnvNames(new Set([activeEnv.name]));
    } else {
      setSelectedEnvNames(new Set(environments.map((e) => e.name)));
    }
  }, [environments, activeEnvId, selectedEnvNames]);
  const scrollAreaRef = useRef<HTMLDivElement>(null);
  const cableRef = useRef<any>(null);
  const subscriptionRef = useRef<any>(null);
  const isPausedRef = useRef(isPaused);

  // Keep ref in sync so the WebSocket callback always sees current value
  useEffect(() => {
    isPausedRef.current = isPaused;
  }, [isPaused]);

  const handleCableData = useCallback((data: any) => {
    if (isPausedRef.current) return;

    // Customer activity events
    if (data.type === "customer_activity") {
      const activity: LiveCustomerActivity = data.activity;
      setFeedItems(prev => {
        if (prev.some(item => item.type === 'customer_activity' && item.data.id === activity.id)) {
          return prev;
        }
        const item: FeedItem = { type: "customer_activity", data: activity };
        return [item, ...prev].slice(0, 100);
      });
      return;
    }

    // Message events
    const { action, message } = data;
    if (!message) return;

    setFeedItems(prev => {
      switch (action) {
        case 'create':
          // Avoid duplicates (message may already be in the initial load)
          if (prev.some(item => item.type === 'message' && item.data.id === message.id)) {
            return prev.map(item =>
              item.type === 'message' && item.data.id === message.id
                ? { type: 'message', data: message }
                : item
            );
          }
          return [{ type: 'message' as const, data: message }, ...prev].slice(0, 100);

        case 'update':
          return prev.map(item =>
            item.type === 'message' && item.data.id === message.id
              ? { type: 'message' as const, data: message }
              : item
          );

        default:
          return prev;
      }
    });
  }, []);

  // Fetch the most recent messages and activities on mount
  const fetchRecentFeed = useCallback(async () => {
    try {
      const [messagesRes, activitiesRes] = await Promise.all([
        request.get('/messages', { params: { per_page: 20, page: 1 } }),
        request.get('/customers/recent_activities').catch(() => ({ data: { activities: [] } })),
      ]);

      const messagesData = messagesRes.data?.data || messagesRes.data?.messages || [];
      const messageItems: FeedItem[] = messagesData.map((m: any) => ({
        type: 'message' as const,
        data: {
          id: m.id,
          to: m.to,
          subject: m.subject,
          channel: m.channel || m.type?.replace('Message', '')?.toLowerCase(),
          status: m.status,
          environment: m.environment,
          created_at: m.created_at,
          updated_at: m.updated_at,
        },
      }));

      const activitiesData = activitiesRes.data?.activities || [];
      const activityItems: FeedItem[] = activitiesData.map((a: any) => ({
        type: 'customer_activity' as const,
        data: a as LiveCustomerActivity,
      }));

      const combined = [...messageItems, ...activityItems].sort(
        (a, b) => new Date(b.data.created_at).getTime() - new Date(a.data.created_at).getTime()
      );

      setFeedItems(combined.slice(0, 100));
    } catch (error) {
      console.error('Failed to fetch recent feed:', error);
    }
  }, []);

  useEffect(() => {
    if (currentUser) {
      setFeedItems([]);
      fetchRecentFeed();
      connectToCable();
    }

    return () => {
      disconnectFromCable();
    };
  }, [currentUser, activeEnvId]);

  useEffect(() => {
    if (autoScroll && scrollAreaRef.current) {
      const viewport = scrollAreaRef.current.querySelector('[data-radix-scroll-area-viewport]');
      (viewport || scrollAreaRef.current).scrollTo({ top: 0, behavior: 'smooth' });
    }
  }, [feedItems, autoScroll]);

  const connectToCable = () => {
    try {
      cableRef.current = createAuthenticatedConsumer();
      if (!cableRef.current) return;

      subscriptionRef.current = cableRef.current.subscriptions.create(
        { channel: 'MessagesChannel' },
        {
          connected() {
            setIsConnected(true);
            console.log('Connected to MessagesChannel');
          },

          disconnected() {
            setIsConnected(false);
            console.log('Disconnected from MessagesChannel');
          },

          received(data: any) {
            handleCableData(data);
          }
        }
      );
    } catch (error) {
      console.error('Failed to connect to ActionCable:', error);
      setIsConnected(false);
    }
  };

  const disconnectFromCable = () => {
    if (subscriptionRef.current) {
      subscriptionRef.current.unsubscribe();
    }
    if (cableRef.current) {
      cableRef.current.disconnect();
    }
    setIsConnected(false);
  };

  const togglePause = () => {
    setIsPaused(!isPaused);
  };

  const clearMessages = () => {
    setFeedItems([]);
  };

  const exportMessages = () => {
    const messageItems = feedItems
      .filter((item): item is FeedItem & { type: 'message' } => item.type === 'message');
    const csv = [
      ['ID', 'To', 'Subject', 'Channel', 'Status', 'Environment', 'Created At'].join(','),
      ...messageItems.map(item => [
        item.data.id,
        item.data.to,
        item.data.subject || '',
        item.data.channel,
        item.data.status,
        item.data.environment,
        item.data.created_at
      ].join(','))
    ].join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `messages_${format(new Date(), 'yyyy-MM-dd_HH-mm')}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
  };


  const allEnvNames = useMemo(
    () => environments.map((e) => e.name),
    [environments]
  );
  const allEnvsSelected = selectedEnvNames !== null && allEnvNames.length > 0
    && allEnvNames.every((n) => selectedEnvNames.has(n));

  const toggleEnvName = useCallback((name: string) => {
    setSelectedEnvNames((prev) => {
      const next = new Set(prev);
      if (next.has(name)) {
        next.delete(name);
      } else {
        next.add(name);
      }
      return next;
    });
  }, []);

  const toggleAllEnvs = useCallback(() => {
    if (allEnvsSelected) {
      setSelectedEnvNames(new Set());
    } else {
      setSelectedEnvNames(new Set(allEnvNames));
    }
  }, [allEnvsSelected, allEnvNames]);

  const envFilterLabel = useMemo(() => {
    if (!selectedEnvNames || allEnvsSelected) return 'All environments';
    if (selectedEnvNames.size === 0) return 'No environment';
    if (selectedEnvNames.size === 1) {
      return [...selectedEnvNames][0];
    }
    return `${selectedEnvNames.size} environments`;
  }, [selectedEnvNames, allEnvsSelected]);

  const filteredFeedItems = useMemo(() => {
    const filtered = feedItems.filter(item => {
      const env = item.data.environment;
      if (selectedEnvNames && selectedEnvNames.size > 0 && !allEnvsSelected) {
        if (!selectedEnvNames.has(env)) return false;
      }
      if (item.type === 'customer_activity') {
        // Show activity items unless a channel/status filter is active
        return !channelFilter && !statusFilter;
      }
      const msg = item.data as LiveMessage;
      if (channelFilter && msg.channel !== channelFilter) return false;
      if (statusFilter && msg.status !== statusFilter) return false;
      return true;
    });
    // Collapse repeated activity rows to the latest per customer + type + campaign.
    // feedItems is newest-first, so dedupeLatest keeps the most recent. Messages get a
    // unique key so they are never collapsed.
    return dedupeLatest(filtered, (item) => {
      if (item.type !== 'customer_activity') return `msg-${item.data.id}`;
      const a = item.data;
      return `act-${a.customer.id}-${a.activity_type}-${String(a.properties?.campaign_id ?? '')}`;
    });
  }, [feedItems, channelFilter, statusFilter, selectedEnvNames, allEnvsSelected]);

  return (
    <div className="p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <Activity className="h-6 w-6" />
            <h1 className="page-heading">Activity</h1>
            <Button
              variant="outline"
              size="sm"
              onClick={togglePause}
              title={isConnected ? (isPaused ? 'Click to resume live updates' : 'Click to pause live updates') : 'Disconnected'}
            >
              <div className={`w-2 h-2 rounded-full mr-1.5 ${isConnected ? (isPaused ? 'bg-yellow-500' : 'bg-green-500 animate-pulse') : 'bg-red-500'}`} />
              {isConnected ? (isPaused ? 'Paused' : 'Live') : 'Disconnected'}
            </Button>
          </div>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <Button
            variant="outline"
            size="sm"
            onClick={exportMessages}
            disabled={feedItems.length === 0}
          >
            <Download className="h-4 w-4 mr-2" />
            Export CSV
          </Button>

          <Button variant="outline" size="sm" onClick={clearMessages}>
            Clear
          </Button>
        </div>
      </div>

      {/* Filters and Settings */}
      <div className="flex items-center justify-between mb-6 p-4 bg-muted/50 rounded-lg flex-wrap gap-4">
        <div className="flex items-center gap-4 flex-wrap">
          <div className="flex items-center gap-2">
            <Filter className="h-4 w-4" />
            <span className="text-sm font-medium">Filters:</span>
          </div>
          
          <Select value={channelFilter || 'all'} onValueChange={(v) => setChannelFilter(v === 'all' ? '' : v)}>
            <SelectTrigger className="w-32">
              <SelectValue placeholder="All channels" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All channels</SelectItem>
              <SelectItem value="email"><Mail className="inline h-4 w-4 mr-2" />Email</SelectItem>
              <SelectItem value="sms"><MessageSquare className="inline h-4 w-4 mr-2" />SMS</SelectItem>
              <SelectItem value="whatsapp"><Phone className="inline h-4 w-4 mr-2" />WhatsApp</SelectItem>
              <SelectItem value="push"><Bell className="inline h-4 w-4 mr-2" />Push</SelectItem>
            </SelectContent>
          </Select>
          
          <Select value={statusFilter || 'all'} onValueChange={(v) => setStatusFilter(v === 'all' ? '' : v)}>
            <SelectTrigger className="w-32">
              <SelectValue placeholder="All statuses" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All statuses</SelectItem>
              <SelectItem value="pending">Pending</SelectItem>
              <SelectItem value="sent">Sent</SelectItem>
              <SelectItem value="delivered">Delivered</SelectItem>
              <SelectItem value="failed">Failed</SelectItem>
              <SelectItem value="bounced">Bounced</SelectItem>
            </SelectContent>
          </Select>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="sm" className="w-44 justify-between">
                <span className="truncate">{envFilterLabel}</span>
                <ChevronDown className="h-4 w-4 shrink-0 opacity-50" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="start" className="w-44">
              <DropdownMenuCheckboxItem
                checked={allEnvsSelected}
                onCheckedChange={toggleAllEnvs}
              >
                All environments
              </DropdownMenuCheckboxItem>
              <DropdownMenuSeparator />
              {environments.map((env) => (
                <DropdownMenuCheckboxItem
                  key={env.id}
                  checked={selectedEnvNames?.has(env.name) ?? false}
                  onCheckedChange={() => toggleEnvName(env.name)}
                >
                  {env.name}
                </DropdownMenuCheckboxItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        
        <div className="flex items-center gap-2">
          <span className="text-sm">Auto-scroll</span>
          <Switch checked={autoScroll} onCheckedChange={setAutoScroll} />
        </div>
      </div>

      {/* Message Feed */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            <span>Real-time Message Feed</span>
            <Badge variant="outline">
              {filteredFeedItems.length} items
            </Badge>
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          <ScrollArea ref={scrollAreaRef} className="h-[600px]">
            <div>
              {filteredFeedItems.length === 0 ? (
                <div className="text-center py-12">
                  <Activity className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
                  <h3 className="text-lg font-medium mb-2">No activity yet</h3>
                  <p className="text-muted-foreground">
                    {isPaused
                      ? 'Activity is paused. Click Resume to see new messages.'
                      : isConnected
                        ? 'Waiting for new activity...'
                        : 'Not connected to live feed.'
                    }
                  </p>
                </div>
              ) : (
                <>
                  {/* Mobile: stacked cards */}
                  <div className="md:hidden divide-y divide-border">
                    {filteredFeedItems.map((item) => {
                      if (item.type === 'customer_activity') {
                        const activity = item.data as LiveCustomerActivity;
                        const config = activityConfig(activity.activity_type);
                        const ActivityIcon = config.Icon;
                        const displayName = [activity.customer.first_name, activity.customer.last_name]
                          .filter(Boolean).join(' ') || activity.customer.email;
                        const campaignName = activity.properties?.campaign_name
                          ? String(activity.properties.campaign_name)
                          : null;
                        return (
                          <button
                            key={`activity-m-${activity.id}`}
                            onClick={() => navigate(`/customers/${activity.customer.id}`)}
                            className={`w-full text-left p-4 flex flex-col gap-2 hover:bg-muted/50 transition-colors border-l-2 ${config.border} ${config.bg}`}
                          >
                            <div className="flex items-center justify-between gap-2">
                              <div className="flex items-center gap-2 min-w-0">
                                <ActivityIcon className={`h-4 w-4 shrink-0 ${config.iconColor}`} />
                                <span className="font-medium truncate">{displayName}</span>
                              </div>
                              <span className={`status-badge ${config.statusClass} text-xs shrink-0`}>{config.status}</span>
                            </div>
                            <div className="text-sm text-muted-foreground truncate">
                              {config.label}{campaignName ? `: ${campaignName}` : ''}
                            </div>
                            <div className="flex items-center gap-2 text-xs text-muted-foreground">
                              <span>{activity.environment}</span>
                              <span className="ml-auto font-mono">{format(new Date(activity.created_at), 'MMM d, HH:mm:ss')}</span>
                            </div>
                          </button>
                        );
                      }

                      const message = item.data as LiveMessage;
                      return (
                        <button
                          key={`msg-m-${message.id}-${message.updated_at}`}
                          onClick={() => navigate(`/messages/${message.id}`)}
                          className="w-full text-left p-4 flex flex-col gap-2 hover:bg-muted/50 transition-colors"
                        >
                          <div className="flex items-center justify-between gap-2">
                            <div className="flex items-center gap-2 min-w-0">
                              <ChannelTypeIcon type={message.channel} size={16} />
                              <span className="font-medium truncate" title={message.to}>
                                <FormattedRecipients raw={message.to} maxVisible={1} />
                              </span>
                            </div>
                            <span className={`${statusClass(message.status)} text-xs shrink-0`}>{message.status}</span>
                          </div>
                          <div className="text-sm text-muted-foreground truncate">
                            {message.subject || '-'}
                          </div>
                          <div className="flex items-center gap-2 text-xs text-muted-foreground">
                            <Badge variant="outline" className="text-xs">{message.channel.toUpperCase()}</Badge>
                            <span>{message.environment}</span>
                            <span className="ml-auto font-mono">{format(new Date(message.created_at), 'MMM d, HH:mm:ss')}</span>
                          </div>
                        </button>
                      );
                    })}
                  </div>

                  {/* Desktop: table */}
                  <Table className="hidden md:table">
                    <TableHeader>
                      <TableRow>
                        <TableHead>Channel</TableHead>
                        <TableHead>Recipient</TableHead>
                        <TableHead>Subject</TableHead>
                        <TableHead>Environment</TableHead>
                        <TableHead>Time</TableHead>
                        <TableHead className="text-right">Status</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {filteredFeedItems.map((item) => {
                        if (item.type === 'customer_activity') {
                          const activity = item.data as LiveCustomerActivity;
                          const config = activityConfig(activity.activity_type);
                          const ActivityIcon = config.Icon;
                          const displayName = [activity.customer.first_name, activity.customer.last_name]
                            .filter(Boolean).join(' ') || activity.customer.email;
                          const campaignName = activity.properties?.campaign_name
                            ? String(activity.properties.campaign_name)
                            : null;
                          return (
                            <TableRow
                              key={`activity-${activity.id}`}
                              className={`${config.bg} border-l-2 ${config.border} cursor-pointer`}
                              onClick={() => navigate(`/customers/${activity.customer.id}`)}
                            >
                              <TableCell>
                                <div className="flex items-center gap-2">
                                  <ActivityIcon className={`h-4 w-4 ${config.iconColor}`} />
                                  <Badge variant="outline" className={`text-xs ${config.iconColor}`}>
                                    {config.badge}
                                  </Badge>
                                </div>
                              </TableCell>
                              <TableCell className="font-medium">
                                <span>{displayName}</span>
                                {displayName !== activity.customer.email && (
                                  <span className="text-xs text-muted-foreground ml-2">
                                    {activity.customer.email}
                                  </span>
                                )}
                              </TableCell>
                              <TableCell>
                                <span className="text-sm text-muted-foreground">
                                  {config.label}{campaignName ? `: ${campaignName}` : ''}
                                </span>
                              </TableCell>
                              <TableCell>
                                <span className="text-xs text-muted-foreground">{activity.environment}</span>
                              </TableCell>
                              <TableCell>
                                <span className="text-xs font-mono text-muted-foreground">
                                  {format(new Date(activity.created_at), 'MMM d, HH:mm:ss')}
                                </span>
                              </TableCell>
                              <TableCell className="text-right">
                                <span className={`status-badge ${config.statusClass} text-xs`}>
                                  {config.status}
                                </span>
                              </TableCell>
                            </TableRow>
                          );
                        }

                        const message = item.data as LiveMessage;
                        return (
                          <TableRow
                            key={`msg-${message.id}-${message.updated_at}`}
                            className="cursor-pointer group"
                            onClick={() => navigate(`/messages/${message.id}`)}
                          >
                            <TableCell>
                              <div className="flex items-center gap-2">
                                <ChannelTypeIcon type={message.channel} size={16} />
                                <Badge variant="outline" className="text-xs">
                                  {message.channel.toUpperCase()}
                                </Badge>
                              </div>
                            </TableCell>
                            <TableCell className="font-medium">
                              <span className="truncate block max-w-[200px]" title={message.to}>
                                <FormattedRecipients raw={message.to} maxVisible={2} />
                              </span>
                            </TableCell>
                            <TableCell>
                              <span className="text-sm text-muted-foreground truncate max-w-xs block">
                                {message.subject || '-'}
                              </span>
                            </TableCell>
                            <TableCell>
                              <span className="text-xs text-muted-foreground">{message.environment}</span>
                            </TableCell>
                            <TableCell>
                              <span className="text-xs font-mono text-muted-foreground">
                                {format(new Date(message.created_at), 'MMM d, HH:mm:ss')}
                              </span>
                            </TableCell>
                            <TableCell className="text-right">
                              <span className={`${statusClass(message.status)} text-xs`}>
                                {message.status}
                              </span>
                            </TableCell>
                          </TableRow>
                        );
                      })}
                    </TableBody>
                  </Table>

                </>
              )}
            </div>
          </ScrollArea>
        </CardContent>
      </Card>
    </div>
  );
}