function num(value) {
    return Number(value || 0);
}

function formatMoney(value) {
    return num(value).toLocaleString("pt-BR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
    });
}

function formatDate(value) {
    if (!value) return null;
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) return null;
    return date.toISOString().slice(0, 10);
}

function formatDateBr(value) {
    const iso = formatDate(value);
    if (!iso) return "—";
    const [y, m, d] = iso.split("-");
    return `${d}/${m}/${y}`;
}

function parsePeriodoComissao(periodo) {
    const raw = String(periodo || "").trim();
    if (raw.length < 6) return null;
    const month = Number(raw.slice(0, 2));
    const year = Number(raw.slice(2));
    if (!month || !year) return null;
    return { month, year, label: `${String(month).padStart(2, "0")}/${year}` };
}

function periodoComissaoToDateRange(inicio, fim) {
    const start = inicio ? new Date(`${inicio}T00:00:00`) : null;
    const end = fim ? new Date(`${fim}T23:59:59`) : null;
    return { start, end };
}

function comissaoPeriodoInRange(periodo, inicio, fim) {
    const parsed = parsePeriodoComissao(periodo);
    if (!parsed) return false;
    const periodDate = new Date(parsed.year, parsed.month - 1, 1);
    const { start, end } = periodoComissaoToDateRange(inicio, fim);
    if (start && periodDate < new Date(start.getFullYear(), start.getMonth(), 1)) return false;
    if (end && periodDate > new Date(end.getFullYear(), end.getMonth(), 1)) return false;
    return true;
}

module.exports = {
    num,
    formatMoney,
    formatDate,
    formatDateBr,
    parsePeriodoComissao,
    comissaoPeriodoInRange,
};
