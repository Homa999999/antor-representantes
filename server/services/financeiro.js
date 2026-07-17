const getPool = require("../db");
const { num, formatDate } = require("../utils/format");

const SORT_COLUMNS = {
    emissao: "d.df20dtemissao",
    duplicata: "TRIM(d.df20documento)",
    vencimento: "d.df20dtvencimento",
    valor: "COALESCE(d.df20valor, 0)",
    saldo: "COALESCE(d.df20saldo, 0)",
    pagamento: "d.df20dtpagamento",
    pago: "COALESCE(d.df20valor_pago, 0)",
    atraso: "COALESCE(d.df20dias, GREATEST(0, (CURRENT_DATE - d.df20dtvencimento)))",
};

async function getRepresentanteCodigo(representanteId) {
    if (!representanteId) return null;
    const { rows } = await getPool().query(
        `SELECT TRIM(aa80codigo) AS codigo FROM aa80 WHERE aa80id = $1 LIMIT 1`,
        [representanteId]
    );
    return rows[0]?.codigo || null;
}

async function listFinanceiro(filters = {}, user = {}) {
    const {
        situacao = "abertas",
        tipoData = "vencimento",
        periodoInicio,
        periodoFim,
        cliente = "",
        sort = "vencimento",
        order = "asc",
        limit = 300,
    } = filters;

    const dateColumn = {
        vencimento: "d.df20dtvencimento",
        emissao: "d.df20dtemissao",
        pagamento: "d.df20dtpagamento",
    }[tipoData] || "d.df20dtvencimento";

    const conditions = ["COALESCE(d.df20ativo, 0) = 0"];
    const params = [];
    let paramIndex = 1;

    const repCodigo = await getRepresentanteCodigo(user.representanteId);

    if (cliente.trim()) {
        conditions.push(`TRIM(d.df20entidadedesc) ILIKE $${paramIndex++}`);
        params.push(`%${cliente.trim()}%`);
    } else if (repCodigo) {
        conditions.push(`TRIM(d.df20repres_cod) = $${paramIndex++}`);
        params.push(repCodigo);
    } else {
        return { items: [], total: { valor: 0, saldo: 0, pago: 0 }, count: 0, requiresCliente: true };
    }

    if (situacao === "abertas") {
        conditions.push("COALESCE(d.df20saldo, 0) > 0");
    } else if (situacao === "fechadas") {
        conditions.push("COALESCE(d.df20saldo, 0) <= 0");
    }

    if (periodoInicio) {
        conditions.push(`${dateColumn} >= $${paramIndex++}`);
        params.push(periodoInicio);
    }

    if (periodoFim) {
        conditions.push(`${dateColumn} <= $${paramIndex++}`);
        params.push(periodoFim);
    }

    const sortColumn = SORT_COLUMNS[sort] || SORT_COLUMNS.vencimento;
    const sortOrder = String(order).toLowerCase() === "desc" ? "DESC" : "ASC";

    const sql = `
        SELECT
            d.df20id AS id,
            d.df20dtemissao AS emissao,
            TRIM(d.df20documento) AS documento,
            TRIM(d.df20sequ) AS sequencia,
            d.df20dtvencimento AS vencimento,
            COALESCE(d.df20valor, 0) AS valor,
            COALESCE(d.df20saldo, 0) AS saldo,
            d.df20dtpagamento AS pagamento,
            COALESCE(d.df20valor_pago, 0) AS pago,
            COALESCE(
                d.df20dias,
                CASE
                    WHEN COALESCE(d.df20saldo, 0) > 0 AND d.df20dtvencimento < CURRENT_DATE
                        THEN (CURRENT_DATE - d.df20dtvencimento)
                    ELSE 0
                END
            ) AS atraso,
            TRIM(d.df20entidadedesc) AS entidade
        FROM df20 d
        WHERE ${conditions.join(" AND ")}
        ORDER BY ${sortColumn} ${sortOrder} NULLS LAST, d.df20id DESC
        LIMIT $${paramIndex}
    `;

    params.push(Math.min(Number(limit) || 300, 500));

    const { rows } = await getPool().query(sql, params);

    const totals = rows.reduce(
        (acc, row) => {
            acc.valor += num(row.valor);
            acc.saldo += num(row.saldo);
            acc.pago += num(row.pago);
            return acc;
        },
        { valor: 0, saldo: 0, pago: 0 }
    );

    return {
        items: rows.map((row) => ({
            id: row.id,
            emissao: formatDate(row.emissao),
            duplicata: `${row.documento || ""}${row.sequencia ? `-${row.sequencia}` : ""}`.trim() || "—",
            vencimento: formatDate(row.vencimento),
            valor: num(row.valor),
            saldo: num(row.saldo),
            pagamento: formatDate(row.pagamento),
            pago: num(row.pago),
            atraso: num(row.atraso),
            entidade: row.entidade,
        })),
        total: totals,
        count: rows.length,
        requiresCliente: false,
    };
}

module.exports = { listFinanceiro };
