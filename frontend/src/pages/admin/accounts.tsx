import React, { useState, useEffect } from 'react';
import { Plus, Building, Users, Edit, Trash2, MoreHorizontal, ChevronLeft, ChevronRight } from 'lucide-react';
import { usePageParam } from '@/hooks/usePageParam';
import { format } from 'date-fns';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu';
import { Skeleton } from '@/components/ui/skeleton';
import { getAccounts, createAccount, deleteAccount, Account, CreateAccountRequest } from '@/api/admin';
import toast from 'react-hot-toast';
import { useConfirm } from '@/components/ui/confirm-dialog';
import { PAYMENT_STATUS_COLORS } from '@/lib/labels';

const PLAN_COLORS = {
  free: 'bg-muted text-foreground',
  starter: 'bg-blue-100 text-blue-800',
  pro: 'bg-purple-100 text-purple-800',
  enterprise: 'bg-green-100 text-green-800',
};

export function AdminAccountsPage() {
  const { confirm, ConfirmDialog } = useConfirm();
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [loading, setLoading] = useState(true);
  const [totalCount, setTotalCount] = useState(0);
  const [currentPage, setCurrentPage] = usePageParam();
  const [totalPages, setTotalPages] = useState(1);
  const [createDialogOpen, setCreateDialogOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  
  const [createForm, setCreateForm] = useState<CreateAccountRequest>({
    name: '',
    plan: 'free',
    first_user: {
      name: '',
      email: ''
    }
  });

  useEffect(() => {
    loadAccounts();
  }, [currentPage]);

  const loadAccounts = async () => {
    try {
      setLoading(true);
      const response = await getAccounts(currentPage, 25);
      setAccounts(response.accounts);
      setTotalCount(response.meta.total_count);
      setTotalPages(response.meta.total_pages);
    } catch (error) {
      toast.error('Failed to load accounts');
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateAccount = async () => {
    if (!createForm.name.trim()) {
      toast.error('Account name is required');
      return;
    }

    try {
      setCreating(true);
      const newAccount = await createAccount(createForm);
      setAccounts(prev => [newAccount, ...prev]);
      setCreateForm({
        name: '',
        plan: 'free',
        first_user: { name: '', email: '' }
      });
      setCreateDialogOpen(false);
      toast.success('Account created successfully');
    } catch (error: any) {
      toast.error(error.response?.data?.message || 'Failed to create account');
    } finally {
      setCreating(false);
    }
  };

  const handleDeleteAccount = async (id: number, name: string) => {
    const confirmed = await confirm({ title: 'Delete Account', description: `Are you sure you want to delete the account "${name}"? This will delete all associated data and cannot be undone.`, confirmLabel: 'Delete', variant: 'destructive' });
    if (!confirmed) return;

    try {
      await deleteAccount(id);
      setAccounts(prev => prev.filter(account => account.id !== id));
      toast.success('Account deleted successfully');
    } catch (error) {
      toast.error('Failed to delete account');
    }
  };

  const handleInputChange = (field: string, value: string) => {
    if (field.startsWith('first_user.')) {
      const userField = field.split('.')[1];
      setCreateForm(prev => ({
        ...prev,
        first_user: prev.first_user ? {
          ...prev.first_user,
          [userField]: value
        } : { name: '', email: '', [userField]: value }
      }));
    } else {
      setCreateForm(prev => ({ ...prev, [field]: value }));
    }
  };

  const Pagination = () => (
    <div className="flex items-center justify-between px-4 py-3 border-t">
      <div className="text-sm text-muted-foreground">
        Showing {((currentPage - 1) * 25) + 1}-{Math.min(currentPage * 25, totalCount)} of {totalCount} accounts
      </div>
      
      <div className="flex items-center space-x-2">
        <Button
          variant="outline"
          size="sm"
          onClick={() => setCurrentPage(currentPage - 1)}
          disabled={currentPage === 1}
        >
          <ChevronLeft className="h-4 w-4" />
        </Button>
        
        <div className="text-sm">
          Page {currentPage} of {totalPages}
        </div>
        
        <Button
          variant="outline"
          size="sm"
          onClick={() => setCurrentPage(currentPage + 1)}
          disabled={currentPage === totalPages}
        >
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>
    </div>
  );

  if (loading && accounts.length === 0) {
    return (
      <div className="p-6">
        <div className="flex justify-between items-center mb-6">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-10 w-32" />
        </div>
        
        <Card>
          <CardContent className="p-0">
            <div className="space-y-3 p-4">
              {Array.from({ length: 10 }).map((_, i) => (
                <Skeleton key={i} className="h-20" />
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div>
          <h1 className="page-heading">Account Management</h1>
          <p className="page-subtitle">
            Manage tenant accounts and billing
          </p>
        </div>
        
        <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="h-4 w-4 mr-2" />
              Create Account
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-md">
            <DialogHeader>
              <DialogTitle>Create New Account</DialogTitle>
              <DialogDescription>
                Create a new tenant account with an initial admin user.
              </DialogDescription>
            </DialogHeader>
            
            <div className="space-y-4">
              <div>
                <Label htmlFor="account-name">Account Name</Label>
                <Input
                  id="account-name"
                  value={createForm.name}
                  onChange={(e) => handleInputChange('name', e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleCreateAccount()}
                  placeholder="Acme Corp"
                />
              </div>
              
              <div>
                <Label htmlFor="plan">Plan</Label>
                <Select value={createForm.plan} onValueChange={(value) => handleInputChange('plan', value)}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select plan" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="free">Free</SelectItem>
                    <SelectItem value="starter">Starter</SelectItem>
                    <SelectItem value="pro">Pro</SelectItem>
                    <SelectItem value="enterprise">Enterprise</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              
              <div className="border-t pt-4">
                <Label className="text-sm font-medium mb-3 block">First Admin User (Optional)</Label>
                
                <div className="space-y-3">
                  <div>
                    <Label htmlFor="user-name">Full Name</Label>
                    <Input
                      id="user-name"
                      value={createForm.first_user?.name || ''}
                      onChange={(e) => handleInputChange('first_user.name', e.target.value)}
                      onKeyDown={(e) => e.key === 'Enter' && handleCreateAccount()}
                      placeholder="John Doe"
                    />
                  </div>
                  
                  <div>
                    <Label htmlFor="user-email">Email</Label>
                    <Input
                      id="user-email"
                      type="email"
                      value={createForm.first_user?.email || ''}
                      onChange={(e) => handleInputChange('first_user.email', e.target.value)}
                      onKeyDown={(e) => e.key === 'Enter' && handleCreateAccount()}
                      placeholder="john@acme.com"
                    />
                  </div>
                </div>
              </div>
            </div>
            
            <DialogFooter>
              <Button variant="outline" onClick={() => setCreateDialogOpen(false)}>
                Cancel
              </Button>
              <Button onClick={handleCreateAccount} disabled={creating}>
                {creating ? 'Creating...' : 'Create Account'}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Building className="h-5 w-5" />
            Tenant Accounts
            <Badge variant="outline">
              {totalCount} total
            </Badge>
          </CardTitle>
        </CardHeader>
        
        <CardContent className="p-0">
          {accounts.length === 0 ? (
            <div className="text-center py-12">
              <Building className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <h3 className="text-lg font-medium mb-2">No accounts found</h3>
              <p className="text-muted-foreground mb-4">
                Create the first tenant account to get started.
              </p>
              <Button onClick={() => setCreateDialogOpen(true)}>
                <Plus className="h-4 w-4 mr-2" />
                Create Account
              </Button>
            </div>
          ) : (
            <>
              {/* Mobile: stacked cards */}
              <div className="md:hidden divide-y divide-border">
                {accounts.map((account) => (
                  <div key={account.id} className="p-4 flex flex-col gap-2">
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                          <Building className="h-4 w-4" />
                        </div>
                        <div className="min-w-0">
                          <p className="font-medium truncate">{account.name}</p>
                          <p className="text-sm text-muted-foreground">ID: {account.id}</p>
                        </div>
                      </div>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="sm" className="shrink-0">
                            <MoreHorizontal className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem>
                            <Edit className="h-4 w-4 mr-2" />
                            Edit
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            className="text-destructive"
                            onClick={() => handleDeleteAccount(account.id, account.name)}
                          >
                            <Trash2 className="h-4 w-4 mr-2" />
                            Delete
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge className={`${PLAN_COLORS[account.plan]} capitalize`}>
                        {account.plan}
                      </Badge>
                      <Badge className={`${PAYMENT_STATUS_COLORS[account.payment_status]} capitalize`}>
                        {account.payment_status.replace('_', ' ')}
                      </Badge>
                      <span className="flex items-center gap-1 text-sm text-muted-foreground">
                        <Users className="h-4 w-4" />
                        {account.users.length}
                      </span>
                    </div>
                    <div className="text-sm text-muted-foreground font-mono">
                      {format(new Date(account.created_at), 'MMM d, yyyy')}
                    </div>
                  </div>
                ))}
              </div>

              <Table className="hidden md:table">
                <TableHeader>
                  <TableRow>
                    <TableHead>Account</TableHead>
                    <TableHead>Plan</TableHead>
                    <TableHead>Payment Status</TableHead>
                    <TableHead>Trial</TableHead>
                    <TableHead>Users</TableHead>
                    <TableHead>Created</TableHead>
                    <TableHead className="w-12"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {accounts.map((account) => (
                    <TableRow key={account.id}>
                      <TableCell className="font-medium">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                            <Building className="h-4 w-4" />
                          </div>
                          <div>
                            <p className="font-medium">{account.name}</p>
                            <p className="text-sm text-muted-foreground">ID: {account.id}</p>
                          </div>
                        </div>
                      </TableCell>
                      
                      <TableCell>
                        <Badge className={`${PLAN_COLORS[account.plan]} capitalize`}>
                          {account.plan}
                        </Badge>
                      </TableCell>
                      
                      <TableCell>
                        <Badge className={`${PAYMENT_STATUS_COLORS[account.payment_status]} capitalize`}>
                          {account.payment_status.replace('_', ' ')}
                        </Badge>
                      </TableCell>
                      
                      <TableCell>
                        {account.trial_ends_at ? (
                          <div className="text-sm">
                            <Badge variant={account.trial_expired ? 'destructive' : 'secondary'}>
                              {account.trial_expired ? 'Expired' : 'Active'}
                            </Badge>
                            <div className="text-muted-foreground mt-1 font-mono text-xs">
                              Ends {format(new Date(account.trial_ends_at), 'MMM d, yyyy')}
                            </div>
                          </div>
                        ) : (
                          <span className="text-muted-foreground">No trial</span>
                        )}
                      </TableCell>
                      
                      <TableCell>
                        <div className="flex items-center gap-1">
                          <Users className="h-4 w-4 text-muted-foreground" />
                          <span>{account.users.length}</span>
                        </div>
                      </TableCell>
                      
                      <TableCell>
                        <div className="text-sm font-mono">
                          <div>{format(new Date(account.created_at), 'MMM d, yyyy')}</div>
                          <div className="text-muted-foreground">
                            {format(new Date(account.created_at), 'h:mm a')}
                          </div>
                        </div>
                      </TableCell>
                      
                      <TableCell>
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="sm">
                              <MoreHorizontal className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem>
                              <Edit className="h-4 w-4 mr-2" />
                              Edit
                            </DropdownMenuItem>
                            <DropdownMenuItem 
                              className="text-destructive"
                              onClick={() => handleDeleteAccount(account.id, account.name)}
                            >
                              <Trash2 className="h-4 w-4 mr-2" />
                              Delete
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
              
              {totalPages > 1 && <Pagination />}
            </>
          )}
        </CardContent>
      </Card>

      {ConfirmDialog}
    </div>
  );
}