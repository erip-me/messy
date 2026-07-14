import request from "../utils/request";

export interface HelpdeskStats {
  open_count: number;
  pending_count: number;
  resolved_count: number;
  closed_count: number;
  unassigned_count: number;
  tickets_today: number;
  tickets_this_week: number;
  avg_first_response_seconds: number | null;
  avg_resolution_seconds: number | null;
  per_operator: {
    user_id: number;
    name: string;
    avatar_url: string | null;
    open_count: number;
    pending_count: number;
    resolved_today: number;
  }[];
}

export function getHelpdeskStats() {
  return request.get<HelpdeskStats>("/helpdesk/stats");
}
