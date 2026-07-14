import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Trash2, Edit, Zap, Play, Pause } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { format } from 'date-fns';
import { getDrips, deleteDrip, activateDrip, pauseDrip, Drip, DripStatus } from '@/api/drips';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';

const STATUS_BADGE: Record<DripStatus, { label: string; className: string }> = {
  draft:    { label: 'Draft',    className: 'bg-muted text-foreground' },
  active:   { label: 'Active',   className: 'bg-green-100 text-green-700' },
  paused:   { label: 'Paused',   className: 'bg-yellow-100 text-yellow-700' },
  archived: { label: 'Archived', className: 'bg-muted text-muted-foreground' },
};

export function DripsIndexPage() {
  const [drips, setDrips] = useState<Drip[]>([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();
  const activeEnvId = useActiveEnvironment();
  const { confirm, ConfirmDialog } = useConfirm();

  useEffect(() => { load(); }, [activeEnvId]);

  const load = async () => {
    setLoading(true);
    try { setDrips(await getDrips()); }
    catch { toast.error('Failed to load drips'); }
    finally { setLoading(false); }
  };

  const handleDelete = async (id: number, name: string, e: React.MouseEvent) => {
    e.stopPropagation();
    const confirmed = await confirm({
      title: 'Delete Drip',
      description: `Delete drip "${name}"? Active enrollments will be removed.`,
      confirmLabel: 'Delete',
      variant: 'destructive',
    });
    if (!confirmed) return;
    try {
      await deleteDrip(id);
      setDrips(d => d.filter(x => x.id !== id));
      toast.success('Drip deleted');
    } catch (err: any) {
      toast.error(err.response?.data?.error || 'Failed to delete');
    }
  };

  const toggleStatus = async (drip: Drip, e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      const updated = drip.status === 'active' ? await pauseDrip(drip.id) : await activateDrip(drip.id);
      setDrips(d => d.map(x => (x.id === drip.id ? updated : x)));
      toast.success(updated.status === 'active' ? 'Drip activated' : 'Drip paused');
    } catch (err: any) {
      toast.error(err.response?.data?.errors?.[0] || err.response?.data?.error || 'Failed to update');
    }
  };

  return (
    <div className="p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div>
          <h1 className="page-heading">Drips</h1>
          <p className="page-subtitle">Automated sequences triggered when customers enter a segment</p>
        </div>
        <Button onClick={() => navigate('/drips/new')}>
          <Plus className="h-4 w-4 mr-2" />New Drip
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Zap className="h-5 w-5" />
            All Drips
            <Badge variant="outline">{drips.length}</Badge>
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {loading ? (
            <PageSkeleton columns={6} rows={5} actions={1} />
          ) : drips.length === 0 ? (
            <div className="text-center py-16">
              <Zap className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <h3 className="text-lg font-medium mb-2">No drips yet</h3>
              <p className="text-muted-foreground text-sm mb-4">Create a drip to automatically nurture customers as they enter a segment.</p>
              <Button onClick={() => navigate('/drips/new')}><Plus className="h-4 w-4 mr-2" />New Drip</Button>
            </div>
          ) : (
            <>
            {/* Mobile: stacked cards */}
            <div className="md:hidden divide-y divide-border">
              {drips.map(d => {
                const badge = STATUS_BADGE[d.status];
                return (
                  <button
                    key={d.id}
                    onClick={() => navigate(`/drips/${d.id}/edit`)}
                    className="w-full text-left p-4 flex flex-col gap-2 hover:bg-muted/50 transition-colors"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <span className="font-medium truncate">{d.name}</span>
                      <span className={`shrink-0 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${badge.className}`}>
                        {badge.label}
                      </span>
                    </div>
                    <div className="text-sm text-muted-foreground truncate">
                      {d.segment?.name || '—'}
                    </div>
                    <div className="flex items-center gap-2 text-xs text-muted-foreground">
                      <span>{d.steps.length} steps</span>
                      <span>· {d.stats.active.toLocaleString()} active</span>
                      <span>· {d.stats.completed.toLocaleString()} completed</span>
                      <span className="ml-auto font-mono">
                        {format(new Date(d.created_at), 'MMM d, yyyy')}
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
                  <TableHead>Trigger Segment</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Steps</TableHead>
                  <TableHead>Active</TableHead>
                  <TableHead>Completed</TableHead>
                  <TableHead>Date</TableHead>
                  <TableHead className="w-32"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {drips.map(d => {
                  const badge = STATUS_BADGE[d.status];
                  return (
                    <TableRow key={d.id} className="cursor-pointer hover:bg-muted/50" onClick={() => navigate(`/drips/${d.id}/edit`)}>
                      <TableCell className="font-medium">{d.name}</TableCell>
                      <TableCell className="text-sm text-muted-foreground">{d.segment?.name || '—'}</TableCell>
                      <TableCell>
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${badge.className}`}>
                          {badge.label}
                        </span>
                      </TableCell>
                      <TableCell className="text-sm">{d.steps.length}</TableCell>
                      <TableCell className="text-sm">{d.stats.active.toLocaleString()}</TableCell>
                      <TableCell className="text-sm">{d.stats.completed.toLocaleString()}</TableCell>
                      <TableCell className="text-sm text-muted-foreground font-mono">
                        {format(new Date(d.created_at), 'MMM d, yyyy')}
                      </TableCell>
                      <TableCell onClick={e => e.stopPropagation()}>
                        <div className="flex items-center gap-1">
                          {(d.status === 'active' || d.status === 'paused') && (
                            <Button variant="ghost" size="sm" onClick={e => toggleStatus(d, e)} title={d.status === 'active' ? 'Pause' : 'Activate'}>
                              {d.status === 'active' ? <Pause className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                            </Button>
                          )}
                          {d.status === 'draft' && (
                            <Button variant="ghost" size="sm" onClick={e => toggleStatus(d, e)} title="Activate">
                              <Play className="h-4 w-4" />
                            </Button>
                          )}
                          <Button variant="ghost" size="sm" onClick={() => navigate(`/drips/${d.id}/edit`)}>
                            <Edit className="h-4 w-4" />
                          </Button>
                          <Button variant="ghost" size="sm" className="text-destructive hover:text-destructive" onClick={e => handleDelete(d.id, d.name, e)}>
                            <Trash2 className="h-4 w-4" />
                          </Button>
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
