const crypto = require("crypto");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const getPool = require("../db");

const JWT_SECRET = () => process.env.JWT_SECRET || "antor-dev-secret";
const BCRYPT_ROUNDS = 10;

function normalizeWebPassword(senha) {
    return String(senha || "").trim().toUpperCase();
}

function isBcryptHash(value) {
    return /^\$2[aby]\$\d{2}\$/.test(String(value || "").trim());
}

function isMd5Hash(value) {
    return /^[a-f0-9]{32}$/i.test(String(value || "").trim());
}

function hashMd5Legacy(senha) {
    return crypto.createHash("md5").update(normalizeWebPassword(senha), "utf8").digest("hex");
}

async function hashWebPassword(senha) {
    return bcrypt.hash(normalizeWebPassword(senha), BCRYPT_ROUNDS);
}

async function verifyWebPassword(plain, stored) {
    const plainNorm = normalizeWebPassword(plain);
    const storedTrim = String(stored || "").trim();

    if (!storedTrim) {
        return { ok: false, needsUpgrade: false };
    }

    if (isBcryptHash(storedTrim)) {
        const ok = await bcrypt.compare(plainNorm, storedTrim);
        return { ok, needsUpgrade: false };
    }

    if (isMd5Hash(storedTrim)) {
        const ok = hashMd5Legacy(plainNorm) === storedTrim.toLowerCase();
        return { ok, needsUpgrade: ok };
    }

    const ok = storedTrim.toUpperCase() === plainNorm;
    return { ok, needsUpgrade: ok };
}

function isUsuarioDesativado(row) {
    if (!row) return false;

    const ativado = String(row.usuario_ativado ?? "S").trim().toUpperCase();
    if (["N", "0", "F"].includes(ativado)) return true;

    if (row.usuario_ativo === false) return true;

    return false;
}

function isActiveUsuario(row) {
    return row && !isUsuarioDesativado(row);
}

function getRepresentanteId(row) {
    const id = Number(row?.usuario_representante_id);
    return Number.isFinite(id) && id > 0 ? id : null;
}

function hasWebFullAccess(row) {
    if (!row) return false;
    if (row.usuario_acessa_web === true) return true;
    if (row.usuario_acessa_website === true) return true;
    return false;
}

function canAccessWebSystem(row) {
    if (!isActiveUsuario(row)) return false;
    if (getRepresentanteId(row)) return true;
    return hasWebFullAccess(row);
}

const USUARIO_ACCESS_FIELDS = `
    usuario_id,
    usuario_nome,
    usuario_usuario,
    usuario_codigo,
    usuario_representante_id,
    usuario_ativado,
    usuario_ativo,
    usuario_senha_web,
    usuario_email,
    usuario_corporativo,
    usuario_pessoal,
    usuario_representante_email,
    usuario_acessa_website
`;

async function findUsuarioById(usuarioId) {
    const { rows } = await getPool().query(
        `SELECT ${USUARIO_ACCESS_FIELDS}
         FROM usuario
         WHERE usuario_id = $1
         LIMIT 1`,
        [usuarioId]
    );
    return rows[0] || null;
}

function hasWebPassword(row) {
    return Boolean(String(row.usuario_senha_web || "").trim());
}

function getUserEmail(row) {
    const candidates = [row.usuario_email, row.usuario_corporativo, row.usuario_pessoal, row.usuario_representante_email];
    for (const value of candidates) {
        const email = String(value || "").trim();
        if (email && email.includes("@")) return email;
    }
    return null;
}

function maskEmail(email) {
    const [local, domain] = email.split("@");
    if (!domain) return email;
    const visible = local.slice(0, Math.min(2, local.length));
    return `${visible}${"*".repeat(Math.max(local.length - visible.length, 3))}@${domain}`;
}

function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email || "").trim());
}

function normalizeEmail(email) {
    return String(email || "").trim().toLowerCase();
}

function matchesUsuarioCorporativo(user, value) {
    const corp = normalizeEmail(user.usuario_corporativo);
    if (!corp) return false;
    return normalizeEmail(value) === corp;
}

