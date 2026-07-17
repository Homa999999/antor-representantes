const express = require("express");
const authMiddleware = require("../middleware/auth");
const { listFinanceiro } = require("../services/financeiro");

const router = express.Router();

router.get("/", authMiddleware, async (req, res) => {
    try {
        const data = await listFinanceiro(
            {
                situacao: req.query.situacao,
                tipoData: req.query.tipo_data,
                periodoInicio: req.query.periodo_inicio,
                periodoFim: req.query.periodo_fim,
                cliente: req.query.cliente,
                sort: req.query.sort,
                order: req.query.order,
                limit: req.query.limit,
            },
            req.user
        );
        res.json(data);
    } catch (err) {
        console.error("Erro ao listar financeiro:", err.message);
        res.status(500).json({ error: "Erro ao carregar financeiro." });
    }
});

module.exports = router;
