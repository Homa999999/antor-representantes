require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });

const path = require("path");
const express = require("express");
const cors = require("cors");
const getPool = require("./db");
const authRoutes = require("./routes/auth");
const dashboardRoutes = require("./routes/dashboard");
const pedidosRoutes = require("./routes/pedidos");
const financeiroRoutes = require("./routes/financeiro");
const comissaoRoutes = require("./routes/comissao");

const app = express();
const PORT = Number(process.env.PORT || 3000);
const rootDir = path.join(__dirname, "..");

app.use(cors());
app.use(express.json());

app.get("/api/health", async (_req, res) => {
    try {
        await getPool().query("SELECT 1");
        res.json({ ok: true, database: process.env.DB_NAME || "bd_antor2026_07_16" });
    } catch (err) {
        res.status(503).json({ ok: false, error: err.message });
    }
});

app.use("/api/auth", authRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/pedidos", pedidosRoutes);
app.use("/api/financeiro", financeiroRoutes);
app.use("/api/comissao", comissaoRoutes);

app.use(express.static(rootDir));

app.get("/", (_req, res) => {
    res.redirect("/login/");
});

async function start() {
    try {
        await getPool().query("SELECT 1");
        console.log("PostgreSQL conectado.");
    } catch (err) {
        console.error("Falha ao conectar no PostgreSQL:", err.message);
        console.error("Verifique o .env e reinicie o servidor após alterar a senha.");
        process.exit(1);
    }

    const server = app.listen(PORT, () => {
        console.log(`Antor rodando em http://localhost:${PORT}`);
        console.log(`Banco: ${process.env.DB_NAME || "bd_antor2026_07_16"}`);
    });

    server.on("error", (err) => {
        if (err.code === "EADDRINUSE") {
            console.error(`Porta ${PORT} já está em uso.`);
            console.error("O Antor provavelmente já está rodando — acesse http://localhost:" + PORT);
            console.error("Para reiniciar, encerre o processo anterior ou use: npx kill-port 3000");
            process.exit(1);
        }
        throw err;
    });
}

start();
