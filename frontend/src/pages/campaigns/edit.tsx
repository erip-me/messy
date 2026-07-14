import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Save, Send } from 'lucide-react';
import Editor from '@monaco-editor/react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent } from '@/components/ui/card';
import { SearchableSelect } from '@/components/ui/searchable-select';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Skeleton } from '@/components/ui/skeleton';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { getCampaign, createCampaign, updateCampaign, sendCampaign } from '@/api/campaigns';
import { getSegments, Segment } from '@/api/segments';

export function CampaignEditPage() {
  const { id } = useParams<{ id: string }>();
  const isEdit = !!id;
  const navigate = useNavigate();

  const [loading, setLoading] = useState(isEdit);
  const [saving, setSaving] = useState(false);
  const [sending, setSending] = useState(false);
  const [segments, setSegments] = useState<Segment[]>([]);

  const { confirm, ConfirmDialog } = useConfirm();
  const [name, setName] = useState('');
  const [subject, setSubject] = useState('');
  const [segmentId, setSegmentId] = useState<string>('');
  const [content, setContent] = useState('<h1>Hello {{first_name}}!</h1>\n<p>Your email content here.</p>');

  useEffect(() => {
    getSegments().then(setSegments).catch(() => {});
    if (!isEdit) { setLoading(false); return; }
    getCampaign(Number(id))
      .then(c => {
        setName(c.name); setSubject(c.subject);
        setContent(c.content || '');
        setSegmentId(c.segment_id ? String(c.segment_id) : '');
      })
      .catch(() => toast.error('Failed to load campaign'))
      .finally(() => setLoading(false));
  }, [id, isEdit]);

  const payload = () => ({
    name, subject,
    content, segment_id: segmentId ? Number(segmentId) : null
  });

  const handleSave = async () => {
    if (!name.trim() || !subject.trim()) {
      toast.error('Name and subject are required'); return;
    }
    setSaving(true);
    try {
      if (isEdit) {
        await updateCampaign(Number(id), payload());
        toast.success('Campaign saved');
      } else {
        await createCampaign(payload());
        toast.success('Campaign created');
        navigate('/campaigns');
      }
    } catch (e: any) {
      toast.error(e.response?.data?.errors?.[0] || 'Failed to save');
    } finally { setSaving(false); }
  };

  const handleSend = async () => {
    if (!name.trim()) { toast.error('Campaign name is required'); return; }
    if (!subject.trim()) { toast.error('Subject line is required'); return; }
    if (!segmentId) { toast.error('Please select a segment before sending'); return; }
    if (!content.trim()) { toast.error('Campaign content is required'); return; }
    const confirmed = await confirm({
      title: 'Send Campaign',
      description: 'Send this campaign to the selected segment? This cannot be undone.',
      confirmLabel: 'Send',
      variant: 'destructive',
    });
    if (!confirmed) return;
    setSending(true);
    try {
      // Save first, then send
      await updateCampaign(Number(id), payload());
      await sendCampaign(Number(id));
      toast.success('Campaign is now sending!');
      navigate(`/campaigns/${id}`);
    } catch (e: any) {
      toast.error(e.response?.data?.error || 'Failed to send');
    } finally { setSending(false); }
  };

  if (loading) return (
    <div className="p-6 space-y-4">
      <Skeleton className="h-10 w-64" />
      <Skeleton className="h-96 w-full" />
    </div>
  );

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="flex flex-wrap items-center gap-4 mb-6">
        <Button variant="ghost" size="sm" onClick={() => navigate('/campaigns')}>
          <ArrowLeft className="h-4 w-4 mr-2" />Campaigns
        </Button>
        <h1 className="text-xl font-semibold flex-1">{isEdit ? 'Edit Campaign' : 'New Campaign'}</h1>
        <div className="flex gap-2 flex-wrap">
          <Button variant="outline" onClick={handleSave} disabled={saving}>
            <Save className="h-4 w-4 mr-2" />
            {saving ? 'Saving…' : 'Save Draft'}
          </Button>
          {isEdit && (
            <Button onClick={handleSend} disabled={sending || !segmentId}>
              <Send className="h-4 w-4 mr-2" />
              {sending ? 'Sending…' : 'Send Campaign'}
            </Button>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left: settings */}
        <div className="space-y-4">
          <Card>
            <CardContent className="p-4 space-y-4">
              <div className="space-y-1.5">
                <Label>Campaign Name</Label>
                <Input placeholder="e.g. March Newsletter" value={name} onChange={e => setName(e.target.value)} />
              </div>
              <div className="space-y-1.5">
                <Label>Subject Line</Label>
                <Input placeholder="Your email subject…" value={subject} onChange={e => setSubject(e.target.value)} />
              </div>
              <div className="space-y-1.5">
                <Label>Target Segment</Label>
                <SearchableSelect
                  options={segments.map(s => ({ value: String(s.id), label: `${s.name} (${s.customer_count.toLocaleString()})` }))}
                  value={segmentId}
                  onValueChange={setSegmentId}
                  placeholder="Select a segment…"
                  searchPlaceholder="Search segments…"
                  emptyText="No segments found"
                />
                {!segmentId && (
                  <p className="text-xs text-muted-foreground">Select a segment to enable sending</p>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Tips */}
          <Card>
            <CardContent className="p-4">
              <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide mb-2">Template Variables</p>
              <div className="space-y-1 text-xs text-muted-foreground">
                <p><code className="bg-muted px-1 rounded">{'{{first_name}}'}</code>: Customer first name</p>
                <p><code className="bg-muted px-1 rounded">{'{{last_name}}'}</code>: Customer last name</p>
                <p><code className="bg-muted px-1 rounded">{'{{email}}'}</code>: Customer email</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Right: editor */}
        <div className="lg:col-span-2">
          <Tabs defaultValue="editor">
            <TabsList className="mb-3">
              <TabsTrigger value="editor">HTML Editor</TabsTrigger>
              <TabsTrigger value="preview">Preview</TabsTrigger>
            </TabsList>
            <TabsContent value="editor">
              <div className="rounded-lg border overflow-hidden">
                <Editor
                  height="500px"
                  language="html"
                  value={content}
                  onChange={v => setContent(v || '')}
                  theme="vs-dark"
                  options={{
                    minimap: { enabled: false },
                    fontSize: 13,
                    wordWrap: 'on',
                    lineNumbers: 'on',
                    scrollBeyondLastLine: false,
                  }}
                />
              </div>
            </TabsContent>
            <TabsContent value="preview">
              <div className="rounded-lg border overflow-hidden bg-card h-[500px]">
                <iframe
                  srcDoc={content || '<p style="padding:20px;color:#888;">No content yet</p>'}
                  className="w-full h-full border-0"
                  title="Email Preview"
                  sandbox="allow-same-origin"
                />
              </div>
            </TabsContent>
          </Tabs>
        </div>
      </div>

      {ConfirmDialog}
    </div>
  );
}
