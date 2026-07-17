const express = require("express");
const {
    isUsuarioDesativado,
    hasWebPassword,
    getUserEmail,
    maskEmail,
    isValidEmail,
    matchesUsuarioCorporativo,
    findUsuarioByLogin,
    findUsuarioById,
    canAccessWebSystem,
    createSessionToken,
    createPendingSetupToken,
    verifyPendingSetupToken,
    createPendingResetToken,
    verifyPendingResetToken,
    createSetupToken,
    verifySetupToken,
    createResetToken,
    verifyResetToken,
    generateCode,
    saveWebPassword,
    upgradeWebPasswordHash,
    verifyWebPassword,
    normalizeWebPassword,
    publicUser,
} = require("../services/userAuth");
const { sendAccessCodeEmail } = require("../services/mail");

const router = express.Router();

const AUTH_ERRORS = {
    MISSING_EMAIL: "Informe o e-mail corporativo.",
    MISSING_PASSWORD: "Informe a senha.",
    USER_NOT_FOUND: "E-mail corporativo não encontrado.",
    USER_DEACTIVATED: "Usuário desativado.",
    INVALID_PASSWORD: "Senha inválida.",
    WEB_ACCESS_DENIED: "Seu usuário não possui permissão para acessar o sistema web.",
    SERVER_LOGIN: "Erro ao validar login. Tente novamente em instantes.",
    SERVER_SETUP: "Erro ao configurar acesso. Tente novamente em instantes.",
    SERVER_RESET: "Erro ao recuperar senha. Tente novamente em instantes.",
    INVALID_EMAIL: "Informe um e-mail válido.",
    EMAIL_MISMATCH: "O e-mail informado não confere com o cadastro corporativo.",
    EMAIL_SEND_FAILED: "Não foi possível enviar o e-mail com o código. Tente novamente em instantes.",
    SETUP_NOT_ALLOWED: "Não é possível configurar este usuário.",
    RESET_NOT_ALLOWED: "Não é possível redefinir a senha deste usuário.",
    RESET_NO_PASSWORD: "Este usuário ainda não possui senha web. Faça login para configurar o primeiro acesso.",
    SESSION_EXPIRED: "Sessão expirada. Faça login novamente.",
    CODE_EXPIRED: "Código expirado. Faça login novamente.",
    CODE_INVALID: "Código inválido.",
    SETUP_SESSION_INVALID: "Sessão de configuração inválida.",
    RESET_SESSION_INVALID: "Sessão de redefinição inválida.",
    PASSWORD_TOO_SHORT: "A senha deve ter pelo menos 6 caracteres.",
    PASSWORD_MISMATCH: "As senhas não conferem.",
    PASSWORD_ALREADY_SET: "Este usuário já possui senha web cadastrada.",
    USE_FIRST_ACCESS: "Use o fluxo de primeiro acesso para definir a senha.",
    USER_INVALID: "Usuário inválido.",
    RESEND_NOT_ALLOWED: "Não é possível reenviar o código para este usuário.",
};

const WEB_ACCESS_DENIED = AUTH_ERRORS.WEB_ACCESS_DENIED;

function loginError(res, status, code) {
    return res.status(status).json({ error: AUTH_ERRORS[code], code });
}

async function sendVerificationCode(user, email, res, { createToken, emailContext }) {
    if (!isValidEmail(email)) {
        return res.status(400).json({ error: AUTH_ERRORS.INVALID_EMAIL, code: "INVALID_EMAIL" });
    }

    if (!matchesUsuarioCorporativo(user, email)) {
        return res.status(403).json({ error: AUTH_ERRORS.EMAIL_MISMATCH, code: "EMAIL_MISMATCH" });
    }

    const code = generateCode();

    try {
        await sendAccessCodeEmail({
            to: email.trim(),
            nome: String(user.usuario_nome || "").trim(),
            code,
            context: emailContext,
        });
    } catch (err) {
        console.error("Erro ao enviar e-mail:", err.message);
        return res.status(503).json({
            error: AUTH_ERRORS.EMAIL_SEND_FAILED,
            code: "EMAIL_SEND_FAILED",
        });
    }

    const setupToken = createToken(user.usuario_id, code, email);

    return res.json({
        requiresSetup: true,
        step: "code",
        setupToken,
        emailMasked: maskEmail(email.trim()),
        message: "Enviamos um e-mail para você com um código de verificação.",
    });
}

