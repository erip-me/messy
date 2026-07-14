import React, { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Save, Plus, Minus, Maximize, Trash2, Zap, Clock, Filter, Pause, Play, Flag, Users, Mail, Eye } from 'lucide-react';
import { ChannelTypeIcon } from '@/components/channel-icons';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { SearchableSelect } from '@/components/ui/searchable-select';
import { Switch } from '@/components/ui/switch';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { transformMarkdown } from '@/utils/markdown-transformer';
import { PreviewFrame, PlaintextPreview } from '@/components/template-preview';
import { ConditionGroupBlock, serialiseGroup, hydrateGroup, uid } from '@/components/condition-builder';
import { ConditionGroup, Attribute, getAttributes, getSegments, Segment } from '@/api/segments';
import { listTemplates, Template } from '@/api/templates';
import { listFolders, Folder as FolderType } from '@/api/folders';
import { TemplateTreePicker } from '@/components/template-tree-picker';
import { getSendingIdentities, SendingIdentity } from '@/api/sending-identities';
import {
  getDrip, updateDrip, activateDrip, pauseDrip, projectDrip, DripStep, DripProjection,
} from '@/api/drips';

interface StepDraft {
  localId: string;
  id?: number;          // persisted drip_step id (absent until saved)
  templateId: number | null;
  channel: string;
  delayDays: number;
  conditions: ConditionGroup;
  onFail: 'skip' | 'exit';
  sentCount: number;    // messages actually sent for this step
}

const CHANNELS: { value: string; label: string }[] = [
  { value: 'email', label: 'Email' },
  { value: 'sms', label: 'SMS' },
  { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'push', label: 'Push' },
];

function emptyGroup(): ConditionGroup {
  return { id: uid(), operator: 'and', conditions: [] };
}

function newStep(): StepDraft {
  return { localId: uid(), templateId: null, channel: 'email', delayDays: 0, conditions: emptyGroup(), onFail: 'skip', sentCount: 0 };
}

function fromApiStep(s: DripStep): StepDraft {
  return {
    localId: uid(),
    id: s.id,
    templateId: s.template_id,
    channel: s.channel || 'email',
    delayDays: s.delay_days || 0,
    conditions: hydrateGroup(s.conditions || {}),
    onFail: s.on_fail || 'skip',
    sentCount: s.sent_count || 0,
  };
}

// Client-side template preview (mirrors the templates editor / campaign wizard).
function TemplatePreview({ template }: { template: Template | null }) {
  if (!template || !template.body) {
    return <div className="p-6 text-muted-foreground text-sm text-center">Select a template to preview it</div>;
  }
  try {
    let preview = template.body.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (_, name) => name);
    if (template.body_format === 'markdown') preview = transformMarkdown(preview, {});
    if (template.channel !== 'email') {
      return <PlaintextPreview text={preview} />;
    }
    return <PreviewFrame html={preview} minHeight={320} title="Template Preview" />;
  } catch {
    return <div className="p-4 text-destructive text-sm">Preview error</div>;
  }
}

