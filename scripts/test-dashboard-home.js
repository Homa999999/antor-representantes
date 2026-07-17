require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const getPool = require("../server/db");
const { getHomeDashboard } = require("../server/services/dashboard");

(async () => {
    const p = getPool();

    const global = await p.query(`
        SELECT
            COALESCE(SUM(CASE WHEN ano = EXTRACT(YEAR FROM CURRENT_DATE) THEN valor_mes ELSE 0 END), 0) AS valor_ano,
            COALESCE(SUM(CASE WHEN ano = EXTRACT(YEAR FROM CURRENT_DATE) AND mes = EXTRACT(MONTH FROM CURRENT_DATE) THEN valor_mes ELSE 0 END), 0) AS valor_mes,
            COUNT(*) AS total_rows,
            MAX(mes) FILTER (WHERE ano = EXTRACT(YEAR FROM CURRENT_DATE)) AS max_mes_ano
        FROM dashboard_vendas
    `);
    console.log("global", global.rows[0]);

    const users = await p.query(`
        SELECT usuario_id, usuario_representante_id, TRIM(usuario_corporativo) AS corp
        FROM usuario
        WHERE usuario_corporativo IS NOT NULL
          AND TRIM(usuario_corporativo) <> ''
        LIMIT 5
    `);

    for (const user of users.rows) {
        try {
            const data = await getHomeDashboard(user.usuario_id);
            console.log("user", user.usuario_id, "rep", user.usuario_representante_id, data.escopo, data.vendas);
        } catch (err) {
            console.log("user", user.usuario_id, "error", err.message);
        }
    }

    process.exit(0);
})().catch((err) => {
    console.error(err);
    process.exit(1);
});