async function findUsuarioByLogin(usuario) {
    const { rows } = await getPool().query(
        `SELECT
            ${USUARIO_ACCESS_FIELDS}
         FROM usuario
         WHERE LOWER(TRIM(usuario_corporativo)) = LOWER(TRIM($1))
         LIMIT 1`,
        [usuario]
    );
    return rows[0] || null;
}

function createSessionToken(user, remember = false) {
    return jwt.sign(
        {
            id: user.usuario_id,
            nome: user.usuario_nome,
            usuario: user.usuario_usuario,
            codigo: user.usuario_codigo,
            representanteId: user.usuario_representante_id,
        },
        JWT_SECRET(),
        { expiresIn: remember ? "30d" : "8h" }
    );
}

function createPendingSetupToken(userId) {
    return jwt.sign(
        {
            purpose: "pending_setup",
            userId,
        },
        JWT_SECRET(),
        { expiresIn: "30m" }
    );
}

function verifyPendingSetupToken(token) {
    const payload = jwt.verify(token, JWT_SECRET());
    if (payload.purpose !== "pending_setup") {
        throw new Error("Token de configuração inválido.");
    }
    return payload;
}

function createPendingResetToken(userId) {
    return jwt.sign(
        {
            purpose: "pending_reset",
            userId,
        },
        JWT_SECRET(),
        { expiresIn: "30m" }
    );
}

function verifyPendingResetToken(token) {
    const payload = jwt.verify(token, JWT_SECRET());
    if (payload.purpose !== "pending_reset") {
        throw new Error("Token de recuperação inválido.");
    }
    return payload;
}

function createResetToken(userId, code, email) {
    return jwt.sign(
        {
            purpose: "password_reset",
            userId,
            code: String(code),
            email: normalizeEmail(email),
        },
        JWT_SECRET(),
        { expiresIn: "15m" }
    );
}

function verifyResetToken(resetToken) {
    const payload = jwt.verify(resetToken, JWT_SECRET());
    if (payload.purpose !== "password_reset") {
        throw new Error("Token de recuperação inválido.");
    }
    return payload;
}

function createSetupToken(userId, code, email) {
    return jwt.sign(
        {
            purpose: "password_setup",
            userId,
            code: String(code),
            email: normalizeEmail(email),
        },
        JWT_SECRET(),
        { expiresIn: "15m" }
    );
}

function verifySetupToken(setupToken) {
    const payload = jwt.verify(setupToken, JWT_SECRET());
    if (payload.purpose !== "password_setup") {
        throw new Error("Token de configuração inválido.");
    }
    return payload;
}

function generateCode() {
    return String(Math.floor(100000 + Math.random() * 900000));
}

async function saveWebPassword(userId, senha, email) {
    const hash = await hashWebPassword(senha);
    await getPool().query(
        `UPDATE usuario
         SET usuario_senha_web = $1,
             usuario_email = COALESCE(NULLIF(TRIM(usuario_email), ''), $2)
         WHERE usuario_id = $3`,
        [hash, normalizeEmail(email), userId]
    );
}

async function upgradeWebPasswordHash(userId, senha) {
    const hash = await hashWebPassword(senha);
    await getPool().query(
        `UPDATE usuario SET usuario_senha_web = $1 WHERE usuario_id = $2`,
        [hash, userId]
    );
}

function publicUser(user) {
    const emailCorporativo = String(user.usuario_corporativo || "").trim();
    return {
        id: user.usuario_id,
        nome: user.usuario_nome,
        usuario: user.usuario_usuario,
        emailCorporativo: emailCorporativo || null,
    };
}

module.exports = {
    isActiveUsuario,
    isUsuarioDesativado,
    getRepresentanteId,
    hasWebFullAccess,
    canAccessWebSystem,
    findUsuarioById,
    hasWebPassword,
    getUserEmail,
    maskEmail,
    isValidEmail,
    normalizeEmail,
    matchesUsuarioCorporativo,
    findUsuarioByLogin,
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
    normalizeWebPassword,
    hashWebPassword,
    verifyWebPassword,
    saveWebPassword,
    upgradeWebPasswordHash,
    publicUser,
};
