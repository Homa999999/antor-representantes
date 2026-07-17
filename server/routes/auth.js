const express = require("express");
const {
    isActiveUsuario,
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

const WEB_ACCESS_DENIED = "Seu usuário não possui permissão para acessar o sistema web.";

async function sendVerificationCode(user, email, res, { createToken, emailContext }) {
    if (!isValidEmail(email)) {
        return res.status(400).json({ error: "Informe um e-mail válido." });
    }

    if (!matchesUsuarioCorporativo(user, email)) {
        return res.status(403).json({ error: "O e-mail informado não confere com o cadastro corporativo." });
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
            error: "Não foi possível enviar o e-mail com o código. Tente novamente em instantes.",
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
        return res.status(400).json({ error: "Informe o e-mail corporativo." });
    }

    try {
        const user = await findUsuarioByLogin(usuario);

        if (!user || !isActiveUsuario(user)) {
            return res.status(401).json({ error: "Usuário ou senha inválidos." });
        }

        if (!hasWebPassword(user)) {
            if (!canAccessWebSystem(user)) {
                return res.status(403).json({ error: WEB_ACCESS_DENIED });
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
            return res.status(400).json({ error: "Informe a senha." });
        }

        const passwordCheck = await verifyWebPassword(senha, user.usuario_senha_web);
        if (!passwordCheck.ok) {
            return res.status(401).json({ error: "Usuário ou senha inválidos." });
        }

        if (passwordCheck.needsUpgrade) {
            try {
                await upgradeWebPasswordHash(user.usuario_id, senha);
            } catch (upgradeErr) {
                console.warn("Não foi possível atualizar hash da senha web:", upgradeErr.message);
            }
        }

        if (!canAccessWebSystem(user)) {
            return res.status(403).json({ error: WEB_ACCESS_DENIED });
        }

        const token = createSessionToken(user, remember);

        res.json({
            token,
            user: publicUser(user),
        });
    } catch (err) {
        console.error("Erro no login:", err.message);
        res.status(500).json({ error: "Erro ao validar login. Verifique a conexão com o banco." });
    }
});

router.post("/primeiro-acesso/enviar-codigo", async (req, res) => {
    const { pendingToken, email } = req.body || {};

    if (!pendingToken || !email?.trim()) {
        return res.status(400).json({ error: "Informe o e-mail." });
    }

    try {
        const payload = verifyPendingSetupToken(pendingToken);
        const user = await findUsuarioById(payload.userId);

        if (!user || !isActiveUsuario(user) || hasWebPassword(user)) {
            return res.status(400).json({ error: "Não é possível configurar este usuário." });
        }

        return sendSetupCode(user, email, res);
    } catch (err) {
        if (err.name === "TokenExpiredError" || err.name === "JsonWebTokenError") {
            return res.status(401).json({ error: "Sessão expirada. Faça login novamente." });
        }
        console.error("Erro ao enviar código:", err.message);
        res.status(500).json({ error: "Erro ao enviar código." });
    }
});

router.post("/primeiro-acesso/reenviar", async (req, res) => {
    const { setupToken } = req.body || {};

    if (!setupToken) {
        return res.status(400).json({ error: "Sessão de configuração inválida." });
    }

    try {
        const payload = verifySetupToken(setupToken);
        const user = await findUsuarioById(payload.userId);

        if (!user || !isActiveUsuario(user) || hasWebPassword(user) || !payload.email) {
            return res.status(400).json({ error: "Não é possível reenviar o código para este usuário." });
        }

        return sendSetupCode(user, payload.email, res);
    } catch {
        return res.status(401).json({ error: "Código expirado. Faça login novamente." });
    }
});

router.post("/primeiro-acesso/definir-senha", async (req, res) => {
    const { setupToken, codigo, senha, confirmarSenha } = req.body || {};

    if (!setupToken || !codigo?.trim() || !senha || !confirmarSenha) {
        return res.status(400).json({ error: "Preencha o código e a nova senha." });
    }

    const senhaNormalizada = normalizeWebPassword(senha);
    const confirmarNormalizada = normalizeWebPassword(confirmarSenha);

    if (senhaNormalizada.length < 6) {
        return res.status(400).json({ error: "A senha deve ter pelo menos 6 caracteres." });
    }

    if (senhaNormalizada !== confirmarNormalizada) {
        return res.status(400).json({ error: "As senhas não conferem." });
    }

    try {
        const payload = verifySetupToken(setupToken);

        if (String(payload.code) !== String(codigo).trim()) {
            return res.status(401).json({ error: "Código inválido." });
        }

        const user = await findUsuarioById(payload.userId);
        if (!user || !isActiveUsuario(user)) {
            return res.status(401).json({ error: "Usuário inválido." });
        }

        if (hasWebPassword(user)) {
            return res.status(400).json({ error: "Este usuário já possui senha web cadastrada." });
        }

        await saveWebPassword(user.usuario_id, senhaNormalizada, payload.email);

        if (!canAccessWebSystem(user)) {
            return res.status(403).json({ error: WEB_ACCESS_DENIED });
        }

        const token = createSessionToken(user);

        res.json({
            token,
            user: publicUser(user),
            message: "Senha definida com sucesso.",
        });
    } catch (err) {
        if (err.name === "TokenExpiredError") {
            return res.status(401).json({ error: "Código expirado. Faça login novamente." });
        }
        if (err.name === "JsonWebTokenError") {
            return res.status(401).json({ error: "Sessão de configuração inválida." });
        }
        console.error("Erro ao definir senha:", err.message);
        res.status(500).json({ error: "Erro ao definir senha." });
    }
});

router.post("/esqueci-senha/iniciar", async (req, res) => {
    const { usuario } = req.body || {};

    if (!usuario?.trim()) {
        return res.status(400).json({ error: "Informe o e-mail corporativo." });
    }

    try {
        const user = await findUsuarioByLogin(usuario);

        if (!user || !isActiveUsuario(user)) {
            return res.status(401).json({ error: "E-mail não encontrado ou inválido." });
        }

        if (!hasWebPassword(user)) {
            return res.status(403).json({
                error: "Este usuário ainda não possui senha web. Faça login para configurar o primeiro acesso.",
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
        res.status(500).json({ error: "Erro ao iniciar recuperação de senha." });
    }
});

router.post("/esqueci-senha/enviar-codigo", async (req, res) => {
    const { pendingToken, email } = req.body || {};

    if (!pendingToken || !email?.trim()) {
        return res.status(400).json({ error: "Informe o e-mail." });
    }

    try {
        const payload = verifyPendingResetToken(pendingToken);
        const user = await findUsuarioById(payload.userId);

        if (!user || !isActiveUsuario(user) || !hasWebPassword(user)) {
            return res.status(400).json({ error: "Não é possível redefinir a senha deste usuário." });
        }

        return sendResetCode(user, email, res);
    } catch (err) {
        if (err.name === "TokenExpiredError" || err.name === "JsonWebTokenError") {
            return res.status(401).json({ error: "Sessão expirada. Tente novamente." });
        }
        console.error("Erro ao enviar código:", err.message);
        res.status(500).json({ error: "Erro ao enviar código." });
    }
});

router.post("/esqueci-senha/reenviar", async (req, res) => {
    const { setupToken } = req.body || {};

    if (!setupToken) {
        return res.status(400).json({ error: "Sessão de redefinição inválida." });
    }

    try {
        const payload = verifyResetToken(setupToken);
        const user = await findUsuarioById(payload.userId);

        if (!user || !isActiveUsuario(user) || !hasWebPassword(user) || !payload.email) {
            return res.status(400).json({ error: "Não é possível reenviar o código para este usuário." });
        }

        return sendResetCode(user, payload.email, res);
    } catch {
        return res.status(401).json({ error: "Código expirado. Tente novamente." });
    }
});

router.post("/esqueci-senha/redefinir-senha", async (req, res) => {
    const { setupToken, codigo, senha, confirmarSenha } = req.body || {};

    if (!setupToken || !codigo?.trim() || !senha || !confirmarSenha) {
        return res.status(400).json({ error: "Preencha o código e a nova senha." });
    }

    const senhaNormalizada = normalizeWebPassword(senha);
    const confirmarNormalizada = normalizeWebPassword(confirmarSenha);

    if (senhaNormalizada.length < 6) {
        return res.status(400).json({ error: "A senha deve ter pelo menos 6 caracteres." });
    }

    if (senhaNormalizada !== confirmarNormalizada) {
        return res.status(400).json({ error: "As senhas não conferem." });
    }

    try {
        const payload = verifyResetToken(setupToken);

        if (String(payload.code) !== String(codigo).trim()) {
            return res.status(401).json({ error: "Código inválido." });
        }

        const user = await findUsuarioById(payload.userId);
        if (!user || !isActiveUsuario(user)) {
            return res.status(401).json({ error: "Usuário inválido." });
        }

        if (!hasWebPassword(user)) {
            return res.status(400).json({ error: "Use o fluxo de primeiro acesso para definir a senha." });
        }

        await upgradeWebPasswordHash(user.usuario_id, senhaNormalizada);

        if (!canAccessWebSystem(user)) {
            return res.status(403).json({ error: WEB_ACCESS_DENIED });
        }

        const token = createSessionToken(user);

        res.json({
            token,
            user: publicUser(user),
            message: "Senha redefinida com sucesso.",
        });
    } catch (err) {
        if (err.name === "TokenExpiredError") {
            return res.status(401).json({ error: "Código expirado. Tente novamente." });
        }
        if (err.name === "JsonWebTokenError") {
            return res.status(401).json({ error: "Sessão de redefinição inválida." });
        }
        console.error("Erro ao redefinir senha:", err.message);
        res.status(500).json({ error: "Erro ao redefinir senha." });
    }
});

router.get("/me", require("../middleware/auth"), (req, res) => {
    res.json({ user: req.user });
});

module.exports = router;
