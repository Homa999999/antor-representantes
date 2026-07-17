require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const getPool = require("../server/db");

(async () => {
    const p = getPool();
    const rows = (await p.query(`
        SELECT pd_id_representante, pd_cod_representante, COUNT(*)::int AS c
        FROM pd_fixo
        WHERE pd_id_representante IS NOT NULL
        GROUP BY 1,2 ORDER BY c DESC LIMIT 5
    `)).rows;
    console.log(rows);
    const u = (await p.query(`
        SELECT usuario_id, usuario_representante_id FROM usuario
        WHERE usuario_representante_id IS NOT NULL LIMIT 3
    `)).rows;
    console.log(u);
    process.exit(0);
})();
