import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Zap, Plus, ArrowRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { SearchableSelect } from '@/components/ui/searchable-select';
import { Switch } from '@/components/ui/switch';
import toast from 'react-hot-toast';
import { getSegments, Segment } from '@/api/segments';
import { createDrip } from '@/api/drips';

// Step 1 of creating a drip: name it, pick the trigger segment, set entry rules,
// then save and open the visual designer.
export function DripSetupPage() {
  const navigate = useNavigate();
  const [name, setName] = useState('');
  const [segmentId, setSegmentId] = useState<number | null>(null);
  const [exitOnLeave, setExitOnLeave] = useState(true);
  const [allowReentry, setAllowReentry] = useState(false);
  const [enrollExisting, setEnrollExisting] = useState(true);
  const [segments, setSegments] = useState<Segment[]>([]);
  const [segmentsLoaded, setSegmentsLoaded] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    getSegments().then(setSegments).catch(() => {}).finally(() => setSegmentsLoaded(true));
  }, []);

  const handleCreate = async () => {
    if (!name.trim()) { toast.error('Please enter a drip name'); return; }
    if (!segmentId) { toast.error('Please choose a trigger segment'); return; }
    setSaving(true);
    try {
      const drip = await createDrip({
        name: name.trim(),
        segment_id: segmentId,
        exit_on_segment_leave: exitOnLeave,
        allow_reentry: allowReentry,
        enroll_existing_on_start: enrollExisting,
        steps: [],
      });
      navigate(`/drips/${drip.id}/edit`, { replace: true });
    } catch (e: any) {
      toast.error(e.response?.data?.errors?.[0] || 'Failed to create drip');
      setSaving(false);
    }
  };

  return (
    <div className="p-6 max-w-2xl">
      <div className="flex items-center gap-4 mb-6">
        <Button variant="ghost" size="sm" onClick={() => navigate('/drips')}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        <div>
          <h1 className="page-heading flex items-center gap-2"><Zap className="h-5 w-5" />New Drip</h1>
          <p className="page-subtitle">Name your drip and choose what triggers it. Next you'll design the sequence.</p>
        </div>
      </div>

      <Card>
        <CardContent className="p-5 space-y-5">
          <div className="space-y-1.5">
            <Label htmlFor="drip-name">Drip Name</Label>
            <Input id="drip-name" placeholder="e.g. Seller onboarding" value={name} onChange={e => setName(e.target.value)} />
          </div>

          <div className="space-y-1.5">
            <Label>Trigger Segment</Label>
            {segmentsLoaded && segments.length === 0 ? (
              <div className="rounded-lg border border-dashed p-4 text-center">
                <p className="text-sm text-muted-foreground mb-3">No segments yet. Create one to use as this drip's trigger.</p>
                <Button variant="outline" size="sm" onClick={() => navigate('/segments/new')}>
                  <Plus className="h-4 w-4 mr-2" />Create a segment
                </Button>
              </div>
            ) : (
              <>
                <SearchableSelect
                  value={segmentId ? String(segmentId) : undefined}
                  onValueChange={v => setSegmentId(Number(v))}
                  options={segments.map(s => ({ value: String(s.id), label: s.name }))}
                  placeholder="Choose a segment…"
                  searchPlaceholder="Search segments…"
                />
                <p className="text-xs text-muted-foreground">Customers start this drip when they enter the segment.</p>
              </>
            )}
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
            <p className="text-xs text-muted-foreground">
              {enrollExisting
                ? 'When you start, current segment members are enrolled too.'
                : 'Existing members are left alone; only new entrants start the drip.'}
            </p>
          </div>

          <div className="flex items-center justify-between">
            <div>
              <Label className="text-sm">Exit when leaving segment</Label>
              <p className="text-xs text-muted-foreground">Stop the drip if the customer no longer matches.</p>
            </div>
            <Switch checked={exitOnLeave} onCheckedChange={setExitOnLeave} />
          </div>

          <div className="flex items-center justify-between">
            <div>
              <Label className="text-sm">Allow re-entry</Label>
              <p className="text-xs text-muted-foreground">Re-run the drip if they re-enter the segment later.</p>
            </div>
            <Switch checked={allowReentry} onCheckedChange={setAllowReentry} />
          </div>

          <div className="pt-2">
            <Button onClick={handleCreate} disabled={saving}>
              {saving ? 'Saving…' : <>Save & design sequence<ArrowRight className="h-4 w-4 ml-2" /></>}
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
