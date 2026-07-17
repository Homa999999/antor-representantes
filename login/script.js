const form = document.getElementById("form-login");
if (form) {

const inputSenha = document.getElementById("senha");
const btnToggleSenha = document.getElementById("btn-toggle-senha");
const linkEsqueci = document.getElementById("link-esqueci");
const btnEntrar = document.getElementById("btn-entrar");
const loadingOverlay = document.getElementById("loading-overlay");
const inputUsuario = document.getElementById("usuario");
const checkboxLembrar = document.getElementById("lembrar");
const loginError = document.getElementById("login-error");

const modalSetup = document.getElementById("modal-setup");
const modalSetupMessage = document.getElementById("modal-setup-message");
const modalSetupEmail = document.getElementById("modal-setup-email");
const stepEmail = document.getElementById("setup-step-email");
const stepCode = document.getElementById("setup-step-code");
const formSetupEmail = document.getElementById("form-setup-email");
const formSetup = document.getElementById("form-setup");
const inputSetupEmail = document.getElementById("setup-email");
const modalSetupErrorEmail = document.getElementById("modal-setup-error-email");
const modalSetupError = document.getElementById("modal-setup-error");
const btnSetupReenviar = document.getElementById("btn-setup-reenviar");
const btnSetupSubmit = document.getElementById("btn-setup-submit");
const btnEnviarCodigo = document.getElementById("btn-enviar-codigo");
const modalSetupClose = document.getElementById("modal-setup-close");
const modalSetupTitle = document.getElementById("modal-setup-title");
const btnSetupSubmitText = document.getElementById("btn-setup-submit-text");

let pendingToken = null;
let setupToken = null;
let flowMode = "setup";

const savedLogin = AntorAPI.getRememberLogin();
if (savedLogin.remember && savedLogin.email && inputUsuario) {
    inputUsuario.value = savedLogin.email;
    if (checkboxLembrar) checkboxLembrar.checked = true;
}

if (AntorAPI.isAuthenticated()) {
    window.location.href = "../home/";
}

btnToggleSenha.addEventListener("click", () => {
    const mostrar = inputSenha.type === "password";
    inputSenha.type = mostrar ? "text" : "password";
    btnToggleSenha.innerHTML = mostrar
        ? '<i class="fa-solid fa-eye-slash"></i>'
        : '<i class="fa-solid fa-eye"></i>';
    btnToggleSenha.setAttribute("aria-label", mostrar ? "Ocultar senha" : "Mostrar senha");
});

linkEsqueci.addEventListener("click", async (e) => {
    e.preventDefault();
    showLoginError("");
    setFlowMode("reset");

    const usuario = inputUsuario.value.trim();
    if (!usuario) {
        showEmailStep({
            message: "Informe seu e-mail corporativo para redefinir a senha.",
            suggestedEmail: "",
        });
        return;
    }

    try {
        const { response, data } = await postAuth("/auth/esqueci-senha/iniciar", { usuario });
        if (!response.ok) {
            showLoginError(resolveAuthError(data, "Não foi possível iniciar a recuperação."));
            return;
        }
        showEmailStep(data);
    } catch (err) {
        showLoginError(err.message || "Erro ao conectar ao servidor.");
    }
});

function setFlowMode(mode) {
    flowMode = mode;
    if (modalSetupTitle) {
        modalSetupTitle.textContent = mode === "reset" ? "Esqueci minha senha" : "Primeiro acesso";
    }
    if (btnSetupSubmitText) {
        btnSetupSubmitText.textContent =
            mode === "reset" ? "Redefinir senha e entrar" : "Definir senha e entrar";
    }
}

function getFlowPaths() {
    if (flowMode === "reset") {
        return {
            enviarCodigo: "/auth/esqueci-senha/enviar-codigo",
            definirSenha: "/auth/esqueci-senha/redefinir-senha",
            reenviar: "/auth/esqueci-senha/reenviar",
            iniciar: "/auth/esqueci-senha/iniciar",
        };
    }
    return {
        enviarCodigo: "/auth/primeiro-acesso/enviar-codigo",
        definirSenha: "/auth/primeiro-acesso/definir-senha",
        reenviar: "/auth/primeiro-acesso/reenviar",
        iniciar: null,
    };
}

function setLoading(active) {
    btnEntrar.disabled = active;
    btnEntrar.classList.toggle("loading", active);
    btnEntrar.querySelector("span").textContent = active ? "Entrando..." : "Entrar";
    loadingOverlay.classList.toggle("show", active);
    loadingOverlay.setAttribute("aria-busy", active ? "true" : "false");
}

function showLoginError(message) {
    if (!loginError) return;
    loginError.textContent = message;
    loginError.hidden = !message;
}

function resolveAuthError(data, fallback) {
    return data?.error || fallback;
}

function showStepError(el, message) {
    if (!el) return;
    el.textContent = message;
    el.hidden = !message;
}

function showEmailStep(data) {
    pendingToken = data.pendingToken;
    setupToken = null;
    modalSetupMessage.textContent = data.message || "Informe seu e-mail para receber o código de verificação.";
    modalSetupEmail.textContent = "";
    stepEmail.hidden = false;
    stepCode.hidden = true;
    formSetupEmail?.reset();
    formSetup?.reset();
    if (data.suggestedEmail && inputSetupEmail) {
        inputSetupEmail.value = data.suggestedEmail;
    }
    showStepError(modalSetupErrorEmail, "");
    showStepError(modalSetupError, "");
    modalSetup.hidden = false;
    modalSetup.setAttribute("aria-hidden", "false");
    inputSetupEmail?.focus();
}

function showCodeStep(data) {
    setupToken = data.setupToken;
    modalSetupMessage.textContent = data.message || "Enviamos um e-mail para você com um código de verificação.";
    modalSetupEmail.textContent = data.emailMasked ? `Enviado para ${data.emailMasked}` : "";
    stepEmail.hidden = true;
    stepCode.hidden = false;
    formSetup?.reset();
    showStepError(modalSetupError, "");
    document.getElementById("setup-codigo")?.focus();
}

function openSetupModal(data) {
    setFlowMode("setup");
    if (data.step === "code" && data.setupToken) {
        showCodeStep(data);
        modalSetup.hidden = false;
        modalSetup.setAttribute("aria-hidden", "false");
        return;
    }
    showEmailStep(data);
}

function closeSetupModal() {
    modalSetup.hidden = true;
    modalSetup.setAttribute("aria-hidden", "true");
    pendingToken = null;
    setupToken = null;
    setFlowMode("setup");
}

modalSetupClose?.addEventListener("click", closeSetupModal);

modalSetup?.addEventListener("click", (e) => {
    if (e.target === modalSetup) closeSetupModal();
});

async function postAuth(path, body) {
    const response = await fetch(`${AntorAPI.API_BASE}${path}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
    });

    if (response.status === 405) {
        throw new Error(
            "Servidor incorreto. Inicie com npm start e acesse http://localhost:3000/login/"
        );
    }

    const data = await response.json().catch(() => ({}));
    return { response, data };
}

function finishLogin(data, remember = false) {
    AntorAPI.setSession(data.token, data.user, { remember });
    AntorAPI.saveRememberLogin(inputUsuario?.value.trim() || "", remember);
    window.location.href = "../home/";
}

form.addEventListener("submit", async (e) => {
    e.preventDefault();
    showLoginError("");

    const usuario = inputUsuario.value.trim();
    const senha = inputSenha.value;

    if (!usuario) {
        showLoginError("Informe o e-mail corporativo.");
        return;
    }

    const senhaNormalizada = senha.toUpperCase();
    const remember = Boolean(checkboxLembrar?.checked);

    setLoading(true);

    try {
        const { response, data } = await postAuth("/auth/login", {
            usuario,
            senha: senhaNormalizada,
            lembrar: remember,
        });

        if (data.requiresSetup) {
            openSetupModal(data);
            setLoading(false);
            return;
        }

        if (!response.ok) {
            showLoginError(resolveAuthError(data, "Não foi possível entrar."));
            setLoading(false);
            return;
        }

        finishLogin(data, remember);
    } catch (err) {
        showLoginError(err.message || "Não foi possível conectar ao servidor.");
        setLoading(false);
    }
});

formSetupEmail?.addEventListener("submit", async (e) => {
    e.preventDefault();
    showStepError(modalSetupErrorEmail, "");

    const email = inputSetupEmail?.value.trim();
    if (!email) {
        showStepError(modalSetupErrorEmail, "Informe seu e-mail.");
        return;
    }

    let token = pendingToken;
    const paths = getFlowPaths();

    if (flowMode === "reset" && !token) {
        btnEnviarCodigo.disabled = true;
        try {
            const { response, data } = await postAuth(paths.iniciar, { usuario: email });
            if (!response.ok) {
                showStepError(modalSetupErrorEmail, resolveAuthError(data, "Não foi possível iniciar a recuperação."));
                btnEnviarCodigo.disabled = false;
                return;
            }
            token = data.pendingToken;
            pendingToken = token;
        } catch {
            showStepError(modalSetupErrorEmail, "Erro ao conectar ao servidor.");
            btnEnviarCodigo.disabled = false;
            return;
        }
    }

    if (!token) {
        showStepError(modalSetupErrorEmail, "Sessão expirada. Tente entrar novamente.");
        return;
    }

    btnEnviarCodigo.disabled = true;

    try {
        const { response, data } = await postAuth(paths.enviarCodigo, {
            pendingToken: token,
            email,
        });

        if (!response.ok) {
            showStepError(modalSetupErrorEmail, resolveAuthError(data, "Não foi possível enviar o código."));
            btnEnviarCodigo.disabled = false;
            return;
        }

        showCodeStep(data);
    } catch {
        showStepError(modalSetupErrorEmail, "Erro ao conectar ao servidor.");
    } finally {
        btnEnviarCodigo.disabled = false;
    }
});

formSetup?.addEventListener("submit", async (e) => {
    e.preventDefault();
    showStepError(modalSetupError, "");

    const codigo = document.getElementById("setup-codigo")?.value.trim();
    const senha = document.getElementById("setup-senha")?.value.toUpperCase();
    const confirmarSenha = document.getElementById("setup-confirmar")?.value.toUpperCase();

    if (!setupToken) {
        showStepError(modalSetupError, "Sessão expirada. Tente entrar novamente.");
        return;
    }

    btnSetupSubmit.disabled = true;

    try {
        const paths = getFlowPaths();
        const { response, data } = await postAuth(paths.definirSenha, {
            setupToken,
            codigo,
            senha,
            confirmarSenha,
        });

        if (!response.ok) {
            showStepError(
                modalSetupError,
                resolveAuthError(
                    data,
                    flowMode === "reset"
                        ? "Não foi possível redefinir a senha."
                        : "Não foi possível definir a senha."
                )
            );
            btnSetupSubmit.disabled = false;
            return;
        }

        finishLogin(data);
    } catch {
        showStepError(modalSetupError, "Erro ao conectar ao servidor.");
        btnSetupSubmit.disabled = false;
    }
});

btnSetupReenviar?.addEventListener("click", async () => {
    if (!setupToken) {
        showStepError(modalSetupError, "Sessão expirada. Tente entrar novamente.");
        return;
    }

    showStepError(modalSetupError, "");
    btnSetupReenviar.disabled = true;

    try {
        const paths = getFlowPaths();
        const { response, data } = await postAuth(paths.reenviar, { setupToken });

        if (data.setupToken) {
            showCodeStep(data);
        } else if (!response.ok) {
            showStepError(modalSetupError, resolveAuthError(data, "Não foi possível reenviar o código."));
        }
    } catch {
        showStepError(modalSetupError, "Erro ao reenviar código.");
    } finally {
        btnSetupReenviar.disabled = false;
    }
});
}
