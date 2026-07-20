const getPool = require("../db");
const {
    findUsuarioById,
    getRepresentanteId,
    canAccessWebSystem,
} = require("./userAuth");
const { num, formatDate } = require("../utils/format");

const REP_ACTIVE_CONDITIONS = [
    "TRIM(COALESCE(aa80representante, 'N')) = 'S'",
    "COALESCE(aa80inativo, false) = false",
];

const COMISSAO_PAGE_SIZE = 30;

function formatRepresentanteLabel(row) {
    const na = String(row?.na || "").trim();
    const nome = String(row?.nome || "").trim();
    return na || nome;
}

function formatPeriodoMesAno(value) {
    const iso = formatDate(value);
    if (!iso) return "—";
    const [year, month] = iso.split("-");
    return `${month}/${year}`;
}

function parseIsoDate(value) {
    const str = String(value || "").trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(str)) return null;

    const year = Number(str.slice(0, 4));
    const month = Number(str.slice(5, 7));
    const day = Number(str.slice(8, 10));
    const maxYear = new Date().getFullYear() + 1;

    if (year < 1990 || year > maxYear) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    const date = new Date(`${str}T12:00:00`);
    if (Number.isNaN(date.getTime())) return null;
    if (formatDate(date) !== str) return null;

    return str;
}

function resolvePeriodoFiltro(periodoInicio, periodoFim) {
    const inicio = parseIsoDate(periodoInicio);
    const fim = parseIsoDate(periodoFim);

    if (!inicio || !fim) {
        return { error: "Informe um período válido (data inicial e final)." };
    }

    if (inicio > fim) {
        return { error: "A data inicial não pode ser maior que a data final." };
    }

    return { inicio, fim };
}

async function getRepresentanteById(representanteId) {
    if (!representanteId) return null;

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

async function resolveComissaoUser(jwtUser = {}) {
    const user = await findUsuarioById(jwtUser.id);
    if (!user || !canAccessWebSystem(user)) {
        const err = new Error("WEB_ACCESS_DENIED");
        err.status = 403;
        throw err;
    }

    const representanteId = getRepresentanteId(user);
    const canSelectRepresentante = !representanteId && user.usuario_acessa_website === true;

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
            id: rep.id,
            codigo: rep.codigo,
            label: formatRepresentanteLabel(rep),
        };
    }

    if (access.canSelectRepresentante && representanteText.trim()) {
        const rep = await findRepresentanteByText(representanteText);
        if (!rep) return null;
        return {
            id: rep.id,
            codigo: rep.codigo,
            label: formatRepresentanteLabel(rep),
        };
    }

    return null;
}

