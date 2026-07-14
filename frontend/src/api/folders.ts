import { headerJson } from "../utils/constants";
import request from "../utils/request";

export interface Folder {
  id: number;
  name: string;
  parent_folder_id?: number;
  environment_id: number;
  account_id: number;
  is_deleted: boolean;
  created_at: string;
  updated_at: string;
  child_folders?: Folder[];
  templates?: {
    id: number;
    name: string;
    trigger: string;
    created_at: string;
    updated_at: string;
  }[];
}

export interface CreateFolderRequest {
  name: string;
  parent_folder_id?: number;
  environment_id?: number;
}

export interface UpdateFolderRequest {
  name?: string;
  parent_folder_id?: number;
}

export interface MoveFolderRequest {
  target_folder_id?: number;
}

const controller = "/folders";

export const getFolders = async (apiKey: string, environment_id?: number): Promise<Folder[]> => {
  const params = new URLSearchParams();
  if (environment_id !== undefined) params.append('environment_id', environment_id.toString());

  const response = await request({
    url: `${controller}${params.toString() ? `?${params.toString()}` : ''}`,
    method: "GET",
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const getFolderById = async (id: number, apiKey: string): Promise<Folder> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "GET",
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const createFolder = async (data: CreateFolderRequest, apiKey: string): Promise<Folder> => {
  const response = await request({
    url: controller,
    method: "POST",
    data,
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const updateFolder = async (id: number, data: UpdateFolderRequest, apiKey: string): Promise<Folder> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "PATCH",
    data,
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const deleteFolder = async (id: number, apiKey: string): Promise<void> => {
  await request({
    url: `${controller}/${id}`,
    method: "DELETE",
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
};

// Uses standard JWT auth (via request interceptor) instead of apiKey
export const listFolders = () =>
  request.get<Folder[]>(controller).then(r => r.data);

export const moveFolder = async (id: number, data: MoveFolderRequest, apiKey: string): Promise<Folder> => {
  const response = await request({
    url: `${controller}/${id}/move`,
    method: "POST",
    data,
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};