async function sendSetupCode(user, email, res) {
    return sendVerificationCode(user, email, res, {
        createToken: createSetupToken,
        emailContext: "setup",
    });
}

async function sendResetCode(user, email, res) {
    return sendVerificationCode(user, email, res, {
        createToken: createResetToken,
        emailContext: "reset",
    });
}

router.post("/login", async (req, res) => {
    const { usuario, senha, lembrar } = req.body || {};
    const remember = Boolean(lembrar);

    if (!usuario?.trim()) {
        return loginError(res, 400, "MISSING_EMAIL");
    }

    try {
        const user = await findUsuarioByLogin(usuario);

        if (!user) {
            return loginError(res, 401, "USER_NOT_FOUND");
        }

        if (isUsuarioDesativado(user)) {
            return loginError(res, 403, "USER_DEACTIVATED");
        }

        if (!hasWebPassword(user)) {
            if (!canAccessWebSystem(user)) {
                return loginError(res, 403, "WEB_ACCESS_DENIED");
            }

            const existingEmail = String(user.usuario_corporativo || "").trim() || getUserEmail(user);
            return res.status(403).json({
                requiresSetup: true,
                step: "email",
                pendingToken: createPendingSetupToken(user.usuario_id),
                message: "Informe seu e-mail para receber o código de verificação.",
                suggestedEmail: existingEmail || "",
            });
        }

        if (!senha?.trim()) {
            return loginError(res, 400, "MISSING_PASSWORD");
        }

        const passwordCheck = await verifyWebPassword(senha, user.usuario_senha_web);
        if (!passwordCheck.ok) {
            return loginError(res, 401, "INVALID_PASSWORD");
        }

        if (passwordCheck.needsUpgrade) {
            try {
                await upgradeWebPasswordHash(user.usuario_id, senha);
            } catch (upgradeErr) {
                console.warn("Não foi possível atualizar hash da senha web:", upgradeErr.message);
            }
        }

        if (!canAccessWebSystem(user)) {
            return loginError(res, 403, "WEB_ACCESS_DENIED");
        }

        const token = createSessionToken(user, remember);

        res.json({
            token,
            user: publicUser(user),
        });
    } catch (err) {
        console.error("Erro no login:", err.message);
        res.status(500).json({ error: AUTH_ERRORS.SERVER_LOGIN, code: "SERVER_LOGIN" });
    }
});

router.post("/primeiro-acesso/enviar-codigo", async (req, res) => {
    const { pendingToken, email } = req.body || {};

    if (!pendingToken || !email?.trim()) {
        return loginError(res, 400, "MISSING_EMAIL");
    }

    try {
        const payload = verifyPendingSetupToken(pendingToken);
        const user = await findUsuarioById(payload.userId);

        if (!user) {
            return loginError(res, 400, "USER_NOT_FOUND");
        }

        if (isUsuarioDesativado(user)) {
            return loginError(res, 403, "USER_DEACTIVATED");
        }

        if (hasWebPassword(user)) {
            return res.status(400).json({ error: AUTH_ERRORS.PASSWORD_ALREADY_SET, code: "PASSWORD_ALREADY_SET" });
        }

        return sendSetupCode(user, email, res);
    } catch (err) {
        if (err.name === "TokenExpiredError" || err.name === "JsonWebTokenError") {
            return loginError(res, 401, "SESSION_EXPIRED");
        }
        console.error("Erro ao enviar código:", err.message);
        res.status(500).json({ error: AUTH_ERRORS.SERVER_SETUP, code: "SERVER_SETUP" });
    }
});

