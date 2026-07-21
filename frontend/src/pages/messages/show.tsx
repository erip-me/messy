import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Mail, Clock, CheckCircle, XCircle, AlertCircle, ShieldX, BellOff, Copy, RotateCw, User, Paperclip, FileText, FileImage, FileArchive, FileSpreadsheet, File } from 'lucide-react';
import { ChannelTypeIcon } from '@/components/channel-icons';
import { format } from 'date-fns';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { getMessageById, retryMessage, getWhatsAppTemplates, Message, ChildMessage, MessageDelivery } from '@/api/messages';
import { copyToClipboard } from '@/utils/clipboard';
import toast from 'react-hot-toast';
import { parseRecipients } from '@/utils/recipients';


const STATUS_ICONS: Record<string, typeof Clock> = {
  pending: Clock,
  sent: Mail,
  delivered: CheckCircle,
  failed: XCircle,
  bounced: AlertCircle,
  rejected: ShieldX,
  suppressed: BellOff,
  expired: Clock,
};

import { statusClass } from '@/lib/status-colors';
import { UNSUB_REASON_LABELS } from '@/lib/labels';

function getUnsubInfo(customer: Message['customer'], channel?: string) {
  if (!customer?.unsubscribed_channels || !channel) return null;
  const value = customer.unsubscribed_channels[channel];
  if (!value) return null;
  if (typeof value === 'string') return { at: value, reason: null };
  return { at: value.at, reason: value.reason };
}

