const getPool = require("../db");
const {
    findUsuarioById,
    getRepresentanteId,
    canAccessWebSystem,
} = require("./userAuth");

function num(value) {
    return Number(value || 0);
}

function round(value, digits = 2) {
    const factor = 10 ** digits;
    return Math.round(num(value) * factor) / factor;
}

function toMil(value) {
    return round(num(value) / 1000, 1);
}

async function getPedidosResumo() {
    const { rows } = await getPool().query(`
        SELECT
            COUNT(*) FILTER (
                WHERE COALESCE(pd_inativado, false) = false
                  AND pd_data_faturamento IS NULL
                  AND pd_data_fechamento IS NULL
                  AND COALESCE(TRIM(pd_programado), '') NOT IN ('S', 's', '1')
            ) AS em_aberto,
            COUNT(*) FILTER (
                WHERE COALESCE(pd_inativado, false) = false
                  AND pd_data_faturamento IS NULL
                  AND pd_data_fechamento IS NULL
                  AND COALESCE(TRIM(pd_programado), '') IN ('S', 's', '1')
            ) AS em_andamento,
            COUNT(*) FILTER (
                WHERE COALESCE(pd_inativado, false) = false
                  AND (pd_data_faturamento IS NOT NULL OR pd_data_fechamento IS NOT NULL)
            ) AS concluidos,
            COUNT(*) FILTER (
                WHERE COALESCE(pd_inativado, false) = false
                  AND pd_data_faturamento IS NULL
                  AND pd_data_embarque IS NOT NULL
                  AND pd_data_embarque < CURRENT_DATE
            ) AS atrasados
        FROM pd_fixo
    `);

    return rows[0];
}

async function getPedidosSemana() {
    const { rows } = await getPool().query(`
        WITH dias AS (
            SELECT generate_series(
                date_trunc('week', CURRENT_DATE)::date,
                (date_trunc('week', CURRENT_DATE) + interval '6 days')::date,
                interval '1 day'
            )::date AS dia
        )
        SELECT
            EXTRACT(ISODOW FROM d.dia)::int AS dow,
            TO_CHAR(d.dia, 'Dy') AS label,
            COUNT(p.pd_id) AS total
        FROM dias d
        LEFT JOIN pd_fixo p
          ON p.pd_data_emissao = d.dia
         AND COALESCE(p.pd_inativado, false) = false
        GROUP BY d.dia
        ORDER BY d.dia
    `);

    const labelsPt = { Mon: "Seg", Tue: "Ter", Wed: "Qua", Thu: "Qui", Fri: "Sex", Sat: "Sáb", Sun: "Dom" };
    const counts = rows.map((row) => num(row.total));
    const max = Math.max(...counts, 1);

    return rows.map((row) => ({
        label: labelsPt[row.label.trim()] || row.label.trim(),
        total: num(row.total),
        percent: round((num(row.total) / max) * 100, 0),
    }));
}

async function getMetaConclusao() {
    const { rows } = await getPool().query(`
        SELECT
            COUNT(*) FILTER (WHERE COALESCE(pd_inativado, false) = false) AS total_mes,
            COUNT(*) FILTER (
                WHERE COALESCE(pd_inativado, false) = false
                  AND (pd_data_faturamento IS NOT NULL OR pd_data_fechamento IS NOT NULL)
            ) AS concluidos_mes,
            COUNT(*) FILTER (
                WHERE COALESCE(pd_inativado, false) = false
                  AND pd_data_faturamento IS NULL
                  AND pd_data_fechamento IS NULL
            ) AS abertos_mes
        FROM pd_fixo
        WHERE pd_data_emissao >= date_trunc('month', CURRENT_DATE)
          AND pd_data_emissao < date_trunc('month', CURRENT_DATE) + interval '1 month'
    `);

    const total = num(rows[0]?.total_mes);
    const concluidos = num(rows[0]?.concluidos_mes);
    const abertos = num(rows[0]?.abertos_mes);
    const percent = total > 0 ? round((concluidos / total) * 100, 0) : 0;

    return { total, concluidos, abertos, percent };
}

async function getFinanceiroMes() {
    const { rows } = await getPool().query(`
        SELECT
            COALESCE(SUM(CASE WHEN TRIM(df20rec_pag) = 'R' THEN df20valor ELSE 0 END), 0) AS receita,
            COALESCE(SUM(CASE WHEN TRIM(df20rec_pag) = 'P' THEN df20valor ELSE 0 END), 0) AS despesas,
            COALESCE(SUM(CASE WHEN TRIM(df20rec_pag) = 'R' AND COALESCE(df20saldo, 0) > 0 THEN df20saldo ELSE 0 END), 0) AS a_receber
        FROM df20
        WHERE COALESCE(df20ativo, 0) = 0
          AND df20dtemissao >= date_trunc('month', CURRENT_DATE)
          AND df20dtemissao < date_trunc('month', CURRENT_DATE) + interval '1 month'
    `);

    const receita = num(rows[0]?.receita);
    const despesas = num(rows[0]?.despesas);
    const aReceber = num(rows[0]?.a_receber);
    const saldo = receita - despesas;
    const max = Math.max(receita, despesas, Math.abs(saldo), 1);

    return {
        receita,
        despesas,
        saldo,
        aReceber,
        receitaPercent: round((receita / max) * 100, 0),
        despesasPercent: round((despesas / max) * 100, 0),
        saldoPercent: round((Math.abs(saldo) / max) * 100, 0),
        mesLabel: new Date().toLocaleDateString("pt-BR", { month: "short", year: "numeric" }).replace(".", ""),
    };
}

