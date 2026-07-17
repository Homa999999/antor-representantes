const getPool = require("../db");
const { num, formatDate } = require("../utils/format");

const SORT_COLUMNS = {
    cliente: "TRIM(p.pd_nome_cliente)",
    comerc: "TRIM(p.pd_nome_representante)",
    posse: "COALESCE(NULLIF(TRIM(p.pd_programado_descricao), ''), TRIM(p.pd_programado))",
    pedido: "TRIM(p.pd_codigo)",
    emissao: "p.pd_data_emissao",
    valor: "COALESCE(p.pd_valor_liquido, p.pd_valor, 0)",
};

function buildStatusCase(alias = "p") {
    return `
        CASE
            WHEN COALESCE(${alias}.pd_inativado, false) = true
              OR EXISTS (SELECT 1 FROM pd_cancelados c WHERE c.pdc_id_pedido = ${alias}.pd_id)
                THEN 'cancelado'
            WHEN TRIM(COALESCE(${alias}.pd_programado, '')) = 'P'
                THEN 'aceito'
            ELSE 'aguard'
        END
    `;
}

function buildPosseCase(alias = "p") {
    return `
        COALESCE(
            NULLIF(TRIM(${alias}.pd_programado_descricao), ''),
            CASE TRIM(COALESCE(${alias}.pd_programado, ''))
                WHEN 'P' THEN 'Programado'
                WHEN 'E' THEN 'Em execução'
                ELSE 'Aguardando'
            END
        )
    `;
}

async function listPedidos(filters = {}, user = {}) {
    const {
        cliente = "",
        periodoInicio,
        periodoFim,
        pedido = "",
        status = "",
        produto = "",
        cor = "",
        sort = "emissao",
        order = "desc",
        limit = 200,
    } = filters;

    const conditions = ["1=1"];
    const params = [];
    let paramIndex = 1;

    if (user.representanteId) {
        conditions.push(`TRIM(p.pd_id_representante) = $${paramIndex++}`);
        params.push(String(user.representanteId));
    }

    if (cliente.trim()) {
        conditions.push(`TRIM(p.pd_nome_cliente) ILIKE $${paramIndex++}`);
        params.push(`%${cliente.trim()}%`);
    }

    if (periodoInicio) {
        conditions.push(`p.pd_data_emissao >= $${paramIndex++}`);
        params.push(periodoInicio);
    }

    if (periodoFim) {
        conditions.push(`p.pd_data_emissao <= $${paramIndex++}`);
        params.push(periodoFim);
    }

    if (pedido.trim()) {
        conditions.push(`TRIM(p.pd_codigo) ILIKE $${paramIndex++}`);
        params.push(`%${pedido.trim()}%`);
    }

    if (status) {
        conditions.push(`${buildStatusCase("p")} = $${paramIndex++}`);
        params.push(status);
    }

    if (produto.trim() || cor.trim()) {
        conditions.push(`EXISTS (
            SELECT 1 FROM pdi_item i
            WHERE i.pdi_id_pedido = p.pd_id
              ${produto.trim() ? `AND TRIM(i.pdi_ref_prod) ILIKE $${paramIndex++}` : ""}
              ${cor.trim() ? `AND TRIM(i.pdi_cor_prod) ILIKE $${paramIndex++}` : ""}
        )`);
        if (produto.trim()) params.push(`%${produto.trim()}%`);
        if (cor.trim()) params.push(`%${cor.trim()}%`);
    }

    const sortColumn = SORT_COLUMNS[sort] || SORT_COLUMNS.emissao;
    const sortOrder = String(order).toLowerCase() === "asc" ? "ASC" : "DESC";

    const sql = `
        SELECT
            p.pd_id AS id,
            TRIM(p.pd_codigo) AS pedido,
            TRIM(p.pd_nome_cliente) AS cliente,
            TRIM(p.pd_nome_representante) AS comerciante,
            ${buildPosseCase("p")} AS posse,
            ${buildStatusCase("p")} AS status,
            p.pd_data_emissao AS emissao,
            COALESCE(p.pd_valor_liquido, p.pd_valor, 0) AS valor
        FROM pd_fixo p
        WHERE ${conditions.join(" AND ")}
        ORDER BY ${sortColumn} ${sortOrder} NULLS LAST, p.pd_id DESC
        LIMIT $${paramIndex}
    `;

    params.push(Math.min(Number(limit) || 200, 500));

    const { rows } = await getPool().query(sql, params);
    const total = rows.reduce((sum, row) => sum + num(row.valor), 0);

    return {
        items: rows.map((row) => ({
            id: row.id,
            pedido: row.pedido,
            cliente: row.cliente,
            comerciante: row.comerciante || "—",
            posse: row.posse,
            status: row.status,
            emissao: formatDate(row.emissao),
            valor: num(row.valor),
        })),
        total: num(total),
        count: rows.length,
    };
}

module.exports = { listPedidos };
