import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Trash2, Eye, Edit, Megaphone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { format } from 'date-fns';
import { getCampaigns, deleteCampaign, Campaign, CampaignStatus } from '@/api/campaigns';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';
import { ChannelTypeIcon } from '@/components/channel-icons';

const STATUS_BADGE: Record<CampaignStatus, { label: string; className: string }> = {
  draft:   { label: 'Draft',   className: 'bg-muted text-foreground' },
  sending: { label: 'Sending', className: 'bg-blue-100 text-blue-700' },
  sent:    { label: 'Sent',    className: 'bg-green-100 text-green-700' },
  failed:  { label: 'Failed',  className: 'bg-red-100 text-red-700' },
};

export function CampaignsIndexPage() {
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();
  const activeEnvId = useActiveEnvironment();
  const { confirm, ConfirmDialog } = useConfirm();

  useEffect(() => { load(); }, [activeEnvId]);

  const load = async () => {
    setLoading(true);
    try { setCampaigns(await getCampaigns()); }
    catch { toast.error('Failed to load campaigns'); }
    finally { setLoading(false); }
  };

  const handleDelete = async (id: number, name: string, e: React.MouseEvent) => {
    e.stopPropagation();
    const confirmed = await confirm({
      title: 'Delete Campaign',
      description: `Delete campaign "${name}"?`,
      confirmLabel: 'Delete',
      variant: 'destructive',
    });
    if (!confirmed) return;
    try {
      await deleteCampaign(id);
      setCampaigns(c => c.filter(x => x.id !== id));
      toast.success('Campaign deleted');
    } catch (err: any) {
      toast.error(err.response?.data?.error || 'Failed to delete');
    }
  };

  return (
    <div className="p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div>
          <h1 className="page-heading">Campaigns</h1>
          <p className="page-subtitle">Create and send campaigns to customer segments</p>
        </div>
        <Button onClick={() => navigate('/campaigns/new')}>
          <Plus className="h-4 w-4 mr-2" />New Campaign
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Megaphone className="h-5 w-5" />
            All Campaigns
            <Badge variant="outline">{campaigns.length}</Badge>
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {loading ? (
            <PageSkeleton columns={5} rows={5} actions={1} />
          ) : campaigns.length === 0 ? (
            <div className="text-center py-16">
              <Megaphone className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <h3 className="text-lg font-medium mb-2">No campaigns yet</h3>
              <p className="text-muted-foreground text-sm mb-4">Create your first campaign to start sending messages.</p>
              <Button onClick={() => navigate('/campaigns/new')}><Plus className="h-4 w-4 mr-2" />New Campaign</Button>
            </div>
          ) : (
            <>
            {/* Mobile: stacked cards */}
            <div className="md:hidden divide-y divide-border">
              {campaigns.map(c => {
                const badge = STATUS_BADGE[c.status];
                return (
                  <button
                    key={c.id}
                    onClick={() => navigate(`/campaigns/${c.id}`)}
                    className="w-full text-left p-4 flex flex-col gap-2 hover:bg-muted/50 transition-colors"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <span className="font-medium truncate">{c.name}</span>
                      <span className={`shrink-0 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${badge.className}`}>
                        {badge.label}
                      </span>
                    </div>
                    <div className="flex items-center gap-1.5 text-sm text-muted-foreground">
                      <ChannelTypeIcon type={c.channel || 'email'} size={14} />
                      <span className="capitalize">{c.channel || 'email'}</span>
                      <span>· {c.segment?.name || 'All'}</span>
                    </div>
                    <div className="flex items-center gap-2 text-xs text-muted-foreground">
                      <span>{c.recipient_count.toLocaleString()} recipients</span>
                      {c.status === 'sent' && <span>· {c.stats.open_rate}% open</span>}
                      <span className="ml-auto font-mono">
                        {format(new Date(c.sent_at || c.created_at), 'MMM d, yyyy')}
                      </span>
                    </div>
                  </button>
                );
              })}
            </div>

            {/* Desktop: table */}
            <Table className="hidden md:table">
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Channel</TableHead>
                  <TableHead>Segment</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Recipients</TableHead>
                  <TableHead>Open Rate</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead className="w-24"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {campaigns.map(c => {
                  const badge = STATUS_BADGE[c.status];
                  return (
                    <TableRow key={c.id} className="cursor-pointer hover:bg-muted/50" onClick={() => navigate(`/campaigns/${c.id}`)}>
                      <TableCell className="font-medium">{c.name}</TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1.5">
                          <ChannelTypeIcon type={c.channel || 'email'} size={16} />
                          <span className="text-sm capitalize">{c.channel || 'email'}</span>
                        </div>
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground">{c.segment?.name || 'All'}</TableCell>
                      <TableCell>
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${badge.className}`}>
                          {badge.label}
                        </span>
                      </TableCell>
                      <TableCell className="text-sm">{c.recipient_count.toLocaleString()}</TableCell>
                      <TableCell className="text-sm">
                        {c.status === 'sent' ? `${c.stats.open_rate}%` : '—'}
                      </TableCell>
                      <TableCell className="text-sm text-muted-foreground font-mono">
                        {format(new Date(c.sent_at || c.created_at), 'MMM d, yyyy')}
                      </TableCell>
                      <TableCell onClick={e => e.stopPropagation()}>
                        <div className="flex items-center gap-1">
                          {c.status === 'draft' && (
                            <Button variant="ghost" size="sm" onClick={() => navigate(`/campaigns/${c.id}/edit`)}>
                              <Edit className="h-4 w-4" />
                            </Button>
                          )}
                          <Button variant="ghost" size="sm" onClick={() => navigate(`/campaigns/${c.id}`)}>
                            <Eye className="h-4 w-4" />
                          </Button>
                          {c.status !== 'sending' && (
                            <Button variant="ghost" size="sm" className="text-destructive hover:text-destructive" onClick={e => handleDelete(c.id, c.name, e)}>
                              <Trash2 className="h-4 w-4" />
                            </Button>
                          )}
                        </div>
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

      {ConfirmDialog}
    </div>
  );
}
