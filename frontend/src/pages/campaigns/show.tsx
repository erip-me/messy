import React, { useState, useEffect, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { usePageParam } from '@/hooks/usePageParam';
import { ArrowLeft, Users, CheckCircle, XCircle, Eye, MousePointer, RefreshCw, Megaphone, Ban, Clock, RotateCcw, UserMinus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Progress } from '@/components/ui/progress';
import { Skeleton } from '@/components/ui/skeleton';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import toast from 'react-hot-toast';
import { format } from 'date-fns';
import { getCampaign, getCampaignDeliveries, retryDelivery, retryAllFailed, Campaign, CampaignDelivery, CampaignStatus } from '@/api/campaigns';
import { ChannelTypeIcon } from '@/components/channel-icons';
import { createAuthenticatedConsumer } from '@/utils/cable';

const STATUS_BADGE: Record<CampaignStatus, { label: string; className: string }> = {
  draft:   { label: 'Draft',   className: 'bg-muted text-foreground' },
  sending: { label: 'Sending', className: 'bg-blue-100 text-blue-700' },
  sent:    { label: 'Sent',    className: 'bg-green-100 text-green-700' },
  failed:  { label: 'Failed',  className: 'bg-red-100 text-red-700' },
};

export function CampaignShowPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [deliveries, setDeliveries] = useState<CampaignDelivery[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = usePageParam();
  const [totalPages, setTotalPages] = useState(1);
  const [statusFilter, setStatusFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [_deliveriesLoading, setDeliveriesLoading] = useState(false);
  const [retryingIds, setRetryingIds] = useState<Set<number>>(new Set());
  const [retryingAll, setRetryingAll] = useState(false);
  const cableRef = useRef<any>(null);
  const subscriptionRef = useRef<any>(null);

  const loadCampaign = async () => {
    try {
      const c = await getCampaign(Number(id));
      setCampaign(c);
      return c;
    } catch (e: any) {
      const msg = e?.response?.data?.error || 'Failed to load campaign';
      setError(msg);
      toast.error(msg);
    }
  };

  const loadDeliveries = async (p = page, status = statusFilter) => {
    setDeliveriesLoading(true);
    try {
      const data = await getCampaignDeliveries(Number(id), { page: p, status: status === 'all' ? undefined : status });
      setDeliveries(data.deliveries);
      setTotal(data.total);
      setTotalPages(data.total_pages);
    } catch { /* ignore */ } finally { setDeliveriesLoading(false); }
  };

  // Stable ref for WebSocket callbacks to avoid stale closures
  const loadDeliveriesRef = useRef(loadDeliveries);
  loadDeliveriesRef.current = loadDeliveries;

  const handleRetry = async (deliveryId: number) => {
    setRetryingIds(prev => new Set(prev).add(deliveryId));
    try {
      await retryDelivery(Number(id), deliveryId);
      toast.success('Delivery queued for retry');
      await Promise.all([loadCampaign(), loadDeliveries()]);
    } catch (e: any) {
      toast.error(e?.response?.data?.error || 'Retry failed');
    } finally {
      setRetryingIds(prev => { const s = new Set(prev); s.delete(deliveryId); return s; });
    }
  };

  const handleRetryAll = async () => {
    setRetryingAll(true);
    try {
      const result = await retryAllFailed(Number(id));
      toast.success(result.message);
      await Promise.all([loadCampaign(), loadDeliveries()]);
    } catch (e: any) {
      toast.error(e?.response?.data?.error || 'Retry failed');
    } finally {
      setRetryingAll(false);
    }
  };

  useEffect(() => {
    (async () => {
      setLoading(true);
      await loadCampaign();
      await loadDeliveries();
      setLoading(false);
    })();
  }, [id]);

  useEffect(() => { if (!loading) loadDeliveries(page, statusFilter); }, [page, statusFilter]);

  // Real-time updates via WebSocket (replaces polling)
  useEffect(() => {
    if (!campaign?.id) return;

    const cable = createAuthenticatedConsumer();
    if (!cable) return;
    cableRef.current = cable;

    const subscription = cable.subscriptions.create(
      { channel: 'CampaignChannel', campaign_id: campaign.id },
      {
        received(data: any) {
          if (data.type !== 'delivery_update') return;

          if (data.stats) {
            setCampaign(prev => prev ? { ...prev, stats: data.stats } : null);
          }
          if (data.campaign_status && data.campaign_status !== 'sending') {
            setCampaign(prev => prev ? { ...prev, status: data.campaign_status } : null);
            loadDeliveriesRef.current();
          }
          if (data.delivery) {
            setDeliveries(prev =>
              prev.map(d => d.id === data.delivery.id ? { ...d, ...data.delivery } : d)
            );
          }
        }
      }
    );
    subscriptionRef.current = subscription;

    return () => {
      subscription.unsubscribe();
      cable.disconnect();
    };
  }, [campaign?.id]);

  if (loading) return (
    <div className="p-6 space-y-4">
      <Skeleton className="h-10 w-64" /><Skeleton className="h-32 w-full" /><Skeleton className="h-64 w-full" />
    </div>
  );

  if (error || !campaign) return (
    <div className="p-6">
      <Button variant="ghost" size="sm" onClick={() => navigate('/campaigns')} className="mb-4">
        <ArrowLeft className="h-4 w-4 mr-2" />Campaigns
      </Button>
      <div className="text-center py-20">
        <p className="text-muted-foreground">{error || 'Campaign not found'}</p>
      </div>
    </div>
  );

  const badge = STATUS_BADGE[campaign.status];
  const stats = campaign.stats;
  const sentPct = stats.total > 0 ? Math.round((stats.sent + stats.failed + stats.rejected) / stats.total * 100) : 0;
  const pctOfTotal = (n: number) => (stats.total > 0 ? `${Math.round((n / stats.total) * 100)}%` : null);

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center gap-4 mb-6">
        <Button variant="ghost" size="sm" onClick={() => navigate('/campaigns')}>
          <ArrowLeft className="h-4 w-4 mr-2" />Campaigns
        </Button>
        <div className="flex-1">
          <div className="flex items-center gap-3">
            <h1 className="page-heading">{campaign.name}</h1>
            <span className={`inline-flex items-center px-2.5 py-0.5 rounded text-xs font-medium ${badge.className}`}>
              {badge.label}
            </span>
          </div>
          <p className="page-subtitle flex items-center gap-2">
            <ChannelTypeIcon type={campaign.channel || 'email'} size={14} />
            <span className="capitalize">{campaign.channel || 'email'}</span>
            {campaign.subject && <span>· {campaign.subject}</span>}
            {campaign.from_email && <span>· From: {campaign.from_email}</span>}
            {campaign.template && <span>· Template: {campaign.template.name}</span>}
          </p>
        </div>
        {campaign.status === 'sending' && (
          <div className="flex items-center gap-2 text-sm text-blue-600">
            <RefreshCw className="h-4 w-4 animate-spin" />Sending…
          </div>
        )}
        {campaign.status === 'draft' && (
          <Button variant="outline" onClick={() => navigate(`/campaigns/${id}/edit`)}>Edit Campaign</Button>
        )}
      </div>

      {/* Stats cards */}
      <div className="flex flex-wrap gap-4 mb-6">
        {[
          { icon: Users, label: 'Recipients', value: stats.total.toLocaleString(), pct: null, color: '#9ca3af', seed: 1, filterStatus: 'all' },
          { icon: Clock, label: 'Pending', value: stats.pending.toLocaleString(), pct: pctOfTotal(stats.pending), color: '#6b7280', seed: 6, textClass: 'text-muted-foreground', filterStatus: 'pending', ringClass: 'ring-gray-500' },
          { icon: CheckCircle, label: 'Sent', value: stats.sent.toLocaleString(), pct: pctOfTotal(stats.sent), color: '#22c55e', seed: 2, textClass: 'text-green-600', filterStatus: 'sent', ringClass: 'ring-green-500' },
          ...((campaign.channel || 'email') === 'email' ? [{ icon: Eye, label: 'Open Rate', value: `${stats.open_rate}%`, pct: null, color: '#3b82f6', seed: 3, textClass: 'text-blue-600', filterStatus: 'opened', ringClass: 'ring-blue-500' }] : []),
          { icon: XCircle, label: 'Failed', value: stats.failed.toLocaleString(), pct: pctOfTotal(stats.failed), color: '#ef4444', seed: 4, textClass: 'text-red-500', filterStatus: 'failed', ringClass: 'ring-red-500' },
          { icon: Ban, label: 'Rejected', value: stats.rejected.toLocaleString(), pct: pctOfTotal(stats.rejected), color: '#f97316', seed: 5, textClass: 'text-orange-500', filterStatus: 'rejected', ringClass: 'ring-orange-500' },
          { icon: UserMinus, label: 'Unsubscribed', value: stats.unsubscribed.toLocaleString(), pct: pctOfTotal(stats.unsubscribed), color: '#a855f7', seed: 7, textClass: 'text-purple-600', filterStatus: 'unsubscribed', ringClass: 'ring-purple-500' },
        ].map(({ icon: Icon, label, value, pct, color, seed, textClass, filterStatus: cardFilter, ringClass }) => {
          const isActive = cardFilter && cardFilter !== 'all' && statusFilter === cardFilter;
          return (
            <Card
              key={label}
              className={`flex-1 min-w-[140px] transition-shadow ${cardFilter ? 'cursor-pointer hover:shadow-md' : ''} ${isActive ? `ring-2 ${ringClass}` : ''}`}
              onClick={() => {
                if (!cardFilter) return;
                setStatusFilter(statusFilter === cardFilter ? 'all' : cardFilter);
                setPage(1);
              }}
            >
              <CardContent className="p-4 flex items-center justify-between">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <Icon className="h-4 w-4" style={{ color }} />
                    <span className="text-xs text-muted-foreground">{label}</span>
                  </div>
                  <p className="flex items-baseline gap-1.5">
                    <span className={`text-2xl font-bold ${textClass || ''}`}>{value}</span>
                    {pct && <span className="text-xs font-medium text-muted-foreground">{pct}</span>}
                  </p>
                </div>
                <svg width="64" height="32" viewBox="0 0 64 32" fill="none" className="opacity-60">
                  <polyline
                    points={Array.from({ length: 8 }, (_, i) => {
                      const y = 16 + Math.sin(i * 0.9 + seed * 1.7) * 10 + Math.cos(i * 1.4 + seed) * 5;
                      return `${i * 9},${Math.max(2, Math.min(30, y))}`;
                    }).join(' ')}
                    stroke={color}
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </CardContent>
            </Card>
          );
        })}
      </div>

      {/* Progress bar */}
      {(campaign.status === 'sending' || stats.total > 0) && (
        <Card className="mb-6">
          <CardContent className="p-4">
            <div className="flex justify-between text-sm mb-2">
              <span className="text-muted-foreground">Delivery Progress</span>
              <span className="font-medium">{sentPct}%</span>
            </div>
            <Progress value={sentPct} className="h-2" />
            <div className="flex justify-between text-xs text-muted-foreground mt-1">
              <span>{stats.sent + stats.failed + stats.rejected} of {stats.total} processed</span>
              {stats.pending > 0 && <span>{stats.pending} pending</span>}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Deliveries table */}
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between gap-2 flex-wrap">
            <CardTitle className="flex items-center gap-2">
              <Megaphone className="h-5 w-5" />
              Deliveries
              <Badge variant="outline">{total}</Badge>
            </CardTitle>
            <div className="flex items-center gap-2">
              {statusFilter === 'failed' && stats.failed > 0 && (
                <Button variant="outline" size="sm" className="h-8 text-sm" disabled={retryingAll} onClick={handleRetryAll}>
                  <RotateCcw className={`h-3.5 w-3.5 mr-1.5 ${retryingAll ? 'animate-spin' : ''}`} />
                  {retryingAll ? 'Retrying…' : `Retry all failed (${stats.failed})`}
                </Button>
              )}
            <Select value={statusFilter} onValueChange={v => { setStatusFilter(v || 'all'); setPage(1); }}>
              <SelectTrigger className="w-36 h-8 text-sm">
                <SelectValue placeholder="All statuses" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All statuses</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="sent">Sent</SelectItem>
                <SelectItem value="opened">Opened</SelectItem>
                <SelectItem value="failed">Failed</SelectItem>
                <SelectItem value="rejected">Rejected</SelectItem>
                <SelectItem value="unsubscribed">Unsubscribed</SelectItem>
              </SelectContent>
            </Select>
            </div>
          </div>
        </CardHeader>
        <CardContent className="p-0">
          {deliveries.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground text-sm">
              {campaign.status === 'draft' ? 'No deliveries yet. Send the campaign to get started.' : 'No deliveries match the filter.'}
            </div>
          ) : (
            <>
              {/* Mobile: stacked cards */}
              <div className="md:hidden divide-y divide-border">
                {deliveries.map(d => (
                  <div key={d.id} className="p-4 flex flex-col gap-2">
                    <div className="flex items-center justify-between gap-2">
                      <span className="font-mono text-sm truncate">{d.email}</span>
                      <span className="shrink-0">
                        {d.status === 'sent' && <Badge className="bg-green-100 text-green-700 hover:bg-green-100 text-xs">Sent</Badge>}
                        {d.status === 'failed' && <Badge className="bg-red-100 text-red-700 hover:bg-red-100 text-xs">Failed</Badge>}
                        {d.status === 'pending' && <Badge className="bg-muted text-muted-foreground hover:bg-muted text-xs">Pending</Badge>}
                        {d.status === 'rejected' && <Badge className="bg-orange-100 text-orange-700 hover:bg-orange-100 text-xs">Rejected</Badge>}
                      </span>
                    </div>
                    {d.customer && (
                      <button
                        type="button"
                        onClick={() => navigate(`/customers/${d.customer!.id}`)}
                        className="text-left text-sm text-muted-foreground truncate hover:text-primary hover:underline"
                      >
                        {[d.customer.first_name, d.customer.last_name].filter(Boolean).join(' ') || '—'}
                      </button>
                    )}
                    {d.error_message && (
                      <p className="text-xs text-muted-foreground">{d.error_message}</p>
                    )}
                    <div className="flex items-center gap-3 text-xs text-muted-foreground">
                      <span className="font-mono">{d.sent_at ? format(new Date(d.sent_at), 'MMM d, HH:mm') : '—'}</span>
                      {d.open_count > 0 && <span className="flex items-center gap-1 text-blue-600"><Eye className="h-3.5 w-3.5" />{d.open_count}</span>}
                      {d.click_count > 0 && <span className="flex items-center gap-1 text-purple-600"><MousePointer className="h-3.5 w-3.5" />{d.click_count}</span>}
                      {d.status === 'failed' && (
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-7 w-7 p-0 ml-auto"
                          disabled={retryingIds.has(d.id)}
                          onClick={() => handleRetry(d.id)}
                          title="Retry delivery"
                        >
                          <RotateCcw className={`h-3.5 w-3.5 ${retryingIds.has(d.id) ? 'animate-spin' : ''}`} />
                        </Button>
                      )}
                    </div>
                  </div>
                ))}
              </div>

              {/* Desktop: table */}
              <Table className="hidden md:table">
                <TableHeader>
                  <TableRow>
                    <TableHead>Customer</TableHead>
                    <TableHead>Email</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Sent At</TableHead>
                    <TableHead>Opened</TableHead>
                    <TableHead>Clicks</TableHead>
                    <TableHead className="w-[50px]"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {deliveries.map(d => (
                    <TableRow key={d.id}>
                      <TableCell className="text-sm">
                        {d.customer ? (
                          <button
                            type="button"
                            onClick={() => navigate(`/customers/${d.customer!.id}`)}
                            className="text-left hover:text-primary hover:underline"
                          >
                            {[d.customer.first_name, d.customer.last_name].filter(Boolean).join(' ') || '—'}
                          </button>
                        ) : '—'}
                      </TableCell>
                      <TableCell className="font-mono text-sm">{d.email}</TableCell>
                      <TableCell>
                        <div>
                          {d.status === 'sent' && <Badge className="bg-green-100 text-green-700 hover:bg-green-100 text-xs">Sent</Badge>}
                          {d.status === 'failed' && <Badge className="bg-red-100 text-red-700 hover:bg-red-100 text-xs">Failed</Badge>}
                          {d.status === 'pending' && <Badge className="bg-muted text-muted-foreground hover:bg-muted text-xs">Pending</Badge>}
                          {d.status === 'rejected' && <Badge className="bg-orange-100 text-orange-700 hover:bg-orange-100 text-xs">Rejected</Badge>}
                          {d.error_message && (
                            <p className="text-xs text-muted-foreground mt-1">{d.error_message}</p>
                          )}
                        </div>
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground font-mono">
                        {d.sent_at ? format(new Date(d.sent_at), 'MMM d, HH:mm') : '—'}
                      </TableCell>
                      <TableCell>
                        {d.open_count > 0 ? (
                          <span className="flex items-center gap-1 text-sm text-blue-600"><Eye className="h-3.5 w-3.5" />{d.open_count}</span>
                        ) : <span className="text-muted-foreground text-sm">—</span>}
                      </TableCell>
                      <TableCell>
                        {d.click_count > 0 ? (
                          <span className="flex items-center gap-1 text-sm text-purple-600"><MousePointer className="h-3.5 w-3.5" />{d.click_count}</span>
                        ) : <span className="text-muted-foreground text-sm">—</span>}
                      </TableCell>
                      <TableCell>
                        {d.status === 'failed' && (
                          <Button
                            variant="ghost"
                            size="sm"
                            className="h-7 w-7 p-0"
                            disabled={retryingIds.has(d.id)}
                            onClick={() => handleRetry(d.id)}
                            title="Retry delivery"
                          >
                            <RotateCcw className={`h-3.5 w-3.5 ${retryingIds.has(d.id) ? 'animate-spin' : ''}`} />
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
              {totalPages > 1 && (
                <div className="flex items-center justify-between px-4 py-3 border-t">
                  <p className="text-sm text-muted-foreground">Page {page} of {totalPages}</p>
                  <div className="flex gap-2">
                    <Button variant="outline" size="sm" disabled={page === 1} onClick={() => setPage(page - 1)}>Prev</Button>
                    <Button variant="outline" size="sm" disabled={page === totalPages} onClick={() => setPage(page + 1)}>Next</Button>
                  </div>
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
