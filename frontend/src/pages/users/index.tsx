import { useState } from 'react';
import { useSelector } from 'react-redux';
import { UserPlus, Mail, Trash2, Users, MoreHorizontal, ShieldCheck, ShieldOff } from 'lucide-react';
import { format } from 'date-fns';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Badge } from '@/components/ui/badge';
import { PageSkeleton } from '@/components/ui/table-skeleton';
import { RootState } from '@/store';
import { getUsers, inviteUser, deleteUser, updateUserRole, User, UserRole, InviteUserRequest } from '@/api/users';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { useActiveEnvironment } from '@/hooks/useActiveEnvironment';
import { useResource } from '@/hooks/use-resource';

export function UsersIndexPage() {
  const currentUser = useSelector((state: RootState) => state.auth.user);
  const isAdmin = currentUser?.role === 'admin' || currentUser?.is_super_admin === true;
  const activeEnvId = useActiveEnvironment();
  const { confirm, ConfirmDialog } = useConfirm();
  const [inviteDialogOpen, setInviteDialogOpen] = useState(false);
  const [inviting, setInviting] = useState(false);

  const [inviteForm, setInviteForm] = useState<InviteUserRequest>({
    name: '',
    email: '',
    role: 'member'
  });

  const { data: users = [], loading, setData: setUsers } = useResource(
    getUsers,
    [activeEnvId],
    { initialData: [], errorMessage: 'Failed to load users' },
  );

  const handleInviteUser = async () => {
    if (!inviteForm.name.trim() || !inviteForm.email.trim()) {
      toast.error('Please fill in all fields');
      return;
    }

    try {
      setInviting(true);
      const newUser = await inviteUser(inviteForm);
      setUsers(prev => [newUser, ...(prev ?? [])]);
      setInviteForm({ name: '', email: '', role: 'member' });
      setInviteDialogOpen(false);
      toast.success('User invited successfully');
    } catch (error: any) {
      toast.error(error.response?.data?.message || 'Failed to invite user');
    } finally {
      setInviting(false);
    }
  };

  const handleDeleteUser = async (userId: number, userName: string) => {
    if (userId === Number(currentUser?.id)) {
      toast.error('You cannot delete your own account');
      return;
    }

    const confirmed = await confirm({ title: 'Delete User', description: `Are you sure you want to delete the user "${userName}"? This action cannot be undone.`, confirmLabel: 'Delete', variant: 'destructive' });
    if (!confirmed) return;

    try {
      await deleteUser(userId);
      setUsers(prev => (prev ?? []).filter(user => user.id !== userId));
      toast.success('User deleted successfully');
    } catch (error) {
      toast.error('Failed to delete user');
    }
  };

  const handleInputChange = (field: keyof InviteUserRequest, value: string) => {
    setInviteForm(prev => ({ ...prev, [field]: value }));
  };

  const handleChangeRole = async (user: User, role: UserRole) => {
    try {
      const updated = await updateUserRole(user.id, role);
      setUsers(prev => (prev ?? []).map(u => (u.id === user.id ? updated : u)));
      toast.success(role === 'admin' ? 'User promoted to admin' : 'User changed to member');
    } catch (error: any) {
      toast.error(error.response?.data?.message || 'Failed to update role');
    }
  };

  if (loading) {
    return <PageSkeleton columns={5} rows={8} actions={1} />;
  }

  return (
    <div className="p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div>
          <h1 className="page-heading">Team</h1>
          <p className="page-subtitle">
            Manage users in your organization
          </p>
        </div>
        
        <Dialog open={inviteDialogOpen} onOpenChange={setInviteDialogOpen}>
          {isAdmin && (
            <DialogTrigger asChild>
              <Button>
                <UserPlus className="h-4 w-4 mr-2" />
                Invite User
              </Button>
            </DialogTrigger>
          )}
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Invite New User</DialogTitle>
              <DialogDescription>
                Send an invitation to a new user to join your organization.
              </DialogDescription>
            </DialogHeader>
            
            <div className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="name">Full Name</Label>
                <Input
                  id="name"
                  value={inviteForm.name}
                  onChange={(e) => handleInputChange('name', e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleInviteUser()}
                  placeholder="John Doe"
                />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="email">Email Address</Label>
                <Input
                  id="email"
                  type="email"
                  value={inviteForm.email}
                  onChange={(e) => handleInputChange('email', e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleInviteUser()}
                  placeholder="john@example.com"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="role">Role</Label>
                <Select value={inviteForm.role} onValueChange={(value) => handleInputChange('role', value)}>
                  <SelectTrigger id="role">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="member">Member (read &amp; operate)</SelectItem>
                    <SelectItem value="admin">Admin (manage team, environments &amp; settings)</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            
            <DialogFooter>
              <Button variant="outline" onClick={() => setInviteDialogOpen(false)}>
                Cancel
              </Button>
              <Button onClick={handleInviteUser} disabled={inviting || !inviteForm.name.trim() || !inviteForm.email.trim()}>
                {inviting ? 'Sending...' : 'Send Invitation'}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5" />
            Team Members
            <Badge variant="outline">
              {users.length} users
            </Badge>
          </CardTitle>
        </CardHeader>
        
        <CardContent className="p-0">
          {users.length === 0 ? (
            <div className="text-center py-12">
              <Users className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <h3 className="text-lg font-medium mb-2">No users found</h3>
              <p className="text-muted-foreground mb-4">
                Invite your first team member to get started.
              </p>
              {isAdmin && (
                <Button onClick={() => setInviteDialogOpen(true)}>
                  <UserPlus className="h-4 w-4 mr-2" />
                  Invite User
                </Button>
              )}
            </div>
          ) : (
            <>
              {/* Mobile: stacked cards */}
              <div className="md:hidden divide-y divide-border">
                {users.map((user) => (
                  <div key={user.id} className="p-4 flex flex-col gap-2">
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                          <span className="text-sm font-medium">
                            {user.name.charAt(0).toUpperCase()}
                          </span>
                        </div>
                        <div className="min-w-0">
                          <div className="flex items-center gap-2">
                            <p className="font-medium truncate">{user.name}</p>
                            {user.id === Number(currentUser?.id) && (
                              <Badge className="text-xs bg-emerald-100 text-emerald-700 hover:bg-emerald-100 shrink-0">
                                You
                              </Badge>
                            )}
                          </div>
                          <p className="text-sm text-muted-foreground truncate">{user.email}</p>
                        </div>
                      </div>
                      {isAdmin && (
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="sm" className="shrink-0">
                              <MoreHorizontal className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            {user.role === 'admin' ? (
                              <DropdownMenuItem onClick={() => handleChangeRole(user, 'member')}>
                                <ShieldOff className="h-4 w-4 mr-2" />
                                Change to member
                              </DropdownMenuItem>
                            ) : (
                              <DropdownMenuItem onClick={() => handleChangeRole(user, 'admin')}>
                                <ShieldCheck className="h-4 w-4 mr-2" />
                                Make admin
                              </DropdownMenuItem>
                            )}
                            <DropdownMenuSeparator />
                            <DropdownMenuItem
                              className="text-destructive"
                              onClick={() => handleDeleteUser(user.id, user.name)}
                            >
                              <Trash2 className="h-4 w-4 mr-2" />
                              Delete User
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      )}
                    </div>
                    <div className="flex items-center gap-2 text-xs text-muted-foreground">
                      <Badge variant={user.role === 'admin' ? 'default' : 'secondary'}>
                        {user.role === 'admin' ? 'Admin' : 'Member'}
                      </Badge>
                      {user.is_super_admin && (
                        <Badge variant="outline">Super Admin</Badge>
                      )}
                      <span className="ml-auto font-mono">
                        {user.last_login_at ? format(new Date(user.last_login_at), 'MMM d, yyyy') : 'Never'}
                      </span>
                    </div>
                  </div>
                ))}
              </div>

              {/* Desktop: table */}
              <Table className="hidden md:table">
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Email</TableHead>
                  <TableHead>Role</TableHead>
                  <TableHead>Last Login</TableHead>
                  <TableHead>Joined</TableHead>
                  <TableHead className="w-12"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {users.map((user) => (
                  <TableRow key={user.id}>
                    <TableCell className="font-medium">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                          <span className="text-sm font-medium">
                            {user.name.charAt(0).toUpperCase()}
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <p className="font-medium">{user.name}</p>
                          {user.id === Number(currentUser?.id) && (
                            <Badge className="text-xs bg-emerald-100 text-emerald-700 hover:bg-emerald-100">
                              You
                            </Badge>
                          )}
                        </div>
                      </div>
                    </TableCell>
                    
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Mail className="h-4 w-4 text-muted-foreground" />
                        {user.email}
                      </div>
                    </TableCell>
                    
                    <TableCell>
                      <div className="flex items-center gap-2">
                        <Badge variant={user.role === 'admin' ? 'default' : 'secondary'}>
                          {user.role === 'admin' ? 'Admin' : 'Member'}
                        </Badge>
                        {user.is_super_admin && (
                          <Badge variant="outline">Super Admin</Badge>
                        )}
                      </div>
                    </TableCell>
                    
                    <TableCell>
                      {user.last_login_at ? (
                        <div className="text-sm font-mono">
                          <div>{format(new Date(user.last_login_at), 'MMM d, yyyy')}</div>
                          <div className="text-muted-foreground">
                            {format(new Date(user.last_login_at), 'h:mm a')}
                          </div>
                        </div>
                      ) : (
                        <span className="text-muted-foreground font-mono text-sm">Never</span>
                      )}
                    </TableCell>
                    
                    <TableCell>
                      <div
                        className="text-sm font-mono cursor-default"
                        title={format(new Date(user.created_at), 'h:mm a')}
                      >
                        {format(new Date(user.created_at), 'MMM d, yyyy')}
                      </div>
                    </TableCell>
                    
                    <TableCell>
                      {isAdmin && (
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="sm">
                              <MoreHorizontal className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            {user.role === 'admin' ? (
                              <DropdownMenuItem onClick={() => handleChangeRole(user, 'member')}>
                                <ShieldOff className="h-4 w-4 mr-2" />
                                Change to member
                              </DropdownMenuItem>
                            ) : (
                              <DropdownMenuItem onClick={() => handleChangeRole(user, 'admin')}>
                                <ShieldCheck className="h-4 w-4 mr-2" />
                                Make admin
                              </DropdownMenuItem>
                            )}
                            <DropdownMenuSeparator />
                            <DropdownMenuItem
                              className="text-destructive"
                              onClick={() => handleDeleteUser(user.id, user.name)}
                            >
                              <Trash2 className="h-4 w-4 mr-2" />
                              Delete User
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      )}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            </>
          )}
        </CardContent>
      </Card>

      {ConfirmDialog}
    </div>
  );
}