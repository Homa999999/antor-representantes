require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const getPool = require("../server/db");
const { listComissao } = require("../server/services/comissao");

(async () => {
    const p = getPool();
    const repId = 1421;

    const rep = await p.query(
        `SELECT aa80id, TRIM(aa80codigo) codigo, TRIM(aa80na) na, TRIM(aa80nome) nome FROM aa80 WHERE aa80id=$1`,
        [repId]
    );
    console.log("representante", rep.rows[0]);

    const comissoes = await p.query(
        `SELECT COUNT(*)::int total, COUNT(*) FILTER (WHERE COALESCE(comissao,0)<>0)::int com_valor FROM comissoes WHERE representante_id=$1`,
        [repId]
    );
    console.log("comissoes table", comissoes.rows[0]);

    const comRows = await p.query(
        `SELECT id, TRIM(periodo) periodo, comissao FROM comissoes WHERE representante_id=$1 ORDER BY periodo DESC LIMIT 10`,
        [repId]
    );
    console.log("comissoes sample", comRows.rows);

    const df10 = await p.query(
        `
        SELECT COUNT(*)::int total
        FROM df10
        WHERE TRIM(df10repres_cod) = $1
          AND COALESCE(df10repres_comisao_valor, 0) <> 0
        `,
        [rep.rows[0].codigo]
    );
    console.log("df10 linhas com comissao", df10.rows[0]);

    const view229cod = await p.query(
        `
        SELECT COUNT(*)::int AS total
        FROM relatorio229_comissoes
        WHERE TRIM(df10repres_cod) = $1
        `,
        [rep.rows[0].codigo]
    );
    console.log("relatorio229 by codigo", view229cod.rows[0]);

    const viewSample = await p.query(
        `
        SELECT df10documento, df10dtemissao, "COMISSAO", aa80na, "PEDIDOS"
        FROM relatorio229_comissoes
        WHERE TRIM(df10repres_cod) = $1
        ORDER BY df10dtemissao DESC
        LIMIT 5
        `,
        [rep.rows[0].codigo]
    );
    console.log("relatorio229 sample", viewSample.rows);

    const df10Filtered = await p.query(
        `
        SELECT COUNT(*)::int AS total
        FROM df10
        WHERE TRIM(df10repres_cod) = $1
          AND df10ativo = 0
          AND df10rec_pag = '0'
          AND COALESCE(df10repres_comisao_valor, 0) <> 0
        `,
        [rep.rows[0].codigo]
    );
    console.log("df10 filtered like relatorio229", df10Filtered.rows[0]);

    const count2026 = await p.query(
        `
        SELECT COUNT(*)::int AS total
        FROM relatorio229_comissoes
        WHERE TRIM(df10repres_cod) = $1
          AND df10dtemissao >= '2026-01-01'
          AND df10dtemissao <= '2026-07-20'
        `,
        [rep.rows[0].codigo]
    );
    console.log("relatorio229 2026 jan-jul", count2026.rows[0]);

        const data = await listComissao(
            {
                representante: "CARLA REGINA",
                periodoInicio: "2026-01-01",
                periodoFim: "2026-07-20",
                page: 1,
                limit: 30,
                debug: true,
            },
            { id: 43 }
        );
        console.log("listComissao 2026", data.count, data.totalRecords, data.totalPages, data.items.slice(0, 3), data.meta);

    process.exit(0);
})().catch((err) => {
    console.error(err);
    process.exit(1);
});
