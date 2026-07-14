import { useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";

/**
 * Manages tab navigation via URL path params.
 * The first tab in `validTabs` is the default and uses the bare `basePath`.
 * Other tabs navigate to `basePath/:tab`.
 */
export function useTabNavigation(basePath: string, validTabs: readonly string[]) {
  const { tab: tabParam } = useParams();
  const navigate = useNavigate();

  const defaultTab = validTabs[0];
  const activeTab = validTabs.includes(tabParam || "") ? tabParam! : defaultTab;

  const setActiveTab = useCallback(
    (tab: string) => {
      navigate(tab === defaultTab ? basePath : `${basePath}/${tab}`, { replace: true });
    },
    [navigate, basePath, defaultTab]
  );

  return [activeTab, setActiveTab] as const;
}
