import { createConsumer } from "@rails/actioncable";
import { appSettings } from "./constants";

/**
 * Creates an ActionCable consumer with JWT auth via URL param.
 *
 * The URL is passed as a **function** so that ActionCable calls it on every
 * reconnection attempt, always picking up the latest token from localStorage
 * (which the token-refresh interceptor keeps fresh).
 */
export function createAuthenticatedConsumer() {
  if (!localStorage.getItem("messy_token")) return null;

  const getUrl = () => {
    const token = localStorage.getItem("messy_token");
    if (!token) return null;
    const apiUrl = appSettings.apiBaseUrl || "";
    return apiUrl.replace(/^http/, "ws") + "/cable?token=" + encodeURIComponent(token);
  };

  return createConsumer(getUrl);
}