export function MessageShowPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [apiKey] = useState(''); // TODO: Get from environment selector
  
  const [message, setMessage] = useState<Message | null>(null);
  const [loading, setLoading] = useState(true);
  const [retrying, setRetrying] = useState(false);
  const [waPreview, setWaPreview] = useState<string | null>(null);

  useEffect(() => {
    if (id) {
      loadMessage();
    }
  }, [id]);

  // For WA template messages without a stored merged body (sent via API before
  // compose started persisting it), merge the current template text client-side.
  useEffect(() => {
    setWaPreview(null);
    if (!message || message.channel !== 'whatsapp' || !message.subject) return;
    if (message.body && !message.body.startsWith('[WhatsApp Template:')) return;
    getWhatsAppTemplates()
      .then((templates) => {
        const tpl =
          templates.find((t) => t.name === message.subject && t.language === message.language) ||
          templates.find((t) => t.name === message.subject);
        const text = tpl?.components.find((c) => c.type === 'BODY')?.text;
        if (!text) return;
        const tags: any[] = message.tags || [];
        const params: string[] =
          typeof tags[0] === 'string'
            ? tags
            : (tags.find((t) => t.type?.toLowerCase() === 'body')?.parameters || []).map(
                (p: any) => p.text ?? ''
              );
        setWaPreview(text.replace(/\{\{(\d+)\}\}/g, (m, n) => params[Number(n) - 1] || m));
      })
      .catch(() => {});
  }, [message]);

  const loadMessage = async () => {
    try {
      setLoading(true);
      const messageData = await getMessageById(parseInt(id!), apiKey);
      setMessage(messageData);
    } catch (error) {
      toast.error('Failed to load message details');
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleCopy = (text: string) => {
    copyToClipboard(text)
      .then(() => toast.success('Copied to clipboard'))
      .catch(() => toast.error('Copy failed'));
  };

  const handleRetry = async () => {
    if (!message) return;
    try {
      setRetrying(true);
      const updated = await retryMessage(message.id, apiKey);
      setMessage(updated);
      toast.success('Message queued for retry');
    } catch (error) {
      toast.error('Failed to retry message');
      console.error(error);
    } finally {
      setRetrying(false);
    }
  };

  const _StatusIcon = ({ status }: { status: string }) => {
    const Icon = STATUS_ICONS[status] || Clock;
    return <Icon className="h-4 w-4" />;
  };

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const getFileIcon = (contentType: string) => {
    if (contentType.startsWith('image/')) return { icon: FileImage, color: 'text-violet-500' };
    if (contentType === 'application/pdf') return { icon: FileText, color: 'text-red-500' };
    if (contentType.includes('zip') || contentType.includes('archive') || contentType.includes('tar') || contentType.includes('gzip'))
      return { icon: FileArchive, color: 'text-amber-500' };
    if (contentType.includes('spreadsheet') || contentType.includes('csv') || contentType.includes('excel'))
      return { icon: FileSpreadsheet, color: 'text-green-600' };
    return { icon: File, color: 'text-blue-500' };
  };

  const latestDelivery = (deliveries?: MessageDelivery[]) =>
    deliveries?.length ? deliveries[deliveries.length - 1] : undefined;

  const getDeliveryStatus = (child: ChildMessage) => {
    if (child.status === 'sent') return 'sent';
    if (child.status === 'pending') return 'pending';
    // Check latest delivery for errors
    const delivery = latestDelivery(child.deliveries);
    if (delivery?.error) return 'failed';
    if (delivery?.completed_at) return 'delivered';
    return child.status || 'pending';
  };

  const renderRecipientDeliveries = () => {
    const children = message?.child_messages;
    const deliveries = message?.deliveries;

    // If we have child messages, show per-recipient breakdown
    if (children && children.length > 0) {
      return (
        <div className="space-y-3">
          {children.map((child) => {
            const status = getDeliveryStatus(child);
            const delivery = latestDelivery(child.deliveries);
            const recipient = parseRecipients(child.to)[0];
            return (
              <div key={child.id} className="p-3 border rounded-lg">
                <div className="flex items-center justify-between mb-1">
                  <div className="truncate mr-2">
                    <span className="text-sm font-medium">
                      {recipient?.displayName || recipient?.email || child.to}
                    </span>
                    {recipient?.displayName && (
                      <p className="text-xs text-muted-foreground font-mono">{recipient.email}</p>
                    )}
                  </div>
                  <Badge variant="outline" className={`border-0 shrink-0 ${statusClass(status)}`}>
                    {status}
                  </Badge>
                </div>

                {delivery?.error && (
                  <div className="mt-2 p-2 bg-red-50 border border-red-200 rounded">
                    <p className="text-xs text-red-800">{delivery.error}</p>
                  </div>
                )}

                <div className="mt-2 text-xs text-muted-foreground">
                  {child.sent_at
                    ? `Sent ${format(new Date(child.sent_at), 'MMM d, h:mm a')}`
                    : delivery?.completed_at
                    ? `Completed ${format(new Date(delivery.completed_at), 'MMM d, h:mm a')}`
                    : delivery?.started_at
                    ? `Started ${format(new Date(delivery.started_at), 'MMM d, h:mm a')}`
                    : `Queued ${format(new Date(child.created_at), 'MMM d, h:mm a')}`}
                </div>
              </div>
            );
          })}
        </div>
      );
    }

    // Fallback: show deliveries directly on the parent message
    if (deliveries && deliveries.length > 0) {
      return (
        <div className="space-y-3">
          {deliveries.map((delivery) => {
            const status = delivery.status || (delivery.error ? 'failed' : delivery.completed_at ? 'sent' : 'pending');
            const recipients = parseRecipients(delivery.recipient || message.to);
            return (
              <div key={delivery.id} className="p-3 border rounded-lg">
                {recipients.map((r, i) => (
                  <div key={i} className={`flex items-center justify-between ${i > 0 ? 'mt-2 pt-2 border-t' : ''}`}>
                    <div className="truncate mr-2">
                      <span className="text-sm font-medium">
                        {r.displayName || r.email}
                      </span>
                      {r.displayName && (
                        <p className="text-xs text-muted-foreground font-mono">{r.email}</p>
                      )}
                    </div>
                    {i === 0 && (
                      <Badge variant="outline" className={`border-0 shrink-0 ${statusClass(status)}`}>
                        {status}
                      </Badge>
                    )}
                  </div>
                ))}

                {delivery.error && (
                  <div className="mt-2 p-2 bg-red-50 border border-red-200 rounded">
                    <p className="text-xs text-red-800">{delivery.error}</p>
                  </div>
                )}

                <div className="mt-2 text-xs text-muted-foreground">
                  {delivery.completed_at
                    ? `Completed ${format(new Date(delivery.completed_at), 'MMM d, h:mm a')}`
                    : delivery.started_at
                    ? `Started ${format(new Date(delivery.started_at), 'MMM d, h:mm a')}`
                    : `Created ${format(new Date(delivery.created_at), 'MMM d, h:mm a')}`}
                </div>
              </div>
            );
          })}
        </div>
      );
    }

    return (
      <div className="text-center py-8 text-muted-foreground">
        No delivery information available
      </div>
    );
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="flex items-center gap-4 mb-6">
          <Skeleton className="h-10 w-10" />
          <div>
            <Skeleton className="h-8 w-64" />
            <Skeleton className="h-4 w-32 mt-2" />
          </div>
        </div>
        
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-6">
            <Skeleton className="h-96" />
          </div>
          <div className="space-y-6">
            <Skeleton className="h-64" />
            <Skeleton className="h-32" />
          </div>
        </div>
      </div>
    );
  }

  if (!message) {
    return (
      <div className="p-6">
        <div className="text-center py-12">
          <Mail className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
          <h3 className="text-lg font-medium mb-2">Message not found</h3>
          <p className="text-muted-foreground mb-4">
            The message you're looking for doesn't exist or has been deleted.
          </p>
          <Button onClick={() => navigate('/messages')}>
            Back to Messages
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex items-center gap-4 mb-6">
        <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
          <ArrowLeft className="h-4 w-4" />
        </Button>
        
        <div>
          <h1 className="page-heading">Message Details</h1>
          <p className="page-subtitle">
            {message.subject || message.to || 'Message'} #{message.id}
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main Content */}
        <div className="lg:col-span-2">
          <Card className="card-shadow bg-card">
            <CardHeader>
              <CardTitle className="text-foreground">Message Content</CardTitle>
            </CardHeader>
            <CardContent>
              <Tabs defaultValue="content">
                <TabsList>
                  <TabsTrigger value="content">Rendered Content</TabsTrigger>
                  <TabsTrigger value="source">Source</TabsTrigger>
                  <TabsTrigger value="metadata">Metadata</TabsTrigger>
                </TabsList>
                
                <TabsContent value="content" className="mt-6">
                  {/* WhatsApp template view */}
                  {message.channel === 'whatsapp' && message.subject ? (
                    <div className="space-y-4">
                      <div>
                        <label className="text-sm font-medium text-muted-foreground">Template</label>
                        <div className="mt-1 p-3 bg-muted/50 rounded-md flex items-center gap-3">
                          <span className="font-mono font-medium">{message.subject}</span>
                          {message.language && (
                            <Badge variant="outline" className="text-xs">{message.language}</Badge>
                          )}
                        </div>
                      </div>

                      {(() => {
                        const preview =
                          message.body && !message.body.startsWith('[WhatsApp Template:')
                            ? message.body
                            : waPreview;
                        if (!preview) return null;
                        return (
                          <div>
                            <label className="text-sm font-medium text-muted-foreground">Message Preview</label>
                            <div className="mt-1 rounded-md bg-muted/50 p-4">
                              <div className="flex justify-end">
                                <div className="max-w-[75%] rounded-[16px_16px_4px_16px] bg-status-green px-3.5 py-2.5 text-sm leading-relaxed">
                                  <p className="whitespace-pre-wrap">{preview}</p>
                                </div>
                              </div>
                            </div>
                          </div>
                        );
                      })()}

                      {message.tags && message.tags.length > 0 && (
                        <div>
                          <label className="text-sm font-medium text-muted-foreground">Parameters</label>
                          <div className="mt-1 space-y-1.5">
                            {message.tags.map((tag: any, i: number) => {
                              if (typeof tag === 'string') {
                                return (
                                  <div key={i} className="flex items-center gap-3 rounded-md border bg-muted/30 px-3 py-2">
                                    <span className="text-xs font-semibold text-muted-foreground font-mono">{`{{${i + 1}}}`}</span>
                                    <span className="text-sm font-mono">{tag}</span>
                                  </div>
                                );
                              }
                              const params = tag.parameters || [];
                              return (
                                <div key={i} className="rounded-md border bg-muted/30 px-3 py-2">
                                  <span className="text-xs font-semibold text-muted-foreground uppercase">{tag.type}{tag.sub_type ? ` · ${tag.sub_type}` : ''}</span>
                                  {params.map((p: any, j: number) => (
                                    <span key={j} className="text-sm font-mono ml-3">{p.text || JSON.stringify(p)}</span>
                                  ))}
                                </div>
                              );
                            })}
                          </div>
                        </div>
                      )}
                    </div>
                  ) : (
                    <>
                      {message.subject && (
                        <div className="mb-4">
                          <label className="text-sm font-medium text-muted-foreground">Subject</label>
                          <div className="mt-1 p-3 bg-muted/50 rounded-md">
                            <p className="font-medium">{message.subject}</p>
                          </div>
                        </div>
                      )}

                      <div>
                        <label className="text-sm font-medium text-muted-foreground">Message Body</label>
                        <div className="mt-1 border rounded-md overflow-hidden">
                          <iframe
                            srcDoc={message.body}
                            className="w-full border-0 bg-card min-h-[500px]"
                            sandbox="allow-same-origin"
                            onLoad={(e) => {
                              const iframe = e.target as HTMLIFrameElement;
                              if (iframe.contentDocument?.body) {
                                iframe.style.height = iframe.contentDocument.body.scrollHeight + 32 + 'px';
                              }
                            }}
                          />
                        </div>
                      </div>

                      {message.attachments && message.attachments.length > 0 && (
                        <div className="mt-6">
                          <label className="text-sm font-medium text-muted-foreground flex items-center gap-1.5">
                            <Paperclip className="h-3.5 w-3.5" />
                            Attachments ({message.attachments.length})
                          </label>
                          <div className="mt-2 flex flex-wrap gap-2">
                            {message.attachments.map((attachment) => {
                              const { icon: Icon, color } = getFileIcon(attachment.content_type);
                              return (
                                <a
                                  key={attachment.id}
                                  href={`${attachment.url}?download=1`}
                                  download={attachment.filename}
                                  className="flex items-center gap-2.5 p-2.5 border rounded-lg hover:bg-muted/50 transition-colors cursor-pointer"
                                >
                                  <Icon className={`h-5 w-5 shrink-0 ${color}`} />
                                  <div className="min-w-0">
                                    <p className="text-sm font-medium">{attachment.filename}</p>
                                    <p className="text-xs text-muted-foreground">{formatFileSize(attachment.byte_size)}</p>
                                  </div>
                                </a>
                              );
                            })}
                          </div>
                        </div>
                      )}
                    </>
                  )}
                </TabsContent>
                
                <TabsContent value="source" className="mt-6">
                  <div className="space-y-4">
                    {message.subject && (
                      <div>
                        <div className="flex items-center justify-between mb-2">
                          <label className="text-sm font-medium">Subject</label>
                          <Button 
                            variant="ghost" 
                            size="sm" 
                            onClick={() => handleCopy(message.subject!)}
                          >
                            <Copy className="h-4 w-4" />
                          </Button>
                        </div>
                        <pre className="p-3 bg-muted/50 rounded-md text-sm overflow-x-auto">
                          {message.subject}
                        </pre>
                      </div>
                    )}
                    
                    <div>
                      <div className="flex items-center justify-between mb-2">
                        <label className="text-sm font-medium">Body</label>
                        <Button 
                          variant="ghost" 
                          size="sm" 
                          onClick={() => handleCopy(message.body)}
                        >
                          <Copy className="h-4 w-4" />
                        </Button>
                      </div>
                      <pre className="p-3 bg-muted/50 rounded-md text-sm overflow-x-auto whitespace-pre-wrap">
                        {message.body}
                      </pre>
                    </div>
                  </div>
                </TabsContent>
                
                <TabsContent value="metadata" className="mt-6">
                  <div className="space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="text-sm font-medium text-muted-foreground">Message ID</label>
                        <p className="mt-1">{message.id}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-muted-foreground">Channel</label>
                        <p className="mt-1">{message.channel}</p>
                      </div>
                    </div>
                    
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="text-sm font-medium text-muted-foreground">Environment</label>
                        <p className="mt-1">{message.environment}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-muted-foreground">Status</label>
                        <p className="mt-1">{message.status}</p>
                      </div>
                    </div>
                    
                    {/* WhatsApp template info */}
                    {message.channel === 'whatsapp' && message.subject && (
                      <>
                        <Separator />
                        <div>
                          <label className="text-sm font-medium text-muted-foreground">WhatsApp Template</label>
                          <p className="mt-1 font-mono text-sm">{message.subject}</p>
                        </div>
                        {message.language && (
                          <div>
                            <label className="text-sm font-medium text-muted-foreground">Language</label>
                            <p className="mt-1">{message.language}</p>
                          </div>
                        )}
                        {message.tags && message.tags.length > 0 && (
                          <div>
                            <label className="text-sm font-medium text-muted-foreground">Template Parameters</label>
                            <div className="mt-1 space-y-1.5">
                              {message.tags.map((tag: any, i: number) => {
                                if (typeof tag === 'string') {
                                  return (
                                    <div key={i} className="flex items-center gap-2 rounded border bg-muted/30 px-3 py-1.5">
                                      <span className="text-xs font-semibold text-muted-foreground">{`{{${i + 1}}}`}</span>
                                      <span className="text-sm font-mono">{tag}</span>
                                    </div>
                                  );
                                }
                                // Complex component object
                                const params = tag.parameters || [];
                                return (
                                  <div key={i} className="rounded border bg-muted/30 px-3 py-1.5">
                                    <span className="text-xs font-semibold text-muted-foreground uppercase">{tag.type}{tag.sub_type ? ` (${tag.sub_type})` : ''}</span>
                                    {params.map((p: any, j: number) => (
                                      <span key={j} className="text-sm font-mono ml-2">{p.text || JSON.stringify(p)}</span>
                                    ))}
                                  </div>
                                );
                              })}
                            </div>
                          </div>
                        )}
                      </>
                    )}

                    {/* Trigger info */}
                    {message.trigger && (
                      <>
                        <Separator />
                        <div>
                          <label className="text-sm font-medium text-muted-foreground">Trigger</label>
                          <p className="mt-1 font-mono text-sm">{message.trigger}</p>
                          {message.template_name && (
                            <p className="mt-0.5 text-xs text-muted-foreground">{message.template_name}</p>
                          )}
                        </div>
                        {message.tags && message.tags.length > 0 && (() => {
                          const triggerData = message.tags.find((t: any) => typeof t === 'object' && t.trigger_data);
                          if (!triggerData) return null;
                          const data = triggerData.trigger_data;
                          return (
                            <div>
                              <label className="text-sm font-medium text-muted-foreground">Template Variables</label>
                              <div className="mt-1 space-y-1.5">
                                {Object.entries(data).map(([key, value]) => (
                                  <div key={key} className="flex items-center justify-between gap-4 rounded border bg-muted/30 px-3 py-1.5">
                                    <span className="text-xs font-semibold text-muted-foreground font-mono">{`{{ ${key} }}`}</span>
                                    <span className="text-sm font-mono text-right break-all">{String(value)}</span>
                                  </div>
                                ))}
                              </div>
                            </div>
                          );
                        })()}
                      </>
                    )}

                    {/* Drip info */}
                    {message.drip && (
                      <>
                        <Separator />
                        <div>
                          <label className="text-sm font-medium text-muted-foreground">Drip Campaign</label>
                          <p className="mt-1 text-sm">{message.drip.name}</p>
                          {message.drip.step_position !== null && (
                            <p className="mt-0.5 text-xs text-muted-foreground">Step {message.drip.step_position + 1}</p>
                          )}
                        </div>
                      </>
                    )}

                    <Separator />

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="text-sm font-medium text-muted-foreground">Created</label>
                        <p className="mt-1 font-mono text-sm">{format(new Date(message.created_at), 'PPpp')}</p>
                      </div>
                      <div>
                        <label className="text-sm font-medium text-muted-foreground">Updated</label>
                        <p className="mt-1 font-mono text-sm">{format(new Date(message.updated_at), 'PPpp')}</p>
                      </div>
                    </div>
                    
                    {message.sent_at && (
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="text-sm font-medium text-muted-foreground">Sent At</label>
                          <p className="mt-1 font-mono text-sm">{format(new Date(message.sent_at), 'PPpp')}</p>
                        </div>
                        {message.delivered_at && (
                          <div>
                            <label className="text-sm font-medium text-muted-foreground">Delivered At</label>
                            <p className="mt-1 font-mono text-sm">{format(new Date(message.delivered_at), 'PPpp')}</p>
                          </div>
                        )}
                      </div>
                    )}
                    
                    {message.failed_at && (
                      <div>
                        <label className="text-sm font-medium text-muted-foreground">Failed At</label>
                        <p className="mt-1">{format(new Date(message.failed_at), 'PPpp')}</p>
                        {message.failure_reason && (
                          <div className="mt-2">
                            <label className="text-sm font-medium text-muted-foreground">Failure Reason</label>
                            <p className="mt-1 text-red-600">{message.failure_reason}</p>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                </TabsContent>
              </Tabs>
            </CardContent>
          </Card>
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          {/* Status Card */}
          <Card className="card-shadow bg-card">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2">
                <ChannelTypeIcon type={message.channel} size={20} />
                Status
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex items-center justify-between">
                <span className={statusClass(message.status)}>
                  {(message.status || 'unknown').charAt(0).toUpperCase() + (message.status || 'unknown').slice(1)}
                </span>

                {(message.status === 'failed' || message.status === 'expired' || message.status === 'rejected' || message.status === 'suppressed') && (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={handleRetry}
                    disabled={retrying}
                  >
                    <RotateCw className={`h-3 w-3 mr-1 ${retrying ? 'animate-spin' : ''}`} />
                    {retrying ? 'Retrying...' : 'Retry'}
                  </Button>
                )}
              </div>

              <div className="mt-5 space-y-3 text-sm">
                {message.sending_identity && (
                  <div>
                    <span className="text-muted-foreground text-xs block mb-1">From</span>
                    <div className="text-xs">
                      {message.sending_identity.from_name ? (
                        <>
                          <span className="font-medium">{message.sending_identity.from_name}</span>
                          <span className="text-muted-foreground font-mono ml-1">&lt;{message.sending_identity.from_email}&gt;</span>
                        </>
                      ) : (
                        <span className="font-mono">{message.sending_identity.from_email}</span>
                      )}
                    </div>
                  </div>
                )}

                <div>
                  <span className="text-muted-foreground text-xs block mb-1">To</span>
                  <div className="space-y-1">
                    {parseRecipients(message.to).map((r, i) => (
                      <div key={i} className="text-xs">
                        {r.displayName ? (
                          <>
                            <span className="font-medium">{r.displayName}</span>
                            <span className="text-muted-foreground font-mono ml-1">&lt;{r.email}&gt;</span>
                          </>
                        ) : (
                          <span className="font-mono">{r.email}</span>
                        )}
                      </div>
                    ))}
                  </div>
                </div>

                {message.customer && (() => {
                  const channel = message.channel === 'push' ? 'push' : message.channel;
                  const unsubInfo = getUnsubInfo(message.customer, channel);
                  return (
                    <div>
                      <span className="text-muted-foreground text-xs block mb-1">Customer</span>
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => navigate(`/customers/${message.customer!.id}`)}
                          className="flex items-center gap-2 text-xs text-primary hover:underline"
                        >
                          <User className="h-3.5 w-3.5" />
                          {[message.customer.first_name, message.customer.last_name].filter(Boolean).join(' ') || message.customer.email}
                        </button>
                        {unsubInfo && (
                          <Badge className="bg-orange-100 text-orange-700 hover:bg-orange-100 text-[10px] py-0 px-1.5 gap-1">
                            <BellOff className="h-3 w-3" />
                            Unsub {channel}{unsubInfo.reason ? ` · ${UNSUB_REASON_LABELS[unsubInfo.reason] || unsubInfo.reason}` : ''}
                          </Badge>
                        )}
                      </div>
                    </div>
                  );
                })()}

                {message.cc && (
                  <div>
                    <span className="text-muted-foreground text-xs block mb-1">CC</span>
                    <div className="space-y-1">
                      {parseRecipients(message.cc).map((r, i) => (
                        <div key={i} className="text-xs">
                          {r.displayName ? (
                            <>
                              <span className="font-medium">{r.displayName}</span>
                              <span className="text-muted-foreground font-mono ml-1">&lt;{r.email}&gt;</span>
                            </>
                          ) : (
                            <span className="font-mono">{r.email}</span>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {message.bcc && (
                  <div>
                    <span className="text-muted-foreground text-xs block mb-1">BCC</span>
                    <div className="space-y-1">
                      {parseRecipients(message.bcc).map((r, i) => (
                        <div key={i} className="text-xs">
                          {r.displayName ? (
                            <>
                              <span className="font-medium">{r.displayName}</span>
                              <span className="text-muted-foreground font-mono ml-1">&lt;{r.email}&gt;</span>
                            </>
                          ) : (
                            <span className="font-mono">{r.email}</span>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
                
                <div className="flex justify-between items-center">
                  <span className="text-muted-foreground">Channel</span>
                  <Badge variant="outline" className="text-xs font-mono">
                    {message.channel?.toUpperCase() || 'Unknown'}
                  </Badge>
                </div>
                
                <div className="flex justify-between items-center">
                  <span className="text-muted-foreground">Environment</span>
                  <span className="text-xs">{message.environment || '-'}</span>
                </div>
                
                <div className="flex justify-between items-center">
                  <span className="text-muted-foreground">Created</span>
                  <span className="font-mono text-xs">{format(new Date(message.created_at), 'MMM d, yyyy h:mm a')}</span>
                </div>

                {message.sent_at && (
                  <div className="flex justify-between items-center">
                    <span className="text-muted-foreground">Sent</span>
                    <span className="font-mono text-xs">{format(new Date(message.sent_at), 'MMM d, yyyy h:mm a')}</span>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Per-Recipient Deliveries */}
          <Card className="card-shadow bg-card">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium text-muted-foreground">
                Recipients
                {message.child_messages && message.child_messages.length > 0 && (
                  <span className="text-muted-foreground font-normal ml-1">
                    ({message.child_messages.length})
                  </span>
                )}
              </CardTitle>
            </CardHeader>
            <CardContent>
              {renderRecipientDeliveries()}
            </CardContent>
          </Card>

          {/* Link clicks */}
          {message.link_clicks && message.link_clicks.length > 0 && (
            <Card className="card-shadow bg-card">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  Link clicks
                  <span className="text-muted-foreground font-normal ml-1">
                    ({message.click_count ?? 0})
                  </span>
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  {message.link_clicks.map((link) => (
                    <div key={link.url} className="flex items-center justify-between gap-2">
                      <a
                        href={link.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        title={link.url}
                        className="text-sm text-foreground truncate hover:underline"
                      >
                        {link.url}
                      </a>
                      <Badge variant="outline" className="shrink-0 text-xs font-mono">
                        {link.count}
                      </Badge>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}