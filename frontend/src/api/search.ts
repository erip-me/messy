import { headerJson } from "../utils/constants";
import request from "../utils/request";

export interface SearchResult {
  id: number;
  type: 'template' | 'message';
  title: string;
  subtitle?: string;
  url: string;
  match_field?: string;
  snippet?: string;
}

export interface SearchResponse {
  results: SearchResult[];
  total_count: number;
  query: string;
}

const controller = "/search";

export const globalSearch = async (query: string, limit: number = 10): Promise<SearchResponse> => {
  const params = new URLSearchParams({
    q: query,
    limit: limit.toString(),
  });

  const response = await request({
    url: `${controller}?${params.toString()}`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};