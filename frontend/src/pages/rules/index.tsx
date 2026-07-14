import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Plus, Shield,
  Edit, Trash2, MoreHorizontal, Search, ArrowRight, Filter,
} from 'lucide-react';
import { ChannelTypeIcon } from '@/components/channel-icons';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Switch } from '@/components/ui/switch';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import { getDeliveryRules, updateDeliveryRule, deleteDeliveryRule, DeliveryRule } from '@/api/rules';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';
import { CHANNEL_LABELS } from '@/lib/labels';


const OUTCOME_CONFIG: Record<string, { label: string; className: string }> = {
  deliver:  { label: 'Deliver',  className: 'bg-emerald-100 text-emerald-700 hover:bg-emerald-100' },
  block:    { label: 'Block',    className: 'bg-red-100 text-red-600 hover:bg-red-100' },
  redirect: { label: 'Redirect', className: 'bg-blue-100 text-blue-700 hover:bg-blue-100' },
};

export function RulesIndexPage() {
  const navigate = useNavigate();
  const activeEnvId = useActiveEnvironment();
  const { confirm, ConfirmDialog } = useConfirm();
  const [rules, setRules] = useState<DeliveryRule[]>([]);
  const [loading, setLoading] = useState(true);
  const [showFilters, setShowFilters] = useState(false);
  const [search, setSearch] = useState('');
  const [channelFilter, setChannelFilter] = useState<string>('all');
  const [outcomeFilter, setOutcomeFilter] = useState<string>('all');
  const [activeFilter, setActiveFilter] = useState<string>('all');
  const [sortBy, setSortBy] = useState<'name' | 'condition' | 'tags' | null>(null);
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc');

  const toggleSort = (col: 'name' | 'condition' | 'tags') => {
    if (sortBy === col) setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortDir('asc'); }
  };

  const SortIcon = ({ col }: { col: string }) => {
    if (sortBy !== col) return <span className="ml-1 opacity-0 group-hover/sort:opacity-40 text-xs">↕</span>;
    return <span className="ml-1 text-xs">{sortDir === 'asc' ? '↑' : '↓'}</span>;
  };

  useEffect(() => {
    loadRules();
  }, [activeEnvId]);

  const loadRules = async () => {
    try {
      setLoading(true);
      const data = await getDeliveryRules(activeEnvId);
      setRules(data);
    } catch (error) {
      toast.error('Failed to load delivery rules');
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleToggleActive = async (id: number, active: boolean) => {
    try {
      await updateDeliveryRule(id, { active });
      setRules(prev => prev.map(rule => rule.id === id ? { ...rule, active } : rule));
      toast.success(`Rule ${active ? 'activated' : 'deactivated'}`);
    } catch (error) {
      toast.error('Failed to update rule');
    }
  };

  const handleDelete = async (id: number, name: string) => {
    const confirmed = await confirm({ title: 'Delete Rule', description: `Delete rule "${name}"?`, confirmLabel: 'Delete', variant: 'destructive' });
    if (!confirmed) return;
    try {
      await deleteDeliveryRule(id);
      setRules(prev => prev.filter(rule => rule.id !== id));
      toast.success('Rule deleted');
    } catch (error) {
      toast.error('Failed to delete rule');
    }
  };

  const activeCount = rules.filter(r => r.active).length;

  const clearFilters = () => {
    setSearch('');
    setChannelFilter('all');
    setOutcomeFilter('all');
    setActiveFilter('all');
  };

  const hasActiveFilters = search || channelFilter !== 'all' || outcomeFilter !== 'all' || activeFilter !== 'all';

  const filtered = rules.filter(rule => {
    const matchChannel = channelFilter === 'all' || rule.type === channelFilter;
    const matchOutcome = outcomeFilter === 'all' || rule.outcome === outcomeFilter;
    const matchActive  = activeFilter  === 'all' || (activeFilter === 'active' ? rule.active : !rule.active);
    const q = search.toLowerCase().trim();
    const matchSearch = !q
      || rule.name.toLowerCase().includes(q)
      || (rule.condition || '').toLowerCase().includes(q);
    return matchChannel && matchOutcome && matchActive && matchSearch;
  });

  const sorted = sortBy
    ? [...filtered].sort((a, b) => {
        let cmp = 0;
        if (sortBy === 'name')        cmp = (a.name || '').localeCompare(b.name || '');
        else if (sortBy === 'condition')   cmp = (a.condition || '').localeCompare(b.condition || '');
        else if (sortBy === 'tags')        cmp = (a.tags?.[0] || '').localeCompare(b.tags?.[0] || '');
        return sortDir === 'asc' ? cmp : -cmp;
      })
    : filtered;

  if (loading) {
    return <PageSkeleton columns={6} rows={6} actions={1} />;
  }


  return (
    <div className="p-6 space-y-5">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center">
        <div>
          <h1 className="page-heading">Automations</h1>
          <p className="page-subtitle">
            Control message delivery: block, redirect, or enforce conditions per channel.
          </p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Button variant="outline" onClick={() => setShowFilters(v => !v)}>
            <Filter className="h-4 w-4 mr-2" />
            {showFilters ? 'Hide Filters' : 'Show Filters'}
            {hasActiveFilters && (
              <span className="ml-2 inline-flex items-center justify-center h-4 w-4 rounded-full bg-primary text-primary-foreground text-[10px] font-bold">
                {[search, channelFilter !== 'all', outcomeFilter !== 'all', activeFilter !== 'all'].filter(Boolean).length}
              </span>
            )}
          </Button>
          <Button onClick={() => navigate('/rules/create')}>
            <Plus className="h-4 w-4 mr-2" />
            Create Rule
          </Button>
        </div>
      </div>

      {/* Filter panel */}
      {showFilters && (
        <Card className="card-shadow bg-card">
          <CardContent className="pt-6">
            <div className="flex flex-wrap items-center gap-3">
              <div className="relative min-w-[180px] flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground pointer-events-none" />
                <Input
                  aria-label="Search rules"
                  placeholder="Search rules…"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="pl-10"
                />
              </div>

              <div className="w-36">
                <Select value={channelFilter} onValueChange={setChannelFilter}>
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
                <Select value={outcomeFilter} onValueChange={setOutcomeFilter}>
                  <SelectTrigger>
                    <SelectValue placeholder="All outcomes" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All outcomes</SelectItem>
                    <SelectItem value="deliver">Deliver</SelectItem>
                    <SelectItem value="block">Block</SelectItem>
                    <SelectItem value="redirect">Redirect</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="w-36">
                <Select value={activeFilter} onValueChange={setActiveFilter}>
                  <SelectTrigger>
                    <SelectValue placeholder="All statuses" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All</SelectItem>
                    <SelectItem value="active">Active only</SelectItem>
                    <SelectItem value="inactive">Inactive only</SelectItem>
                  </SelectContent>
                </Select>
              </div>

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

      {/* Table card */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-base">
            <Shield className="h-4 w-4" />
            Delivery Rules
            <Badge variant="outline" className="ml-1">
              {activeCount} of {rules.length} active
            </Badge>
          </CardTitle>
        </CardHeader>

        <CardContent className="p-0">
          {rules.length === 0 ? (
            <div className="text-center py-16 px-6">
              <Shield className="h-10 w-10 text-muted-foreground mx-auto mb-4" />
              <h3 className="text-base font-semibold mb-2">No delivery rules configured</h3>
              <p className="text-sm text-muted-foreground mb-5 max-w-xs mx-auto">
                Rules let you control how messages are delivered: block, redirect, or enforce conditions per channel.
              </p>
              <Button onClick={() => navigate('/rules/create')}>
                <Plus className="h-4 w-4 mr-2" />
                Create your first rule
              </Button>
            </div>
          ) : sorted.length === 0 ? (
            <div className="text-center py-12 text-sm text-muted-foreground">
              No rules match your filters.{' '}
              <button className="underline" onClick={clearFilters}>
                Clear filters
              </button>
            </div>
          ) : (
            <>
            {/* Mobile: stacked cards */}
            <div className="md:hidden divide-y divide-border">
              {sorted.map((rule) => {
                const outcome = OUTCOME_CONFIG[rule.outcome] || { label: rule.outcome, className: '' };
                return (
                  <div key={rule.id} className="p-4 flex flex-col gap-2">
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-2 min-w-0 font-medium">
                        <ChannelTypeIcon type={rule.type} size={16} />
                        <span className="truncate">{rule.name}</span>
                      </div>
                      <div className="flex items-center gap-1 shrink-0">
                        <Switch
                          checked={rule.active}
                          onCheckedChange={(checked) => handleToggleActive(rule.id, checked)}
                        />
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="sm" className="h-7 w-7 p-0">
                              <MoreHorizontal className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem onClick={() => navigate(`/rules/${rule.id}/edit`)}>
                              <Edit className="h-4 w-4 mr-2" />
                              Edit
                            </DropdownMenuItem>
                            <DropdownMenuItem
                              className="text-destructive focus:text-destructive"
                              onClick={() => handleDelete(rule.id, rule.name)}
                            >
                              <Trash2 className="h-4 w-4 mr-2" />
                              Delete
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </div>
                    </div>
                    {rule.condition && (
                      <code className="text-xs bg-muted px-2 py-1 rounded font-mono block truncate" title={rule.condition}>
                        {rule.condition}
                      </code>
                    )}
                    <div className="flex items-center gap-2 flex-wrap">
                      <Badge className={`text-xs ${outcome.className}`}>
                        {outcome.label}
                      </Badge>
                      <Badge variant="outline" className="capitalize text-xs">
                        {CHANNEL_LABELS[rule.type] ?? rule.type}
                      </Badge>
                      {(rule.tags || []).slice(0, 2).map((tag, i) => (
                        <Badge key={i} variant="secondary" className="text-xs">
                          {tag}
                        </Badge>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Desktop: table */}
            <Table className="hidden md:table">
              <TableHeader>
                <TableRow>
                  <TableHead>
                    <button onClick={() => toggleSort('name')} className="flex items-center group/sort hover:text-foreground transition-colors">
                      Name <SortIcon col="name" />
                    </button>
                  </TableHead>
                  <TableHead>Channel</TableHead>
                  <TableHead>
                    <button onClick={() => toggleSort('condition')} className="flex items-center group/sort hover:text-foreground transition-colors">
                      Condition <SortIcon col="condition" />
                    </button>
                  </TableHead>
                  <TableHead>Outcome</TableHead>
                  <TableHead>
                    <button onClick={() => toggleSort('tags')} className="flex items-center group/sort hover:text-foreground transition-colors">
                      Tags <SortIcon col="tags" />
                    </button>
                  </TableHead>
                  <TableHead>Active</TableHead>
                  <TableHead className="w-10" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {sorted.map((rule) => {
                  const outcome = OUTCOME_CONFIG[rule.outcome] || { label: rule.outcome, className: '' };
                  return (
                    <TableRow key={rule.id} className="group">
                      <TableCell className="font-medium">
                        <div className="flex items-center gap-2">
                          <ChannelTypeIcon type={rule.type} size={16} />
                          {rule.name}
                        </div>
                      </TableCell>

                      <TableCell>
                        <Badge variant="outline" className="capitalize text-xs">
                          {CHANNEL_LABELS[rule.type] ?? rule.type}
                        </Badge>
                      </TableCell>

                      <TableCell className="max-w-[220px]">
                        <code className="text-xs bg-muted px-2 py-1 rounded font-mono block truncate" title={rule.condition}>
                          {rule.condition}
                        </code>
                      </TableCell>

                      <TableCell>
                        <div className="flex items-center gap-2">
                          <Badge className={`text-xs ${outcome.className}`}>
                            {outcome.label}
                          </Badge>
                          {rule.outcome === 'redirect' && rule.redirect_to && (
                            <span className="flex items-center gap-1 text-xs text-muted-foreground">
                              <ArrowRight className="h-3 w-3" />
                              <span className="truncate max-w-[80px]">{rule.redirect_to}</span>
                            </span>
                          )}
                        </div>
                      </TableCell>

                      <TableCell>
                        <div className="flex flex-wrap gap-1">
                          {(rule.tags || []).slice(0, 2).map((tag, i) => (
                            <Badge key={i} variant="secondary" className="text-xs">
                              {tag}
                            </Badge>
                          ))}
                          {(rule.tags || []).length > 2 && (
                            <Badge variant="secondary" className="text-xs">
                              +{rule.tags.length - 2}
                            </Badge>
                          )}
                        </div>
                      </TableCell>

                      <TableCell>
                        <Switch
                          checked={rule.active}
                          onCheckedChange={(checked) => handleToggleActive(rule.id, checked)}
                        />
                      </TableCell>

                      <TableCell>
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button
                              variant="ghost"
                              size="sm"
                              className="h-7 w-7 p-0 opacity-0 group-hover:opacity-100 transition-opacity"
                            >
                              <MoreHorizontal className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem onClick={() => navigate(`/rules/${rule.id}/edit`)}>
                              <Edit className="h-4 w-4 mr-2" />
                              Edit
                            </DropdownMenuItem>
                            <DropdownMenuItem
                              className="text-destructive focus:text-destructive"
                              onClick={() => handleDelete(rule.id, rule.name)}
                            >
                              <Trash2 className="h-4 w-4 mr-2" />
                              Delete
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
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

      {hasActiveFilters && sorted.length > 0 && (
        <p className="text-xs text-muted-foreground">
          Showing {sorted.length} of {rules.length} rules
        </p>
      )}

      {ConfirmDialog}
    </div>
  );
}
