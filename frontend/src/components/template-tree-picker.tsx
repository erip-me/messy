import React, { useState } from "react";
import { ChevronsUpDown, Check, Folder } from "lucide-react";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Input } from "@/components/ui/input";
import { ChannelTypeIcon } from "@/components/channel-icons";
import { Template } from "@/api/templates";
import { Folder as FolderType } from "@/api/folders";

interface TemplateTreePickerProps {
  templates: Template[];
  folders: FolderType[];
  // The selected template id as a string; "" / "none" means nothing selected.
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  // When true, renders a "No template" option at the top (when not searching).
  allowNone?: boolean;
  // Optional channel filter — only show templates of this channel.
  channel?: string;
}

// Searchable template picker that renders templates as a folder tree mirroring
// the templates listing. Searching filters templates by name while keeping their
// ancestor folders visible so the path stays readable.
export function TemplateTreePicker({
  templates,
  folders,
  value,
  onChange,
  placeholder = "Select a template",
  allowNone = false,
  channel,
}: TemplateTreePickerProps) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");

  const scoped = channel ? templates.filter((t) => t.channel === channel) : templates;
  const selected = scoped.find((t) => String(t.id) === value) || null;
  const q = query.trim().toLowerCase();

  // Group folders by parent and templates by folder (null key = root level).
  const childFolders = new Map<number | null, FolderType[]>();
  folders.forEach((f) => {
    const key = f.parent_folder_id ?? null;
    (childFolders.get(key) ?? childFolders.set(key, []).get(key)!).push(f);
  });
  const folderTemplates = new Map<number | null, Template[]>();
  scoped.filter((t) => t.id).forEach((t) => {
    const key = t.folder_id ?? null;
    (folderTemplates.get(key) ?? folderTemplates.set(key, []).get(key)!).push(t);
  });

  const matches = (t: Template) => !q || t.name.toLowerCase().includes(q);

  // A folder is shown only if it (transitively) contains a matching template.
  const folderHasMatch = (folderId: number): boolean => {
    if ((folderTemplates.get(folderId) ?? []).some(matches)) return true;
    return (childFolders.get(folderId) ?? []).some((f) => folderHasMatch(f.id));
  };

  const byName = (a: { name: string }, b: { name: string }) => a.name.localeCompare(b.name);

  const renderRow = (t: Template, depth: number) => (
    <button
      key={t.id}
      type="button"
      onClick={() => { onChange(String(t.id)); setOpen(false); setQuery(""); }}
      style={{ paddingLeft: 12 + depth * 16 }}
      className={`w-full text-left pr-3 py-2 text-sm hover:bg-muted flex items-center gap-2 ${String(t.id) === value ? "bg-muted/50" : ""}`}
    >
      <ChannelTypeIcon type={t.channel} size={14} />
      <span className="truncate">{t.name}</span>
      {String(t.id) === value && <Check className="h-3.5 w-3.5 ml-auto text-primary shrink-0" />}
    </button>
  );

  const renderLevel = (parentId: number | null, depth: number): React.ReactNode => {
    // Hide folders that contain no (scoped, matching) templates anywhere in
    // their subtree — keeps the tree clean when channel-scoped or searching.
    const subfolders = (childFolders.get(parentId) ?? [])
      .filter((f) => folderHasMatch(f.id))
      .sort(byName);
    const tpls = (folderTemplates.get(parentId) ?? []).filter(matches).sort(byName);

    return (
      <>
        {subfolders.map((f) => (
          <React.Fragment key={`folder-${f.id}`}>
            <div
              style={{ paddingLeft: 12 + depth * 16 }}
              className="pr-3 py-2 text-xs font-medium text-muted-foreground flex items-center gap-2"
            >
              <Folder className="h-3.5 w-3.5 shrink-0" />
              <span className="truncate">{f.name}</span>
            </div>
            {renderLevel(f.id, depth + 1)}
          </React.Fragment>
        ))}
        {tpls.map((t) => renderRow(t, depth))}
      </>
    );
  };

  const hasResults = scoped.filter((t) => t.id).some(matches);

  return (
    <Popover open={open} onOpenChange={(o) => { setOpen(o); if (!o) setQuery(""); }}>
      <PopoverTrigger asChild>
        <button
          type="button"
          className="flex h-10 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background focus:outline-none focus:ring-2 focus:ring-ring"
        >
          {selected ? (
            <span className="flex items-center gap-2 min-w-0">
              <ChannelTypeIcon type={selected.channel} size={14} />
              <span className="truncate">{selected.name}</span>
            </span>
          ) : (
            <span className="text-muted-foreground">{placeholder}</span>
          )}
          <ChevronsUpDown className="h-4 w-4 opacity-50 shrink-0" />
        </button>
      </PopoverTrigger>
      <PopoverContent className="p-0 w-[var(--radix-popover-trigger-width)]" align="start">
        <div className="p-2 border-b">
          <Input autoFocus placeholder="Search templates…" value={query} onChange={(e) => setQuery(e.target.value)} className="h-8" />
        </div>
        <div className="max-h-64 overflow-y-auto py-1">
          {allowNone && !q && (
            <button
              type="button"
              onClick={() => { onChange("none"); setOpen(false); setQuery(""); }}
              className={`w-full text-left px-3 py-2 text-sm hover:bg-muted ${!selected ? "bg-muted/50" : ""}`}
            >
              No template
            </button>
          )}
          {hasResults ? renderLevel(null, 0) : (
            <p className="px-3 py-4 text-sm text-muted-foreground text-center">No templates match</p>
          )}
        </div>
      </PopoverContent>
    </Popover>
  );
}
