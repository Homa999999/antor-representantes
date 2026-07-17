const express = require("express");
const authMiddleware = require("../middleware/auth");
const { listComissao } = require("../services/comissao");

const router = express.Router();

router.get("/", authMiddleware, async (req, res) => {
    try {
        const data = await listComissao(
            {
                representante: req.query.representante,
                periodoInicio: req.query.periodo_inicio,
                periodoFim: req.query.periodo_fim,
                limit: req.query.limit,
            },
            req.user
        );
        res.json(data);
    } catch (err) {
        console.error("Erro ao listar comissão:", err.message);
        res.status(500).json({ error: "Erro ao carregar comissão." });
    }
});

module.exports = router;
