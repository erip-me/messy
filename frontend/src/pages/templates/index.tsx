import React, { useState, useEffect, useRef, DragEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Folder, FileText, Plus, Search, MoreHorizontal, Edit, Trash2, FolderPlus, Move, GripVertical, CheckSquare, Square, ChevronRight, ArrowLeft } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Breadcrumb, BreadcrumbList, BreadcrumbItem, BreadcrumbLink, BreadcrumbSeparator, BreadcrumbPage } from '@/components/ui/breadcrumb';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import { getTemplates, Template } from '@/api/templates';
import { getFolders, createFolder, deleteFolder, updateFolder, Folder as FolderType } from '@/api/folders';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';
import { ChannelTypeIcon } from '@/components/channel-icons';
import request from '@/utils/request';
import pluralize from 'pluralize';
import { formatDate } from '@/utils/format-date';

export function TemplatesIndexPage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [apiKey] = useState('');
  const activeEnvId = useActiveEnvironment();
  const { confirm, ConfirmDialog } = useConfirm();

  const [templates, setTemplates] = useState<Template[]>([]);
  const [folders, setFolders] = useState<FolderType[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [currentFolderId, setCurrentFolderId] = useState<number | null>(null);
  const [folderPath, setFolderPath] = useState<{ id: number | null; name: string }[]>([{ id: null, name: 'Templates' }]);

  // Selection state
  const [selectedTemplates, setSelectedTemplates] = useState<Set<number>>(new Set());

  // Sort state
  const [sortBy, setSortBy] = useState<'name' | 'trigger' | 'updated'>('name');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('asc');

  // Dialog states
  const [createFolderOpen, setCreateFolderOpen] = useState(false);
  const [newFolderName, setNewFolderName] = useState('');
  const [moveDialogOpen, setMoveDialogOpen] = useState(false);
  const [moveTargetFolder, setMoveTargetFolder] = useState<string>('root');
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);

  // Drag state
  const [dragOverFolderId, setDragOverFolderId] = useState<number | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [dragOverParent, setDragOverParent] = useState(false);
  const dragTemplateId = useRef<number | null>(null);
  const dragFolderId = useRef<number | null>(null);

  const buildFolderPathFromId = (folderId: number) => {
    const path: { id: number | null; name: string }[] = [{ id: null, name: 'Templates' }];
    let current = folders.find(f => f.id === folderId);
    const ancestors: typeof path = [];
    while (current) {
      ancestors.unshift({ id: current.id, name: current.name });
      current = current.parent_folder_id ? folders.find(f => f.id === current!.parent_folder_id) : undefined;
    }
    return [...path, ...ancestors];
  };

  const getFolderUrlPath = (folderId: number) => {
    const fullPath = buildFolderPathFromId(folderId);
    return fullPath.filter(f => f.id !== null).map(f => f.name).join('/');
  };

  const findFolderByUrlPath = (urlPath: string) => {
    const parts = urlPath.split('/');
    let parentId: number | null = null;
    let folder: FolderType | undefined;
    for (const part of parts) {
      folder = folders.find(f => f.name === part && f.parent_folder_id === parentId);
      if (!folder) return undefined;
      parentId = folder.id;
    }
    return folder;
  };

  useEffect(() => {
    const folderUrlPath = searchParams.get('folder');
    if (folderUrlPath && folders.length > 0) {
      const folder = findFolderByUrlPath(folderUrlPath);
      if (folder) {
        setCurrentFolderId(folder.id);
        setFolderPath(buildFolderPathFromId(folder.id));
      }
    } else if (!folderUrlPath && currentFolderId === null) {
      setFolderPath([{ id: null, name: 'Templates' }]);
    }
  }, [searchParams, folders]);

  useEffect(() => {
    loadData();
  }, [activeEnvId]);

  const loadData = async () => {
    try {
      setLoading(true);
      const [templatesData, foldersData] = await Promise.all([
        getTemplates(apiKey, currentFolderId || undefined),
        getFolders(apiKey)
      ]);
      setTemplates(templatesData);
      setFolders(foldersData);
      setSelectedTemplates(new Set());
    } catch (error) {
      toast.error('Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateFolder = async () => {
    if (!newFolderName.trim()) return;
    try {
      await createFolder({ name: newFolderName, parent_folder_id: currentFolderId || undefined }, apiKey);
      setNewFolderName('');
      setCreateFolderOpen(false);
      loadData();
      toast.success('Folder created');
    } catch { toast.error('Failed to create folder'); }
  };

  const handleDeleteFolder = async (folderId: number) => {
    const confirmed = await confirm({ title: 'Delete Folder', description: 'Delete this folder and move contents to parent?', confirmLabel: 'Delete', variant: 'destructive' });
    if (!confirmed) return;
    try {
      await deleteFolder(folderId, apiKey);
      loadData();
      toast.success('Folder deleted');
    } catch { toast.error('Failed to delete folder'); }
  };

  const handleRenameFolder = async (folderId: number, currentName: string) => {
    const newName = prompt('Rename folder:', currentName);
    if (!newName || newName.trim() === '' || newName === currentName) return;
    try {
      await updateFolder(folderId, { name: newName.trim() }, apiKey);
      loadData();
      toast.success('Folder renamed');
    } catch { toast.error('Failed to rename folder'); }
  };

  const handleFolderClick = (folder: FolderType) => {
    setCurrentFolderId(folder.id);
    navigate(`/templates?folder=${getFolderUrlPath(folder.id)}`);
    setFolderPath([...folderPath, { id: folder.id, name: folder.name }]);
    setSelectedTemplates(new Set());
  };

  const handleBreadcrumbClick = (folderId: number | null) => {
    setCurrentFolderId(folderId);
    setSelectedTemplates(new Set());
    if (folderId === null) {
      navigate('/templates');
      setFolderPath([{ id: null, name: 'Templates' }]);
    } else {
      navigate(`/templates?folder=${getFolderUrlPath(folderId)}`);
      const index = folderPath.findIndex(item => item.id === folderId);
      if (index >= 0) setFolderPath(folderPath.slice(0, index + 1));
    }
  };

  // Selection handlers
  const toggleSelect = (id: number) => {
    const next = new Set(selectedTemplates);
    next.has(id) ? next.delete(id) : next.add(id);
    setSelectedTemplates(next);
  };

  const toggleSelectAll = () => {
    if (selectedTemplates.size === displayTemplates.length) {
      setSelectedTemplates(new Set());
    } else {
      setSelectedTemplates(new Set(displayTemplates.map(t => t.id)));
    }
  };

  // Drag & Drop
  const handleDragStart = (e: DragEvent, templateId: number) => {
    // If dragging a selected template, we'll move all selected; otherwise just this one
    if (selectedTemplates.size > 0 && !selectedTemplates.has(templateId)) {
      // Dragging an unselected item — clear selection, drag just this one
      setSelectedTemplates(new Set());
    }
    dragTemplateId.current = templateId;
    dragFolderId.current = null;
    setIsDragging(true);
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', String(templateId));
  };

  const handleFolderDragStart = (e: DragEvent, folderId: number) => {
    dragFolderId.current = folderId;
    dragTemplateId.current = null;
    setIsDragging(true);
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', `folder-${folderId}`);
  };

  const handleDragEnd = () => {
    setIsDragging(false);
    setDragOverParent(false);
    setDragOverFolderId(null);
  };

  const handleDragOver = (e: DragEvent, folderId: number) => {
    // Don't allow dropping a folder onto itself
    if (dragFolderId.current === folderId) return;
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    setDragOverFolderId(folderId);
  };

  const handleDragLeave = () => {
    setDragOverFolderId(null);
  };

  const handleDrop = async (e: DragEvent, folderId: number | null) => {
    e.preventDefault();
    setDragOverFolderId(null);
    setDragOverParent(false);
    setIsDragging(false);

    if (dragFolderId.current) {
      const sourceFolderId = dragFolderId.current;
      if (sourceFolderId === folderId) return;
      try {
        await request.put(`/folders/${sourceFolderId}`, { folder: { parent_folder_id: folderId } });
        toast.success('Folder moved');
        loadData();
      } catch { toast.error('Failed to move folder'); }
      dragFolderId.current = null;
      return;
    }

    const templateId = dragTemplateId.current;
    if (!templateId) return;

    // If the dragged template is part of a selection, move all selected templates
    const idsToMove = selectedTemplates.size > 0 && selectedTemplates.has(templateId)
      ? Array.from(selectedTemplates)
      : [templateId];

    try {
      await Promise.all(
        idsToMove.map(id =>
          request.put(`/templates/${id}`, { template: { folder_id: folderId } })
        )
      );
      toast.success(idsToMove.length > 1 ? `Moved ${idsToMove.length} templates` : 'Template moved');
      setSelectedTemplates(new Set());
      loadData();
    } catch { toast.error('Failed to move templates'); }
  };

  // Bulk actions
  const handleBulkMove = async () => {
    const folderId = moveTargetFolder === 'root' ? null : parseInt(moveTargetFolder);
    try {
      await Promise.all(
        Array.from(selectedTemplates).map(id =>
          request.put(`/templates/${id}`, { template: { folder_id: folderId } })
        )
      );
      toast.success(`Moved ${selectedTemplates.size} templates`);
      setMoveDialogOpen(false);
      setSelectedTemplates(new Set());
      loadData();
    } catch { toast.error('Failed to move templates'); }
  };

  const handleBulkDelete = async () => {
    try {
      await Promise.all(
        Array.from(selectedTemplates).map(id => request.delete(`/templates/${id}`))
      );
      toast.success(`Deleted ${selectedTemplates.size} templates`);
      setDeleteDialogOpen(false);
      setSelectedTemplates(new Set());
      loadData();
    } catch { toast.error('Failed to delete templates'); }
  };

  const filteredData = () => {
    const q = searchQuery.trim().toLowerCase();
    // While searching, look across ALL folders (flat results) and hide folder
    // rows; otherwise scope to the current folder and show its subfolders.
    const foldersInCurrent = q ? [] : folders.filter(f => f.parent_folder_id === currentFolderId);
    const templatesInCurrent = templates.filter(t => {
      if (q) {
        return t.name.toLowerCase().includes(q) || t.trigger?.toLowerCase().includes(q);
      }
      return currentFolderId ? t.folder_id === currentFolderId : !t.folder_id;
    });
    const sorted = [...templatesInCurrent].sort((a, b) => {
      let cmp = 0;
      if (sortBy === 'name') cmp = (a.name || '').localeCompare(b.name || '');
      else if (sortBy === 'trigger') cmp = (a.trigger || '').localeCompare(b.trigger || '');
      else if (sortBy === 'updated') cmp = new Date(a.updated_at || a.created_at).getTime() - new Date(b.updated_at || b.created_at).getTime();
      return sortDir === 'asc' ? cmp : -cmp;
    });
    return { folders: foldersInCurrent, templates: sorted };
  };

  const toggleSort = (col: 'name' | 'trigger' | 'updated') => {
    if (sortBy === col) setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    else { setSortBy(col); setSortDir('asc'); }
  };

  const SortIcon = ({ col }: { col: string }) => {
    if (sortBy !== col) return <span className="ml-1 opacity-0 group-hover/sort:opacity-50">↕</span>;
    return <span className="ml-1">{sortDir === 'asc' ? '↑' : '↓'}</span>;
  };

  const { folders: displayFolders, templates: displayTemplates } = filteredData();
  const allSelected = displayTemplates.length > 0 && selectedTemplates.size === displayTemplates.length;

  if (loading) {
    return <PageSkeleton columns={3} rows={8} actions={2} />;
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-start mb-6">
        <div>
          <h1 className="page-heading">Templates</h1>
          {folderPath.length === 1 ? (
            <p className="page-subtitle">Manage and organise your message templates</p>
          ) : (
            <Breadcrumb className="mt-2">
            <BreadcrumbList>
              {folderPath.map((item, index) => (
                <React.Fragment key={item.id || 'root'}>
                  {index > 0 && <BreadcrumbSeparator />}
                  {index === folderPath.length - 1 ? (
                    <BreadcrumbPage>{item.name}</BreadcrumbPage>
                  ) : (
                    <BreadcrumbItem>
                      <BreadcrumbLink onClick={() => handleBreadcrumbClick(item.id)}>
                        {item.name}
                      </BreadcrumbLink>
                    </BreadcrumbItem>
                  )}
                </React.Fragment>
              ))}
            </BreadcrumbList>
          </Breadcrumb>
          )}
        </div>

        <div className="flex gap-2 flex-wrap">
          <Dialog open={createFolderOpen} onOpenChange={setCreateFolderOpen}>
            <DialogTrigger asChild>
              <Button variant="outline">
                <FolderPlus className="h-4 w-4 mr-2" />
                New Folder
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create New Folder</DialogTitle>
                <DialogDescription>Create a folder to organize your templates.</DialogDescription>
              </DialogHeader>
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="folderName">Folder Name</Label>
                  <Input id="folderName" value={newFolderName} onChange={(e) => setNewFolderName(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && handleCreateFolder()} placeholder="e.g. Marketing" autoFocus />
                </div>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setCreateFolderOpen(false)}>Cancel</Button>
                <Button onClick={handleCreateFolder} disabled={!newFolderName.trim()}>Create Folder</Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>

          <Button onClick={() => navigate(currentFolderId ? `/templates/new?folder_id=${currentFolderId}` : '/templates/new')}>
            <Plus className="h-4 w-4 mr-2" />
            New Template
          </Button>
        </div>
      </div>

      {/* Search + Bulk Actions Bar */}
      <div className="flex flex-wrap justify-between items-center mb-4 gap-4">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input placeholder="Search templates..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} className="pl-10" />
        </div>

        {selectedTemplates.size > 0 && (
          <div className="flex items-center gap-2">
            <span className="text-sm text-muted-foreground">{selectedTemplates.size} selected</span>
            <Button variant="outline" size="sm" onClick={() => setMoveDialogOpen(true)}>
              <Move className="h-4 w-4 mr-1" /> Move
            </Button>
            <Button variant="outline" size="sm" className="text-destructive hover:text-destructive" onClick={() => setDeleteDialogOpen(true)}>
              <Trash2 className="h-4 w-4 mr-1" /> Delete
            </Button>
          </div>
        )}
      </div>

      {/* Table Header */}
      {displayTemplates.length > 0 && (
        <div className="flex items-center px-3 py-2 text-xs font-semibold text-muted-foreground uppercase tracking-wider bg-muted/30 rounded-t-lg">
          <button onClick={toggleSelectAll} className="mr-3 text-muted-foreground hover:text-foreground transition-colors">
            {allSelected ? <CheckSquare className="h-4 w-4 text-primary" /> : <Square className="h-4 w-4" />}
          </button>
          <button onClick={() => toggleSort('name')} className="flex-1 text-left flex items-center group/sort hover:text-foreground transition-colors">
            Name <SortIcon col="name" />
          </button>
          <button onClick={() => toggleSort('trigger')} className="hidden md:flex w-48 text-left items-center group/sort hover:text-foreground transition-colors">
            Trigger <SortIcon col="trigger" />
          </button>
          <button onClick={() => toggleSort('updated')} className="hidden sm:flex w-36 text-right items-center justify-end group/sort hover:text-foreground transition-colors">
            Updated <SortIcon col="updated" />
          </button>
          <span className="w-10"></span>
        </div>
      )}

      {/* Folders */}
      <div className="space-y-1">
        {currentFolderId && (() => {
          const parentIndex = folderPath.length - 2;
          const parent = folderPath[parentIndex];
          const parentFolderId = parent?.id ?? null;
          const parentName = parent?.name ?? 'Templates';
          return (
            <div
              className={`flex items-center p-3 rounded-lg border transition-all cursor-pointer text-muted-foreground ${
                dragOverParent
                  ? 'bg-accent border-primary ring-2 ring-primary/20'
                  : 'hover:bg-muted/50 border-transparent'
              }`}
              onClick={() => {
                if (parent) handleBreadcrumbClick(parent.id);
              }}
              onDragOver={(e) => {
                if (dragFolderId.current === parentFolderId) return;
                e.preventDefault();
                e.dataTransfer.dropEffect = 'move';
                setDragOverParent(true);
              }}
              onDragLeave={() => setDragOverParent(false)}
              onDrop={(e) => handleDrop(e, parentFolderId)}
            >
              <Folder className="h-5 w-5 text-amber-500 fill-amber-100 mr-3 flex-shrink-0" />
              {isDragging ? (
                <span className="text-sm font-medium">{parentName}</span>
              ) : (
                <>
                  <ArrowLeft className="h-4 w-4 mr-2 flex-shrink-0" />
                  <span className="text-sm">Back to <span className="text-foreground font-medium">{parentName}</span></span>
                </>
              )}
            </div>
          );
        })()}
        {displayFolders.map((folder) => (
          <div
            key={`folder-${folder.id}`}
            draggable
            onDragStart={(e) => handleFolderDragStart(e, folder.id)}
            onDragEnd={handleDragEnd}
            className={`flex items-center p-3 rounded-lg border transition-all cursor-pointer group ${
              dragOverFolderId === folder.id
                ? 'bg-amber-50/60 border-amber-200 ring-2 ring-amber-100'
                : 'hover:bg-amber-50/50 border-transparent'
            }`}
            onClick={() => handleFolderClick(folder)}
            onDragOver={(e) => handleDragOver(e, folder.id)}
            onDragLeave={handleDragLeave}
            onDrop={(e) => handleDrop(e, folder.id)}
          >
            <Folder className="h-5 w-5 text-amber-500 fill-amber-100 mr-3 flex-shrink-0" />
            <GripVertical className="h-4 w-4 text-muted-foreground/40 mr-2 cursor-grab" />
            <span className="text-sm font-medium">{folder.name}</span>
            <span className="text-xs text-muted-foreground font-mono ml-2">
              {pluralize('template', folder.templates_count ?? folder.templates?.length ?? 0, true)}, {pluralize('folder', folders.filter(f => f.parent_folder_id === folder.id).length, true)}
            </span>
            <span className="flex-1" />
            <ChevronRight className="h-4 w-4 text-muted-foreground opacity-0 group-hover:opacity-100 transition-opacity" />
            <DropdownMenu>
              <DropdownMenuTrigger asChild onClick={(e) => e.stopPropagation()}>
                <Button variant="ghost" size="sm" className="opacity-0 group-hover:opacity-100 ml-1">
                  <MoreHorizontal className="h-4 w-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuLabel>Folder</DropdownMenuLabel>
                <DropdownMenuItem onClick={(e) => { e.stopPropagation(); handleRenameFolder(folder.id, folder.name); }}><Edit className="h-4 w-4 mr-2" />Rename</DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem className="text-destructive hover:!bg-red-50" onClick={(e) => { e.stopPropagation(); handleDeleteFolder(folder.id); }}>
                  <Trash2 className="h-4 w-4 mr-2" />Delete
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        ))}

        {/* Templates */}
        {displayTemplates.map((template) => {
          const isSelected = selectedTemplates.has(template.id);
          return (
            <div
              key={`template-${template.id}`}
              draggable
              onDragStart={(e) => handleDragStart(e, template.id)}
              onDragEnd={handleDragEnd}
              className={`flex items-center p-3 rounded-lg border transition-all group ${
                isSelected
                  ? 'bg-primary/5 border-transparent'
                  : 'hover:bg-accent border-transparent'
              }`}
            >
              <button
                onClick={(e) => { e.stopPropagation(); toggleSelect(template.id); }}
                className="mr-3 text-muted-foreground hover:text-foreground transition-colors"
              >
                {isSelected ? <CheckSquare className="h-4 w-4 text-primary" /> : <Square className="h-4 w-4" />}
              </button>
              <GripVertical className="h-4 w-4 text-muted-foreground/40 mr-2 cursor-grab" />
              <span className="mr-3 flex-shrink-0">
                <ChannelTypeIcon type={template.channel || 'email'} size={20} />
              </span>
              <span
                className="text-sm font-medium flex-1 min-w-0 truncate cursor-pointer hover:text-primary transition-colors"
                onClick={() => navigate(`/templates/${template.id}/edit`)}
              >
                {template.name}
              </span>
              <span className="hidden md:block w-48 text-xs text-muted-foreground font-mono whitespace-nowrap text-left">
                {template.trigger}
              </span>
              <span className="hidden sm:block w-36 text-xs text-muted-foreground font-mono text-right">
                {formatDate(template.updated_at || template.created_at)}
              </span>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="ghost" size="sm" className="opacity-0 group-hover:opacity-100 ml-1">
                    <MoreHorizontal className="h-4 w-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuLabel>Actions</DropdownMenuLabel>
                  <DropdownMenuItem onClick={() => navigate(`/templates/${template.id}/edit`)}>
                    <Edit className="h-4 w-4 mr-2" />Edit
                  </DropdownMenuItem>
                  <DropdownMenuItem onClick={() => { setSelectedTemplates(new Set([template.id])); setMoveDialogOpen(true); }}>
                    <Move className="h-4 w-4 mr-2" />Move
                  </DropdownMenuItem>
                  <DropdownMenuSeparator />
                  <DropdownMenuItem className="text-destructive hover:!bg-red-50" onClick={() => { setSelectedTemplates(new Set([template.id])); setDeleteDialogOpen(true); }}>
                    <Trash2 className="h-4 w-4 mr-2" />Delete
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          );
        })}
      </div>

      {/* Empty State */}
      {displayFolders.length === 0 && displayTemplates.length === 0 && (
        <div className="text-center py-12">
          <FileText className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
          <h3 className="text-lg font-medium mb-2">No templates found</h3>
          <p className="text-muted-foreground mb-4">
            {searchQuery ? 'No templates match your search.' : 'Get started by creating your first template.'}
          </p>
          <Button onClick={() => navigate(currentFolderId ? `/templates/new?folder_id=${currentFolderId}` : '/templates/new')}>
            <Plus className="h-4 w-4 mr-2" />
            Create Template
          </Button>
        </div>
      )}

      {/* Move Dialog */}
      <Dialog open={moveDialogOpen} onOpenChange={setMoveDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Move {selectedTemplates.size} template{selectedTemplates.size > 1 ? 's' : ''}</DialogTitle>
            <DialogDescription>Select a destination folder.</DialogDescription>
          </DialogHeader>
          <Select value={moveTargetFolder} onValueChange={setMoveTargetFolder}>
            <SelectTrigger>
              <SelectValue placeholder="Select folder" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="root">
                <span className="flex items-center gap-2">
                  <Folder className="h-4 w-4 text-muted-foreground fill-gray-100" /> Root (no folder)
                </span>
              </SelectItem>
              {folders.map(f => (
                <SelectItem key={f.id} value={String(f.id)}>
                  <span className="flex items-center gap-2">
                    <Folder className="h-4 w-4 text-amber-500" /> {f.name}
                  </span>
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <DialogFooter>
            <Button variant="outline" onClick={() => setMoveDialogOpen(false)}>Cancel</Button>
            <Button onClick={handleBulkMove}>Move</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete {selectedTemplates.size} template{selectedTemplates.size > 1 ? 's' : ''}?</DialogTitle>
            <DialogDescription>This action cannot be undone. The selected templates will be permanently deleted.</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)}>Cancel</Button>
            <Button variant="destructive" onClick={handleBulkDelete}>Delete</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {ConfirmDialog}
    </div>
  );
}
