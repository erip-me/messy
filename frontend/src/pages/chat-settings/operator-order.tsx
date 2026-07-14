import { useState, useEffect, useRef } from "react";
import { Button } from "../../components/ui/button";
import { getOperatorProfiles, reorderOperatorProfiles, OperatorProfileListItem } from "../../api/chat-settings";
import { GripVertical, Save, User } from "lucide-react";
import toast from "react-hot-toast";

export function OperatorOrder() {
  const [profiles, setProfiles] = useState<OperatorProfileListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [dirty, setDirty] = useState(false);
  const dragItem = useRef<number | null>(null);
  const dragOverItem = useRef<number | null>(null);

  useEffect(() => {
    loadProfiles();
  }, []);

  async function loadProfiles() {
    try {
      const res = await getOperatorProfiles();
      setProfiles(res.data.operator_profiles);
    } catch {
      toast.error("Failed to load operators");
    } finally {
      setLoading(false);
    }
  }

  function handleDragStart(index: number) {
    dragItem.current = index;
  }

  function handleDragEnter(index: number) {
    dragOverItem.current = index;
  }

  function handleDragEnd() {
    if (dragItem.current === null || dragOverItem.current === null) return;
    if (dragItem.current === dragOverItem.current) return;

    const reordered = [...profiles];
    const [removed] = reordered.splice(dragItem.current, 1);
    reordered.splice(dragOverItem.current, 0, removed);

    dragItem.current = null;
    dragOverItem.current = null;
    setProfiles(reordered);
    setDirty(true);
  }

  async function handleSave() {
    setSaving(true);
    try {
      const order = profiles.map((p, i) => ({ id: p.id, sort_order: i }));
      await reorderOperatorProfiles(order);
      setDirty(false);
      toast.success("Operator order saved");
    } catch {
      toast.error("Failed to save order");
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <div className="p-2">Loading...</div>;

  if (profiles.length === 0) {
    return (
      <div className="text-sm text-muted-foreground">
        No operators have set up their profile yet.
      </div>
    );
  }

  return (
    <div className="max-w-[500px] space-y-4">
      <div>
        <p className="text-xs text-muted-foreground">
          Drag to set the priority order for auto-assignment. Online operators are assigned first in this order, then offline operators.
        </p>
      </div>

      <div className="space-y-1">
        {profiles.map((profile, index) => (
          <div
            key={profile.id}
            draggable
            onDragStart={() => handleDragStart(index)}
            onDragEnter={() => handleDragEnter(index)}
            onDragEnd={handleDragEnd}
            onDragOver={(e) => e.preventDefault()}
            className="flex items-center gap-3 p-3 bg-muted rounded-lg cursor-grab active:cursor-grabbing select-none hover:bg-muted transition-colors"
          >
            <GripVertical className="h-4 w-4 text-muted-foreground shrink-0" />
            <span className="text-sm font-medium text-muted-foreground w-5">{index + 1}</span>
            {profile.avatar_url ? (
              <img
                src={profile.avatar_url}
                alt=""
                className="w-8 h-8 rounded-full object-cover border border-border"
              />
            ) : (
              <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
                <User className="w-4 h-4 text-muted-foreground" />
              </div>
            )}
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-foreground truncate">
                {profile.public_name}
              </p>
              <p className="text-xs text-muted-foreground">
                Max {profile.max_concurrent_chats} chats
                {!profile.auto_assign && " \u00b7 Auto-assign off"}
              </p>
            </div>
            <div className="flex items-center gap-1.5 shrink-0">
              <div
                className={`w-2 h-2 rounded-full ${
                  profile.online ? "bg-green-500" : "bg-gray-300"
                }`}
              />
              <span className="text-xs text-muted-foreground">
                {profile.online ? "Online" : "Offline"}
              </span>
            </div>
          </div>
        ))}
      </div>

      <Button onClick={handleSave} disabled={saving || !dirty}>
        <Save className="h-4 w-4 mr-1" /> {saving ? "Saving..." : "Save Order"}
      </Button>
    </div>
  );
}
