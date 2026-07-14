import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate, Outlet } from 'react-router-dom';
import { useSelector } from 'react-redux';
import { Toaster } from 'react-hot-toast';
import { RootState } from './store';
import { useAnalytics } from './hooks/useAnalytics';

// Bridges Redux auth state + router navigation into PostHog. Rendered inside
// <Router> so it can read the current location.
function AnalyticsBridge() {
  useAnalytics();
  return null;
}

class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { error: Error | null }
> {
  state = { error: null };
  static getDerivedStateFromError(error: Error) { return { error }; }
  render() {
    if (this.state.error) {
      return (
        <div className="p-8 text-center">
          <h2 className="text-lg font-semibold text-destructive mb-2">Something went wrong</h2>
          <pre className="text-xs text-muted-foreground bg-muted p-4 rounded text-left overflow-auto max-h-64">
            {(this.state.error as Error).message}
            {'\n'}
            {(this.state.error as Error).stack}
          </pre>
        </div>
      );
    }
    return this.props.children;
  }
}
import { Layout } from './components/layout/layout';
import { LoginPage } from './pages/login';
import { SignupPage } from './pages/signup';
import { VerifyEmailPage } from './pages/verify-email';
import { OnboardingPage } from './pages/onboarding';
import ValidatePage from './pages/validate';
import { DashboardPage } from './pages/dashboard';

// Real page components
import { TemplatesIndexPage } from './pages/templates/index';
import { TemplateEditPage } from './pages/templates/edit';
import { MessagesIndexPage } from './pages/messages/index';
import { MessageShowPage } from './pages/messages/show';
import { MessageComposePage } from './pages/messages/compose';
import { EnvironmentsIndexPage } from './pages/environments/index';
import { EnvironmentsCreatePage } from './pages/environments/create';
import { EnvironmentsEditPage } from './pages/environments/edit';
import { EnvironmentsTestPage } from './pages/environments/test';
import { IntegrationsIndexPage } from './pages/integrations/index';
import { IntegrationsEditPage } from './pages/integrations/edit';
import { SocialsIndexPage } from './pages/socials/index';
import { SocialsCalendarPage } from './pages/socials/calendar';
import { SocialsPostPage } from './pages/socials/post';
import { LiveActivityPage } from './pages/live-activity';
import { UsersIndexPage } from './pages/users/index';
import { RulesIndexPage } from './pages/rules/index';
import { RulesEditPage } from './pages/rules/edit';
import { AdminAccountsPage } from './pages/admin/accounts';
import { CustomersIndexPage } from './pages/customers/index';
import { CustomerShowPage } from './pages/customers/show';
import { SegmentsIndexPage } from './pages/segments/index';
import { SegmentsEditPage } from './pages/segments/edit';
import { CampaignsIndexPage } from './pages/campaigns/index';
import { CampaignWizardPage } from './pages/campaigns/wizard';
import { CampaignShowPage } from './pages/campaigns/show';
import { DripsIndexPage } from './pages/drips/index';
import { DripSetupPage } from './pages/drips/setup';
import { DripDesignerPage } from './pages/drips/edit';
import { SendingIdentitiesPage } from './pages/sending-identities/index';
import { LayoutsIndexPage } from './pages/layouts/index';
import { LayoutEditPage } from './pages/layouts/edit';
import { SettingsPage } from './pages/settings/index';
import { BillingPage } from './pages/settings/billing';
import { EmailFinderPage } from './pages/tools/email-finder';
import { McpIndexPage } from './pages/mcp/index';
import { OauthConsentPage } from './pages/oauth/consent';
import { InboxPage } from './pages/inbox/index';
import { ChatSettingsPage } from './pages/chat-settings/index';
import { OperatorProfilePage } from './pages/chat-settings/operator-profile';
import { HelpdeskPage } from './pages/helpdesk/index';
import { OperatorsPage } from './pages/operators/index';

// Placeholder components for remaining pages
const AdminUsersPage = () => <div className="p-6"><h1 className="text-2xl font-bold">Global Users</h1></div>;

function ProtectedRoute() {
  const { isAuthenticated, account } = useSelector((state: RootState) => state.auth);

  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (account?.status === 'pending_verification') return <Navigate to="/verify-email" replace />;
  if (!account?.onboarding_completed_at) return <Navigate to="/onboarding" replace />;

  return <Layout><ErrorBoundary><Outlet /></ErrorBoundary></Layout>;
}

