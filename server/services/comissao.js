const getPool = require("../db");
const {
    findUsuarioById,
    getRepresentanteId,
    canAccessWebSystem,
} = require("./userAuth");
const { num, formatDate, formatDateBr } = require("../utils/format");

const REP_ACTIVE_CONDITIONS = [
    "TRIM(COALESCE(aa80representante, 'N')) = 'S'",
    "COALESCE(aa80inativo, false) = false",
];

const COMISSAO_PAGE_SIZE = 30;

const SORT_COLUMNS = {
    data: "r.df10dtpagamento",
    emissao: "r.df10dtemissao",
    vencimento: "r.df10dtvencimento",
    representante: "TRIM(r.representante_na)",
    cliente: "TRIM(r.aa80na)",
    duplicata: "TRIM(r.df10documento)",
    atraso: "r.atraso",
    valor: "r.df10liquido",
    ipi: "r.valor_ipi",
    percentual: "r.percentual",
    comissao: "r.comissao",
};

const REP_TODOS_LABEL = "Todos";

function isTodosRepresentante(text) {
    const value = String(text || "").trim().toLowerCase();
    return !value || value === "todos" || value === "__all__";
}

function buildComissaoQueryContext(repFiltro, periodo) {
    if (repFiltro.all) {
        return {
            baseParams: [periodo.inicio, periodo.fim],
            repFilterSql10: "",
            repFilterSql20: "",
            dateStart: "$1::date",
            dateEnd: "$2::date",
            limitParam: "$3",
            offsetParam: "$4",
        };
    }

    return {
        baseParams: [repFiltro.codigo, periodo.inicio, periodo.fim],
        repFilterSql10: "AND TRIM(df10.df10repres_cod) = TRIM($1)",
        repFilterSql20: "AND TRIM(df20.df20repres_cod) = TRIM($1)",
        dateStart: "$2::date",
        dateEnd: "$3::date",
        limitParam: "$4",
        offsetParam: "$5",
    };
}

