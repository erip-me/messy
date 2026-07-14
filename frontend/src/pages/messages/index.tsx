import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { usePageParam } from '@/hooks/usePageParam';
import { useSelector } from 'react-redux';
import { Search, Filter, Eye, MousePointer, Mail, ChevronLeft, ChevronRight } from 'lucide-react';
import { format, parse } from 'date-fns';
import { createAuthenticatedConsumer } from '@/utils/cable';
import { DatePicker } from '@/components/ui/date-picker';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { SearchableSelect } from '@/components/ui/searchable-select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Card, CardContent } from '@/components/ui/card';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';
import { RootState } from '@/store';
import { getMessages, Message, MessageFilters } from '@/api/messages';
import { getDrips, Drip } from '@/api/drips';
import toast from 'react-hot-toast';
import { FormattedRecipients } from '@/utils/recipients';
import { ChannelTypeIcon } from '@/components/channel-icons';
import { statusClass } from '@/lib/status-colors';


function parseDate(str: string | null): Date | undefined {
  if (!str) return undefined;
  const d = parse(str, 'yyyy-MM-dd', new Date());
  return isNaN(d.getTime()) ? undefined : d;
}

export function MessagesIndexPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const currentUser = useSelector((state: RootState) => state.auth.user);
  const activeEnvId = useActiveEnvironment();
  const [apiKey] = useState(''); // TODO: Get from environment selector

  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [totalCount, setTotalCount] = useState(0);
  const [currentPage, setCurrentPage] = usePageParam();
  const [totalPages, setTotalPages] = useState(1);
  const [perPage] = useState(20);

  // Derive applied filters from URL search params
  const filters: MessageFilters = {
    search: searchParams.get('search') || '',
    channel: searchParams.get('channel') || '',
    status: searchParams.get('status') || '',
    date_from: searchParams.get('date_from') || '',
    date_to: searchParams.get('date_to') || '',
    drip_id: searchParams.get('drip_id') || '',
    drip_step_id: searchParams.get('drip_step_id') || '',
  };

  // Live update state
  const [isLive, setIsLive] = useState(true);
  const [isConnected, setIsConnected] = useState(false);
  const cableRef = useRef<any>(null);
  const subscriptionRef = useRef<any>(null);
  const isLiveRef = useRef(isLive);
  const refreshTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Draft filter states (user edits these, applied on Search)
  const hasUrlFilters = Object.values(filters).some(Boolean);
  const [showFilters, setShowFilters] = useState(hasUrlFilters);
  const [draftSearch, setDraftSearch] = useState(filters.search || '');
  const [draftChannel, setDraftChannel] = useState(filters.channel || '');
  const [draftStatus, setDraftStatus] = useState(filters.status || '');
  const [dateFrom, setDateFrom] = useState<Date | undefined>(parseDate(filters.date_from || null));
  const [dateTo, setDateTo] = useState<Date | undefined>(parseDate(filters.date_to || null));
  const [draftDrip, setDraftDrip] = useState(filters.drip_id || '');
  const [draftStep, setDraftStep] = useState(filters.drip_step_id || '');
  const [drips, setDrips] = useState<Drip[]>([]);

  // Load drips for the source filter (lazy: only when the filter panel is shown)
  useEffect(() => {
    if (showFilters && drips.length === 0) getDrips().then(setDrips).catch(() => {});
  }, [showFilters]);

  const selectedDrip = drips.find(d => String(d.id) === draftDrip);

  const handleSearch = () => {
    setSearchParams(prev => {
      const next = new URLSearchParams(prev);
      // Reset to page 1
      next.delete('page');
      // Set or clear each filter param
      const params: Record<string, string> = {
        search: draftSearch,
        channel: draftChannel,
        status: draftStatus,
        date_from: dateFrom ? format(dateFrom, 'yyyy-MM-dd') : '',
        date_to: dateTo ? format(dateTo, 'yyyy-MM-dd') : '',
        drip_id: draftDrip,
        drip_step_id: draftDrip ? draftStep : '', // step only meaningful with a drip
      };
      for (const [key, value] of Object.entries(params)) {
        if (value) {
          next.set(key, value);
        } else {
          next.delete(key);
        }
      }
      return next;
    }, { replace: true });
  };

  // Stable serialization of filters for useEffect dependency
  const filtersKey = [filters.search, filters.channel, filters.status, filters.date_from, filters.date_to, filters.drip_id, filters.drip_step_id].join('|');

  useEffect(() => {
    loadMessages();
  }, [currentPage, filtersKey, activeEnvId]);

  const loadMessages = async () => {
    try {
      setLoading(true);
      const response = await getMessages(apiKey, currentPage, perPage, filters);
      setMessages(response.data || response.messages || []);
      setTotalCount(response.meta?.total_count || 0);
      setTotalPages(response.meta?.total_pages || 1);
    } catch (error) {
      toast.error('Failed to load messages');
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const clearFilters = () => {
    setDraftSearch('');
    setDraftChannel('');
    setDraftStatus('');
    setDateFrom(undefined);
    setDateTo(undefined);
    setDraftDrip('');
    setDraftStep('');
    setSearchParams(prev => {
      const next = new URLSearchParams(prev);
      next.delete('search');
      next.delete('channel');
      next.delete('status');
      next.delete('date_from');
      next.delete('date_to');
      next.delete('drip_id');
      next.delete('drip_step_id');
      next.delete('page');
      return next;
    }, { replace: true });
  };

  // Keep ref in sync so WebSocket callback sees current value
  useEffect(() => {
    isLiveRef.current = isLive;
  }, [isLive]);

  // Keep a ref to loadMessages so WebSocket callback always calls the latest version
  const loadMessagesRef = useRef(loadMessages);
  useEffect(() => {
    loadMessagesRef.current = loadMessages;
  });

  // Debounced refresh — coalesces rapid signals into one API call
  const scheduleRefresh = useCallback(() => {
    if (!isLiveRef.current) return;
    if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
    refreshTimerRef.current = setTimeout(() => {
      loadMessagesRef.current();
    }, 800);
  }, []);

  // WebSocket connection — only reconnects when user or environment changes
  useEffect(() => {
    if (!currentUser) return;

    cableRef.current = createAuthenticatedConsumer();
    if (!cableRef.current) return;

    subscriptionRef.current = cableRef.current.subscriptions.create(
      { channel: "MessagesChannel" },
      {
        connected() {
          setIsConnected(true);
        },
        disconnected() {
          setIsConnected(false);
        },
        received() {
          scheduleRefresh();
        },
      }
    );

    return () => {
      if (refreshTimerRef.current) clearTimeout(refreshTimerRef.current);
      if (subscriptionRef.current) subscriptionRef.current.unsubscribe();
      if (cableRef.current) cableRef.current.disconnect();
      setIsConnected(false);
    };
  }, [currentUser, activeEnvId]);

  const renderChannelBadge = (channel: string) => {
    return (
      <Badge variant="outline" className="text-xs font-mono">
        {channel ? channel.toUpperCase() : 'Unknown'}
      </Badge>
    );
  };

  const renderStatusBadge = (status: string) => (
    <Badge variant="outline" className={`border-0 ${statusClass(status)}`}>
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </Badge>
  );

  const Pagination = () => (
    <div className="flex items-center justify-between">
      <div className="text-sm text-muted-foreground">
        Showing {((currentPage - 1) * perPage) + 1}-{Math.min(currentPage * perPage, totalCount)} of {totalCount} messages
      </div>
      
      <div className="flex items-center space-x-2">
        <Button
          variant="outline"
          size="sm"
          onClick={() => setCurrentPage(currentPage - 1)}
          disabled={currentPage === 1}
        >
          <ChevronLeft className="h-4 w-4" />
        </Button>
        
        <div className="text-sm">
          Page {currentPage} of {totalPages}
        </div>
        
        <Button
          variant="outline"
          size="sm"
          onClick={() => setCurrentPage(currentPage + 1)}
          disabled={currentPage === totalPages}
        >
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );

  if (loading && messages.length === 0) {
    return <PageSkeleton columns={6} rows={10} actions={2} />;
  }

  return (
    <div className="p-6 bg-background min-h-screen">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div className="flex items-center gap-4 flex-wrap">
          <div>
            <h1 className="page-heading">Transactional</h1>
            <p className="page-subtitle">
              {totalCount} total messages
            </p>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => setIsLive(!isLive)}
            title={isConnected ? (isLive ? 'Click to pause live updates' : 'Click to resume live updates') : 'Disconnected'}
          >
            <div className={`w-2 h-2 rounded-full mr-1.5 ${isConnected ? (isLive ? 'bg-green-500 animate-pulse' : 'bg-yellow-500') : 'bg-red-500'}`} />
            {isConnected ? (isLive ? 'Live' : 'Paused') : 'Disconnected'}
          </Button>
        </div>

        <div className="flex gap-2 flex-wrap">
          <Button variant="outline" onClick={() => setShowFilters(!showFilters)}>
            <Filter className="h-4 w-4 mr-2" />
            {showFilters ? 'Hide Filters' : 'Show Filters'}
          </Button>

          <Button onClick={() => navigate('/messages/compose')}>
            <Mail className="h-4 w-4 mr-2" />
            Compose Message
          </Button>
        </div>
      </div>

      {/* Filters */}
      {showFilters && (
        <Card className="mb-6 card-shadow bg-card">
          <CardContent className="pt-6">
            <div className="flex flex-wrap items-center gap-3">
              <div className="relative min-w-[180px] flex-1">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  aria-label="Search messages"
                  placeholder="Recipient or subject..."
                  value={draftSearch}
                  onChange={(e) => setDraftSearch(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
                  className="pl-10"
                />
              </div>

              <div className="w-36">
                <Select value={draftChannel || 'all'} onValueChange={(value) => setDraftChannel(value === 'all' ? '' : value)}>
                  <SelectTrigger>
                    <SelectValue placeholder="All channels" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All channels</SelectItem>
                    <SelectItem value="email">Email</SelectItem>
                    <SelectItem value="sms">SMS</SelectItem>
                    <SelectItem value="whatsapp">WhatsApp</SelectItem>
                    <SelectItem value="push">Push</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="w-36">
                <Select value={draftStatus || 'all'} onValueChange={(value) => setDraftStatus(value === 'all' ? '' : value)}>
                  <SelectTrigger>
                    <SelectValue placeholder="All statuses" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All statuses</SelectItem>
                    <SelectItem value="pending">Pending</SelectItem>
                    <SelectItem value="sent">Sent</SelectItem>
                    <SelectItem value="expired">Expired</SelectItem>
                    <SelectItem value="delivered">Delivered</SelectItem>
                    <SelectItem value="failed">Failed</SelectItem>
                    <SelectItem value="bounced">Bounced</SelectItem>
                    <SelectItem value="rejected">Rejected</SelectItem>
                    <SelectItem value="suppressed">Suppressed</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="w-32">
                <DatePicker
                  value={dateFrom}
                  onChange={setDateFrom}
                  placeholder="From date"
                  disabledDays={[
                    { after: new Date() },
                    ...(dateTo ? [{ after: dateTo }] : []),
                  ]}
                />
              </div>

              <div className="w-32">
                <DatePicker
                  value={dateTo}
                  onChange={setDateTo}
                  placeholder="To date"
                  disabledDays={[
                    { after: new Date() },
                    ...(dateFrom ? [{ before: dateFrom }] : []),
                  ]}
                />
              </div>

              <div className="w-40">
                <SearchableSelect
                  options={[
                    { value: 'all', label: 'All drips' },
                    ...drips.map(d => ({ value: String(d.id), label: d.name })),
                  ]}
                  value={draftDrip || 'all'}
                  onValueChange={(value) => { setDraftDrip(value === 'all' ? '' : value); setDraftStep(''); }}
                  placeholder="All drips"
                  searchPlaceholder="Search drips…"
                />
              </div>

              {selectedDrip && (
                <div className="w-40">
                  <Select value={draftStep || 'all'} onValueChange={(value) => setDraftStep(value === 'all' ? '' : value)}>
                    <SelectTrigger>
                      <SelectValue placeholder="All steps" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All steps</SelectItem>
                      {selectedDrip.steps.map(s => (
                        <SelectItem key={s.id} value={String(s.id)}>
                          Step {s.position + 1}{s.template ? `: ${s.template.name}` : ''}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              )}

              <Button variant="secondary" size="sm" onClick={handleSearch} className="ml-auto">
                <Search className="h-4 w-4 mr-1.5" />
                Search
              </Button>
            </div>

            <div className="mt-2">
              <Button
                variant="link"
                size="sm"
                onClick={clearFilters}
                className="h-auto px-0 text-muted-foreground hover:text-foreground"
              >
                Clear all filters
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Messages Table */}
      <Card className="card-shadow bg-card">
        <CardContent className="p-0">
          {/* Mobile: stacked cards */}
          <div className="md:hidden divide-y divide-border">
            {messages.map((message) => (
              <button
                key={message.id}
                onClick={() => navigate(`/messages/${message.id}`)}
                className="w-full text-left p-4 flex flex-col gap-2 hover:bg-muted/50 transition-colors"
              >
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="shrink-0"><ChannelTypeIcon type={message.channel} size={14} /></span>
                    <span className="font-medium truncate" title={message.to}>
                      <FormattedRecipients raw={message.to} maxVisible={1} />
                    </span>
                  </div>
                  <span className="shrink-0">{renderStatusBadge(message.status)}</span>
                </div>
                <div className="text-sm text-muted-foreground truncate">
                  {message.subject || message.body.substring(0, 80) + '...'}
                </div>
                <div className="flex items-center gap-2 text-xs text-muted-foreground">
                  {renderChannelBadge(message.channel)}
                  {message.drip_campaign_id && (
                    <Badge variant="outline" className="text-xs">Drip</Badge>
                  )}
                  {(message.open_count ?? 0) > 0 && (
                    <span className="flex items-center gap-1 text-blue-600"><Eye className="h-3.5 w-3.5" />{message.open_count}</span>
                  )}
                  {(message.click_count ?? 0) > 0 && (
                    <span className="flex items-center gap-1 text-purple-600"><MousePointer className="h-3.5 w-3.5" />{message.click_count}</span>
                  )}
                  <span className="ml-auto font-mono">
                    {format(new Date(message.sent_at || message.created_at), 'MMM d, h:mm a')}
                  </span>
                </div>
              </button>
            ))}
          </div>

          {/* Desktop: table */}
          <Table className="hidden md:table">
            <TableHeader>
              <TableRow>
                <TableHead>To</TableHead>
                <TableHead>Subject</TableHead>
                <TableHead className="w-[100px]">Channel</TableHead>
                <TableHead className="w-[100px]">Status</TableHead>
                <TableHead className="w-[120px]">Sent At</TableHead>
                <TableHead className="w-[90px]">Engagement</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {messages.map((message) => (
                <TableRow key={message.id} className="cursor-pointer group" onClick={() => navigate(`/messages/${message.id}`)}>
                  <TableCell className="font-medium max-w-[220px]">
                    <div className="flex items-center gap-2">
                      <span className="shrink-0"><ChannelTypeIcon type={message.channel} size={14} /></span>
                      <span className="truncate" title={message.to}>
                        <FormattedRecipients raw={message.to} maxVisible={2} />
                      </span>
                    </div>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <span className="truncate flex-1">
                        {message.subject || message.body.substring(0, 80) + '...'}
                      </span>
                      {message.drip_campaign_id && (
                        <Badge variant="outline" className="text-xs shrink-0">Drip</Badge>
                      )}
                    </div>
                  </TableCell>
                  <TableCell>
                    {renderChannelBadge(message.channel)}
                  </TableCell>
                  <TableCell>
                    {renderStatusBadge(message.status)}
                  </TableCell>
                  <TableCell>
                    {message.sent_at ? (
                      <div className="font-mono whitespace-nowrap" title={format(new Date(message.sent_at), 'MMM d, yyyy h:mm:ss a')}>
                        <div className="text-xs">{format(new Date(message.sent_at), 'MMM d, yyyy')}</div>
                        <div className="text-xs text-muted-foreground">
                          {format(new Date(message.sent_at), 'h:mm a')}
                        </div>
                      </div>
                    ) : (
                      <div className="font-mono whitespace-nowrap" title={format(new Date(message.created_at), 'MMM d, yyyy h:mm:ss a')}>
                        <div className="text-xs text-muted-foreground">{format(new Date(message.created_at), 'MMM d, yyyy')}</div>
                        <div className="text-xs text-muted-foreground/50 italic">Not sent</div>
                      </div>
                    )}
                  </TableCell>
                  <TableCell>
                    {message.channel === 'email' && ((message.open_count ?? 0) > 0 || (message.click_count ?? 0) > 0) ? (
                      <div className="flex items-center gap-2.5 text-xs">
                        {(message.open_count ?? 0) > 0 && (
                          <span className="flex items-center gap-1 text-blue-600" title={`Opened ${message.open_count} ${message.open_count === 1 ? 'time' : 'times'}`}>
                            <Eye className="h-3.5 w-3.5" />{message.open_count}
                          </span>
                        )}
                        {(message.click_count ?? 0) > 0 && (
                          <span className="flex items-center gap-1 text-purple-600" title={`${message.click_count} link ${message.click_count === 1 ? 'click' : 'clicks'}`}>
                            <MousePointer className="h-3.5 w-3.5" />{message.click_count}
                          </span>
                        )}
                      </div>
                    ) : (
                      <Eye className="h-4 w-4 text-muted-foreground opacity-0 group-hover:opacity-100 transition-opacity" />
                    )}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
          
          {messages.length === 0 && !loading && (
            <div className="text-center py-12">
              <Mail className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <h3 className="text-lg font-medium mb-2">No messages found</h3>
              <p className="text-muted-foreground mb-4">
                {Object.values(filters).some(v => v) 
                  ? 'No messages match your current filters.'
                  : 'No messages have been sent yet.'
                }
              </p>
              <Button onClick={() => navigate('/messages/compose')}>
                <Mail className="h-4 w-4 mr-2" />
                Compose Message
              </Button>
            </div>
          )}
          
          {totalPages > 1 && (
            <div className="p-4 border-t border-border">
              <Pagination />
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}