router.post("/primeiro-acesso/reenviar", async (req, res) => {
    const { setupToken } = req.body || {};

    if (!setupToken) {
        return loginError(res, 400, "SETUP_SESSION_INVALID");
    }

    try {
        const payload = verifySetupToken(setupToken);
        const user = await findUsuarioById(payload.userId);

        if (!user) {
            return loginError(res, 400, "USER_NOT_FOUND");
        }

        if (isUsuarioDesativado(user)) {
            return loginError(res, 403, "USER_DEACTIVATED");
        }

        if (hasWebPassword(user) || !payload.email) {
            return loginError(res, 400, "RESEND_NOT_ALLOWED");
        }

        return sendSetupCode(user, payload.email, res);
    } catch {
        return loginError(res, 401, "CODE_EXPIRED");
    }
});

router.post("/primeiro-acesso/definir-senha", async (req, res) => {
    const { setupToken, codigo, senha, confirmarSenha } = req.body || {};

    if (!setupToken || !codigo?.trim() || !senha || !confirmarSenha) {
        return res.status(400).json({
            error: "Preencha o código e a nova senha.",
            code: "MISSING_FIELDS",
        });
    }

    const senhaNormalizada = normalizeWebPassword(senha);
    const confirmarNormalizada = normalizeWebPassword(confirmarSenha);

    if (senhaNormalizada.length < 6) {
        return loginError(res, 400, "PASSWORD_TOO_SHORT");
    }

    if (senhaNormalizada !== confirmarNormalizada) {
        return loginError(res, 400, "PASSWORD_MISMATCH");
    }

    try {
        const payload = verifySetupToken(setupToken);

        if (String(payload.code) !== String(codigo).trim()) {
            return loginError(res, 401, "CODE_INVALID");
        }

        const user = await findUsuarioById(payload.userId);
        if (!user) {
            return loginError(res, 401, "USER_NOT_FOUND");
        }

        if (isUsuarioDesativado(user)) {
            return loginError(res, 403, "USER_DEACTIVATED");
        }

        if (hasWebPassword(user)) {
            return res.status(400).json({ error: AUTH_ERRORS.PASSWORD_ALREADY_SET, code: "PASSWORD_ALREADY_SET" });
        }

        await saveWebPassword(user.usuario_id, senhaNormalizada, payload.email);

        if (!canAccessWebSystem(user)) {
            return loginError(res, 403, "WEB_ACCESS_DENIED");
        }

        const token = createSessionToken(user);

        res.json({
            token,
            user: publicUser(user),
            message: "Senha definida com sucesso.",
        });
    } catch (err) {
        if (err.name === "TokenExpiredError") {
            return loginError(res, 401, "CODE_EXPIRED");
        }
        if (err.name === "JsonWebTokenError") {
            return loginError(res, 401, "SETUP_SESSION_INVALID");
        }
        console.error("Erro ao definir senha:", err.message);
        res.status(500).json({ error: AUTH_ERRORS.SERVER_SETUP, code: "SERVER_SETUP" });
    }
});

router.post("/esqueci-senha/iniciar", async (req, res) => {
    const { usuario } = req.body || {};

    if (!usuario?.trim()) {
        return loginError(res, 400, "MISSING_EMAIL");
    }

    try {
        const user = await findUsuarioByLogin(usuario);

        if (!user) {
            return loginError(res, 401, "USER_NOT_FOUND");
        }

        if (isUsuarioDesativado(user)) {
            return loginError(res, 403, "USER_DEACTIVATED");
        }

        if (!hasWebPassword(user)) {
            return res.status(403).json({
                error: AUTH_ERRORS.RESET_NO_PASSWORD,
                code: "RESET_NO_PASSWORD",
            });
        }

        const existingEmail = String(user.usuario_corporativo || "").trim() || getUserEmail(user);

        res.json({
            flow: "reset",
            step: "email",
            pendingToken: createPendingResetToken(user.usuario_id),
            message: "Informe seu e-mail corporativo para receber o código de redefinição.",
            suggestedEmail: existingEmail || "",
        });
    } catch (err) {
        console.error("Erro ao iniciar recuperação:", err.message);
        res.status(500).json({ error: AUTH_ERRORS.SERVER_RESET, code: "SERVER_RESET" });
    }
});