export function DripDesignerPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { confirm, ConfirmDialog } = useConfirm();

  const [name, setName] = useState('');
  const [segmentId, setSegmentId] = useState<number | null>(null);
  const [allowReentry, setAllowReentry] = useState(false);
  const [exitOnLeave, setExitOnLeave] = useState(true);
  const [enrollExisting, setEnrollExisting] = useState(true);
  const [status, setStatus] = useState<string>('draft');
  const [steps, setSteps] = useState<StepDraft[]>([]);
  const [selected, setSelected] = useState<number | null>(null);
  const [zoom, setZoom] = useState(1);

  const [attributes, setAttributes] = useState<Attribute[]>([]);
  const [templates, setTemplates] = useState<Template[]>([]);
  const [folders, setFolders] = useState<FolderType[]>([]);
  const [segments, setSegments] = useState<Segment[]>([]);
  const [identities, setIdentities] = useState<SendingIdentity[]>([]);
  const [sendingIdentityId, setSendingIdentityId] = useState<number | null>(null);
  const [projection, setProjection] = useState<DripProjection | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const projectionTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    getAttributes().then(setAttributes).catch(() => {});
    listTemplates({ scope: 'account' }).then(setTemplates).catch(() => {});
    listFolders().then(setFolders).catch(() => {});
    getSegments().then(setSegments).catch(() => {});
    getSendingIdentities().then(setIdentities).catch(() => {});
  }, []);

  useEffect(() => {
    if (!id) return;
    getDrip(Number(id))
      .then(d => {
        setName(d.name);
        setSegmentId(d.segment_id);
        setAllowReentry(d.allow_reentry);
        setExitOnLeave(d.exit_on_segment_leave);
        setEnrollExisting(d.enroll_existing_on_start);
        setSendingIdentityId(d.sending_identity_id);
        setStatus(d.status);
        setSteps(d.steps.map(fromApiStep));
      })
      .catch(() => toast.error('Failed to load drip'))
      .finally(() => setLoading(false));
  }, [id]);

  const templateById = useMemo(() => {
    const map = new Map<number, Template>();
    templates.forEach(t => map.set(t.id, t));
    return map;
  }, [templates]);

  const stepsPayload = useCallback(() => steps.map((s, i) => ({
    position: i,
    template_id: s.templateId,
    channel: s.channel,
    delay_days: s.delayDays,
    conditions: serialiseGroup(s.conditions),
    on_fail: s.onFail,
  })), [steps]);

  // Debounced projection refresh whenever the segment or sequence changes.
  useEffect(() => {
    if (!segmentId) { setProjection(null); return; }
    if (projectionTimer.current) clearTimeout(projectionTimer.current);
    projectionTimer.current = setTimeout(() => {
      projectDrip({ segment_id: segmentId, steps: stepsPayload() }).then(setProjection).catch(() => {});
    }, 500);
    return () => { if (projectionTimer.current) clearTimeout(projectionTimer.current); };
  }, [segmentId, stepsPayload]);

  const updateStep = (idx: number, patch: Partial<StepDraft>) =>
    setSteps(s => s.map((st, i) => (i === idx ? { ...st, ...patch } : st)));

  const addStep = (channel = 'email', at = steps.length) => {
    setSteps(s => { const copy = [...s]; copy.splice(at, 0, { ...newStep(), channel }); return copy; });
    setSelected(at);
  };
  const removeStep = (idx: number) => { setSteps(s => s.filter((_, i) => i !== idx)); setSelected(null); };
  const moveStep = (from: number, to: number) => {
    setSteps(s => {
      const copy = [...s];
      const [moved] = copy.splice(from, 1);
      copy.splice(to > from ? to - 1 : to, 0, moved);
      return copy;
    });
    setSelected(null);
  };

  // --- drag & drop (palette → canvas to add; reorder steps) ---
  const dragRef = useRef<{ type: 'palette'; channel: string } | { type: 'step'; index: number } | null>(null);
  const [dropIndex, setDropIndex] = useState<number | null>(null);
  const [dragging, setDragging] = useState(false);
  const [dragStepIndex, setDragStepIndex] = useState<number | null>(null); // index of the step being reordered (null when dragging from palette)

  const startPaletteDrag = (channel: string) => (e: React.DragEvent) => {
    dragRef.current = { type: 'palette', channel };
    setDragging(true);
    setDragStepIndex(null);
    e.dataTransfer.effectAllowed = 'copyMove';
    e.dataTransfer.setData('text/plain', `palette:${channel}`); // required for drop to fire in some browsers
  };
  const startStepDrag = (index: number) => (e: React.DragEvent) => {
    dragRef.current = { type: 'step', index };
    setDragging(true);
    setDragStepIndex(index);
    e.dataTransfer.effectAllowed = 'copyMove';
    e.dataTransfer.setData('text/plain', `step:${index}`);
  };

  // A drop at `zi` is a no-op when reordering the step that already sits there
  // (the slots immediately before and after the dragged step).
  const isNoopZone = (zi: number) => dragStepIndex !== null && (zi === dragStepIndex || zi === dragStepIndex + 1);
  const allowDrop = (index: number) => (e: React.DragEvent) => {
    if (!dragRef.current) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = dragRef.current.type === 'palette' ? 'copy' : 'move';
    setDropIndex(index);
  };
  const handleDrop = (index: number) => (e: React.DragEvent) => {
    e.preventDefault();
    const d = dragRef.current;
    dragRef.current = null;
    setDropIndex(null);
    setDragging(false);
    setDragStepIndex(null);
    if (!d) return;
    if (d.type === 'palette') addStep(d.channel, index);
    else moveStep(d.index, index);
  };
  const endDrag = () => { dragRef.current = null; setDropIndex(null); setDragging(false); setDragStepIndex(null); };

  // A visible drop slot, shown only while dragging, at insertion `index`.
  const dropZone = (index: number) => (
    <div
      onDragOver={allowDrop(index)}
      onDragLeave={() => setDropIndex(d => (d === index ? null : d))}
      onDrop={handleDrop(index)}
      className={`my-1.5 h-12 rounded-lg border-2 border-dashed flex items-center justify-center text-xs font-medium transition-colors ${dropIndex === index ? "border-primary bg-primary/10 text-primary" : "border-muted-foreground/30 text-muted-foreground/70"}`}
    >
      Drop here
    </div>
  );

  // A neutral spacer shown where dropping would be a no-op (the dragged step's own slots).
  const neutralGap = () => <div className="flex justify-center py-2"><div className="h-6 w-px bg-border/60" /></div>;

  const save = async (): Promise<boolean> => {
    if (!name.trim()) { toast.error('Please enter a drip name'); return false; }
    if (!segmentId) { toast.error('Please choose a trigger segment'); return false; }
    if (steps.some(s => !s.templateId)) { toast.error('Every step needs a template'); return false; }
    setSaving(true);
    try {
      await updateDrip(Number(id), {
        name: name.trim(), segment_id: segmentId,
        allow_reentry: allowReentry, exit_on_segment_leave: exitOnLeave,
        enroll_existing_on_start: enrollExisting,
        sending_identity_id: sendingIdentityId,
        steps: stepsPayload(),
      });
      return true;
    } catch (e: any) {
      toast.error(e.response?.data?.errors?.[0] || 'Failed to save drip');
      return false;
    } finally {
      setSaving(false);
    }
  };

  const handleSave = async () => { if (await save()) toast.success('Drip saved'); };

  const handleStart = async () => {
    if (steps.length === 0) { toast.error('Add at least one step first'); return; }
    const total = projection?.segment_total ?? 0;
    const description = enrollExisting
      ? `${total.toLocaleString()} customer${total === 1 ? '' : 's'} currently in the segment will be enrolled, plus anyone who enters later. Start now?`
      : 'Only customers who enter the segment from now on will be enrolled. Current members are left alone. Start now?';
    const ok = await confirm({ title: 'Start drip', description, confirmLabel: 'Start drip' });
    if (!ok) return;
    if (!(await save())) return;
    try {
      await activateDrip(Number(id));
      setStatus('active');
      toast.success('Drip started');
    } catch (e: any) {
      // activate returns { error } for compliance failures (e.g. missing unsubscribe link)
      toast.error(e.response?.data?.error || e.response?.data?.errors?.[0] || 'Failed to start');
    }
  };

  const handleStop = async () => {
    try { await pauseDrip(Number(id)); setStatus('paused'); toast.success('Drip paused'); }
    catch { toast.error('Failed to pause'); }
  };

  const projForStep = (i: number) => projection?.steps.find(s => s.position === i);

  if (loading) {
    return <div className="p-6 space-y-4"><Skeleton className="h-10 w-48" /><Skeleton className="h-64 w-full" /></div>;
  }

  const selectedStep = selected !== null ? steps[selected] : null;
  const selectedTemplate = selectedStep?.templateId ? templateById.get(selectedStep.templateId) ?? null : null;
  const channelTemplates = selectedStep ? templates.filter(t => t.channel === selectedStep.channel) : [];
  const segmentName = segments.find(s => String(s.id) === String(segmentId))?.name;
  const statusPill = status === 'active'
    ? <span className="inline-flex items-center rounded-full bg-green-100 text-green-700 text-[11px] font-medium px-2 py-0.5">Live</span>
    : status === 'paused'
      ? <span className="inline-flex items-center rounded-full bg-yellow-100 text-yellow-700 text-[11px] font-medium px-2 py-0.5">Paused</span>
      : <span className="inline-flex items-center rounded-full bg-muted text-muted-foreground text-[11px] font-medium px-2 py-0.5">Draft</span>;
  let runningDay = 0;

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div className="flex items-center gap-4 min-w-0">
          <Button variant="ghost" size="sm" onClick={() => navigate('/drips')}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div className="min-w-0">
            <h1 className="page-heading flex items-center gap-2 truncate">
              <Zap className="h-5 w-5 shrink-0" />
              <span className="truncate">{name || 'Untitled drip'}</span>
              {status !== 'draft' && <Badge variant="outline" className="capitalize shrink-0">{status}</Badge>}
            </h1>
            <p className="page-subtitle">Design the sequence, then start the drip</p>
          </div>
        </div>
        <div className="flex items-center gap-2 shrink-0 flex-wrap">
          <Button variant="ghost" onClick={() => navigate(`/messages?drip_id=${id}`)}>
            <Mail className="h-4 w-4 mr-2" />View messages
          </Button>
          <Button variant="outline" onClick={handleSave} disabled={saving}>
            <Save className="h-4 w-4 mr-2" />{saving ? 'Saving…' : 'Save'}
          </Button>
          {status === 'active' ? (
            <Button variant="outline" onClick={handleStop}><Pause className="h-4 w-4 mr-2" />Stop</Button>
          ) : (
            <Button onClick={handleStart} disabled={saving}><Play className="h-4 w-4 mr-2" />Start drip</Button>
          )}
        </div>
      </div>

      <div className="flex gap-4 h-[calc(100vh-11rem)]">
        {/* Actions palette */}
        <aside className="w-52 shrink-0 rounded-xl border bg-card overflow-y-auto">
          <div className="p-4 space-y-5">
            <h3 className="text-sm font-semibold">Actions</h3>
            <div className="space-y-0.5">
              <p className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground mb-1">Messages</p>
              {CHANNELS.map(c => (
                <button
                  key={c.value}
                  draggable
                  onDragStart={startPaletteDrag(c.value)}
                  onDragEnd={endDrag}
                  onClick={() => addStep(c.value)}
                  className="w-full flex items-center gap-2.5 px-2 py-2 rounded-md hover:bg-muted text-sm text-left cursor-grab active:cursor-grabbing"
                >
                  <ChannelTypeIcon type={c.value} size={16} />{c.label}
                </button>
              ))}
            </div>
            <div className="space-y-0.5">
              <p className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground mb-1">Logic</p>
              <div className="flex items-center gap-2.5 px-2 py-2 text-sm text-muted-foreground"><Clock className="h-4 w-4" />Time delay<span className="ml-auto text-[10px]">per step</span></div>
              <div className="flex items-center gap-2.5 px-2 py-2 text-sm text-muted-foreground"><Filter className="h-4 w-4" />Condition<span className="ml-auto text-[10px]">per step</span></div>
            </div>
          </div>
        </aside>

        {/* Canvas */}
        <div className="relative flex-1 rounded-xl border bg-muted/20 overflow-auto bg-[radial-gradient(theme(colors.border)_1px,transparent_1px)] [background-size:16px_16px]">
          <div data-testid="drip-canvas" className="py-10 flex justify-center min-h-full" style={{ transform: `scale(${zoom})`, transformOrigin: "top center" }} onClick={() => setSelected(null)}>
            <div className="w-[320px]">
              {/* Trigger */}
              <div className="rounded-xl border bg-card shadow-sm px-4 py-3 flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-foreground text-background flex items-center justify-center shrink-0"><Zap className="h-4 w-4" /></div>
                <div className="min-w-0">
                  <p className="text-sm font-semibold">Trigger</p>
                  <p className="text-xs text-muted-foreground truncate">When customer enters {segmentName || "a segment"}</p>
                </div>
              </div>
              {projection && (
                <p className="text-center text-xs text-muted-foreground mt-1">
                  <button
                    type="button"
                    onClick={(e) => { e.stopPropagation(); if (segmentId) navigate(`/segments/${segmentId}/edit`); }}
                    disabled={!segmentId}
                    className="inline-flex items-center gap-1 hover:text-foreground hover:underline disabled:no-underline disabled:cursor-default"
                    title={segmentId ? "View segment" : undefined}
                  >
                    <Users className="h-3 w-3" />{projection.segment_total.toLocaleString()} in segment
                  </button>
                </p>
              )}

              {steps.map((step, idx) => {
                const template = step.templateId ? templateById.get(step.templateId) : null;
                const isSel = selected === idx;
                const conds = step.conditions.conditions.length;
                const proj = projForStep(idx);
                runningDay += step.delayDays;
                return (
                  <div key={step.localId}>
                    {/* connector with insert — becomes a drop zone while dragging */}
                    {dragging ? (isNoopZone(idx) ? neutralGap() : dropZone(idx)) : (
                      <div className="flex flex-col items-center">
                        <div className="h-4 w-px bg-border" />
                        <button onClick={(e) => { e.stopPropagation(); addStep("email", idx); }} title="Insert a step here" className="w-6 h-6 rounded-full border bg-card flex items-center justify-center shadow-sm text-muted-foreground hover:text-primary hover:border-primary transition-colors">
                          <Plus className="h-3.5 w-3.5" />
                        </button>
                        <div className="h-4 w-px bg-border" />
                      </div>
                    )}

                    {/* Wait node */}
                    {step.delayDays > 0 && (
                      <div className="flex flex-col items-center">
                        <button onClick={(e) => { e.stopPropagation(); setSelected(idx); }} className="flex items-center gap-2 rounded-full border bg-card shadow-sm px-3 py-1.5 text-xs hover:border-primary">
                          <Clock className="h-3.5 w-3.5 text-muted-foreground" />Wait {step.delayDays} day{step.delayDays === 1 ? "" : "s"}
                        </button>
                        <div className="h-4 w-px bg-border" />
                      </div>
                    )}

                    {/* Message card (draggable to reorder) */}
                    <button
                      draggable
                      onDragStart={startStepDrag(idx)}
                      onDragEnd={endDrag}
                      onClick={(e) => { e.stopPropagation(); setSelected(idx); }}
                      className={`group w-full rounded-xl border bg-card shadow-sm text-left transition-colors cursor-grab active:cursor-grabbing ${isSel ? "border-primary ring-1 ring-primary" : "hover:border-muted-foreground/40"} ${dragStepIndex === idx ? "opacity-40" : ""}`}
                    >
                      <div className="flex items-center gap-2 px-3 pt-3">
                        <div className="w-7 h-7 rounded-md bg-muted flex items-center justify-center shrink-0"><ChannelTypeIcon type={step.channel} size={15} /></div>
                        <span className="text-sm font-medium flex-1 truncate">{template?.name || `Choose a ${step.channel} template…`}</span>
                        <span role="button" tabIndex={0} className="h-6 w-6 inline-flex items-center justify-center rounded text-muted-foreground opacity-0 group-hover:opacity-100 hover:text-destructive" onClick={e => { e.stopPropagation(); removeStep(idx); }}>
                          <Trash2 className="h-3.5 w-3.5" />
                        </span>
                      </div>
                      {template?.subject && <p className="px-3 pt-1 text-xs text-muted-foreground truncate">{template.subject}</p>}
                      <div className="px-3 py-2 mt-2 flex items-center justify-between border-t">
                        {statusPill}
                        <span className="flex items-center gap-1 text-[11px] text-muted-foreground">
                          {step.sentCount > 0 ? `${step.sentCount.toLocaleString()} sent` : proj ? `≈ ${proj.hitting.toLocaleString()}` : ""}
                          {conds > 0 && <Filter className="h-3 w-3" />}
                        </span>
                      </div>
                    </button>
                    <p className="text-[11px] text-muted-foreground mt-1 ml-1">Day {runningDay}</p>
                  </div>
                );
              })}

              {/* trailing insert — becomes the final drop zone while dragging */}
              {dragging ? (isNoopZone(steps.length) ? neutralGap() : dropZone(steps.length)) : (
                <div className="flex flex-col items-center">
                  <div className="h-4 w-px bg-border" />
                  <button onClick={(e) => { e.stopPropagation(); addStep("email", steps.length); }} className="w-6 h-6 rounded-full border bg-card flex items-center justify-center shadow-sm text-muted-foreground hover:text-primary hover:border-primary transition-colors">
                    <Plus className="h-3.5 w-3.5" />
                  </button>
                  <div className="h-4 w-px bg-border" />
                </div>
              )}
              <div className="rounded-xl border border-dashed bg-card/60 px-4 py-3 flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center shrink-0"><Flag className="h-4 w-4 text-muted-foreground" /></div>
                <p className="text-sm text-muted-foreground">End of drip</p>
              </div>
            </div>
          </div>

          {/* Zoom controls */}
          <div className="absolute bottom-4 right-4 flex flex-col items-center rounded-lg border bg-card shadow-sm overflow-hidden">
            <Button variant="ghost" size="icon" className="h-8 w-8 rounded-none" onClick={() => setZoom(z => Math.min(1.5, +(z + 0.1).toFixed(2)))} title="Zoom in"><Plus className="h-4 w-4" /></Button>
            <span className="text-[11px] px-1 text-muted-foreground">{Math.round(zoom * 100)}%</span>
            <Button variant="ghost" size="icon" className="h-8 w-8 rounded-none" onClick={() => setZoom(z => Math.max(0.5, +(z - 0.1).toFixed(2)))} title="Zoom out"><Minus className="h-4 w-4" /></Button>
            <Button variant="ghost" size="icon" className="h-8 w-8 rounded-none border-t" onClick={() => setZoom(1)} title="Reset zoom"><Maximize className="h-4 w-4" /></Button>
          </div>
        </div>

        {/* Inspector */}
        <div className="w-[380px] shrink-0 overflow-y-auto space-y-4">
          {selectedStep ? (
            <Card>
                <CardHeader className="pb-2">
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-sm">Step {selected! + 1}</CardTitle>
                    <button className="text-xs text-muted-foreground hover:text-foreground" onClick={() => setSelected(null)}>Done</button>
                  </div>
                </CardHeader>
                <CardContent>
                  <Tabs defaultValue="edit" key={selectedStep.localId}>
                    <TabsList className="mb-4">
                      <TabsTrigger value="edit">Edit</TabsTrigger>
                      <TabsTrigger value="preview">Preview</TabsTrigger>
                    </TabsList>
                    <TabsContent value="edit" className="space-y-4 mt-0">
                  <div className="space-y-1.5">
                    <Label>Channel</Label>
                    <Select
                      value={selectedStep.channel}
                      onValueChange={v => updateStep(selected!, { channel: v, templateId: null })}
                    >
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        {CHANNELS.map(c => (
                          <SelectItem key={c.value} value={c.value}>
                            <span className="flex items-center gap-2"><ChannelTypeIcon type={c.value} size={14} />{c.label}</span>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  <div className="space-y-1.5">
                    <Label>Template</Label>
                    {channelTemplates.length === 0 ? (
                      <div className="rounded-lg border border-dashed p-4 text-center">
                        <p className="text-sm text-muted-foreground mb-3">No {selectedStep.channel} templates yet.</p>
                        <Button variant="outline" size="sm" onClick={() => navigate('/templates/new')}>
                          <Plus className="h-4 w-4 mr-2" />Create a template
                        </Button>
                      </div>
                    ) : (
                      <div className="flex items-center gap-2">
                        <div className="flex-1 min-w-0">
                          <TemplateTreePicker
                            templates={templates}
                            folders={folders}
                            channel={selectedStep.channel}
                            value={selectedStep.templateId ? String(selectedStep.templateId) : ""}
                            onChange={id => updateStep(selected!, { templateId: Number(id) })}
                            placeholder={`Choose a ${selectedStep.channel} template…`}
                          />
                        </div>
                        <Button variant="ghost" size="icon" className="shrink-0" disabled={!selectedStep.templateId}
                          onClick={() => selectedStep.templateId && window.open(`/templates/${selectedStep.templateId}/edit`, '_blank')}
                          title="Preview template">
                          <Eye className="h-4 w-4" />
                        </Button>
                      </div>
                    )}
                  </div>
                  <div className="space-y-1.5">
                    <Label>Send after (days)</Label>
                    <Input type="number" min={0} value={selectedStep.delayDays}
                      onChange={e => updateStep(selected!, { delayDays: Math.max(0, Number(e.target.value) || 0) })} />
                    <p className="text-xs text-muted-foreground">Counted from the previous message actually sent.</p>
                  </div>
                  <div className="space-y-1.5">
                    <Label>Only send if…</Label>
                    {attributes.length === 0 ? (
                      <p className="text-xs text-muted-foreground">Loading attributes…</p>
                    ) : (
                      <ConditionGroupBlock group={selectedStep.conditions} attributes={attributes}
                        onChange={g => updateStep(selected!, { conditions: g })} depth={0} />
                    )}
                  </div>
                  <div className="space-y-1.5">
                    <Label>If the condition is not met</Label>
                    <Select value={selectedStep.onFail} onValueChange={v => updateStep(selected!, { onFail: v as 'skip' | 'exit' })}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="skip">Skip this step (continue)</SelectItem>
                        <SelectItem value="exit">Exit the drip</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  {selectedStep.id && (
                    <button
                      className="text-sm text-primary hover:underline flex items-center gap-1"
                      onClick={() => navigate(`/messages?drip_id=${id}&drip_step_id=${selectedStep.id}`)}
                    >
                      <Mail className="h-3.5 w-3.5" />
                      View {selectedStep.sentCount.toLocaleString()} message{selectedStep.sentCount === 1 ? '' : 's'} from this step
                    </button>
                  )}
                    </TabsContent>
                    <TabsContent value="preview" className="mt-0">
                      <div className="border rounded-md bg-card min-h-[200px] overflow-hidden">
                        <TemplatePreview template={selectedTemplate} />
                      </div>
                    </TabsContent>
                  </Tabs>
                </CardContent>
              </Card>
          ) : (
            <>
              <Card>
                <CardHeader className="pb-2"><CardTitle className="text-sm">Settings</CardTitle></CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-1.5">
                    <Label htmlFor="drip-name">Name</Label>
                    <Input id="drip-name" value={name} onChange={e => setName(e.target.value)} />
                  </div>
                  <div className="space-y-1.5">
                    <Label>Trigger Segment</Label>
                    <div className="flex items-center gap-2">
                      <div className="flex-1 min-w-0">
                        <SearchableSelect
                          value={segmentId ? String(segmentId) : undefined}
                          onValueChange={v => setSegmentId(Number(v))}
                          options={segments.map(s => ({ value: String(s.id), label: s.name }))}
                          placeholder="Choose a segment…"
                          searchPlaceholder="Search segments…"
                        />
                      </div>
                      <Button variant="ghost" size="icon" className="shrink-0" disabled={!segmentId}
                        onClick={() => segmentId && window.open(`/segments/${segmentId}/edit`, '_blank')}
                        title="Preview segment">
                        <Eye className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                  <div className="space-y-1.5">
                    <Label>Send as</Label>
                    <Select value={sendingIdentityId ? String(sendingIdentityId) : 'default'} onValueChange={v => setSendingIdentityId(v === 'default' ? null : Number(v))}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="default">Default (channel from address)</SelectItem>
                        {identities.map(i => (
                          <SelectItem key={i.id} value={String(i.id)}>{i.from_name ? `${i.from_name} <${i.from_email}>` : i.from_email}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-1.5">
                    <Label>Apply to</Label>
                    <Select value={enrollExisting ? 'existing' : 'new_only'} onValueChange={v => setEnrollExisting(v === 'existing')}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="existing">Everyone in the segment (now + future)</SelectItem>
                        <SelectItem value="new_only">Only people who enter from now on</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex items-center justify-between">
                    <Label className="text-sm">Exit when leaving segment</Label>
                    <Switch checked={exitOnLeave} onCheckedChange={setExitOnLeave} />
                  </div>
                  <div className="flex items-center justify-between">
                    <Label className="text-sm">Allow re-entry</Label>
                    <Switch checked={allowReentry} onCheckedChange={setAllowReentry} />
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-2"><CardTitle className="text-sm flex items-center gap-2"><Users className="h-4 w-4" />Projected reach</CardTitle></CardHeader>
                <CardContent>
                  {projection ? (
                    <>
                      <div className="text-center mb-3">
                        <p className="text-3xl font-bold">{projection.segment_total.toLocaleString()}</p>
                        <p className="text-xs text-muted-foreground">in segment now</p>
                      </div>
                      {projection.steps.length > 0 && (
                        <div className="space-y-1.5">
                          {projection.steps.map(s => (
                            <div key={s.position} className="flex items-center justify-between text-sm">
                              <span className="text-muted-foreground">Step {s.position + 1}</span>
                              <span className="font-medium">
                                {s.hitting.toLocaleString()} receive
                                {s.skipped > 0 ? <span className="text-muted-foreground font-normal"> · {s.skipped.toLocaleString()} skip</span> : null}
                                {s.suppressed > 0 ? <span className="text-muted-foreground font-normal"> · {s.suppressed.toLocaleString()} unsub</span> : null}
                              </span>
                            </div>
                          ))}
                        </div>
                      )}
                      <p className="text-xs text-muted-foreground mt-3">
                        {enrollExisting
                          ? 'Estimated from current segment members and their attributes.'
                          : 'For reference: only future entrants will be enrolled, so actual reach builds up over time.'}
                      </p>
                    </>
                  ) : (
                    <p className="text-sm text-muted-foreground text-center py-4">Choose a segment to see projected reach.</p>
                  )}
                </CardContent>
              </Card>
            </>
          )}
        </div>
      </div>

      {ConfirmDialog}
    </div>
  );
}
