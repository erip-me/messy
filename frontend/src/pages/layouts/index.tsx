import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { LayoutTemplate, Plus, Search, MoreHorizontal, Edit, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { PageSkeleton } from "@/components/ui/table-skeleton";
import { getLayouts, deleteLayout } from "@/api/layouts";
import toast from "react-hot-toast";
import { useActiveEnvironment } from "@/hooks/useActiveEnvironment";
import { useResource } from "@/hooks/use-resource";
import { formatDate } from "@/utils/format-date";

export function LayoutsIndexPage() {
  const navigate = useNavigate();
  const activeEnvId = useActiveEnvironment();
  const [apiKey] = useState("");

  const [searchQuery, setSearchQuery] = useState("");
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [layoutToDelete, setLayoutToDelete] = useState<number | null>(null);

  const { data: layouts = [], loading, reload: loadData } = useResource(
    () => getLayouts(apiKey),
    [activeEnvId],
    { initialData: [], errorMessage: "Failed to load layouts" },
  );

  const handleDelete = async () => {
    if (!layoutToDelete) return;
    try {
      await deleteLayout(layoutToDelete, apiKey);
      toast.success("Layout deleted");
      setDeleteDialogOpen(false);
      setLayoutToDelete(null);
      loadData();
    } catch {
      toast.error("Failed to delete layout");
    }
  };

  const displayLayouts = layouts.filter(
    (l) =>
      searchQuery === "" || l.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (loading) {
    return <PageSkeleton columns={2} rows={6} actions={2} />;
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-start mb-6">
        <div>
          <h1 className="page-heading">Layouts</h1>
          <p className="page-subtitle">
            Shared HTML wrappers for your templates: define the structure once, reuse
            everywhere
          </p>
        </div>
        <Button onClick={() => navigate("/layouts/new")}>
          <Plus className="h-4 w-4 mr-2" />
          New Layout
        </Button>
      </div>

      {/* Search */}
      <div className="flex justify-between items-center mb-4 gap-4">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search layouts..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10"
          />
        </div>
      </div>

      {/* Table Header */}
      {displayLayouts.length > 0 && (
        <div className="flex items-center px-3 py-2 text-xs font-semibold text-muted-foreground uppercase tracking-wider bg-muted/30 rounded-t-lg">
          <span className="flex-1">Name</span>
          <span className="hidden sm:block w-36 text-right">Updated</span>
          <span className="w-10"></span>
        </div>
      )}

      {/* Layout list */}
      <div className="space-y-1">
        {displayLayouts.map((layout) => (
          <div
            key={layout.id}
            className="flex items-center p-3 rounded-lg border border-transparent hover:bg-violet-50/50 transition-all group"
          >
            <LayoutTemplate className="h-5 w-5 text-violet-500 mr-3 flex-shrink-0" />
            <div className="flex-1 min-w-0 flex items-center gap-2 mr-4">
              <span
                className="text-sm font-medium truncate cursor-pointer hover:text-primary transition-colors"
                onClick={() => navigate(`/layouts/${layout.id}/edit`)}
              >
                {layout.name}
              </span>
              <Badge
                variant="outline"
                className="shrink-0 text-violet-600 border-violet-200 bg-violet-50 dark:text-violet-300 dark:border-violet-500/30 dark:bg-violet-500/10"
              >
                Layout
              </Badge>
            </div>
            <span className="hidden sm:block w-36 text-xs text-muted-foreground font-mono text-right">
              {formatDate(layout.updated_at || layout.created_at)}
            </span>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="ghost"
                  size="sm"
                  className="opacity-0 group-hover:opacity-100 ml-1"
                >
                  <MoreHorizontal className="h-4 w-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuLabel>Actions</DropdownMenuLabel>
                <DropdownMenuItem
                  onClick={() => navigate(`/layouts/${layout.id}/edit`)}
                >
                  <Edit className="h-4 w-4 mr-2" />
                  Edit
                </DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  className="text-destructive hover:!bg-red-50"
                  onClick={() => {
                    setLayoutToDelete(layout.id);
                    setDeleteDialogOpen(true);
                  }}
                >
                  <Trash2 className="h-4 w-4 mr-2" />
                  Delete
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        ))}
      </div>

      {/* Empty State */}
      {displayLayouts.length === 0 && (
        <div className="text-center py-12">
          <LayoutTemplate className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
          <h3 className="text-lg font-medium mb-2">No layouts found</h3>
          <p className="text-muted-foreground mb-4">
            {searchQuery
              ? "No layouts match your search."
              : "Create a layout to share a common HTML wrapper across templates."}
          </p>
          <Button onClick={() => navigate("/layouts/new")}>
            <Plus className="h-4 w-4 mr-2" />
            Create Layout
          </Button>
        </div>
      )}

      {/* Delete Confirmation Dialog */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete layout?</DialogTitle>
            <DialogDescription>
              This action cannot be undone. Templates using this layout will no longer
              have a wrapper applied.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleDelete}>
              Delete
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
