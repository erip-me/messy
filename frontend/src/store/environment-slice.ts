import { createSlice, PayloadAction } from '@reduxjs/toolkit';

export interface Environment {
  id: number;
  name: string;
  tag?: string;
  api_key?: string;
}

interface EnvironmentState {
  environments: Environment[];
  activeEnvironmentId: number | null;
}

const savedEnvId = localStorage.getItem('messy_active_env');

const initialState: EnvironmentState = {
  environments: [],
  activeEnvironmentId: savedEnvId ? Number(savedEnvId) : null,
};

const environmentSlice = createSlice({
  name: 'environment',
  initialState,
  reducers: {
    setEnvironments: (state, action: PayloadAction<Environment[]>) => {
      state.environments = action.payload;
      // Auto-select first if none selected or current selection is stale
      const currentValid = action.payload.some(e => e.id === state.activeEnvironmentId);
      if ((!state.activeEnvironmentId || !currentValid) && action.payload.length > 0) {
        state.activeEnvironmentId = action.payload[0].id;
        localStorage.setItem('messy_active_env', String(action.payload[0].id));
      }
    },
    setActiveEnvironment: (state, action: PayloadAction<number>) => {
      state.activeEnvironmentId = action.payload;
      localStorage.setItem('messy_active_env', String(action.payload));
    },
  },
});

export const { setEnvironments, setActiveEnvironment } = environmentSlice.actions;
export default environmentSlice;