router.post("/esqueci-senha/enviar-codigo", async (req, res) => {
    const { pendingToken, email } = req.body || {};

    if (!pendingToken || !email?.trim()) {
        return loginError(res, 400, "MISSING_EMAIL");
    }

    try {
        const payload = verifyPendingResetToken(pendingToken);
        const user = await findUsuarioById(payload.userId);

        if (!user) {
            return loginError(res, 400, "USER_NOT_FOUND");
        }

        if (isUsuarioDesativado(user)) {
            return loginError(res, 403, "USER_DEACTIVATED");
        }

        if (!hasWebPassword(user)) {
            return res.status(400).json({ error: AUTH_ERRORS.RESET_NO_PASSWORD, code: "RESET_NO_PASSWORD" });
        }

        return sendResetCode(user, email, res);
    } catch (err) {
        if (err.name === "TokenExpiredError" || err.name === "JsonWebTokenError") {
            return loginError(res, 401, "SESSION_EXPIRED");
        }
        console.error("Erro ao enviar código:", err.message);
        res.status(500).json({ error: AUTH_ERRORS.SERVER_RESET, code: "SERVER_RESET" });
    }
});

router.post("/esqueci-senha/reenviar", async (req, res) => {
    const { setupToken } = req.body || {};

    if (!setupToken) {
        return loginError(res, 400, "RESET_SESSION_INVALID");
    }

    try {
        const payload = verifyResetToken(setupToken);
        const user = await findUsuarioById(payload.userId);

        if (!user) {
            return loginError(res, 400, "USER_NOT_FOUND");
        }

        if (isUsuarioDesativado(user)) {
            return loginError(res, 403, "USER_DEACTIVATED");
        }

        if (!hasWebPassword(user) || !payload.email) {
            return loginError(res, 400, "RESEND_NOT_ALLOWED");
        }

        return sendResetCode(user, payload.email, res);
    } catch {
        return loginError(res, 401, "CODE_EXPIRED");
    }
});

router.post("/esqueci-senha/redefinir-senha", async (req, res) => {
    const { setupToken, codigo, senha, confirmarSenha } = req.body || {};

    if (!setupToken || !codigo?.trim() || !senha || !confirmarSenha) {
        return res.status(400).json({
            error: "Preencha o código e a nova senha.",
            code: "MISSING_FIELDS",
        });
    }

    const senhaNormalizada = normalizeWebPassword(senha);
    const confirmarNormalizada = normalizeWebPassword(confirmarSenha);

    if (senhaNormalizada.length < 6) {
        return loginError(res, 400, "PASSWORD_TOO_SHORT");
    }

    if (senhaNormalizada !== confirmarNormalizada) {
        return loginError(res, 400, "PASSWORD_MISMATCH");
    }

    try {
        const payload = verifyResetToken(setupToken);

        if (String(payload.code) !== String(codigo).trim()) {
            return loginError(res, 401, "CODE_INVALID");
        }

        const user = await findUsuarioById(payload.userId);
        if (!user) {
            return loginError(res, 401, "USER_NOT_FOUND");
        }

        if (isUsuarioDesativado(user)) {
            return loginError(res, 403, "USER_DEACTIVATED");
        }

        if (!hasWebPassword(user)) {
            return res.status(400).json({ error: AUTH_ERRORS.USE_FIRST_ACCESS, code: "USE_FIRST_ACCESS" });
        }

        await upgradeWebPasswordHash(user.usuario_id, senhaNormalizada);

        if (!canAccessWebSystem(user)) {
            return loginError(res, 403, "WEB_ACCESS_DENIED");
        }

        const token = createSessionToken(user);

        res.json({
            token,
            user: publicUser(user),
            message: "Senha redefinida com sucesso.",
        });
    } catch (err) {
        if (err.name === "TokenExpiredError") {
            return loginError(res, 401, "CODE_EXPIRED");
        }
        if (err.name === "JsonWebTokenError") {
            return loginError(res, 401, "RESET_SESSION_INVALID");
        }
        console.error("Erro ao redefinir senha:", err.message);
        res.status(500).json({ error: AUTH_ERRORS.SERVER_RESET, code: "SERVER_RESET" });
    }
});

router.get("/me", require("../middleware/auth"), (req, res) => {
    res.json({ user: req.user });
});

module.exports = router;