async function getVendasPainel(representanteId = null) {
    const params = [];
    let whereClause = "";

    if (representanteId != null) {
        params.push(representanteId);
        whereClause = "WHERE representante_id = $1";
    }

    const { rows } = await getPool().query(
        `
        SELECT
            COALESCE(SUM(CASE
                    WHEN ano = EXTRACT(YEAR FROM CURRENT_DATE)
                     AND mes = EXTRACT(MONTH FROM CURRENT_DATE)
                    THEN valor_mes
                    ELSE 0
                END), 0) AS valor_mes,
            COALESCE(SUM(CASE
                    WHEN ano = EXTRACT(YEAR FROM CURRENT_DATE)
                     AND mes = EXTRACT(MONTH FROM CURRENT_DATE)
                    THEN metros_mes
                    ELSE 0
                END), 0) AS metros_mes,
            COALESCE(SUM(CASE
                    WHEN ano = EXTRACT(YEAR FROM CURRENT_DATE)
                    THEN valor_mes
                    ELSE 0
                END), 0) AS valor_ano,
            COALESCE(SUM(CASE
                    WHEN ano = EXTRACT(YEAR FROM CURRENT_DATE)
                    THEN metros_mes
                    ELSE 0
                END), 0) AS metros_ano
        FROM dashboard_vendas
        ${whereClause}
        `,
        params
    );

    const row = rows[0] || {};
    const ultimaAtualizacao = await getUltimaAtualizacaoVendas(representanteId);

    return {
        vendasAnoMt: num(row.metros_ano),
        vendasAnoRs: num(row.valor_ano),
        vendasMesMt: num(row.metros_mes),
        vendasMesRs: num(row.valor_mes),
        ultimaAtualizacao,
    };
}

async function getUltimaAtualizacaoVendas(representanteId = null) {
    const params = [];
    let whereClause = "";

    if (representanteId != null) {
        params.push(representanteId);
        whereClause = "WHERE representante_id = $1";
    }

    const { rows } = await getPool().query(
        `
        SELECT ano, mes, MAX(data_hora) AS data_hora
        FROM dashboard_vendas
        ${whereClause}
        GROUP BY ano, mes
        ORDER BY ano DESC, mes DESC
        LIMIT 1
        `,
        params
    );

    const row = rows[0];
    if (!row) return null;

    return {
        ano: num(row.ano),
        mes: num(row.mes),
        dataHora: row.data_hora ? new Date(row.data_hora).toISOString() : null,
    };
}

async function getVariacaoSemanaPedidos() {
    const { rows } = await getPool().query(`
        SELECT
            COUNT(*) FILTER (
                WHERE pd_data_emissao >= date_trunc('week', CURRENT_DATE)
                  AND COALESCE(pd_inativado, false) = false
            ) AS semana_atual,
            COUNT(*) FILTER (
                WHERE pd_data_emissao >= date_trunc('week', CURRENT_DATE) - interval '7 days'
                  AND pd_data_emissao < date_trunc('week', CURRENT_DATE)
                  AND COALESCE(pd_inativado, false) = false
            ) AS semana_anterior
        FROM pd_fixo
    `);

    const atual = num(rows[0]?.semana_atual);
    const anterior = num(rows[0]?.semana_anterior);
    if (anterior === 0) return atual > 0 ? 100 : 0;
    return round(((atual - anterior) / anterior) * 100, 0);
}

function buildProgress(pedidos) {
    const total =
        num(pedidos.em_aberto) +
        num(pedidos.em_andamento) +
        num(pedidos.concluidos) +
        num(pedidos.atrasados);

    const pct = (value) => (total > 0 ? round((num(value) / total) * 100, 0) : 0);

    return {
        emAberto: { count: num(pedidos.em_aberto), percent: pct(pedidos.em_aberto) },
        emAndamento: { count: num(pedidos.em_andamento), percent: pct(pedidos.em_andamento) },
        concluidos: { count: num(pedidos.concluidos), percent: pct(pedidos.concluidos) },
        atrasados: { count: num(pedidos.atrasados), percent: pct(pedidos.atrasados) },
        total,
    };
}

async function getHomeDashboard(usuarioId) {
    const user = await findUsuarioById(usuarioId);

    if (!user || !canAccessWebSystem(user)) {
        const err = new Error("WEB_ACCESS_DENIED");
        err.status = 403;
        throw err;
    }

    const representanteId = getRepresentanteId(user);
    const escopo = representanteId ? "representante" : "global";

    const [meta, vendas] = await Promise.all([
        getMetaConclusao(),
        getVendasPainel(representanteId),
    ]);

    const mesLabel = new Date()
        .toLocaleDateString("pt-BR", { month: "long", year: "numeric" })
        .replace(/^\w/, (c) => c.toUpperCase());

    return {
        escopo,
        representanteId,
        meta: {
            ...meta,
            mesLabel,
        },
        vendas,
    };
}

module.exports = { getHomeDashboard };
