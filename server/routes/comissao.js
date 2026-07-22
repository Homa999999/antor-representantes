const express = require("express");
const authMiddleware = require("../middleware/auth");
const {
    getComissaoContext,
    listRepresentantesOptions,
    listComissao,
} = require("../services/comissao");

const router = express.Router();

router.get("/context", authMiddleware, async (req, res) => {
    try {
        const data = await getComissaoContext(req.user.id);
        res.json(data);
    } catch (err) {
        if (err.status === 403) {
            return res.status(403).json({
                error: "Seu usuário não possui permissão para acessar comissão.",
            });
        }
        console.error("Erro no contexto de comissão:", err.message);
        res.status(500).json({ error: "Erro ao carregar contexto de comissão." });
    }
});

router.get("/representantes", authMiddleware, async (req, res) => {
    try {
        const context = await getComissaoContext(req.user.id);
        if (!context.canSelectRepresentante) {
            return res.status(403).json({
                error: "Você não possui permissão para selecionar representante.",
            });
        }

        const data = await listRepresentantesOptions(req.query.q, {
            offset: req.query.offset,
            limit: req.query.limit || 20,
        });
        res.json(data);
    } catch (err) {
        if (err.status === 403) {
            return res.status(403).json({
                error: "Seu usuário não possui permissão para acessar comissão.",
            });
        }
        console.error("Erro ao listar representantes:", err.message);
        res.status(500).json({ error: "Erro ao carregar representantes." });
    }
});

router.get("/", authMiddleware, async (req, res) => {
    try {
        const data = await listComissao(
            {
                representante: req.query.representante,
                periodoInicio: req.query.periodo_inicio,
                periodoFim: req.query.periodo_fim,
                page: req.query.page,
                limit: req.query.limit,
                sort: req.query.sort,
                order: req.query.order,
                exportAll: req.query.export === "1",
                debug: req.query.debug === "1",
            },
            req.user
        );

        if (data.error && !data.items.length) {
            return res.status(400).json(data);
        }

        res.json(data);
    } catch (err) {
        if (err.status === 403) {
            return res.status(403).json({
                error: "Seu usuário não possui permissão para acessar comissão.",
            });
        }
        console.error("Erro ao listar comissão:", err.message);
        res.status(500).json({ error: "Erro ao carregar comissão." });
    }
});

module.exports = router;
