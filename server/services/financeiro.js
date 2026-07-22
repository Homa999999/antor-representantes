const getPool = require("../db");
const {
    findUsuarioById,
    getRepresentanteId,
    canAccessWebSystem,
    hasWebFullAccess,
} = require("./userAuth");
const { listRepresentantesOptions, REP_TODOS_LABEL } = require("./comissao");
const { num, formatDate } = require("../utils/format");

const REP_ACTIVE_CONDITIONS = [
    "TRIM(COALESCE(aa80representante, 'N')) = 'S'",
    "COALESCE(aa80inativo, false) = false",
];

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

function isTodosRepresentante(text) {
    const value = String(text || "").trim().toLowerCase();
    return !value || value === "todos" || value === "__all__";
}

function formatRepresentanteLabel(row) {
    if (!row) return "";
    const na = String(row.na || "").trim();
    const nome = String(row.nome || "").trim();
    return na || nome || "";
}

async function getRepresentanteById(representanteId) {
    const { rows } = await getPool().query(
        `
        SELECT
            aa80id AS id,
            TRIM(aa80codigo) AS codigo,
            TRIM(aa80na) AS na,
            TRIM(aa80nome) AS nome
        FROM aa80
        WHERE aa80id = $1
          AND ${REP_ACTIVE_CONDITIONS.join(" AND ")}
        LIMIT 1
        `,
        [representanteId]
    );

    return rows[0] || null;
}

async function findRepresentanteByText(text) {
    const term = String(text || "").trim();
    if (!term) return null;

    const { rows } = await getPool().query(
        `
        SELECT
            aa80id AS id,
            TRIM(aa80codigo) AS codigo,
            TRIM(aa80na) AS na,
            TRIM(aa80nome) AS nome
        FROM aa80
        WHERE ${REP_ACTIVE_CONDITIONS.join(" AND ")}
          AND (TRIM(aa80na) ILIKE $1 OR TRIM(aa80nome) ILIKE $1)
        ORDER BY
            CASE WHEN TRIM(aa80na) ILIKE $2 THEN 0 ELSE 1 END,
            TRIM(aa80na)
        LIMIT 1
        `,
        [`%${term}%`, term]
    );

    return rows[0] || null;
}

async function resolveFinanceiroUser(jwtUser = {}) {
    const user = await findUsuarioById(jwtUser.id);
    if (!user || !canAccessWebSystem(user)) {
        const err = new Error("WEB_ACCESS_DENIED");
        err.status = 403;
        throw err;
    }

    const representanteId = getRepresentanteId(user);
    const canSelectRepresentante = !representanteId && hasWebFullAccess(user);

    return {
        user,
        representanteId,
        canSelectRepresentante,
        representanteLocked: Boolean(representanteId),
    };
}

async function resolveRepresentanteFiltro(access, representanteText) {
    if (access.representanteId) {
        const rep = await getRepresentanteById(access.representanteId);
        if (!rep) return null;
        return {
            all: false,
            id: rep.id,
            codigo: rep.codigo,
            label: formatRepresentanteLabel(rep),
        };
    }

    if (access.canSelectRepresentante) {
        if (isTodosRepresentante(representanteText)) {
            return {
                all: true,
                id: null,
                codigo: null,
                label: REP_TODOS_LABEL,
            };
        }

        if (representanteText.trim()) {
            const rep = await findRepresentanteByText(representanteText);
            if (!rep) return null;
            return {
                all: false,
                id: rep.id,
                codigo: rep.codigo,
                label: formatRepresentanteLabel(rep),
            };
        }
    }

    return null;
}

async function getFinanceiroContext(usuarioId) {
    const access = await resolveFinanceiroUser({ id: usuarioId });
    let representante = null;

    if (access.representanteId) {
        representante = await getRepresentanteById(access.representanteId);
    }

    return {
        representanteId: access.representanteId,
        representanteNome: formatRepresentanteLabel(representante),
        canSelectRepresentante: access.canSelectRepresentante,
        representanteLocked: access.representanteLocked,
    };
}

