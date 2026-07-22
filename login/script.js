const form = document.getElementById("form-login");
if (form) {

const loginCard = document.getElementById("login-card");
const inputSenha = document.getElementById("senha");
const btnToggleSenha = document.getElementById("btn-toggle-senha");
const linkEsqueci = document.getElementById("link-esqueci");
const btnEntrar = document.getElementById("btn-entrar");
const btnEntrarIcon = btnEntrar?.querySelector(".btn-entrar-icon");
const btnEntrarText = btnEntrar?.querySelector(".btn-entrar-text");
const inputUsuario = document.getElementById("usuario");
const checkboxLembrar = document.getElementById("lembrar");
const loginError = document.getElementById("login-error");
const loginErrorText = document.getElementById("login-error-text");
const capsHint = document.getElementById("caps-hint");
const modalStepLabel = document.getElementById("modal-step-label");
const passwordMatch = document.getElementById("setup-password-match");
const inputSetupConfirmar = document.getElementById("setup-confirmar");

const modalSetup = document.getElementById("modal-setup");
const modalSetupCard = document.getElementById("modal-setup-card");
const modalSetupIcon = document.getElementById("modal-setup-icon");
const modalSetupMessage = document.getElementById("modal-setup-message");
const modalSetupEmail = document.getElementById("modal-setup-email");
const stepEmail = document.getElementById("setup-step-email");
const stepCode = document.getElementById("setup-step-code");
const stepSuccess = document.getElementById("setup-step-success");
const formSetupEmail = document.getElementById("form-setup-email");
const formSetup = document.getElementById("form-setup");
const inputSetupEmail = document.getElementById("setup-email");
const inputSetupSenha = document.getElementById("setup-senha");
const modalSetupErrorEmail = document.getElementById("modal-setup-error-email");
const modalSetupError = document.getElementById("modal-setup-error");
const btnSetupReenviar = document.getElementById("btn-setup-reenviar");
const btnSetupSubmit = document.getElementById("btn-setup-submit");
const btnEnviarCodigo = document.getElementById("btn-enviar-codigo");
const modalSetupClose = document.getElementById("modal-setup-close");
const modalSetupTitle = document.getElementById("modal-setup-title");
const btnSetupSubmitText = document.getElementById("btn-setup-submit-text");
const passwordStrength = document.getElementById("setup-password-strength");
const otpInputs = Array.from(document.querySelectorAll(".otp-digit"));
const hiddenCodigo = document.getElementById("setup-codigo");

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
    if (btnEntrar.disabled) return;
    clearLoginValidation();
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

function setFieldInvalid(input, invalid) {
    const campo = input?.closest(".campo");
    campo?.classList.toggle("is-invalid", invalid);
    if (input) {
        input.setAttribute("aria-invalid", invalid ? "true" : "false");
    }
}

function clearLoginValidation() {
    setFieldInvalid(inputUsuario, false);
    setFieldInvalid(inputSenha, false);
    showLoginError("");
}

function updateCapsHint(event) {
    if (!capsHint || !event.getModifierState) return;
    capsHint.hidden = !event.getModifierState("CapsLock");
}

function updateModalStepLabel(step) {
    if (!modalStepLabel) return;
    if (!step) {
        modalStepLabel.hidden = true;
        return;
    }
    modalStepLabel.hidden = false;
    modalStepLabel.textContent = `Passo ${step} de 2`;
}

function updatePasswordMatch() {
    if (!passwordMatch || !inputSetupConfirmar || !inputSetupSenha) return;

    const confirmValue = inputSetupConfirmar.value;
    passwordMatch.classList.remove("is-match", "is-mismatch");

    if (!confirmValue) {
        passwordMatch.textContent = "";
        return;
    }

    const matches = confirmValue.toUpperCase() === inputSetupSenha.value.toUpperCase();
    passwordMatch.textContent = matches ? "Senhas conferem" : "As senhas não coincidem";
    passwordMatch.classList.add(matches ? "is-match" : "is-mismatch");
}

function setLoading(active) {
    btnEntrar.disabled = active;
    btnEntrar.classList.toggle("loading", active);
    inputUsuario.disabled = active;
    inputSenha.disabled = active;
    if (checkboxLembrar) checkboxLembrar.disabled = active;
    linkEsqueci.classList.toggle("is-disabled", active);
    if (btnEntrarText) {
        btnEntrarText.textContent = active ? "Entrando..." : "Entrar";
    }
    if (btnEntrarIcon) {
        btnEntrarIcon.className = active
            ? "fa-solid fa-spinner btn-entrar-icon"
            : "fa-solid fa-right-to-bracket btn-entrar-icon";
    }
    if (!active) {
        linkEsqueci.classList.remove("is-disabled");
    }
}

function shakeElement(element) {
    if (!element) return;
    element.classList.remove("is-shake");
    void element.offsetWidth;
    element.classList.add("is-shake");
}

function showLoginError(message, { focusField = null, invalidFields = [] } = {}) {
    if (!loginError) return;
    if (loginErrorText) {
        loginErrorText.textContent = message;
    } else {
        loginError.textContent = message;
    }
    loginError.hidden = !message;

    setFieldInvalid(inputUsuario, invalidFields.includes(inputUsuario));
    setFieldInvalid(inputSenha, invalidFields.includes(inputSenha));

    if (message) {
        shakeElement(loginCard);
    }

    focusField?.focus();
}

function resolveAuthError(data, fallback) {
    return data?.error || fallback;
}

function showStepError(el, message) {
    if (!el) return;
    const textEl = el.querySelector("span") || el;
    textEl.textContent = message;
    el.hidden = !message;
    if (message) {
        shakeElement(modalSetupCard);
    }
}

function syncOtpValue() {
    const value = otpInputs.map((input) => input.value.replace(/\D/g, "")).join("");
    if (hiddenCodigo) hiddenCodigo.value = value;
    return value;
}

function resetOtpInputs() {
    otpInputs.forEach((input) => {
        input.value = "";
    });
    syncOtpValue();
}

function bindOtpInputs() {
    otpInputs.forEach((input, index) => {
        input.addEventListener("input", () => {
            input.value = input.value.replace(/\D/g, "").slice(0, 1);
            syncOtpValue();
            if (input.value && index < otpInputs.length - 1) {
                otpInputs[index + 1].focus();
            }
        });

        input.addEventListener("keydown", (event) => {
            if (event.key === "Backspace" && !input.value && index > 0) {
                otpInputs[index - 1].focus();
            }
        });

        input.addEventListener("paste", (event) => {
            event.preventDefault();
            const pasted = (event.clipboardData?.getData("text") || "").replace(/\D/g, "").slice(0, 6);
            pasted.split("").forEach((char, charIndex) => {
                if (otpInputs[charIndex]) {
                    otpInputs[charIndex].value = char;
                }
            });
            syncOtpValue();
            otpInputs[Math.min(pasted.length, otpInputs.length - 1)]?.focus();
        });
    });
}

function evaluatePasswordStrength(password) {
    let score = 0;
    if (password.length >= 6) score += 1;
    if (password.length >= 8) score += 1;
    if (/[A-Z]/.test(password)) score += 1;
    if (/[0-9]/.test(password)) score += 1;
    if (/[^A-Za-z0-9]/.test(password)) score += 1;

    if (score <= 1) return { level: 1, label: "Fraca" };
    if (score <= 2) return { level: 2, label: "Razoável" };
    if (score <= 3) return { level: 3, label: "Boa" };
    return { level: 4, label: "Forte" };
}

function updatePasswordStrength() {
    if (!passwordStrength) return;
    const password = inputSetupSenha?.value || "";
    const label = passwordStrength.querySelector(".password-strength-label");

    if (!password) {
        passwordStrength.dataset.level = "0";
        if (label) label.textContent = "Digite uma senha";
        return;
    }

    const result = evaluatePasswordStrength(password);
    passwordStrength.dataset.level = String(result.level);
    if (label) label.textContent = result.label;
}

function resetPasswordStrength() {
    if (!passwordStrength) return;
    passwordStrength.dataset.level = "0";
    const label = passwordStrength.querySelector(".password-strength-label");
    if (label) label.textContent = "Digite uma senha";
    updatePasswordMatch();
}

function resetModalVisualState() {
    if (modalSetupIcon) {
        modalSetupIcon.classList.remove("is-success");
        modalSetupIcon.innerHTML = '<i class="fa-solid fa-envelope-circle-check"></i>';
    }
    if (stepSuccess) stepSuccess.hidden = true;
    updateModalStepLabel(null);
    resetOtpInputs();
    resetPasswordStrength();
    if (passwordMatch) {
        passwordMatch.textContent = "";
        passwordMatch.classList.remove("is-match", "is-mismatch");
    }
}

function showEmailStep(data) {
    resetModalVisualState();
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
    updateModalStepLabel(1);
    modalSetup.hidden = false;
    modalSetup.setAttribute("aria-hidden", "false");
    inputSetupEmail?.focus();
}

function showCodeStep(data) {
    resetModalVisualState();
    setupToken = data.setupToken;
    modalSetupMessage.textContent = data.message || "Enviamos um e-mail para você com um código de verificação.";
    modalSetupEmail.textContent = data.emailMasked ? `Enviado para ${data.emailMasked}` : "";
    stepEmail.hidden = true;
    stepCode.hidden = false;
    formSetup?.reset();
    showStepError(modalSetupError, "");
    updateModalStepLabel(2);
    otpInputs[0]?.focus();
}

function showSetupSuccess() {
    stepEmail.hidden = true;
    stepCode.hidden = true;
    if (stepSuccess) stepSuccess.hidden = false;
    if (modalSetupIcon) {
        modalSetupIcon.classList.add("is-success");
        modalSetupIcon.innerHTML = '<i class="fa-solid fa-circle-check"></i>';
    }
    if (modalSetupTitle) modalSetupTitle.textContent = "Tudo certo!";
    if (modalSetupMessage) modalSetupMessage.textContent = "";
    if (modalSetupEmail) modalSetupEmail.textContent = "";
    updateModalStepLabel(null);
    modalSetupClose?.setAttribute("hidden", "hidden");
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
    resetModalVisualState();
    modalSetupClose?.removeAttribute("hidden");
}

modalSetupClose?.addEventListener("click", closeSetupModal);

modalSetup?.addEventListener("click", (e) => {
    if (e.target === modalSetup) closeSetupModal();
});

document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    if (modalSetup?.hidden === false) {
        closeSetupModal();
    }
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
    clearLoginValidation();

    const usuario = inputUsuario.value.trim();
    const senha = inputSenha.value;

    if (!usuario) {
        showLoginError("Informe o e-mail corporativo.", {
            focusField: inputUsuario,
            invalidFields: [inputUsuario],
        });
        return;
    }

    if (!senha) {
        showLoginError("Informe sua senha.", {
            focusField: inputSenha,
            invalidFields: [inputSenha],
        });
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
            showLoginError(resolveAuthError(data, "Não foi possível entrar."), {
                focusField: inputSenha,
                invalidFields: [inputSenha],
            });
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

    const codigo = syncOtpValue();
    const senha = document.getElementById("setup-senha")?.value.toUpperCase();
    const confirmarSenha = document.getElementById("setup-confirmar")?.value.toUpperCase();

    if (!setupToken) {
        showStepError(modalSetupError, "Sessão expirada. Tente entrar novamente.");
        return;
    }

    if (codigo.length !== 6) {
        showStepError(modalSetupError, "Informe o código de 6 dígitos.");
        otpInputs[Math.min(codigo.length, 5)]?.focus();
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

        showSetupSuccess();
        window.setTimeout(() => finishLogin(data), 900);
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

inputSetupSenha?.addEventListener("input", () => {
    updatePasswordStrength();
    updatePasswordMatch();
});
inputSetupConfirmar?.addEventListener("input", updatePasswordMatch);

[inputUsuario, inputSenha].forEach((input) => {
    input?.addEventListener("input", () => {
        setFieldInvalid(input, false);
        if (loginError && !loginError.hidden) {
            showLoginError("");
        }
    });
});

inputSenha?.addEventListener("keydown", updateCapsHint);
inputSenha?.addEventListener("keyup", updateCapsHint);

bindOtpInputs();

if (inputUsuario?.value.trim()) {
    inputSenha?.focus();
} else {
    inputUsuario?.focus();
}
}
