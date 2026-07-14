import React, { useState, useEffect } from 'react';
import { ArrowLeft, Search, Folder, ChevronRight, FileText } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { CampaignChannel } from '@/api/campaigns';
import { Template } from '@/api/templates';
import { Folder as FolderType } from '@/api/folders';
import { ChannelTypeIcon } from '@/components/channel-icons';
import { transformMarkdown } from '@/utils/markdown-transformer';
import { PreviewFrame, PlaintextPreview } from '@/components/template-preview';

export function CampaignPreview({
  content,
  template,
  channel,
}: {
  content: string;
  template: Template | null;
  channel: CampaignChannel | null;
}) {
  const body = template?.body || content;
  if (!body) {
    return <div className="p-4 text-muted-foreground">No content to preview</div>;
  }

  try {
    let preview = body;

    // Replace Liquid variables with placeholder names
    preview = preview.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (_, name) => name);

    if (template?.body_format === 'markdown') {
      preview = transformMarkdown(preview, {});
    }

    // Plaintext channels
    if (channel !== 'email') {
      return <PlaintextPreview text={preview} />;
    }

    return <PreviewFrame html={preview} minHeight={400} title="Campaign Preview" />;
  } catch {
    return <div className="p-4 text-destructive text-sm">Preview error</div>;
  }
}

// --- Template Picker Dialog ---
export function TemplatePicker({
  open,
  onOpenChange,
  templates,
  folders,
  channel,
  onSelect,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  templates: Template[];
  folders: FolderType[];
  channel: CampaignChannel;
  onSelect: (template: Template) => void;
}) {
  const [searchQuery, setSearchQuery] = useState('');
  const [currentFolderId, setCurrentFolderId] = useState<number | null>(null);
  const [folderPath, setFolderPath] = useState<{ id: number | null; name: string }[]>([
    { id: null, name: 'All Templates' },
  ]);

  // Reset state when dialog opens
  useEffect(() => {
    if (open) {
      setSearchQuery('');
      setCurrentFolderId(null);
      setFolderPath([{ id: null, name: 'All Templates' }]);
    }
  }, [open]);

  const channelTemplates = templates.filter(t => t.channel === channel);

  const displayFolders = folders.filter(f => f.parent_folder_id === currentFolderId);

  const displayTemplates = channelTemplates.filter(t => {
    const inFolder = currentFolderId ? t.folder_id === currentFolderId : !t.folder_id;
    if (searchQuery) {
      return (
        t.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        t.trigger?.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }
    return inFolder;
  });

  const handleFolderClick = (folder: FolderType) => {
    setCurrentFolderId(folder.id);
    setFolderPath(prev => [...prev, { id: folder.id, name: folder.name }]);
    setSearchQuery('');
  };

  const handleBreadcrumbClick = (folderId: number | null) => {
    setCurrentFolderId(folderId);
    if (folderId === null) {
      setFolderPath([{ id: null, name: 'All Templates' }]);
    } else {
      const index = folderPath.findIndex(item => item.id === folderId);
      if (index >= 0) setFolderPath(folderPath.slice(0, index + 1));
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl h-[70vh] flex flex-col">
        <DialogHeader>
          <DialogTitle>Select a template</DialogTitle>
        </DialogHeader>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search templates..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            className="pl-10"
            autoFocus
          />
        </div>

        {/* Breadcrumb */}
        {!searchQuery && folderPath.length > 1 && (
          <div className="flex items-center gap-1 text-sm">
            {folderPath.map((item, index) => (
              <React.Fragment key={item.id ?? 'root'}>
                {index > 0 && <ChevronRight className="h-3.5 w-3.5 text-muted-foreground" />}
                {index === folderPath.length - 1 ? (
                  <span className="font-medium">{item.name}</span>
                ) : (
                  <button
                    type="button"
                    onClick={() => handleBreadcrumbClick(item.id)}
                    className="text-muted-foreground hover:text-foreground transition-colors"
                  >
                    {item.name}
                  </button>
                )}
              </React.Fragment>
            ))}
          </div>
        )}

        {/* Content */}
        <div className="flex-1 overflow-y-auto space-y-1 min-h-0">
          {/* Back to parent */}
          {!searchQuery && currentFolderId && (
            <button
              type="button"
              onClick={() => {
                const parentIndex = folderPath.length - 2;
                const parent = folderPath[parentIndex];
                handleBreadcrumbClick(parent?.id ?? null);
              }}
              className="flex items-center p-3 rounded-lg w-full text-left text-muted-foreground hover:bg-muted/50 transition-colors"
            >
              <Folder className="h-5 w-5 text-amber-500 fill-amber-100 mr-3 shrink-0" />
              <ArrowLeft className="h-4 w-4 mr-2 shrink-0" />
              <span className="text-sm">
                Back to <span className="text-foreground font-medium">{folderPath[folderPath.length - 2]?.name}</span>
              </span>
            </button>
          )}

          {/* Folders */}
          {!searchQuery && displayFolders.map(folder => (
            <button
              key={`folder-${folder.id}`}
              type="button"
              onClick={() => handleFolderClick(folder)}
              className="flex items-center p-3 rounded-lg w-full text-left hover:bg-accent transition-colors group"
            >
              <Folder className="h-5 w-5 text-amber-500 fill-amber-100 mr-3 shrink-0" />
              <span className="text-sm font-medium flex-1">{folder.name}</span>
              <ChevronRight className="h-4 w-4 text-muted-foreground opacity-0 group-hover:opacity-100 transition-opacity" />
            </button>
          ))}

          {/* Templates */}
          {displayTemplates.map(template => (
            <button
              key={`template-${template.id}`}
              type="button"
              onClick={() => {
                onSelect(template);
                onOpenChange(false);
              }}
              className="flex items-center p-3 rounded-lg w-full text-left hover:bg-muted/50 transition-colors group"
            >
              <span className="mr-3 shrink-0">
                <ChannelTypeIcon type={template.channel || 'email'} size={20} />
              </span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{template.name}</p>
                {template.subject && (
                  <p className="text-xs text-muted-foreground truncate">{template.subject}</p>
                )}
              </div>
              <span className="text-xs text-muted-foreground font-mono shrink-0 ml-2">
                {template.trigger}
              </span>
            </button>
          ))}

          {/* Empty */}
          {displayTemplates.length === 0 && displayFolders.length === 0 && (
            <div className="text-center py-12 text-muted-foreground">
              <FileText className="h-8 w-8 mx-auto mb-2 opacity-40" />
              <p className="text-sm">
                {searchQuery
                  ? 'No templates match your search'
                  : `No ${channel} templates in this folder`}
              </p>
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