function buildComissaoBaseCte(ctx) {
    return `
    comissao_base AS (
        SELECT
            sql."ID_TAB" AS id_tab,
            sql.pormes,
            sql.df10id,
            TRIM(sql.df10documento) AS df10documento,
            TRIM(sql.df10sequ) AS df10sequ,
            sql.df10dtemissao,
            sql.df10dtvencimento,
            sql.df10dtpagamento,
            sql.df10liquido,
            sql.df10dias,
            TRIM(sql.aa80na) AS aa80na,
            TRIM(sql.pd_codigo) AS pd_codigo,
            TRIM(sql.representanteNA) AS representante_na,
            CASE
                WHEN sql.df10dias IS NOT NULL THEN GREATEST(0, sql.df10dias)
                WHEN sql.df10dtvencimento IS NOT NULL AND sql.df10dtpagamento IS NOT NULL
                    THEN GREATEST(0, (sql.df10dtpagamento::date - sql.df10dtvencimento::date))
                ELSE 0
            END AS atraso,
            COALESCE(sql.valor_ipi, 0) AS valor_ipi,
            COALESCE(sql.df10repres_comisao, 0) AS percentual,
            CAST(
                ((sql.df10liquido - sql.valor_ipi) * sql.df10repres_comisao) / 100
                AS numeric(18, 2)
            ) AS comissao
        FROM (
            SELECT DISTINCT
                '10' AS "ID_TAB",
                CAST(EXTRACT(YEAR FROM df10.df10dtpagamento) AS character(4))
                    || LPAD(CAST(EXTRACT(MONTH FROM df10.df10dtpagamento) AS character(2)), 2, '0') AS pormes,
                df10.df10id,
                df10.df10documento,
                df10.df10sequ,
                df10.df10dtemissao,
                df10.df10dtvencimento,
                df10.df10dtpagamento,
                df10.df10liquido,
                df10.df10dias,
                df10.df10repres_comisao,
                aa80.aa80na,
                CAST(pd_fixo.pd_codigo AS character(12)) AS pd_codigo,
                CASE
                    WHEN (
                        SELECT aa80id
                        FROM aa80 rep
                        WHERE rep.aa80codigo = df10.df10repres_cod
                    ) > 0 THEN (
                        SELECT aa80na
                        FROM aa80 rep
                        WHERE rep.aa80codigo = df10.df10repres_cod
                    )
                END AS representanteNA,
                (
                    (
                        nf_fixa.imposto_vipi / (
                            CASE
                                WHEN (
                                    SELECT COUNT(inner_df10.df10id)
                                    FROM df10 inner_df10
                                    WHERE inner_df10.df10documentoid = nf_fixa.nf_id
                                ) = 0 THEN 1
                                ELSE (
                                    SELECT COUNT(inner_df10.df10id)
                                    FROM df10 inner_df10
                                    WHERE inner_df10.df10documentoid = nf_fixa.nf_id
                                )
                            END
                        )
                    )
                ) AS valor_ipi
            FROM df10
            LEFT JOIN nf_fixa ON nf_fixa.nf_id = df10.df10documentoid
            LEFT JOIN pd_fixo ON pd_fixo.pd_romaneio = nf_fixa.nota_romaneio
            INNER JOIN aa80 ON aa80.aa80id = df10.df10entidadeid
            WHERE df10.df10empresaid = 1
              AND df10.df10ativo = 0
              AND df10.df10rec_pag = '0'
              AND df10.df10repres_comisao_valor <> 0
              AND df10.df10saldo = 0
              AND df10.df10liquido > 0
              AND df10.df10dtpagamento >= ${ctx.dateStart}
              AND df10.df10dtpagamento <= ${ctx.dateEnd}
              ${ctx.repFilterSql10}

            UNION

            SELECT DISTINCT
                '20' AS "ID_TAB",
                CAST(EXTRACT(YEAR FROM df20.df20dtpagamento) AS character(4))
                    || LPAD(CAST(EXTRACT(MONTH FROM df20.df20dtpagamento) AS character(2)), 2, '0') AS pormes,
                df20.df20id,
                df20.df20documento || '*' AS df10documento,
                df20.df20sequ,
                df20.df20dtemissao,
                df20.df20dtvencimento AS df10dtvencimento,
                df20.df20dtpagamento,
                df20.df20liquido AS df10liquido,
                df20.df20dias AS df10dias,
                df20.df20repres_comisao,
                aa80.aa80na,
                CAST(pd_fixo.pd_codigo AS character(12)) AS pd_codigo,
                CASE
                    WHEN (
                        SELECT aa80id
                        FROM aa80 rep
                        WHERE rep.aa80codigo = df20.df20repres_cod
                    ) > 0 THEN (
                        SELECT aa80na
                        FROM aa80 rep
                        WHERE rep.aa80codigo = df20.df20repres_cod
                    )
                END AS representanteNA,
                CAST(0 AS numeric(18, 2)) AS valor_ipi
            FROM df20
            LEFT JOIN nf_fixa ON nf_fixa.nf_id = df20.df20documentoid
            LEFT JOIN pd_fixo ON pd_fixo.pd_romaneio = nf_fixa.nota_romaneio
            INNER JOIN aa80 ON aa80.aa80id = df20.df20entidadeid
            WHERE df20.df20empresaid = 1
              AND df20.df20ativo = 0
              AND df20.df20rec_pag = '0'
              AND df20.df20repres_comisao_valor <> 0
              AND TRIM(df20.df20repres_cod) <> ''
              AND df20.df20saldo = 0
              AND df20.df20dtpagamento >= ${ctx.dateStart}
              AND df20.df20dtpagamento <= ${ctx.dateEnd}
              ${ctx.repFilterSql20}
        ) sql
    )
`;
}

function formatRepresentanteLabel(row) {
    const na = String(row?.na || "").trim();
    const nome = String(row?.nome || "").trim();
    return na || nome;
}