async function getComissaoContext(usuarioId) {
    const access = await resolveComissaoUser({ id: usuarioId });
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

async function listRepresentantesOptions(search = "", options = {}) {
    const pageLimit = Math.min(Math.max(Number(options.limit) || 20, 1), 50);
    const pageOffset = Math.max(Number(options.offset) || 0, 0);
    const params = [];
    const conditions = [...REP_ACTIVE_CONDITIONS];

    if (search.trim()) {
        params.push(`%${search.trim()}%`);
        conditions.push(
            `(TRIM(aa80na) ILIKE $${params.length} OR TRIM(aa80nome) ILIKE $${params.length})`
        );
    }

    const whereClause = conditions.join(" AND ");

    const { rows: countRows } = await getPool().query(
        `SELECT COUNT(*)::int AS total FROM aa80 WHERE ${whereClause}`,
        params
    );
    const total = countRows[0]?.total || 0;

    const listParams = [...params, pageLimit, pageOffset];
    const { rows } = await getPool().query(
        `
        SELECT
            TRIM(aa80codigo) AS codigo,
            aa80id AS id,
            TRIM(aa80na) AS na,
            TRIM(aa80nome) AS nome
        FROM aa80
        WHERE ${whereClause}
        ORDER BY TRIM(aa80na)
        LIMIT $${listParams.length - 1}
        OFFSET $${listParams.length}
        `,
        listParams
    );

    const items = rows.map((row) => ({
        ...row,
        label: formatRepresentanteLabel(row),
    }));

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

async function listComissao(filters = {}, jwtUser = {}) {
    const {
        representante = "",
        periodoInicio,
        periodoFim,
        page = 1,
        limit = COMISSAO_PAGE_SIZE,
        debug = false,
    } = filters;

    const access = await resolveComissaoUser(jwtUser);
    const repFiltro = await resolveRepresentanteFiltro(access, representante);
    const periodo = resolvePeriodoFiltro(periodoInicio, periodoFim);
    const pageLimit = Math.min(Math.max(Number(limit) || COMISSAO_PAGE_SIZE, 1), 100);
    const requestedPage = Math.max(Number(page) || 1, 1);

    if (!repFiltro) {
        return {
            items: [],
            total: 0,
            count: 0,
            totalRecords: 0,
            page: 1,
            limit: pageLimit,
            totalPages: 0,
            error: "Representante não informado ou não encontrado.",
            meta: debug
                ? {
                      fonte: "relatorio229_comissoes",
                      motivo: "Representante não informado ou não encontrado.",
                      filtros: { representante, periodoInicio, periodoFim },
                  }
                : undefined,
        };
    }

    if (periodo.error) {
        return {
            items: [],
            total: 0,
            count: 0,
            totalRecords: 0,
            page: 1,
            limit: pageLimit,
            totalPages: 0,
            error: periodo.error,
            meta: debug
                ? {
                      fonte: "relatorio229_comissoes",
                      motivo: periodo.error,
                      representante: repFiltro,
                      filtros: { representante, periodoInicio, periodoFim },
                  }
                : undefined,
        };
    }

    const params = [repFiltro.codigo, periodo.inicio, periodo.fim];

    const baseCte = `
        WITH meses AS (
            SELECT
                DATE_TRUNC('month', r.df10dtemissao) AS mes_ref,
                TO_CHAR(r.df10dtemissao, 'MM/YYYY') AS periodo,
                SUM(COALESCE(r."COMISSAO", 0)) AS comissao,
                COUNT(*)::int AS lancamentos
            FROM relatorio229_comissoes r
            WHERE TRIM(r.df10repres_cod) = $1
              AND r.df10dtemissao >= $2::date
              AND r.df10dtemissao <= $3::date
            GROUP BY DATE_TRUNC('month', r.df10dtemissao), TO_CHAR(r.df10dtemissao, 'MM/YYYY')
        )
    `;

    const summarySql = `
        ${baseCte}
        SELECT
            COUNT(*)::int AS total_records,
            COALESCE(SUM(comissao), 0) AS total_comissao,
            COALESCE(SUM(lancamentos), 0)::int AS total_lancamentos
        FROM meses
    `;

    const { rows: summaryRows } = await getPool().query(summarySql, params);
    const totalRecords = summaryRows[0]?.total_records || 0;
    const totalComissao = num(summaryRows[0]?.total_comissao);
    const totalLancamentos = Number(summaryRows[0]?.total_lancamentos) || 0;
    const totalPages = totalRecords ? Math.ceil(totalRecords / pageLimit) : 0;
    const currentPage = totalPages ? Math.min(requestedPage, totalPages) : 1;
    const pageOffset = (currentPage - 1) * pageLimit;

    const listSql = `
        ${baseCte}
        SELECT mes_ref, periodo, comissao, lancamentos
        FROM meses
        ORDER BY mes_ref DESC
        LIMIT $4 OFFSET $5
    `;

    const { rows } = await getPool().query(listSql, [...params, pageLimit, pageOffset]);

    const items = rows.map((row) => ({
        id: `${repFiltro.id}-${formatDate(row.mes_ref) || row.periodo}`,
        representanteId: repFiltro.id,
        representante: repFiltro.label || "—",
        periodo: row.periodo || formatPeriodoMesAno(row.mes_ref),
        comissao: num(row.comissao),
        lancamentos: Number(row.lancamentos) || 0,
    }));

    const result = {
        items,
        total: totalComissao,
        count: items.length,
        totalRecords,
        page: currentPage,
        limit: pageLimit,
        totalPages,
        rangeStart: totalRecords ? pageOffset + 1 : 0,
        rangeEnd: totalRecords ? pageOffset + items.length : 0,
    };

    if (debug) {
        result.meta = {
            fonte: "relatorio229_comissoes",
            agrupamento: "mensal",
            representante: repFiltro,
            filtros: {
                representanteTexto: representante,
                periodoInicio: periodo.inicio,
                periodoFim: periodo.fim,
                page: currentPage,
                limit: pageLimit,
            },
            sqlResumo: {
                codigoRepresentante: repFiltro.codigo,
                mesesRetornados: items.length,
                mesesNoPeriodo: totalRecords,
                lancamentosNoPeriodo: totalLancamentos,
            },
        };
    }

    return result;
}

module.exports = {
    getComissaoContext,
    listRepresentantesOptions,
    listComissao,
    COMISSAO_PAGE_SIZE,
};
