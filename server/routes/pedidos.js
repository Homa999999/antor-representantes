const express = require("express");
const authMiddleware = require("../middleware/auth");
const { listPedidos } = require("../services/pedidos");

const router = express.Router();

router.get("/", authMiddleware, async (req, res) => {
    try {
        const data = await listPedidos(
            {
                cliente: req.query.cliente,
                periodoInicio: req.query.periodo_inicio,
                periodoFim: req.query.periodo_fim,
                pedido: req.query.pedido,
                status: req.query.status,
                produto: req.query.produto,
                cor: req.query.cor,
                sort: req.query.sort,
                order: req.query.order,
                limit: req.query.limit,
            },
            req.user
        );
        res.json(data);
    } catch (err) {
        console.error("Erro ao listar pedidos:", err.message);
        res.status(500).json({ error: "Erro ao carregar pedidos." });
    }
});

module.exports = router;
