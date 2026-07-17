const BACKEND_PORT = "3000";

function resolveApiBase() {
    if (window.location.protocol === "file:") {
        return `http://localhost:${BACKEND_PORT}/api`;
    }

    if (window.location.port === BACKEND_PORT) {
        return "/api";
    }

    const host = window.location.hostname || "localhost";
    return `http://${host}:${BACKEND_PORT}/api`;
}

const API_BASE = resolveApiBase();

const TOKEN_KEY = "antor_token";
const USER_KEY = "antor_user";
const REMEMBER_KEY = "antor_remember";
const REMEMBER_EMAIL_KEY = "antor_remember_email";
const VALUES_HIDDEN_KEY = "antor_vendas_values_hidden";

function getToken() {
    return sessionStorage.getItem(TOKEN_KEY) || localStorage.getItem(TOKEN_KEY);
}

function getUser() {
    const raw = sessionStorage.getItem(USER_KEY) || localStorage.getItem(USER_KEY);
    if (!raw) return null;
    try {
        return JSON.parse(raw);
    } catch {
        return null;
    }
}

function setSession(token, user, options = {}) {
    const remember = Boolean(options.remember);
    const storage = remember ? localStorage : sessionStorage;
    const other = remember ? sessionStorage : localStorage;

    storage.setItem(TOKEN_KEY, token);
    storage.setItem(USER_KEY, JSON.stringify(user));
    other.removeItem(TOKEN_KEY);
    other.removeItem(USER_KEY);

    sessionStorage.setItem(VALUES_HIDDEN_KEY, "1");
    localStorage.removeItem(VALUES_HIDDEN_KEY);
}

function saveRememberLogin(email, remember) {
    if (remember && email) {
        localStorage.setItem(REMEMBER_KEY, "1");
        localStorage.setItem(REMEMBER_EMAIL_KEY, email);
        return;
    }

    localStorage.removeItem(REMEMBER_KEY);
    localStorage.removeItem(REMEMBER_EMAIL_KEY);
}

function getRememberLogin() {
    return {
        remember: localStorage.getItem(REMEMBER_KEY) === "1",
        email: localStorage.getItem(REMEMBER_EMAIL_KEY) || "",
    };
}

function clearSession() {
    sessionStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(USER_KEY);
    sessionStorage.removeItem(VALUES_HIDDEN_KEY);
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    localStorage.removeItem(VALUES_HIDDEN_KEY);
}

function isAuthenticated() {
    return Boolean(getToken());
}

async function apiFetch(path, options = {}) {
    const headers = { ...(options.headers || {}) };

    if (options.body && !headers["Content-Type"]) {
        headers["Content-Type"] = "application/json";
    }

    const token = getToken();
    if (token) {
        headers.Authorization = `Bearer ${token}`;
    }

    const response = await fetch(`${API_BASE}${path}`, {
        ...options,
        headers,
    });

    let data = null;
    const contentType = response.headers.get("content-type") || "";
    if (contentType.includes("application/json")) {
        data = await response.json();
    }

    if (!response.ok) {
        const message = data?.error || "Erro na requisição.";
        throw new Error(message);
    }

    return data;
}

function requireAuth(redirectTo = "../login/") {
    if (!isAuthenticated()) {
        window.location.href = redirectTo;
        return false;
    }
    return true;
}

function loginPath() {
    const parts = window.location.pathname.split("/").filter(Boolean);
    const depth = parts.length > 0 && !parts[parts.length - 1].includes(".") ? parts.length : parts.length - 1;
    if (depth <= 0) return "/login/";
    return `${"../".repeat(depth)}login/`;
}

window.AntorAPI = {
    API_BASE,
    getToken,
    getUser,
    setSession,
    saveRememberLogin,
    getRememberLogin,
    clearSession,
    isAuthenticated,
    apiFetch,
    requireAuth,
    loginPath,
};
