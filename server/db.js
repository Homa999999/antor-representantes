require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });

const { Pool } = require("pg");

function getDbConfig() {
    const password = process.env.DB_PASSWORD;

    if (typeof password !== "string" || !password.trim()) {
        throw new Error(
            "DB_PASSWORD não configurada. Edite o arquivo .env na raiz do projeto e preencha a senha do PostgreSQL."
        );
    }

    return {
        host: process.env.DB_HOST || "localhost",
        port: Number(process.env.DB_PORT || 5432),
        database: process.env.DB_NAME || "bd_antor2026_07_16",
        user: process.env.DB_USER || "postgres",
        password: String(password),
    };
}

let pool;

function getPool() {
    if (!pool) {
        pool = new Pool(getDbConfig());
        pool.on("error", (err) => {
            console.error("Erro inesperado no pool PostgreSQL:", err.message);
        });
    }
    return pool;
}

module.exports = getPool;
