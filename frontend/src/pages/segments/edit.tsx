import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Users, ArrowLeft, Save, RefreshCw, ShieldCheck, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Progress } from '@/components/ui/progress';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { ConditionGroupBlock, serialiseGroup, hydrateGroup, uid } from '@/components/condition-builder';
import {
  getSegment, createSegment, updateSegment, previewSegment, getAttributes, cleanSegment,
  ConditionGroup, Attribute, PreviewResult, Segment
} from '@/api/segments';

// --- Main page ---
export function SegmentsEditPage() {
  const { id } = useParams<{ id: string }>();
  const isEdit = !!id;
  const navigate = useNavigate();

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [group, setGroup] = useState<ConditionGroup>({ id: uid(), operator: 'and', conditions: [] });
  const [attributes, setAttributes] = useState<Attribute[]>([]);
  const [preview, setPreview] = useState<PreviewResult | null>(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [cleaning, setCleaning] = useState(false);
  const [cleanupStatus, setCleanupStatus] = useState<string | null>(null);
  const [cleanupProgress, setCleanupProgress] = useState(0);
  const [cleanupTotal, setCleanupTotal] = useState(0);
  const [cleanupStats, setCleanupStats] = useState<Segment['cleanup_stats']>(null);
  const [loading, setLoading] = useState(isEdit);
  const previewTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const cleanupPollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const { confirm, ConfirmDialog } = useConfirm();

  const applyCleanupState = (seg: Segment) => {
    setCleanupStatus(seg.cleanup_status || null);
    setCleanupProgress(seg.cleanup_progress || 0);
    setCleanupTotal(seg.cleanup_total || 0);
    setCleanupStats(seg.cleanup_stats || null);
  };

  // Poll for cleanup progress
  useEffect(() => {
    if (cleanupStatus !== "in_progress" || !isEdit) return;
    cleanupPollRef.current = setInterval(() => {
      getSegment(Number(id)).then(seg => {
        applyCleanupState(seg);
        if (seg.cleanup_status !== "in_progress") {
          clearInterval(cleanupPollRef.current!);
          cleanupPollRef.current = null;
          if (seg.cleanup_status === "completed") toast.success("List cleanup complete!");
        }
      }).catch(() => {});
    }, 5000);
    return () => { if (cleanupPollRef.current) clearInterval(cleanupPollRef.current); };
  }, [cleanupStatus, id, isEdit]);

  // Load attributes on mount
  useEffect(() => {
    getAttributes().then(setAttributes).catch(() => {});
  }, []);

  // Load segment if editing
  useEffect(() => {
    if (!isEdit) return;
    getSegment(Number(id))
      .then(seg => {
        setName(seg.name);
        setDescription(seg.description || '');
        applyCleanupState(seg);
        // Hydrate with local IDs for React keys
        setGroup(hydrateGroup(seg.conditions));
      })
      .catch(() => toast.error('Failed to load segment'))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  // Debounced preview refresh whenever group changes
  const refreshPreview = useCallback(() => {
    if (previewTimerRef.current) clearTimeout(previewTimerRef.current);
    previewTimerRef.current = setTimeout(async () => {
      setPreviewLoading(true);
      try {
        const result = await previewSegment(serialiseGroup(group));
        setPreview(result);
      } catch {
        // silent — preview errors shouldn't interrupt the UX
      } finally {
        setPreviewLoading(false);
      }
    }, 600);
  }, [group]);

  useEffect(() => { refreshPreview(); }, [refreshPreview]);

  useEffect(() => () => {
    if (previewTimerRef.current) clearTimeout(previewTimerRef.current);
  }, []);

  const handleSave = async () => {
    if (!name.trim()) { toast.error('Please enter a segment name'); return; }
    setSaving(true);
    try {
      const payload = {
        name: name.trim(),
        description: description.trim() || undefined,
        conditions: serialiseGroup(group),
      };
      if (isEdit) {
        await updateSegment(Number(id), payload);
        toast.success('Segment updated');
      } else {
        await createSegment(payload);
        toast.success('Segment created');
        navigate('/segments');
      }
    } catch (e: any) {
      toast.error(e.response?.data?.errors?.[0] || 'Failed to save segment');
    } finally {
      setSaving(false);
    }
  };

  const handleClean = async () => {
    const confirmed = await confirm({
      title: 'Clean List',
      description: 'This will verify all email addresses in this segment and auto-unsubscribe invalid ones. You\'ll receive an email when it\'s done. Continue?',
      confirmLabel: 'Start Cleanup',
    });
    if (!confirmed) return;
    try {
      setCleaning(true);
      const result = await cleanSegment(Number(id));
      toast.success(result.message);
      setCleanupStatus("in_progress");
      setCleanupProgress(0);
    } catch (e: any) {
      toast.error(e.response?.data?.error || 'Failed to start list cleanup');
    } finally {
      setCleaning(false);
    }
  };

  if (loading) {
    return (
      <div className="p-6 space-y-4">
        <Skeleton className="h-10 w-48" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={() => navigate('/segments')}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div>
            <h1 className="page-heading">{isEdit ? 'Edit Segment' : 'New Segment'}</h1>
            <p className="page-subtitle">
              {isEdit ? 'Update your segment conditions' : 'Define conditions to target specific customers'}
            </p>
          </div>
        </div>
        <Button onClick={handleSave} disabled={saving}>
          <Save className="h-4 w-4 mr-2" />
          {saving ? 'Saving…' : isEdit ? 'Save Changes' : 'Create Segment'}
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Left: builder */}
        <div className="space-y-4">
          {/* Name + description */}
          <Card>
            <CardContent className="p-4 space-y-3">
              <div className="space-y-1.5">
                <Label htmlFor="seg-name">Segment Name</Label>
                <Input
                  id="seg-name"
                  placeholder="e.g. Pro plan customers"
                  value={name}
                  onChange={e => setName(e.target.value)}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="seg-desc">
                  Description <span className="text-muted-foreground text-xs">(optional)</span>
                </Label>
                <Input
                  id="seg-desc"
                  placeholder="What does this segment represent?"
                  value={description}
                  onChange={e => setDescription(e.target.value)}
                />
              </div>
            </CardContent>
          </Card>

          {/* Condition builder */}
          <div>
            <h2 className="text-sm font-semibold mb-2 text-muted-foreground uppercase tracking-wide">Conditions</h2>
            {attributes.length === 0 ? (
              <Card>
                <CardContent className="p-8 text-center text-muted-foreground text-sm">
                  Loading attributes…
                </CardContent>
              </Card>
            ) : (
              <ConditionGroupBlock
                group={group}
                attributes={attributes}
                onChange={setGroup}
                depth={0}
              />
            )}
          </div>
        </div>

        {/* Right: preview */}
        <div className="space-y-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center justify-between text-sm">
                <span className="flex items-center gap-2">
                  <Users className="h-4 w-4" />
                  Audience Preview
                </span>
                {previewLoading && <RefreshCw className="h-3.5 w-3.5 animate-spin text-muted-foreground" />}
              </CardTitle>
            </CardHeader>
            <CardContent>
              {preview === null ? (
                <div className="text-center py-4">
                  <Skeleton className="h-10 w-20 mx-auto mb-2" />
                  <Skeleton className="h-4 w-32 mx-auto" />
                </div>
              ) : (
                <>
                  <div className="text-center mb-4">
                    <p className="text-4xl font-bold">{preview.count.toLocaleString()}</p>
                    <p className="text-sm text-muted-foreground">matching customers</p>
                  </div>

                  {preview.sample.length > 0 && (
                    <>
                      <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide mb-2">Sample</p>
                      <div className="space-y-2">
                        {preview.sample.map(c => (
                          <button
                            key={c.id}
                            type="button"
                            onClick={() => navigate(`/customers/${c.id}`)}
                            className="flex items-center gap-2 text-sm w-full text-left rounded-md -mx-1 px-1 py-0.5 hover:bg-muted transition-colors"
                            title="View customer"
                          >
                            <div className="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                              <span className="text-xs font-bold text-primary">
                                {(c.first_name?.[0] || c.email[0]).toUpperCase()}
                              </span>
                            </div>
                            <div className="min-w-0">
                              {(c.first_name || c.last_name) && (
                                <p className="text-xs font-medium truncate">
                                  {[c.first_name, c.last_name].filter(Boolean).join(' ')}
                                </p>
                              )}
                              <p className="text-xs text-muted-foreground font-mono truncate">{c.email}</p>
                            </div>
                          </button>
                        ))}
                      </div>
                    </>
                  )}

                  {preview.count === 0 && (
                    <p className="text-sm text-muted-foreground text-center py-2">
                      No customers match these conditions yet.
                    </p>
                  )}
                </>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-4">
              <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide mb-2">Tips</p>
              <ul className="text-xs text-muted-foreground space-y-1">
                <li>• <strong>AND</strong>: all conditions must match</li>
                <li>• <strong>OR</strong>: any condition must match</li>
                <li>• Use <strong>Groups</strong> for complex logic</li>
                <li>• Preview updates automatically</li>
              </ul>
            </CardContent>
          </Card>

          {isEdit && (
            <Card>
              <CardContent className="p-4">
                <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide mb-2">List Hygiene</p>

                {cleanupStatus === "in_progress" ? (
                  <>
                    <div className="flex items-center gap-2 mb-2">
                      <Loader2 className="h-3 w-3 animate-spin text-muted-foreground" />
                      <p className="text-xs text-muted-foreground">
                        Verifying emails… {cleanupProgress} / {cleanupTotal}
                      </p>
                    </div>
                    <Progress value={cleanupTotal > 0 ? (cleanupProgress / cleanupTotal) * 100 : 0} className="h-2" />
                  </>
                ) : cleanupStatus === "completed" && cleanupStats ? (
                  <>
                    <div className="text-xs space-y-1 mb-3">
                      <div className="flex justify-between"><span className="text-muted-foreground">Verified</span><span className="font-medium">{cleanupStats.total}</span></div>
                      {cleanupStats.skipped > 0 && (
                        <div className="flex justify-between"><span className="text-muted-foreground">Skipped (recent)</span><span className="font-medium">{cleanupStats.skipped}</span></div>
                      )}
                      <div className="flex justify-between"><span className="text-green-600">High quality</span><span className="font-medium">{cleanupStats.high}</span></div>
                      <div className="flex justify-between"><span className="text-yellow-600">Medium quality</span><span className="font-medium">{cleanupStats.medium}</span></div>
                      <div className="flex justify-between"><span className="text-orange-600">Low quality</span><span className="font-medium">{cleanupStats.low}</span></div>
                      <div className="flex justify-between"><span className="text-red-600">Invalid</span><span className="font-medium">{cleanupStats.invalid}</span></div>
                      <div className="flex justify-between"><span className="text-red-600">Unsubscribed</span><span className="font-medium">{cleanupStats.unsubscribed}</span></div>
                    </div>
                    <Button
                      variant="outline"
                      size="sm"
                      className="w-full"
                      onClick={handleClean}
                      disabled={cleaning}
                    >
                      <ShieldCheck className="h-4 w-4 mr-2" />
                      {cleaning ? 'Starting…' : 'Re-run Cleanup'}
                    </Button>
                  </>
                ) : cleanupStatus === "failed" ? (
                  <>
                    <p className="text-xs text-red-600 mb-3">
                      Last cleanup was interrupted. You can re-run it.
                    </p>
                    <Button
                      variant="outline"
                      size="sm"
                      className="w-full"
                      onClick={handleClean}
                      disabled={cleaning}
                    >
                      <ShieldCheck className="h-4 w-4 mr-2" />
                      {cleaning ? 'Starting…' : 'Re-run Cleanup'}
                    </Button>
                  </>
                ) : (
                  <>
                    <p className="text-xs text-muted-foreground mb-3">
                      Verify email addresses and auto-remove invalid ones.
                    </p>
                    <Button
                      variant="outline"
                      size="sm"
                      className="w-full"
                      onClick={handleClean}
                      disabled={cleaning}
                    >
                      <ShieldCheck className="h-4 w-4 mr-2" />
                      {cleaning ? 'Starting…' : 'Clean List'}
                    </Button>
                  </>
                )}
              </CardContent>
            </Card>
          )}
        </div>
      </div>

      {ConfirmDialog}
    </div>
  );
}