// Requires auth only — no onboarding check (used for onboarding/verify pages themselves)
function AuthenticatedRoute({ children }: { children: React.ReactNode }) {
  const isAuthenticated = useSelector((state: RootState) => state.auth.isAuthenticated);
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

function SuperAdminRoute() {
  const user = useSelector((state: RootState) => state.auth.user);
  const isAuthenticated = useSelector((state: RootState) => state.auth.isAuthenticated);

  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (!user?.is_super_admin) return <Navigate to="/" replace />;

  return <Layout><Outlet /></Layout>;
}

function App() {
  return (
    <Router>
      <AnalyticsBridge />
      <div className="App">
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/signup" element={<SignupPage />} />
          <Route path="/verify-email" element={<VerifyEmailPage />} />
          <Route path="/validate/:token" element={<ValidatePage />} />
          {/* OAuth consent for MCP connectors — needs a logged-in user; the page
              itself redirects to login (preserving the return URL) if not. */}
          <Route path="/oauth/consent" element={<OauthConsentPage />} />
          <Route path="/onboarding" element={
            <AuthenticatedRoute><OnboardingPage /></AuthenticatedRoute>
          } />
          
          {/* Protected routes — require auth + onboarding */}
          <Route element={<ProtectedRoute />}>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/templates" element={<TemplatesIndexPage />} />
            <Route path="/templates/new" element={<TemplateEditPage />} />
            <Route path="/templates/:id/edit" element={<TemplateEditPage />} />
            <Route path="/layouts" element={<LayoutsIndexPage />} />
            <Route path="/layouts/new" element={<LayoutEditPage />} />
            <Route path="/layouts/:id/edit" element={<LayoutEditPage />} />
            <Route path="/messages" element={<MessagesIndexPage />} />
            <Route path="/messages/compose" element={<MessageComposePage />} />
            <Route path="/messages/:id" element={<MessageShowPage />} />
            <Route path="/environments" element={<EnvironmentsIndexPage />} />
            <Route path="/environments/create" element={<EnvironmentsCreatePage />} />
            <Route path="/environments/:id/edit" element={<EnvironmentsEditPage />} />
            <Route path="/environments/:id/test" element={<EnvironmentsTestPage />} />
            <Route path="/integrations" element={<IntegrationsIndexPage />} />
            <Route path="/socials" element={<SocialsIndexPage />} />
            <Route path="/socials/:regionId" element={<SocialsCalendarPage />} />
            <Route path="/socials/:regionId/:date" element={<SocialsPostPage />} />
            <Route path="/integrations/create" element={<IntegrationsEditPage />} />
            <Route path="/integrations/:id/edit" element={<IntegrationsEditPage />} />
            <Route path="/rules" element={<RulesIndexPage />} />
            <Route path="/rules/create" element={<RulesEditPage />} />
            <Route path="/rules/:id/edit" element={<RulesEditPage />} />
            <Route path="/inbox" element={<InboxPage />} />
            <Route path="/inbox/:id" element={<InboxPage />} />
            <Route path="/admin/chat-widget" element={<ChatSettingsPage />} />
            <Route path="/admin/chat-widget/:tab" element={<ChatSettingsPage />} />
            <Route path="/admin/help-desk" element={<HelpdeskPage />} />
            <Route path="/admin/help-desk/:tab" element={<HelpdeskPage />} />
            <Route path="/operator-profile" element={<OperatorProfilePage />} />
            <Route path="/admin/operators" element={<OperatorsPage />} />
            <Route path="/live-activity" element={<LiveActivityPage />} />
            <Route path="/users" element={<UsersIndexPage />} />
            <Route path="/customers" element={<CustomersIndexPage />} />
            <Route path="/customers/:id" element={<CustomerShowPage />} />
            <Route path="/segments" element={<SegmentsIndexPage />} />
            <Route path="/segments/new" element={<SegmentsEditPage />} />
            <Route path="/segments/:id/edit" element={<SegmentsEditPage />} />
            <Route path="/campaigns" element={<CampaignsIndexPage />} />
            <Route path="/campaigns/new" element={<CampaignWizardPage />} />
            <Route path="/campaigns/:id/edit" element={<CampaignWizardPage />} />
            <Route path="/campaigns/:id" element={<CampaignShowPage />} />
            <Route path="/drips" element={<DripsIndexPage />} />
            <Route path="/drips/new" element={<DripSetupPage />} />
            <Route path="/drips/:id/edit" element={<DripDesignerPage />} />
            <Route path="/admin/domain" element={<SettingsPage />} />
            <Route path="/settings/billing" element={<BillingPage />} />
            <Route path="/identities" element={<SendingIdentitiesPage />} />
            <Route path="/tools/email-finder" element={<EmailFinderPage />} />
            <Route path="/mcp" element={<McpIndexPage />} />
          </Route>

          {/* Super Admin routes */}
          <Route element={<SuperAdminRoute />}>
            <Route path="/admin/accounts" element={<AdminAccountsPage />} />
            <Route path="/admin/users" element={<AdminUsersPage />} />
          </Route>
        </Routes>
        
        <Toaster 
          position="top-right"
          toastOptions={{
            duration: 4000,
          }}
        />
      </div>
    </Router>
  );
}

export default App;