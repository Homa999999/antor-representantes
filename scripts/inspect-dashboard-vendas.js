require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const getPool = require("../server/db");

(async () => {
    const p = getPool();
    const cols = await p.query(`
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = 'dashboard_vendas'
        ORDER BY ordinal_position
    `);
    console.log("dashboard_vendas", cols.rows);

    const ucols = await p.query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'usuario'
          AND (column_name LIKE '%acessa%' OR column_name LIKE '%representante%')
        ORDER BY column_name
    `);
    console.log("usuario cols", ucols.rows);

    const sample = await p.query("SELECT * FROM dashboard_vendas LIMIT 5");
    console.log("sample", sample.rows);

    const webCols = await p.query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'usuario'
          AND column_name IN ('usuario_acessa_web', 'usuario_acessa_website')
    `);
    console.log("web access cols", webCols.rows);

    const reps = await p.query(`
        SELECT usuario_id, TRIM(usuario_corporativo) AS corp,
               usuario_representante_id, usuario_acessa_website
        FROM usuario
        WHERE usuario_representante_id IS NOT NULL
        LIMIT 5
    `);
    console.log("reps", reps.rows);
})().catch((e) => {
    console.error(e.message);
    process.exit(1);
});
