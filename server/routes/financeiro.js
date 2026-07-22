const express = require("express");
const authMiddleware = require("../middleware/auth");
const {
    getFinanceiroContext,
    listRepresentantesOptions,
    listClientesOptions,
    listFinanceiro,
} = require("../services/financeiro");

const router = express.Router();

router.get("/context", authMiddleware, async (req, res) => {
    try {
        const data = await getFinanceiroContext(req.user.id);
        res.json(data);
    } catch (err) {
        if (err.status === 403) {
            return res.status(403).json({
                error: "Seu usuário não possui permissão para acessar financeiro.",
            });
        }
        console.error("Erro no contexto de financeiro:", err.message);
        res.status(500).json({ error: "Erro ao carregar contexto de financeiro." });
    }
});

router.get("/representantes", authMiddleware, async (req, res) => {
    try {
        const context = await getFinanceiroContext(req.user.id);
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
                error: "Seu usuário não possui permissão para acessar financeiro.",
            });
        }
        console.error("Erro ao listar representantes:", err.message);
        res.status(500).json({ error: "Erro ao carregar representantes." });
    }
});

router.get("/clientes", authMiddleware, async (req, res) => {
    try {
        const data = await listClientesOptions(req.query.representante, req.user, req.query.q, {
            offset: req.query.offset,
            limit: req.query.limit || 20,
        });
        res.json(data);
    } catch (err) {
        if (err.status === 403) {
            return res.status(403).json({
                error: "Seu usuário não possui permissão para acessar financeiro.",
            });
        }
        console.error("Erro ao listar clientes:", err.message);
        res.status(500).json({ error: "Erro ao carregar clientes." });
    }
});

router.get("/", authMiddleware, async (req, res) => {
    try {
        const data = await listFinanceiro(
            {
                situacao: req.query.situacao,
                tipoData: req.query.tipo_data,
                periodoInicio: req.query.periodo_inicio,
                periodoFim: req.query.periodo_fim,
                representante: req.query.representante,
                cliente: req.query.cliente,
                sort: req.query.sort,
                order: req.query.order,
                limit: req.query.limit,
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
                error: "Seu usuário não possui permissão para acessar financeiro.",
            });
        }
        console.error("Erro ao listar financeiro:", err.message);
        res.status(500).json({ error: "Erro ao carregar financeiro." });
    }
});

module.exports = router;
