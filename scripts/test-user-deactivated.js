require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const { findUsuarioByLogin, isUsuarioDesativado } = require("../server/services/userAuth");
const getPool = require("../server/db");

(async () => {
    const cols = await getPool().query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'usuario'
          AND column_name IN ('usuario_ativo', 'usuario_ativado')
    `);
    console.log("cols", cols.rows);

    const deactivated = await getPool().query(`
        SELECT TRIM(usuario_corporativo) AS corp, usuario_ativado, usuario_ativo
        FROM usuario
        WHERE TRIM(COALESCE(usuario_ativado, 'S')) IN ('N', '0', 'F')
           OR usuario_ativo = false
        LIMIT 3
    `);
    console.log("deactivated sample", deactivated.rows);

    if (deactivated.rows[0]?.corp) {
        const user = await findUsuarioByLogin(deactivated.rows[0].corp);
        console.log("isUsuarioDesativado", isUsuarioDesativado(user));
    }

    process.exit(0);
})().catch((err) => {
    console.error(err.message);
    process.exit(1);
});
