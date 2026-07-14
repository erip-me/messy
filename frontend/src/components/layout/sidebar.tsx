import { useEffect, useState, useRef } from 'react';
import { NavLink, useNavigate, useLocation } from 'react-router-dom';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '@/store';
import { logout } from '@/store/auth-slice';
import nameLogo from '@/assets/nameLogo.png';
import { setEnvironments, setActiveEnvironment } from '@/store/environment-slice';
import { cn } from '@/lib/utils';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import request from '@/utils/request';
import { getConversationStats } from '@/api/conversations';
import { createAuthenticatedConsumer } from '@/utils/cable';
import { useTheme } from '@/hooks/useTheme';
import {
  Home,
  Mail,
  FileText,
  Send,
  Globe,
  Settings,
  Activity,
  Users2,
  UserCog,
  Power,
  Layers,
  LayoutTemplate,
  Megaphone,
  MessageCircle,
  User,
  ChevronRight,
  Inbox,
  Zap,
  AtSign,
  CreditCard,
  Plug,
  Share2,
  X,
  Sun,
  Moon,
  type LucideIcon,
} from 'lucide-react';

interface SidebarProps {
  /** Called after a navigation action — used to close the mobile drawer. */
  onNavigate?: () => void;
}

interface NavItem {
  name: string;
  href: string;
  icon: LucideIcon;
}

interface NavSection {
  label: string;
  items: NavItem[];
}

const sections: NavSection[] = [
  {
    label: 'Messaging',
    items: [
      { name: 'Layouts', href: '/layouts', icon: LayoutTemplate },
      { name: 'Templates', href: '/templates', icon: FileText },
      { name: 'Transactional', href: '/messages', icon: Mail },
      { name: 'Campaigns', href: '/campaigns', icon: Megaphone },
      { name: 'Socials', href: '/socials', icon: Share2 },
      { name: 'Drips', href: '/drips', icon: Zap },
      { name: 'Automations', href: '/rules', icon: Send },
    ],
  },
  {
    label: 'Audience',
    items: [
      { name: 'Contacts', href: '/customers', icon: Users2 },
      { name: 'Segments', href: '/segments', icon: Layers },
    ],
  },
];

const adminSection: NavSection = {
  label: 'Settings',
  items: [
    { name: 'Integrations', href: '/integrations', icon: Settings },
    { name: 'Identities', href: '/identities', icon: AtSign },
    { name: 'Environments', href: '/environments', icon: Globe },
    { name: 'Chat Widget', href: '/admin/chat-widget', icon: MessageCircle },
    { name: 'Operators', href: '/admin/operators', icon: Users2 },
    { name: 'Team', href: '/users', icon: UserCog },
    { name: 'MCP Server', href: '/mcp', icon: Plug },
    { name: 'Domain', href: '/admin/domain', icon: Settings },
    { name: 'Billing', href: '/settings/billing', icon: CreditCard },
    { name: 'Your Profile', href: '/operator-profile', icon: User },
  ],
};

function sectionMatchesPath(section: NavSection, pathname: string): boolean {
  return section.items.some(
    (item) => pathname === item.href || pathname.startsWith(item.href + '/')
  );
}

