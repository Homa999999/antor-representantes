const nodemailer = require("nodemailer");
const getPool = require("../db");

let cachedTransporter = null;

function escapeHtml(value) {
    return String(value || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

function buildAccessCodeEmailHtml({ nome, code, context = "setup" }) {
    const safeName = escapeHtml(nome);
    const safeCode = escapeHtml(code);
    const greeting = safeName ? `Olá, <strong style="color:#1e293b">${safeName}</strong>!` : "Olá!";
    const isReset = context === "reset";
    const badge = isReset ? "Redefinição de senha" : "Primeiro acesso";
    const instruction = isReset
        ? "Use o código abaixo na tela de login para redefinir sua senha de acesso:"
        : "Use o código abaixo na tela de login para definir sua senha de acesso:";
    const title = isReset ? "Redefinição de senha — Antor" : "Código de acesso — Antor";

    return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title}</title>
</head>
<body style="margin:0;padding:0;background-color:#f8fafc;font-family:'Segoe UI',Arial,sans-serif;color:#1e293b;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#f8fafc" style="background-color:#f8fafc;padding:32px 16px;">
        <tr>
            <td align="center">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background-color:#ffffff;border:1px solid #e2e8f0;border-radius:12px;overflow:hidden;">
                    <tr>
                        <td bgcolor="#ffcf00" style="background-color:#ffcf00;padding:24px 28px;text-align:center;">
                            <div style="font-size:22px;font-weight:800;letter-spacing:0.08em;color:#1e293b;">ANTOR</div>
                            <div style="margin-top:4px;font-size:12px;font-weight:500;color:#475569;letter-spacing:0.04em;">${badge}</div>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding:28px 28px 24px;">
                            <p style="margin:0 0 12px;font-size:16px;line-height:1.6;color:#1e293b;">${greeting}</p>
                            <p style="margin:0 0 24px;font-size:15px;line-height:1.65;color:#64748b;">
                                ${instruction}
                            </p>
                            <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                                <tr>
                                    <td align="center" style="padding:0 0 20px;">
                                        <table role="presentation" cellspacing="0" cellpadding="0" style="background-color:#fffbeb;border:1px solid #ffcf00;border-radius:10px;">
                                            <tr>
                                                <td style="padding:18px 28px;text-align:center;">
                                                    <div style="font-size:32px;font-weight:700;letter-spacing:10px;color:#b8860b;font-family:Consolas,'Courier New',monospace;">
                                                        ${safeCode}
                                                    </div>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                            <p style="margin:0 0 16px;font-size:14px;line-height:1.6;color:#64748b;">
                                Este código expira em <strong style="color:#1e293b;">15 minutos</strong>.
                            </p>
                            <p style="margin:0;font-size:13px;line-height:1.6;color:#94a3b8;">
                                Se você não solicitou este código, ignore este e-mail.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>`;
}
async function getSmtpConfig() {
    if (process.env.SMTP_HOST) {
        return {
            host: process.env.SMTP_HOST,
            port: Number(process.env.SMTP_PORT || 587),
            secure: process.env.SMTP_SECURE === "true",
            auth: process.env.SMTP_USER
                ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS || "" }
                : undefined,
            from: process.env.SMTP_FROM || process.env.SMTP_USER,
        };
    }

    const { rows } = await getPool().query(`SELECT * FROM parametros_smtp ORDER BY parametros_smtp_id LIMIT 1`);
    const smtp = rows[0];
    if (!smtp) return null;

    const host = String(smtp.parametros_smtp_servidor || "").trim();
    const user = String(smtp.parametros_smtp_login || "").trim();
    const pass = String(smtp.parametros_smtp_senha || "").trim();
    const fromName = String(smtp.parametros_smtp_reme_nome || "Antor").trim();
    const fromEmail = String(smtp.parametros_smtp_reme_email || user).trim();
    const port = Number(String(smtp.parametros_smtp_porta || "587").trim()) || 587;

    if (!host || !user) return null;

    return {
        host,
        port,
        secure: Boolean(smtp.parametros_smtp_conexao_ssl),
        auth: { user, pass },
        from: fromEmail.includes("@") ? `"${fromName}" <${fromEmail}>` : `"${fromName}" <${user}>`,
    };
}

async function getTransporter() {
    if (cachedTransporter) return cachedTransporter;
    const config = await getSmtpConfig();
    if (!config) return null;

    cachedTransporter = nodemailer.createTransport({
        host: config.host,
        port: config.port,
        secure: config.secure,
        auth: config.auth,
        tls: { rejectUnauthorized: false },
    });

    cachedTransporter._from = config.from;
    return cachedTransporter;
}

async function sendAccessCodeEmail({ to, nome, code, context = "setup" }) {
    const transporter = await getTransporter();
    const isReset = context === "reset";
    const subject = isReset ? "Redefinição de senha — Antor" : "Código de acesso — Antor";
    const textAction = isReset ? "redefinir sua senha de acesso ao sistema Antor" : "definir sua senha de acesso ao sistema Antor";
    const text = [
        `Olá${nome ? `, ${nome}` : ""}!`,
        "",
        `Use o código abaixo para ${textAction}:`,
        "",
        code,
        "",
        "O código expira em 15 minutos.",
        "",
        "Se você não solicitou este código, ignore este e-mail.",
    ].join("\n");

    const html = buildAccessCodeEmailHtml({ nome, code, context });
    if (!transporter) {
        if (process.env.NODE_ENV !== "production") {
            console.log(`[DEV] Código para ${to}: ${code}`);
            return { devMode: true };
        }
        throw new Error("Servidor de e-mail não configurado.");
    }

    await transporter.sendMail({
        from: transporter._from,
        to,
        subject,
        text,
        html,
    });

    return { devMode: false };
}

module.exports = { sendAccessCodeEmail };
