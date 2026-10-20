import { useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { Check, ChevronsUpDown, Settings2 } from 'lucide-react';
import { RootState } from '@/store';
import { setActiveWorkspace, Workspace } from '@/store/workspace-slice';
import { setActiveEnvironment, clearEnvironment } from '@/store/environment-slice';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { cn } from '@/lib/utils';
import { getInitials } from '@/utils/initials';
import { tagStyle } from '@/utils/tag-colors';

/** Only what the picker needs — the /users/me workspace list carries this much. */
type EnvOption = { id: number; name: string };

// Workspace face for the switcher: the operator profile avatar where there is
// one, otherwise initials on the same deterministic palette the tag chips use,
// so each workspace keeps a stable colour instead of a wall of grey.
export function WorkspaceAvatar({ ws, className }: { ws: Workspace; className?: string }) {
  const [first, second] = ws.name.split(/\s+/);
  return (
    <Avatar className={cn('h-6 w-6 shrink-0', className)}>
      {ws.avatar_url && <AvatarImage src={ws.avatar_url} alt="" />}
      <AvatarFallback className="text-[10px] font-semibold leading-none" style={tagStyle(ws.name)}>
        {getInitials(first, second, ws.name)}
      </AvatarFallback>
    </Avatar>
  );
}

function EnvironmentItem({
  env,
  selected,
  onSelect,
}: {
  env: EnvOption;
  selected: boolean;
  onSelect: () => void;
}) {
  return (
    <DropdownMenuItem className="gap-2.5" onSelect={onSelect}>
      <span
        className={cn(
          'h-1.5 w-1.5 shrink-0 rounded-full',
          selected ? 'bg-primary' : 'bg-muted-foreground/40'
        )}
      />
      <span className={cn('truncate', selected && 'font-medium text-foreground')}>{env.name}</span>
      {selected && <Check className="ml-auto h-4 w-4 shrink-0 text-primary" />}
    </DropdownMenuItem>
  );
}

interface WorkspaceSwitcherProps {
  /** Called after a pick — used to close the mobile drawer. */
  onNavigate?: () => void;
}

/**
 * Workspace × environment picker.
 *
 * The two selections are one hierarchy, not two independent lists: environments
 * belong to a workspace, so they live one level in — each workspace row opens a
 * submenu of its own environments (Radix drives hover/click/arrow-key traversal).
 * With a single workspace there is nothing to branch on, so the environments are
 * promoted to the top level instead of hiding behind one pointless submenu.
 */
export function WorkspaceSwitcher({ onNavigate }: WorkspaceSwitcherProps) {
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const environments = useSelector((state: RootState) => state.environment.environments);
  const activeEnvironmentId = useSelector((state: RootState) => state.environment.activeEnvironmentId);
  const workspaces = useSelector((state: RootState) => state.workspace.workspaces);
  const activeWorkspaceId = useSelector((state: RootState) => state.workspace.activeWorkspaceId);

  // The active workspace's list comes from the store (refetched on every switch,
  // so it reflects environments added since sign-in); the others come from the
  // /users/me payload, which is enough to render and click through the tree.
  //
  // Sorted by id — neither payload is ordered, so without this the rows shuffle
  // between workspaces and "switch to this workspace" picks an arbitrary
  // environment as the default.
  const environmentsFor = (ws: { id: number; environments?: EnvOption[] }): EnvOption[] => {
    const envs = ws.id === activeWorkspaceId && environments.length ? environments : ws.environments || [];
    return [...envs].sort((a, b) => a.id - b.id);
  };

  const activeWorkspace = workspaces.find((w) => w.id === activeWorkspaceId);
  const activeEnvironment = activeWorkspace
    ? environmentsFor(activeWorkspace).find((e) => e.id === activeEnvironmentId)
    : undefined;

  const justSelectedRef = useRef(false);

  // One pick sets both. Setting the target environment up front (instead of
  // clearing and waiting for the refetch to auto-select the first one) is what
  // makes "switch straight to workspace B's UAT" possible — the refetch keeps
  // the selection because it's in the new workspace's list.
  const switchTo = (workspaceId: number, environmentId?: number) => {
    justSelectedRef.current = true;
    if (workspaceId !== activeWorkspaceId) {
      dispatch(clearEnvironment());
      dispatch(setActiveWorkspace(workspaceId));
      if (environmentId) dispatch(setActiveEnvironment(environmentId));
      navigate('/');
      onNavigate?.();
    } else if (environmentId && environmentId !== activeEnvironmentId) {
      dispatch(setActiveEnvironment(environmentId));
    }
  };

  // Environments are workspace-scoped, so land in the right workspace first.
  const manageEnvironments = (workspaceId: number, environmentId?: number) => {
    switchTo(workspaceId, environmentId);
    navigate('/environments');
    onNavigate?.();
  };

  const multiWorkspace = workspaces.length > 1;

  // Nothing to pick: a lone workspace with no environments yet.
  if (!multiWorkspace && environments.length === 0) return null;

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        aria-label="Switch workspace or environment"
        className="flex w-full items-center gap-2.5 rounded-lg border border-input bg-card px-2.5 py-2 text-left transition-colors hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-1 data-[state=open]:bg-accent"
      >
        {activeWorkspace && <WorkspaceAvatar ws={activeWorkspace} className="h-7 w-7" />}
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-medium leading-tight text-foreground">
            {activeWorkspace?.name || 'Select workspace'}
          </span>
          <span className="block truncate text-xs leading-tight text-muted-foreground">
            {activeEnvironment?.name || 'No environment'}
          </span>
        </span>
        <ChevronsUpDown className="h-4 w-4 shrink-0 text-muted-foreground" />
      </DropdownMenuTrigger>
      <DropdownMenuContent
        align="start"
        // Trigger width is the floor, not the cap: the sidebar is narrow enough
        // that workspace names would truncate at 2–3 words.
        className="max-h-[70vh] w-[var(--radix-dropdown-menu-trigger-width)] min-w-[17rem] overflow-y-auto"
        // Radix hands focus back to the trigger on close, which leaves a focus
        // ring sitting there after a pick. Skip that on an actual selection
        // only — dismissing with Escape still returns focus.
        onCloseAutoFocus={(e) => {
          if (justSelectedRef.current) e.preventDefault();
          justSelectedRef.current = false;
        }}
      >
        {multiWorkspace ? (
          <>
            <DropdownMenuLabel>Workspaces</DropdownMenuLabel>
            {workspaces.map((ws) => {
              const envs = environmentsFor(ws);
              const isActiveWorkspace = ws.id === activeWorkspaceId;

              // A workspace with no environments has no second level, so it acts
              // directly rather than opening an empty submenu.
              if (envs.length === 0) {
                return (
                  <DropdownMenuItem
                    key={ws.id}
                    className="gap-2.5"
                    onSelect={() => switchTo(ws.id)}
                  >
                    <WorkspaceAvatar ws={ws} />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-medium text-foreground">{ws.name}</span>
                      <span className="block truncate text-xs text-muted-foreground">
                        No environments
                      </span>
                    </span>
                    {isActiveWorkspace && <Check className="h-4 w-4 shrink-0 text-primary" />}
                  </DropdownMenuItem>
                );
              }

              return (
                <DropdownMenuSub key={ws.id}>
                  <DropdownMenuSubTrigger className="gap-2.5">
                    <WorkspaceAvatar ws={ws} />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-medium text-foreground">{ws.name}</span>
                      <span className="block truncate text-xs text-muted-foreground">
                        {isActiveWorkspace && activeEnvironment
                          ? activeEnvironment.name
                          : `${envs.length} environment${envs.length === 1 ? '' : 's'}`}
                      </span>
                    </span>
                    {isActiveWorkspace && (
                      <Check className="ml-auto mr-1.5 h-4 w-4 shrink-0 text-primary" />
                    )}
                  </DropdownMenuSubTrigger>
                  <DropdownMenuSubContent className="max-h-[70vh] min-w-[13rem] overflow-y-auto">
                    <DropdownMenuLabel className="truncate">{ws.name}</DropdownMenuLabel>
                    {envs.map((env) => (
                      <EnvironmentItem
                        key={env.id}
                        env={env}
                        selected={isActiveWorkspace && env.id === activeEnvironmentId}
                        onSelect={() => switchTo(ws.id, env.id)}
                      />
                    ))}
                    <DropdownMenuSeparator />
                    <DropdownMenuItem
                      className="gap-2.5 text-muted-foreground"
                      onSelect={() => manageEnvironments(ws.id, envs[0]?.id)}
                    >
                      <Settings2 className="h-4 w-4 shrink-0" />
                      Manage environments
                    </DropdownMenuItem>
                  </DropdownMenuSubContent>
                </DropdownMenuSub>
              );
            })}
          </>
        ) : (
          <>
            <DropdownMenuLabel className="truncate">
              {activeWorkspace?.name || 'Environments'}
            </DropdownMenuLabel>
            {[...environments].sort((a, b) => a.id - b.id).map((env) => (
              <EnvironmentItem
                key={env.id}
                env={env}
                selected={env.id === activeEnvironmentId}
                onSelect={() => {
                  justSelectedRef.current = true;
                  dispatch(setActiveEnvironment(env.id));
                }}
              />
            ))}
            <DropdownMenuSeparator />
            <DropdownMenuItem
              className="gap-2.5 text-muted-foreground"
              onSelect={() => {
                justSelectedRef.current = true;
                navigate('/environments');
                onNavigate?.();
              }}
            >
              <Settings2 className="h-4 w-4 shrink-0" />
              Manage environments
            </DropdownMenuItem>
          </>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
