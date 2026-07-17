require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const getPool = require("../server/db");

(async () => {
    const p = getPool();
    const cols = await p.query(`
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'usuario' AND column_name LIKE '%senha%' OR (table_name = 'usuario' AND column_name LIKE '%email%')
        ORDER BY 1
    `);
    console.log("cols", cols.rows);

    const users = await p.query(`
        SELECT usuario_usuario, TRIM(usuario_email) AS email, TRIM(usuario_corporativo) AS corp,
               usuario_senha_web
        FROM usuario
        WHERE UPPER(TRIM(COALESCE(usuario_ativado, 'S'))) NOT IN ('N', '0', 'F')
        LIMIT 5
    `);
    console.log("users", users.rows);

    const smtp = await p.query("SELECT * FROM parametros_smtp LIMIT 1");
    console.log("smtp", smtp.rows[0]);

    const counts = await p.query(`
        SELECT COUNT(*)::int AS total,
               COUNT(NULLIF(TRIM(COALESCE(usuario_email, usuario_corporativo, usuario_pessoal, '')), ''))::int AS com_email
        FROM usuario
    `);
    console.log("counts", counts.rows[0]);

    const withEmail = await p.query(`
        SELECT usuario_usuario, TRIM(COALESCE(NULLIF(TRIM(usuario_email), ''), NULLIF(TRIM(usuario_corporativo), ''), NULLIF(TRIM(usuario_pessoal), ''))) AS email
        FROM usuario
        WHERE NULLIF(TRIM(COALESCE(usuario_email, usuario_corporativo, usuario_pessoal, '')), '') IS NOT NULL
        LIMIT 5
    `);
    console.log("withEmail", withEmail.rows);
})().catch((e) => {
    console.error(e.message);
    process.exit(1);
});