async function listClientesOptions(representanteText = "", jwtUser = {}, search = "", options = {}) {
    const access = await resolveFinanceiroUser(jwtUser);
    const repFiltro = await resolveRepresentanteFiltro(access, representanteText);

    if (!repFiltro) {
        return {
            items: [],
            total: 0,
            offset: 0,
            limit: 0,
            hasMore: false,
            nextOffset: 0,
        };
    }

    const pageLimit = Math.min(Math.max(Number(options.limit) || 20, 1), 50);
    const pageOffset = Math.max(Number(options.offset) || 0, 0);
    const conditions = ["TRIM(COALESCE(aa80cliente, 'N')) = 'S'"];
    const params = [];

    if (!repFiltro.all && repFiltro.id) {
        params.push(repFiltro.id);
        conditions.push(`aa80repres1id = $${params.length}`);
    }

    if (search.trim()) {
        params.push(`%${search.trim()}%`);
        conditions.push(
            `(TRIM(aa80na) ILIKE $${params.length} OR TRIM(aa80nome) ILIKE $${params.length})`
        );
    }

    const whereClause = conditions.join(" AND ");

    const { rows: countRows } = await getPool().query(
        `
        SELECT COUNT(*)::int AS total
        FROM aa80
        WHERE ${whereClause}
        `,
        params
    );
    const total = countRows[0]?.total || 0;

    const listParams = [...params, pageLimit, pageOffset];
    const { rows } = await getPool().query(
        `
        SELECT
            aa80id AS id,
            TRIM(aa80codigo) AS codigo,
            TRIM(aa80nome) AS nome,
            TRIM(aa80na) AS na,
            aa80repres1id AS repres1id
        FROM aa80
        WHERE ${whereClause}
        ORDER BY TRIM(aa80na), TRIM(aa80nome), aa80id
        LIMIT $${listParams.length - 1}
        OFFSET $${listParams.length}
        `,
        listParams
    );

    const items = rows.map((row) => {
        const na = String(row.na || "").trim();
        const nome = String(row.nome || "").trim();
        return {
            id: row.id,
            codigo: row.codigo,
            label: na || nome,
            nome,
            na,
            repres1id: row.repres1id,
        };
    });

    const loaded = pageOffset + items.length;

    return {
        items,
        total,
        offset: pageOffset,
        limit: pageLimit,
        hasMore: loaded < total,
        nextOffset: loaded,
    };
}

async function listFinanceiro(filters = {}, jwtUser = {}) {
    const {
        situacao = "abertas",
        tipoData = "vencimento",
        periodoInicio,
        periodoFim,
        representante = "",
        cliente = "",
        sort = "vencimento",
        order = "asc",
        limit = 300,
    } = filters;

    const access = await resolveFinanceiroUser(jwtUser);
    const repFiltro = await resolveRepresentanteFiltro(access, representante);

    if (!repFiltro) {
        return {
            items: [],
            total: { valor: 0, saldo: 0, pago: 0 },
            count: 0,
            error: "Representante não informado ou não encontrado.",
        };
    }

    const dateColumn = {
        vencimento: "d.df20dtvencimento",
        emissao: "d.df20dtemissao",
        pagamento: "d.df20dtpagamento",
    }[tipoData] || "d.df20dtvencimento";

    const conditions = ["COALESCE(d.df20ativo, 0) = 0"];
    const params = [];
    let paramIndex = 1;

    if (!repFiltro.all && repFiltro.codigo) {
        conditions.push(`TRIM(d.df20repres_cod) = $${paramIndex++}`);
        params.push(repFiltro.codigo);
    }

    if (cliente.trim()) {
        conditions.push(`TRIM(d.df20entidadedesc) ILIKE $${paramIndex++}`);
        params.push(`%${cliente.trim()}%`);
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
    };
}

module.exports = {
    getFinanceiroContext,
    listRepresentantesOptions,
    listClientesOptions,
    listFinanceiro,
    REP_TODOS_LABEL,
};
