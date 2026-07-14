import { useState, useEffect, useRef } from "react";
import { Button } from "../../components/ui/button";
import { Input } from "../../components/ui/input";
import { Label } from "../../components/ui/label";
import { Textarea } from "../../components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Switch } from "../../components/ui/switch";
import { getOperatorProfile, updateOperatorProfile, uploadOperatorAvatar, OperatorProfile } from "../../api/chat-settings";
import { Save, Upload, User } from "lucide-react";
import toast from "react-hot-toast";

export function OperatorProfilePage() {
  const [profile, setProfile] = useState<OperatorProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [formData, setFormData] = useState({
    public_name: "",
    bio: "",
    availability: "online",
    auto_assign: true,
    max_concurrent_chats: 10,
  });
  const avatarInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    loadProfile();
  }, []);

  async function loadProfile() {
    try {
      const res = await getOperatorProfile();
      if (res.data.operator_profile) {
        setProfile(res.data.operator_profile);
        setFormData({
          public_name: res.data.operator_profile.public_name,
          bio: res.data.operator_profile.bio || "",
          availability: res.data.operator_profile.availability,
          auto_assign: res.data.operator_profile.auto_assign,
          max_concurrent_chats: res.data.operator_profile.max_concurrent_chats,
        });
      }
    } catch {
      toast.error("Failed to load profile");
    } finally {
      setLoading(false);
    }
  }

  async function handleSave() {
    if (!formData.public_name) {
      toast.error("Public name is required");
      return;
    }
    setSaving(true);
    try {
      const res = await updateOperatorProfile(formData);
      setProfile(res.data.operator_profile);
      toast.success("Profile saved");
    } catch {
      toast.error("Failed to save profile");
    } finally {
      setSaving(false);
    }
  }

  async function handleAvatarUpload(file: File) {
    try {
      const res = await uploadOperatorAvatar(file);
      setProfile(res.data.operator_profile);
      toast.success("Avatar uploaded");
    } catch {
      toast.error("Failed to upload avatar");
    }
  }

  if (loading) return <div className="p-6">Loading...</div>;

  return (
    <div className="p-6 max-w-2xl">
      <h1 className="page-heading text-2xl mb-6">Operator Profile</h1>
      <p className="text-sm text-muted-foreground mb-6">
        This is your public profile shown to visitors in the chat widget. It is separate from your account profile.
      </p>

      <div className="space-y-4">
        <div>
          <Label>Avatar</Label>
          <p className="text-xs text-muted-foreground mt-0.5 mb-2">Your photo shown to visitors in the chat widget</p>
          <div className="flex items-center gap-4">
            {profile?.avatar_url ? (
              <img
                src={profile.avatar_url}
                alt=""
                className="w-16 h-16 rounded-full object-cover border border-border"
              />
            ) : (
              <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center border border-border">
                <User className="w-6 h-6 text-muted-foreground" />
              </div>
            )}
            <div>
              <input
                ref={avatarInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) handleAvatarUpload(file);
                }}
              />
              <Button variant="outline" size="sm" onClick={() => avatarInputRef.current?.click()}>
                <Upload className="h-3.5 w-3.5 mr-1" /> {profile?.avatar_url ? "Change" : "Upload"}
              </Button>
            </div>
          </div>
        </div>

        <div>
          <Label>Public Name *</Label>
          <Input
            value={formData.public_name}
            onChange={(e) => setFormData({ ...formData, public_name: e.target.value })}
            placeholder="Your display name in chat"
            className="mt-1"
          />
        </div>

        <div>
          <Label>Bio</Label>
          <Textarea
            value={formData.bio}
            onChange={(e) => setFormData({ ...formData, bio: e.target.value })}
            placeholder="A short description about yourself"
            className="mt-1"
          />
        </div>

        <div>
          <Label>Availability</Label>
          <Select
            value={formData.availability}
            onValueChange={(v) => setFormData({ ...formData, availability: v })}
          >
            <SelectTrigger className="w-48 mt-1">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="online">Online</SelectItem>
              <SelectItem value="away">Away</SelectItem>
              <SelectItem value="offline">Offline</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div>
          <Label>Max Concurrent Chats</Label>
          <Input
            type="number"
            value={formData.max_concurrent_chats}
            onChange={(e) => setFormData({ ...formData, max_concurrent_chats: Number(e.target.value) })}
            className="w-24 mt-1"
            min={1}
          />
        </div>

        <div className="flex items-center justify-between">
          <div>
            <Label>Auto-assign conversations</Label>
            <p className="text-xs text-muted-foreground">Include you in round-robin auto-assignment</p>
          </div>
          <Switch
            checked={formData.auto_assign}
            onCheckedChange={(v) => setFormData({ ...formData, auto_assign: v })}
          />
        </div>

        <Button onClick={handleSave} disabled={saving}>
          <Save className="h-4 w-4 mr-1" /> {saving ? "Saving..." : "Save Profile"}
        </Button>
      </div>
    </div>
  );
}