export function Sidebar({ onNavigate }: SidebarProps = {}) {
  const user = useSelector((state: RootState) => state.auth.user);
  const environments = useSelector((state: RootState) => state.environment.environments);
  const activeEnvironmentId = useSelector((state: RootState) => state.environment.activeEnvironmentId);
  const dispatch = useDispatch();
  const navigate = useNavigate();
  const location = useLocation();
  const { resolved: theme, toggle: toggleTheme } = useTheme();

  // Track which sections are expanded; restore from localStorage, auto-expand current path
  const [expanded, setExpanded] = useState<Record<string, boolean>>(() => {
    const saved = localStorage.getItem('messy_sidebar_expanded');
    const persisted: Record<string, boolean> = saved ? JSON.parse(saved) : {};
    const initial: Record<string, boolean> = {};
    [...sections, adminSection].forEach((s) => {
      initial[s.label] = persisted[s.label] ?? sectionMatchesPath(s, location.pathname);
    });
    return initial;
  });

  // Auto-expand section on navigation (don't collapse others)
  useEffect(() => {
    setExpanded((prev) => {
      const next = { ...prev };
      [...sections, adminSection].forEach((s) => {
        if (sectionMatchesPath(s, location.pathname)) {
          next[s.label] = true;
        }
      });
      return next;
    });
  }, [location.pathname]);

  // Persist expand state to localStorage
  useEffect(() => {
    localStorage.setItem('messy_sidebar_expanded', JSON.stringify(expanded));
  }, [expanded]);

  const toggleSection = (label: string) => {
    setExpanded((prev) => ({ ...prev, [label]: !prev[label] }));
  };

  useEffect(() => {
    const fetchEnvironments = async () => {
      try {
        const res = await request.get('/environments');
        const envs = Array.isArray(res.data) ? res.data : res.data?.environments || [];
        dispatch(setEnvironments(envs));
      } catch (e) {
        // silent
      }
    };
    fetchEnvironments();
  }, [dispatch]);

  const handleLogout = () => {
    dispatch(logout());
    navigate('/login');
  };

  // Operator presence — global WebSocket connection + heartbeat
  const [operatorStatus, setOperatorStatus] = useState<'online' | 'away' | 'offline'>('offline');
  const [inboxUnread, setInboxUnread] = useState(0);
  const presenceSubRef = useRef<any>(null);
  const cableRef = useRef<any>(null);

  const refreshUnread = () => {
    getConversationStats().then((res) => setInboxUnread(res.data.unread)).catch(() => {});
  };

  useEffect(() => {
    const cable = createAuthenticatedConsumer();
    if (!cable) return;
    cableRef.current = cable;

    // Load current status + unread count
    request.get('/operator_profile').then((res) => {
      if (res.data.operator_profile) {
        setOperatorStatus(res.data.operator_profile.availability || 'offline');
      }
    }).catch(() => {});
    refreshUnread();

    const sub = cable.subscriptions.create(
      { channel: 'OperatorPresenceChannel' },
      { received() {} }
    );
    presenceSubRef.current = sub;

    const inboxSub = cable.subscriptions.create(
      { channel: 'OperatorInboxChannel' },
      {
        received(data: any) {
          if (data.type === 'new_message' || data.type === 'new_conversation') {
            refreshUnread();
          }
        },
      }
    );

    // Heartbeat every 60s via WebSocket, with REST fallback
    const interval = setInterval(() => {
      sub.perform('heartbeat');
      request.post('/operator_profile/heartbeat').catch(() => {});
    }, 60000);

    return () => {
      clearInterval(interval);
      inboxSub.unsubscribe();
      sub.unsubscribe();
      cable.disconnect();
    };
  }, [user?.id]);

  // Refresh unread when inbox marks messages as read
  useEffect(() => {
    const handler = () => refreshUnread();
    window.addEventListener('messy:inbox-read', handler);
    return () => window.removeEventListener('messy:inbox-read', handler);
  }, []);

  function togglePresence() {
    const next = operatorStatus === 'online' ? 'offline' : 'online';
    setOperatorStatus(next);
    presenceSubRef.current?.perform('set_availability', { status: next });
    request.patch('/operator_profile', { availability: next }).catch(() => {});
  }

  const renderSection = (section: NavSection) => {
    const isExpanded = expanded[section.label] ?? false;
    const isActiveSection = sectionMatchesPath(section, location.pathname);

    return (
      <div key={section.label}>
        <button
          onClick={() => toggleSection(section.label)}
          className={cn(
            'flex items-center w-full px-3 py-1.5 text-xs font-semibold tracking-wider uppercase rounded-lg transition-colors',
            isActiveSection
              ? 'text-foreground'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          <ChevronRight
            className={cn(
              'h-3 w-3 mr-1.5 transition-transform duration-200',
              isExpanded && 'rotate-90'
            )}
          />
          {section.label}
        </button>

        <div
          className={cn(
            'overflow-hidden transition-all duration-200',
            isExpanded ? 'max-h-96 opacity-100' : 'max-h-0 opacity-0'
          )}
        >
          <div className="ml-[11px] pl-3 border-l border-border mt-0.5 mb-1 space-y-0.5">
            {section.items.map((item) => (
              <NavLink
                key={item.name}
                to={item.href}
                onClick={onNavigate}
                className={({ isActive }) =>
                  cn(
                    'flex items-center px-2.5 py-1.5 text-[13px] font-medium rounded-lg transition-colors',
                    isActive
                      ? 'bg-accent text-accent-foreground'
                      : 'text-muted-foreground hover:text-foreground hover:bg-muted'
                  )
                }
              >
                <item.icon className="mr-2.5 h-4 w-4" />
                {item.name}
              </NavLink>
            ))}
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="flex flex-col h-full sidebar-bg border-r border-border">
      <div className="px-6 pt-6 pb-4 border-b border-border">
        <div className="flex items-center justify-between mb-4">
          <img
            src={nameLogo}
            alt="Messy"
            className="h-10 w-auto cursor-pointer"
            onClick={() => {
              navigate('/');
              onNavigate?.();
            }}
          />
          <button
            onClick={onNavigate}
            className="p-2 -mr-2 rounded-lg text-muted-foreground hover:text-foreground hover:bg-muted transition-colors lg:hidden"
            aria-label="Close menu"
          >
            <X className="h-5 w-5" />
          </button>
        </div>
        {environments.length > 0 && (
          <Select
            value={String(activeEnvironmentId || '')}
            onValueChange={(val) => dispatch(setActiveEnvironment(Number(val)))}
          >
            <SelectTrigger className="bg-card text-sm h-9 transition-colors">
              <SelectValue placeholder="Select environment" />
            </SelectTrigger>
            <SelectContent>
              {environments.map((env) => (
                <SelectItem key={env.id} value={String(env.id)}>
                  {env.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
      </div>

      <nav className="flex-1 px-4 py-4 space-y-1 overflow-y-auto">
        {/* Primary destinations — standalone */}
        <NavLink
          to="/"
          end
          onClick={onNavigate}
          className={({ isActive }) =>
            cn(
              'flex items-center px-3 py-2 text-sm font-medium rounded-lg transition-colors',
              isActive
                ? 'bg-accent text-accent-foreground'
                : 'text-muted-foreground hover:text-foreground hover:bg-muted'
            )
          }
        >
          <Home className="mr-3 h-5 w-5" />
          Overview
        </NavLink>
        <NavLink
          to="/live-activity"
          onClick={onNavigate}
          className={({ isActive }) =>
            cn(
              'flex items-center px-3 py-2 text-sm font-medium rounded-lg transition-colors mb-1',
              isActive
                ? 'bg-accent text-accent-foreground'
                : 'text-muted-foreground hover:text-foreground hover:bg-muted'
            )
          }
        >
          <Activity className="mr-3 h-5 w-5" />
          Activity
        </NavLink>
        <NavLink
          to="/inbox"
          onClick={onNavigate}
          className={({ isActive }) =>
            cn(
              'flex items-center px-3 py-2 text-sm font-medium rounded-lg transition-colors mb-1',
              isActive
                ? 'bg-accent text-accent-foreground'
                : 'text-muted-foreground hover:text-foreground hover:bg-muted'
            )
          }
        >
          <MessageCircle className="mr-3 h-5 w-5" />
          Inbox
          {inboxUnread > 0 && (
            <span className="ml-auto bg-red-500 text-white text-[10px] font-bold leading-none px-1.5 py-0.5 rounded-full min-w-[18px] text-center">
              {inboxUnread > 99 ? '99+' : inboxUnread}
            </span>
          )}
        </NavLink>
        <NavLink
          to="/admin/help-desk"
          onClick={onNavigate}
          className={({ isActive }) =>
            cn(
              'flex items-center px-3 py-2 text-sm font-medium rounded-lg transition-colors mb-1',
              isActive
                ? 'bg-accent text-accent-foreground'
                : 'text-muted-foreground hover:text-foreground hover:bg-muted'
            )
          }
        >
          <Inbox className="mr-3 h-5 w-5" />
          Help Center
        </NavLink>

        {/* Grouped sections */}
        {sections.map(renderSection)}

        {/* Admin section */}
        {renderSection(adminSection)}
      </nav>

      <div className="border-t border-border px-4 py-4">
        <div className="flex items-center space-x-3 px-3 py-2 rounded-lg hover:bg-muted transition-colors">
          <button
            onClick={togglePresence}
            className="relative w-10 h-10 avatar-teal rounded-full flex items-center justify-center text-white"
            title={`Status: ${operatorStatus} (click to toggle)`}
          >
            <span className="text-sm font-semibold">
              {user?.name?.charAt(0)?.toUpperCase()}
            </span>
            <span
              className={cn(
                'absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full border-2 border-[hsl(var(--sidebar-bg))]',
                operatorStatus === 'online' ? 'bg-green-400' : operatorStatus === 'away' ? 'bg-yellow-400' : 'bg-gray-400'
              )}
            />
          </button>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-foreground truncate">{user?.name}</p>
            <p className="text-xs text-muted-foreground truncate">{user?.email}</p>
          </div>
          <button
            onClick={toggleTheme}
            className="p-2 rounded-lg text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
            title={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
            aria-label="Toggle dark mode"
          >
            {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          </button>
          <button
            onClick={handleLogout}
            className="p-2 rounded-lg text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
            title="Logout"
          >
            <Power className="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
