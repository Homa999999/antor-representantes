const express = require("express");
const authMiddleware = require("../middleware/auth");
const { getHomeDashboard } = require("../services/dashboard");

const router = express.Router();

router.get("/home", authMiddleware, async (req, res) => {
    try {
        const data = await getHomeDashboard(req.user.id);
        res.json(data);
    } catch (err) {
        if (err.status === 403) {
            return res.status(403).json({ error: "Seu usuário não possui permissão para acessar o sistema web." });
        }
        console.error("Erro no dashboard home:", err.message);
        res.status(500).json({ error: "Erro ao carregar dados do dashboard." });
    }
});

module.exports = router;
