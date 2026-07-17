require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const {
    findUsuarioByLogin,
    hasWebPassword,
    getUserEmail,
    createSetupToken,
    generateCode,
} = require("../server/services/userAuth");

(async () => {
    const user = await findUsuarioByLogin("ERICA");
    console.log("user", user?.usuario_usuario, "webPass", hasWebPassword(user), "email", getUserEmail(user));
    const code = generateCode();
    const token = createSetupToken(user.usuario_id, code);
    console.log("code", code, "token ok", Boolean(token));
    process.exit(0);
})().catch((e) => {
    console.error(e);
    process.exit(1);
});
