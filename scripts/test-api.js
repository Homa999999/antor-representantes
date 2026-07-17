require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const getPool = require("../server/db");
const { listPedidos } = require("../server/services/pedidos");
const { listFinanceiro } = require("../server/services/financeiro");
const { listComissao } = require("../server/services/comissao");

(async () => {
    const user = { representanteId: null };
    const pedidos = await listPedidos({ periodoInicio: "2026-07-01", periodoFim: "2026-07-17" }, user);
    console.log("pedidos", pedidos.count, pedidos.items[0]);
    const fin = await listFinanceiro({ cliente: "GOYAZES", situacao: "todas" }, user);
    console.log("financeiro", fin.count, fin.items[0]);
    const com = await listComissao({ periodoInicio: "2018-01-01", periodoFim: "2019-12-31" }, user);
    console.log("comissao", com.count, com.items[0]);
    process.exit(0);
})().catch((e) => {
    console.error(e);
    process.exit(1);
});
