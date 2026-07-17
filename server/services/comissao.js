const getPool = require("../db");
const { num, parsePeriodoComissao, comissaoPeriodoInRange } = require("../utils/format");

async function listComissao(filters = {}, user = {}) {
    const {
        representante = "",
        periodoInicio,
        periodoFim,
        limit = 300,
    } = filters;

    const conditions = ["COALESCE(c.comissao, 0) <> 0"];
    const params = [];
    let paramIndex = 1;

    if (representante.trim()) {
        conditions.push(`TRIM(a.aa80nome) ILIKE $${paramIndex++}`);
        params.push(`%${representante.trim()}%`);
    } else if (user.representanteId) {
        conditions.push(`c.representante_id = $${paramIndex++}`);
        params.push(user.representanteId);
    }

    const sql = `
        SELECT
            c.id,
            c.representante_id,
            TRIM(c.periodo) AS periodo,
            COALESCE(c.comissao, 0) AS comissao,
            TRIM(a.aa80nome) AS representante
        FROM comissoes c
        LEFT JOIN aa80 a ON a.aa80id = c.representante_id
        WHERE ${conditions.join(" AND ")}
        ORDER BY c.periodo DESC, c.id DESC
        LIMIT $${paramIndex}
    `;

    params.push(Math.min(Number(limit) || 300, 500));

    const { rows } = await getPool().query(sql, params);

    const filtered = rows.filter((row) =>
        comissaoPeriodoInRange(row.periodo, periodoInicio, periodoFim)
    );

    const items = filtered.map((row) => {
        const parsed = parsePeriodoComissao(row.periodo);
        return {
            id: row.id,
            representanteId: row.representante_id,
            representante: row.representante || "—",
            periodo: parsed?.label || String(row.periodo || "").trim(),
            comissao: num(row.comissao),
        };
    });

    const total = items.reduce((sum, row) => sum + row.comissao, 0);

    return {
        items,
        total,
        count: items.length,
    };
}

module.exports = { listComissao };
