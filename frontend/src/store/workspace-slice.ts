import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { logout } from './auth-slice';

export interface Workspace {
  id: number;
  name: string;
  // Mirrors AccountMembership#role, and feeds auth.user.role on a switch.
  role: 'admin' | 'member';
}

interface WorkspaceState {
  workspaces: Workspace[];
  // Invitations awaiting this person's decision. Deliberately separate from
  // `workspaces`: being invited grants nothing until they accept, so these must
  // never feed the switcher.
  pendingWorkspaces: Workspace[];
  activeWorkspaceId: number | null;
}

const savedWorkspaceId = localStorage.getItem('messy_active_workspace');

const initialState: WorkspaceState = {
  workspaces: [],
  pendingWorkspaces: [],
  activeWorkspaceId: savedWorkspaceId ? Number(savedWorkspaceId) : null,
};

const workspaceSlice = createSlice({
  name: 'workspace',
  initialState,
  reducers: {
    setWorkspaces: (state, action: PayloadAction<Workspace[]>) => {
      state.workspaces = action.payload;
      // Drop a stale selection (e.g. a workspace the user was removed from)
      // rather than keep sending an id the server will now reject.
      const currentValid = action.payload.some((w) => w.id === state.activeWorkspaceId);
      if ((!state.activeWorkspaceId || !currentValid) && action.payload.length > 0) {
        state.activeWorkspaceId = action.payload[0].id;
        localStorage.setItem('messy_active_workspace', String(action.payload[0].id));
      }
    },
    setPendingWorkspaces: (state, action: PayloadAction<Workspace[]>) => {
      state.pendingWorkspaces = action.payload;
    },
    setActiveWorkspace: (state, action: PayloadAction<number>) => {
      state.activeWorkspaceId = action.payload;
      localStorage.setItem('messy_active_workspace', String(action.payload));
    },
    clearWorkspace: (state) => {
      state.workspaces = [];
      state.pendingWorkspaces = [];
      state.activeWorkspaceId = null;
      localStorage.removeItem('messy_active_workspace');
    },
  },
  // The selection belongs to the session, not the browser. Left behind, the next
  // person to sign in here sends the previous user's X-Account-Id and eats a 403
  // on their first request.
  extraReducers: (builder) => {
    builder.addCase(logout, (state) => {
      state.workspaces = [];
      state.pendingWorkspaces = [];
      state.activeWorkspaceId = null;
      localStorage.removeItem('messy_active_workspace');
    });
  },
});

export const { setWorkspaces, setPendingWorkspaces, setActiveWorkspace, clearWorkspace } =
  workspaceSlice.actions;
export default workspaceSlice;
