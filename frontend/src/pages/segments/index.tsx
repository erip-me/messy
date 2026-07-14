import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Filter, Trash2, Users, Edit } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { format } from 'date-fns';
import { getSegments, deleteSegment } from '@/api/segments';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';
import { useResource } from '@/hooks/use-resource';

export function SegmentsIndexPage() {
  const navigate = useNavigate();
  const activeEnvId = useActiveEnvironment();
  const { confirm, ConfirmDialog } = useConfirm();
  const { data: segments = [], loading, setData: setSegments } = useResource(
    getSegments,
    [activeEnvId],
    { initialData: [], errorMessage: 'Failed to load segments' },
  );

  const handleDelete = async (id: number, name: string, e: React.MouseEvent) => {
    e.stopPropagation();
    const confirmed = await confirm({ title: 'Delete Segment', description: `Delete segment "${name}"?`, confirmLabel: 'Delete', variant: 'destructive' });
    if (!confirmed) return;
    try {
      await deleteSegment(id);
      setSegments(s => (s ?? []).filter(x => x.id !== id));
      toast.success('Segment deleted');
    } catch {
      toast.error('Failed to delete segment');
    }
  };

  return (
    <div className="p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div>
          <h1 className="page-heading">Segments</h1>
          <p className="page-subtitle">Define dynamic customer groups based on attributes</p>
        </div>
        <Button onClick={() => navigate('/segments/new')}>
          <Plus className="h-4 w-4 mr-2" />
          New Segment
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Filter className="h-5 w-5" />
            All Segments
            <Badge variant="outline">{segments.length}</Badge>
          </CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {loading ? (
            <PageSkeleton columns={4} rows={5} actions={1} />
          ) : segments.length === 0 ? (
            <div className="text-center py-16">
              <Filter className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <h3 className="text-lg font-medium mb-2">No segments yet</h3>
              <p className="text-muted-foreground text-sm mb-4">Create your first segment to group customers dynamically.</p>
              <Button onClick={() => navigate('/segments/new')}>
                <Plus className="h-4 w-4 mr-2" />New Segment
              </Button>
            </div>
          ) : (
            <>
              {/* Mobile: stacked cards */}
              <div className="md:hidden divide-y divide-border">
                {segments.map(seg => (
                  <button
                    key={seg.id}
                    onClick={() => navigate(`/segments/${seg.id}/edit`)}
                    className="w-full text-left p-4 flex flex-col gap-2 hover:bg-muted/50 transition-colors"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <span className="font-medium truncate">{seg.name}</span>
                      <Badge variant="secondary" className="gap-1 shrink-0">
                        <Users className="h-3 w-3" />
                        {seg.customer_count.toLocaleString()}
                      </Badge>
                    </div>
                    {seg.description && (
                      <div className="text-sm text-muted-foreground truncate">{seg.description}</div>
                    )}
                    <div className="text-xs text-muted-foreground font-mono">
                      {format(new Date(seg.updated_at), 'MMM d, yyyy')}
                    </div>
                  </button>
                ))}
              </div>

              {/* Desktop: table */}
              <Table className="hidden md:table">
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Description</TableHead>
                  <TableHead>Contacts</TableHead>
                  <TableHead>Updated</TableHead>
                  <TableHead className="w-20"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {segments.map(seg => (
                  <TableRow
                    key={seg.id}
                    className="cursor-pointer hover:bg-muted/50"
                    onClick={() => navigate(`/segments/${seg.id}/edit`)}
                  >
                    <TableCell className="font-medium">{seg.name}</TableCell>
                    <TableCell className="text-muted-foreground text-sm">{seg.description || '—'}</TableCell>
                    <TableCell>
                      <Badge variant="secondary" className="gap-1">
                        <Users className="h-3 w-3" />
                        {seg.customer_count.toLocaleString()}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground font-mono">
                      {format(new Date(seg.updated_at), 'MMM d, yyyy')}
                    </TableCell>
                    <TableCell>
                      <div className="flex items-center gap-1" onClick={e => e.stopPropagation()}>
                        <Button variant="ghost" size="sm" onClick={() => navigate(`/segments/${seg.id}/edit`)}>
                          <Edit className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          className="text-destructive hover:text-destructive"
                          onClick={(e) => handleDelete(seg.id, seg.name, e)}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
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