function formatDuplicata(documento, sequ) {
    const doc = String(documento || "").trim();
    const seq = String(sequ || "").trim();
    if (!doc) return "—";
    return seq ? `${doc} / ${seq}` : doc;
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
        sort = "data",
        order = "desc",
        exportAll = false,
        debug = false,
    } = filters;

    const access = await resolveComissaoUser(jwtUser);
    const repFiltro = await resolveRepresentanteFiltro(access, representante);
    const periodo = resolvePeriodoFiltro(periodoInicio, periodoFim);
    const maxLimit = exportAll ? 10000 : 100;
    const pageLimit = Math.min(Math.max(Number(limit) || COMISSAO_PAGE_SIZE, 1), maxLimit);
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
                      fonte: "df10_df20_union",
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
                      fonte: "df10_df20_union",
                      motivo: periodo.error,
                      representante: repFiltro,
                      filtros: { representante, periodoInicio, periodoFim },
                  }
                : undefined,
        };
    }

    const queryCtx = buildComissaoQueryContext(repFiltro, periodo);
    const baseCte = buildComissaoBaseCte(queryCtx);

    const summarySql = `
        WITH ${baseCte}
        SELECT
            COUNT(*)::int AS total_records,
            COALESCE(SUM(r.comissao), 0) AS total_comissao,
            COALESCE(SUM(r.df10liquido), 0) AS total_venda
        FROM comissao_base r
    `;

    const { rows: summaryRows } = await getPool().query(summarySql, queryCtx.baseParams);
    const totalRecords = summaryRows[0]?.total_records || 0;
    const totalComissao = num(summaryRows[0]?.total_comissao);
    const totalVenda = num(summaryRows[0]?.total_venda);
    const totalPages = totalRecords ? Math.ceil(totalRecords / pageLimit) : 0;
    const currentPage = totalPages ? Math.min(requestedPage, totalPages) : 1;
    const pageOffset = (currentPage - 1) * pageLimit;
    const sortColumn = SORT_COLUMNS[sort] || SORT_COLUMNS.data;
    const sortOrder = String(order).toLowerCase() === "asc" ? "ASC" : "DESC";

    const listSql = `
        WITH ${baseCte}
        SELECT
            r.id_tab,
            r.df10id,
            r.df10dtemissao,
            r.df10dtvencimento,
            r.df10dtpagamento,
            r.atraso,
            r.representante_na,
            r.aa80na AS cliente,
            r.df10documento,
            r.df10sequ,
            r.df10liquido AS valor_venda,
            r.valor_ipi,
            r.percentual,
            r.comissao,
            r.pd_codigo AS pedido
        FROM comissao_base r
        ORDER BY ${sortColumn} ${sortOrder} NULLS LAST,
            r.representante_na,
            TRIM(r.aa80na),
            TRIM(r.df10documento),
            TRIM(r.df10sequ)
        LIMIT ${queryCtx.limitParam} OFFSET ${queryCtx.offsetParam}
    `;

    const { rows } = await getPool().query(listSql, [...queryCtx.baseParams, pageLimit, pageOffset]);

    const items = rows.map((row, index) => {
        const duplicata = formatDuplicata(row.df10documento, row.df10sequ);

        return {
            id: `${row.id_tab}-${row.df10id}-${pageOffset + index}`,
            representanteId: repFiltro.id,
            representante: String(row.representante_na || repFiltro.label || "—").trim() || "—",
            data: formatDateBr(row.df10dtpagamento),
            emissao: formatDateBr(row.df10dtemissao),
            vencimento: formatDateBr(row.df10dtvencimento),
            cliente: String(row.cliente || "").trim() || "—",
            duplicata,
            pedido: String(row.pedido || "").trim() || duplicata,
            atraso: num(row.atraso),
            valorVenda: num(row.valor_venda),
            ipi: num(row.valor_ipi),
            percentual: num(row.percentual),
            comissao: num(row.comissao),
        };
    });

    const result = {
        items,
        total: totalComissao,
        totalVenda,
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
            fonte: "df10_df20_union",
            agrupamento: "lancamento_por_pagamento",
            representante: repFiltro,
            filtros: {
                representanteTexto: representante,
                periodoInicio: periodo.inicio,
                periodoFim: periodo.fim,
                page: currentPage,
                limit: pageLimit,
                sort,
                order: sortOrder.toLowerCase(),
            },
            sqlResumo: {
                todosRepresentantes: Boolean(repFiltro.all),
                codigoRepresentante: repFiltro.codigo,
                registrosRetornados: items.length,
                registrosNoPeriodo: totalRecords,
                totalVendaPeriodo: totalVenda,
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
    REP_TODOS_LABEL,
};
