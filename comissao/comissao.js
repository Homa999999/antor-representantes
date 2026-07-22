let comissaoContext = null;
let repPicker = null;
let comissaoPage = 1;

const REP_PAGE_SIZE = 20;
const COMISSAO_PAGE_SIZE = 30;
const REP_TODOS_LABEL = "Todos";
const SORT_KEYS = ["data", "emissao", "vencimento", "cliente", "duplicata", "atraso", "valor", "ipi", "percentual", "comissao"];
const COMISSAO_COLUMNS = [
    { id: "data", label: "Data de pagamento", defaultVisible: true },
    { id: "emissao", label: "Emissão", defaultVisible: false },
    { id: "vencimento", label: "Vence em", defaultVisible: false },
    { id: "cliente", label: "Cliente", defaultVisible: true },
    { id: "duplicata", label: "Duplicata", defaultVisible: true },
    { id: "atraso", label: "Atraso", defaultVisible: false },
    { id: "valor", label: "Valor total", defaultVisible: true },
    { id: "ipi", label: "IPI", defaultVisible: false },
    { id: "percentual", label: "%", defaultVisible: false },
    { id: "comissao", label: "Comissão", defaultVisible: true },
];
const COMISSAO_LABEL_COLS = ["data", "emissao", "vencimento", "cliente", "duplicata", "atraso"];
const COL_STORAGE_KEY = "comissao-visible-cols";
const DEFAULT_VISIBLE_COLS = COMISSAO_COLUMNS.filter((col) => col.defaultVisible).map((col) => col.id);

const COMISSAO_PRINT_TABLE_HEAD = `
    <thead>
        <tr>
            <th>Data pag.</th>
            <th>Emissão</th>
            <th>Vence em</th>
            <th>Cliente</th>
            <th>Duplicata</th>
            <th class="col-atraso-h">Atr.</th>
            <th class="col-valor-h">Vlr total</th>
            <th class="col-valor-h">IPI</th>
            <th class="col-pct-h">%</th>
            <th class="col-valor-h">Comissão</th>
        </tr>
    </thead>
`;
let currentSort = { field: "data", order: "desc" };
let comissaoLoading = false;
let lastComissaoData = null;
let comissaoPrintSnapshot = null;
let visibleCols = new Set(DEFAULT_VISIBLE_COLS);

function sanitizePrintFileNamePart(value, fallback = "representante") {
    const cleaned = String(value || "")
        .trim()
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .replace(/[^a-zA-Z0-9_-]+/g, "_")
        .replace(/_+/g, "_")
        .replace(/^_|_$/g, "");

    return cleaned || fallback;
}

function buildComissaoPrintFileName() {
    const now = new Date();
    const day = String(now.getDate()).padStart(2, "0");
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const year = String(now.getFullYear());
    const repInput = document.getElementById("representante");
    const representante = sanitizePrintFileNamePart(
        repInput?.value.trim() || comissaoContext?.representanteNome,
        "representante"
    );

    return `relatorioSigma_${day}_${month}_${year}_${representante}`;
}

function waitForPrintFrameReady(iframe) {
    return new Promise((resolve) => {
        const doc = iframe.contentDocument;
        if (!doc) {
            resolve();
            return;
        }

        const finish = () => {
            requestAnimationFrame(() => requestAnimationFrame(resolve));
        };

        const waitForImages = () => {
            const images = Array.from(doc.images || []);
            if (!images.length) {
                finish();
                return;
            }

            Promise.all(
                images.map(
                    (img) =>
                        new Promise((res) => {
                            if (img.complete) res();
                            else {
                                img.onload = res;
                                img.onerror = res;
                            }
                        })
                )
            ).then(finish);
        };

        if (doc.readyState === "complete") {
            waitForImages();
            return;
        }

        iframe.addEventListener("load", waitForImages, { once: true });
    });
}

function createComissaoExportIframe(fileName) {
    return new Promise((resolve, reject) => {
        const printHeader = document.querySelector(".comissao-print-header");
        const printSections = document.getElementById("comissao-print-sections");
        if (!printHeader || !printSections) {
            reject(new Error("Conteúdo de impressão indisponível."));
            return;
        }

        const iframe = document.createElement("iframe");
        iframe.setAttribute("aria-hidden", "true");
        iframe.style.cssText = "position:fixed;right:0;bottom:0;width:0;height:0;border:0;";
        document.body.appendChild(iframe);

        const doc = iframe.contentDocument;
        const baseHref = new URL(".", window.location.href).href;
        const safeTitle = String(fileName).replace(/[<>&"]/g, "");

        doc.open();
        doc.write(`<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<base href="${baseHref}">
<title>${safeTitle}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="comissao.css">
<style>html, body { font-family: "Plus Jakarta Sans", sans-serif; }</style>
</head>
<body>
${printHeader.outerHTML}
${printSections.outerHTML}
</body>
</html>`);
        doc.close();

        iframe.addEventListener(
            "load",
            async () => {
                try {
                    await waitForPrintFrameReady(iframe);
                    await new Promise((res) => setTimeout(res, 300));
                    resolve(iframe);
                } catch (error) {
                    iframe.remove();
                    reject(error);
                }
            },
            { once: true }
        );
    });
}

async function printComissaoInIframe(fileName) {
    const iframe = await createComissaoExportIframe(fileName);

    return new Promise((resolve, reject) => {
        let cleaned = false;
        const cleanup = () => {
            if (cleaned) return;
            cleaned = true;
            iframe.remove();
            resolve();
        };

        try {
            const printWindow = iframe.contentWindow;
            if (!printWindow) {
                throw new Error("Não foi possível abrir a impressão.");
            }

            const fallbackTimer = setTimeout(cleanup, 300000);
            printWindow.addEventListener(
                "afterprint",
                () => {
                    clearTimeout(fallbackTimer);
                    cleanup();
                },
                { once: true }
            );
            printWindow.focus();
            printWindow.print();
        } catch (error) {
            cleanup();
            reject(error);
        }
    });
}

const COMISSAO_XLSX_HEADERS = [
    "Representante",
    "Data pag.",
    "Emissão",
    "Vence em",
    "Cliente",
    "Duplicata",
    "Atr.",
    "Vlr total",
    "IPI",
    "%",
    "Comissão",
];

function buildComissaoXlsxRows(data) {
    const rows = [COMISSAO_XLSX_HEADERS];
    const groups = groupItemsByRepresentante(data.items);

    groups.forEach((group, groupIndex) => {
        groupItemsByCliente(group.items).forEach((clientGroup) => {
            clientGroup.items.forEach((item) => {
                rows.push([
                    group.nome,
                    item.data || "",
                    item.emissao || "",
                    item.vencimento || "",
                    item.cliente || "",
                    item.duplicata || "",
                    Number(item.atraso) > 0 ? Number(item.atraso) : "",
                    Number(item.valorVenda) || 0,
                    Number(item.ipi) || 0,
                    Number(item.percentual) || 0,
                    Number(item.comissao) || 0,
                ]);
            });
        });

        if (groupIndex < groups.length - 1) {
            rows.push([]);
        }
    });

    return rows;
}

function downloadComissaoXlsx(fileName, data) {
    if (typeof XLSX === "undefined") {
        throw new Error("Biblioteca de Excel indisponível. Verifique sua conexão.");
    }

    const rows = buildComissaoXlsxRows(data);
    const worksheet = XLSX.utils.aoa_to_sheet(rows);
    worksheet["!cols"] = [
        { wch: 18 },
        { wch: 12 },
        { wch: 12 },
        { wch: 12 },
        { wch: 28 },
        { wch: 16 },
        { wch: 6 },
        { wch: 14 },
        { wch: 12 },
        { wch: 8 },
        { wch: 14 },
    ];

    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, "Comissão");
    XLSX.writeFile(workbook, `${fileName}.xlsx`);
}

function beginComissaoExport(data = lastComissaoData, scope = "page", range = null) {
    if (!data?.items?.length) {
        AntorToast.warning("Nenhum registro para exportar.");
        return null;
    }

    const periodo = getPeriodoFiltro();
    if (periodo.error) {
        AntorToast.warning(periodo.error);
        return null;
    }

    comissaoPrintSnapshot = {
        printRegistros: document.getElementById("print-registros").textContent,
        totalVenda: document.getElementById("comissao-total-venda").textContent,
        totalComissao: document.getElementById("comissao-total").textContent,
        count: document.getElementById("comissao-count").textContent,
    };

    updatePrintHeader(data, periodo, scope, range);
    renderPrintSections(data);

    return buildComissaoPrintFileName();
}

async function fetchComissaoForPrint(scope, range = null) {
    if (scope === "page") {
        return lastComissaoData;
    }

    const totalRecords = Number(lastComissaoData?.totalRecords) || 0;
    const totalPages = Number(lastComissaoData?.totalPages) || 1;
    if (!totalRecords) {
        return lastComissaoData;
    }

    if (scope === "all") {
        const allItems = [];
        let page = 1;
        const limit = 10000;
        let lastResponse = null;

        while (allItems.length < totalRecords) {
            const { params, periodo } = buildComissaoParams(page, limit);
            if (periodo.error) {
                throw new Error(periodo.error);
            }

            params.set("export", "1");
            const data = await AntorAPI.apiFetch(`/comissao?${params.toString()}`);
            if (data.error) {
                throw new Error(data.error);
            }

            lastResponse = data;
            allItems.push(...(data.items || []));

            if (!data.items?.length || page >= (data.totalPages || 1)) {
                break;
            }

            page += 1;
        }

        return {
            ...lastResponse,
            items: allItems,
            count: allItems.length,
            totalRecords,
            page: 1,
            totalPages: 1,
            rangeStart: 1,
            rangeEnd: allItems.length,
        };
    }

    const startPage = range?.from || 1;
    const endPage = range?.to || totalPages;
    const allItems = [];
    let lastResponse = null;
    let rangeStart = 0;
    let rangeEnd = 0;

    for (let page = startPage; page <= endPage; page += 1) {
        const { params, periodo } = buildComissaoParams(page, COMISSAO_PAGE_SIZE);
        if (periodo.error) {
            throw new Error(periodo.error);
        }

        const data = await AntorAPI.apiFetch(`/comissao?${params.toString()}`);
        if (data.error) {
            throw new Error(data.error);
        }

        lastResponse = data;
        allItems.push(...(data.items || []));

        if (page === startPage) {
            rangeStart = Number(data.rangeStart) || 1;
        }
        if (page === endPage) {
            rangeEnd = Number(data.rangeEnd) || allItems.length;
        }
    }

    return {
        ...lastResponse,
        items: allItems,
        count: allItems.length,
        totalRecords,
        page: startPage,
        totalPages: endPage - startPage + 1,
        rangeStart: rangeStart || 1,
        rangeEnd: rangeEnd || allItems.length,
        printRange: { from: startPage, to: endPage },
    };
}

function validatePrintRange() {
    const totalPages = Number(lastComissaoData?.totalPages) || 1;
    const fromInput = document.getElementById("print-scope-from");
    const toInput = document.getElementById("print-scope-to");
    const fromRaw = Number.parseInt(String(fromInput?.value || ""), 10);
    const toRaw = Number.parseInt(String(toInput?.value || ""), 10);

    if (!Number.isFinite(fromRaw)) {
        AntorToast.warning("Informe a página inicial.");
        fromInput?.focus();
        return null;
    }

    if (!Number.isFinite(toRaw)) {
        AntorToast.warning("Informe a página final.");
        toInput?.focus();
        return null;
    }

    if (fromRaw < 1 || fromRaw > totalPages) {
        AntorToast.warning(`A página inicial deve estar entre 1 e ${totalPages}.`);
        fromInput?.focus();
        return null;
    }

    if (toRaw < 1 || toRaw > totalPages) {
        AntorToast.warning(`A página final deve estar entre 1 e ${totalPages}.`);
        toInput?.focus();
        return null;
    }

    if (fromRaw > toRaw) {
        AntorToast.error("A página inicial não pode ser maior que a final.");
        fromInput?.focus();
        return null;
    }

    if (fromInput) fromInput.value = String(fromRaw);
    if (toInput) toInput.value = String(toRaw);

    return { from: fromRaw, to: toRaw };
}

function syncPrintScopeRangeFields() {
    const fromInput = document.getElementById("print-scope-from");
    const toInput = document.getElementById("print-scope-to");
    const totalPages = Number(lastComissaoData?.totalPages) || 1;
    const rangeEnabled = totalPages > 1;

    [fromInput, toInput].forEach((input) => {
        if (!input) return;
        input.disabled = !rangeEnabled;
    });
}

function getPrintScopeFromUI() {
    const scope = document.querySelector('input[name="print-scope"]:checked')?.value || "page";
    if (scope !== "range") {
        return { scope };
    }

    const range = validatePrintRange();
    if (!range) return null;

    return { scope, range };
}

function updatePrintScopeModalDescriptions() {
    const data = lastComissaoData;
    const pageDesc = document.getElementById("print-scope-page-desc");
    const allDesc = document.getElementById("print-scope-all-desc");
    const rangeDesc = document.getElementById("print-scope-range-desc");
    const allOption = document.querySelector('input[name="print-scope"][value="all"]');
    const rangeOption = document.querySelector('input[name="print-scope"][value="range"]');
    const pageOption = document.querySelector('input[name="print-scope"][value="page"]');
    const fromInput = document.getElementById("print-scope-from");
    const toInput = document.getElementById("print-scope-to");

    if (!data || !pageDesc || !allDesc) return;

    const totalRecords = Number(data.totalRecords) || data.items.length;
    const page = Number(data.page) || 1;
    const totalPages = Number(data.totalPages) || 1;
    const itemCount = data.items.length;
    const multiPage = totalPages > 1;

    pageDesc.textContent = multiPage
        ? `Página ${page} de ${totalPages} · ${itemCount} registro(s)`
        : `${itemCount} registro(s) exibidos`;

    allDesc.textContent = `${totalRecords} registro(s) no período filtrado`;

    if (rangeDesc) {
        rangeDesc.textContent = multiPage
            ? `Intervalo entre a página 1 e ${totalPages}`
            : "Disponível apenas com mais de uma página";
    }

    if (fromInput) {
        fromInput.min = "1";
        fromInput.max = String(totalPages);
        fromInput.value = String(page);
    }

    if (toInput) {
        toInput.min = "1";
        toInput.max = String(totalPages);
        toInput.value = String(page);
    }

    if (allOption) {
        allOption.disabled = !multiPage;
    }

    if (rangeOption) {
        rangeOption.disabled = !multiPage;
    }

    if (pageOption && !multiPage) {
        pageOption.checked = true;
    }

    syncPrintScopeRangeFields();
}

let exportScopeMode = "print";

const EXPORT_SCOPE_UI = {
    print: {
        title: "Imprimir relatório",
        message: "Escolha o que deseja imprimir. A impressão só começa após confirmar.",
        icon: "fa-print",
        iconClass: "",
        confirm: "Imprimir",
        confirmIcon: "fa-print",
    },
    excel: {
        title: "Exportar Excel",
        message: "Escolha o que deseja exportar. O download só começa após confirmar.",
        icon: "fa-file-excel",
        iconClass: "is-excel",
        confirm: "Baixar Excel",
        confirmIcon: "fa-file-excel",
    },
};

function updateExportScopeModalUI(mode) {
    const config = EXPORT_SCOPE_UI[mode] || EXPORT_SCOPE_UI.print;
    exportScopeMode = mode;

    const modalCard = document.getElementById("comissao-print-modal-card");
    const title = document.getElementById("comissao-print-modal-title");
    const message = document.getElementById("comissao-print-modal-message");
    const iconWrap = document.querySelector(".comissao-print-modal-icon");
    const icon = iconWrap?.querySelector("i");
    const confirmBtn = document.getElementById("comissao-print-modal-confirm");
    const isExcel = mode === "excel";

    if (title) title.textContent = config.title;
    if (message) message.textContent = config.message;
    if (icon) icon.className = `fa-solid ${config.icon}`;
    modalCard?.classList.toggle("is-excel", isExcel);
    iconWrap?.classList.toggle("is-excel", isExcel);
    if (confirmBtn) {
        confirmBtn.innerHTML = `<i class="fa-solid ${config.confirmIcon}" aria-hidden="true"></i> ${config.confirm}`;
    }
}

function openExportScopeModal(mode = "print") {
    if (comissaoLoading) return;

    if (!lastComissaoData?.items?.length) {
        AntorToast.warning("Nenhum registro para exportar.");
        return;
    }

    const periodo = getPeriodoFiltro();
    if (periodo.error) {
        AntorToast.warning(periodo.error);
        return;
    }

    updatePrintScopeModalDescriptions();
    updateExportScopeModalUI(mode);

    const modal = document.getElementById("comissao-print-modal");
    if (!modal) return;

    modal.hidden = false;
    modal.setAttribute("aria-hidden", "false");
    document.body.classList.add("comissao-print-modal-open");
    document.getElementById("comissao-print-modal-confirm")?.focus();
}

function closePrintScopeModal() {
    const modal = document.getElementById("comissao-print-modal");
    if (!modal || modal.hidden) return;

    modal.hidden = true;
    modal.setAttribute("aria-hidden", "true");
    document.body.classList.remove("comissao-print-modal-open");
}

async function executePrintComissao(selection = { scope: "page" }) {
    if (comissaoLoading) {
        AntorToast.info("Aguarde o carregamento dos resultados.");
        return;
    }

    const scope = selection.scope || "page";
    const range = selection.range || null;

    if (scope === "range" && !range) {
        AntorToast.error("Intervalo de páginas inválido.");
        return;
    }

    closePrintScopeModal();
    setComissaoLoading(true);

    try {
        const printData = await fetchComissaoForPrint(scope, range);
        const fileName = beginComissaoExport(printData, scope, range);
        if (!fileName) return;

        await printComissaoInIframe(fileName);
    } catch (error) {
        AntorToast.error(error.message || "Não foi possível imprimir o relatório.");
    } finally {
        restoreComissaoAfterPrint();
        setComissaoLoading(false);
    }
}

function repLabel(item) {
    return String(item?.label || item?.na || item?.nome || "").trim();
}

const PERIODO_MIN = "1990-01-01";

function isValidPeriodoDate(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ""))) return false;
    const year = Number(value.slice(0, 4));
    const maxYear = new Date().getFullYear() + 1;
    return year >= 1990 && year <= maxYear;
}

function clampPeriodoInput(input, fallback) {
    if (!input) return fallback;
    if (!isValidPeriodoDate(input.value)) {
        input.value = fallback;
    }
    return input.value;
}

function bindPeriodoInputs() {
    const inicio = document.getElementById("periodo-inicio");
    const fim = document.getElementById("periodo-fim");
    const max = AntorList.todayISO();

    if (!inicio || !fim) return;

    [inicio, fim].forEach((input) => {
        input.min = PERIODO_MIN;
        input.max = max;
    });

    AntorDatePicker.setConstraints(inicio, { min: PERIODO_MIN, max });
    AntorDatePicker.setConstraints(fim, { min: PERIODO_MIN, max });

    inicio.addEventListener("change", () => {
        const inicioVal = clampPeriodoInput(inicio, `${new Date().getFullYear()}-01-01`);
        AntorDatePicker.setValue(inicio, inicioVal);
        if (inicio.value > fim.value) {
            AntorDatePicker.setValue(fim, inicio.value);
        }
        fim.min = inicio.value;
        AntorDatePicker.setConstraints(fim, { min: inicio.value });
    });

    fim.addEventListener("change", () => {
        const fimVal = clampPeriodoInput(fim, max);
        AntorDatePicker.setValue(fim, fimVal);
        if (fim.value < inicio.value) {
            AntorDatePicker.setValue(inicio, fim.value);
        }
        inicio.max = fim.value;
        AntorDatePicker.setConstraints(inicio, { max: fim.value });
    });
}

function setDefaultDates() {
    const inicio = document.getElementById("periodo-inicio");
    const fim = document.getElementById("periodo-fim");
    const anoInicio = `${new Date().getFullYear()}-01-01`;
    const hoje = AntorList.todayISO();

    if (inicio) AntorDatePicker.setValue(inicio, clampPeriodoInput(inicio, anoInicio));
    if (fim) AntorDatePicker.setValue(fim, clampPeriodoInput(fim, hoje));
}

function getPeriodoFiltro() {
    const inicio = document.getElementById("periodo-inicio");
    const fim = document.getElementById("periodo-fim");
    const anoInicio = `${new Date().getFullYear()}-01-01`;
    const hoje = AntorList.todayISO();
    const periodoInicio = clampPeriodoInput(inicio, anoInicio);
    const periodoFim = clampPeriodoInput(fim, hoje);

    if (periodoInicio > periodoFim) {
        return { error: "A data inicial não pode ser maior que a data final." };
    }

    return { periodoInicio, periodoFim };
}

function applyComissaoSortHeader() {
    const table = document.querySelector(".comissao-table");
    if (!table) return;

    table.querySelectorAll("thead th.sortable").forEach((th) => {
        th.classList.remove("sorted-asc", "sorted-desc");
        if (th.dataset.sort === currentSort.field) {
            th.classList.add(currentSort.order === "desc" ? "sorted-desc" : "sorted-asc");
        }
    });
}

function setComissaoLoading(loading) {
    comissaoLoading = loading;

    const wrap = document.getElementById("comissao-table-wrap");
    const overlay = document.getElementById("comissao-loading");
    const table = document.querySelector(".comissao-table");
    const prevBtn = document.getElementById("comissao-prev");
    const nextBtn = document.getElementById("comissao-next");
    const pageInput = document.getElementById("comissao-page-input");
    const searchBtn = document.querySelector("#form-filtros .btn-pesquisar");
    const printBtn = document.getElementById("btn-imprimir");
    const downloadBtn = document.getElementById("btn-download");

    wrap?.classList.toggle("is-loading", loading);
    if (overlay) {
        overlay.hidden = !loading;
        overlay.setAttribute("aria-busy", loading ? "true" : "false");
    }

    table?.querySelectorAll("thead th.sortable").forEach((th) => {
        th.classList.toggle("is-disabled", loading);
        th.setAttribute("aria-disabled", loading ? "true" : "false");
    });

    if (searchBtn) searchBtn.disabled = loading;
    if (printBtn) printBtn.disabled = loading;
    if (downloadBtn) downloadBtn.disabled = loading;

    if (loading) {
        if (prevBtn) prevBtn.disabled = true;
        if (nextBtn) nextBtn.disabled = true;
        if (pageInput) pageInput.disabled = true;
        return;
    }

    if (lastComissaoData) {
        renderComissaoPagination(lastComissaoData);
    } else {
        if (prevBtn) prevBtn.disabled = true;
        if (nextBtn) nextBtn.disabled = true;
        if (pageInput) pageInput.disabled = false;
    }
}

function goToComissaoPage(requestedPage) {
    if (comissaoLoading) return;

    const totalPages = Number(lastComissaoData?.totalPages) || 1;
    const page = Math.min(Math.max(Number.parseInt(String(requestedPage), 10) || 1, 1), totalPages);
    const pageInput = document.getElementById("comissao-page-input");

    if (pageInput) {
        pageInput.value = String(page);
    }

    if (page !== comissaoPage) {
        loadComissao(page);
    }
}

function renderComissaoPagination(data) {
    const nav = document.getElementById("comissao-pagination");
    const info = document.getElementById("comissao-pagination-info");
    const pageInput = document.getElementById("comissao-page-input");
    const pageTotal = document.getElementById("comissao-page-total");
    const prevBtn = document.getElementById("comissao-prev");
    const nextBtn = document.getElementById("comissao-next");

    if (!nav || !info || !pageInput || !pageTotal || !prevBtn || !nextBtn) return;

    const totalRecords = Number(data.totalRecords) || 0;
    const totalPages = Number(data.totalPages) || 0;
    const page = Number(data.page) || 1;

    if (!totalRecords || totalPages <= 1) {
        nav.hidden = true;
        return;
    }

    nav.hidden = false;
    info.textContent = `Mostrando ${data.rangeStart}-${data.rangeEnd} de ${totalRecords} registros`;
    pageInput.value = String(page);
    pageInput.max = String(totalPages);
    pageInput.disabled = comissaoLoading;
    pageTotal.textContent = `de ${totalPages}`;
    prevBtn.disabled = comissaoLoading || page <= 1;
    nextBtn.disabled = comissaoLoading || page >= totalPages;
}

function renderComissao(data) {
    const tbody = document.getElementById("comissao-tbody");
    const table = document.querySelector(".comissao-table");
    const empty = document.getElementById("resultados-empty");
    if (!tbody || !table || !empty) return;

    tbody.innerHTML = "";

    if (!data.items.length) {
        table.classList.remove("has-rows");
        empty.classList.remove("hidden");
        renderComissaoPagination({ totalRecords: 0, totalPages: 0, page: 1 });

        if (comissaoContext?.canSelectRepresentante && !document.getElementById("representante")?.value.trim()) {
            empty.querySelector("p").textContent = "Selecione um representante ou Todos.";
            empty.querySelector("small").textContent = "Use a lista para filtrar por representante.";
        } else {
            empty.querySelector("p").textContent = "Nenhum registro encontrado.";
            empty.querySelector("small").textContent = "Ajuste os filtros e tente novamente.";
        }
    } else {
        table.classList.add("has-rows");
        empty.classList.add("hidden");

        data.items.forEach((item) => {
            const tr = document.createElement("tr");
            tr.innerHTML = buildComissaoRowCells(item);
            tbody.appendChild(tr);
        });

        applyColumnVisibility();
        renderComissaoPagination(data);
    }

    updateComissaoTableFooter(data);

    const totalRecords = Number(data.totalRecords) || data.count || 0;
    document.getElementById("comissao-registros").textContent = `${totalRecords} registros`;
    document.getElementById("comissao-count").textContent = `${totalRecords} registro(s).`;
    document.getElementById("comissao-total-venda").textContent = `R$ ${AntorList.formatMoney(data.totalVenda)}`;
    document.getElementById("comissao-total").textContent = `R$ ${AntorList.formatMoney(data.total)}`;

    lastComissaoData = data;
}

function buildComissaoParams(page, limit) {
    const repInput = document.getElementById("representante");
    if (comissaoContext?.canSelectRepresentante && repInput && !repInput.value.trim()) {
        repInput.value = REP_TODOS_LABEL;
    }

    const periodo = getPeriodoFiltro();
    const form = document.getElementById("form-filtros");
    const params = AntorList.formToQuery(form);
    params.set("periodo_inicio", periodo.periodoInicio);
    params.set("periodo_fim", periodo.periodoFim);
    params.set("page", String(page));
    params.set("limit", String(limit));
    params.set("sort", currentSort.field);
    params.set("order", currentSort.order);
    return { params, periodo };
}

function formatAtraso(value) {
    const days = Number(value) || 0;
    return days > 0 ? `${days}d` : "—";
}

function formatPercentual(value) {
    const percent = Number(value) || 0;
    if (!percent) return "—";
    return `${percent.toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}%`;
}

function loadVisibleCols() {
    try {
        const stored = localStorage.getItem(COL_STORAGE_KEY);
        if (stored) {
            const parsed = JSON.parse(stored);
            if (Array.isArray(parsed)) {
                const valid = parsed.filter((id) => COMISSAO_COLUMNS.some((col) => col.id === id));
                if (valid.length) {
                    visibleCols = new Set(valid);
                    return;
                }
            }
        }
    } catch (error) {
        console.warn("[Comissão] preferências de colunas inválidas:", error);
    }

    visibleCols = new Set(DEFAULT_VISIBLE_COLS);
}

function saveVisibleCols() {
    localStorage.setItem(COL_STORAGE_KEY, JSON.stringify([...visibleCols]));
}

function isColVisible(colId) {
    return visibleCols.has(colId);
}

function updateTfootLayout() {
    const row = document.querySelector("#comissao-tfoot .comissao-tfoot-row");
    if (!row) return;

    row.querySelectorAll("td[data-col]").forEach((td) => {
        td.colSpan = 1;
        td.hidden = false;
    });

    const visibleLabelCols = COMISSAO_LABEL_COLS.filter((colId) => isColVisible(colId));
    const firstLabelCol = visibleLabelCols[0];

    COMISSAO_LABEL_COLS.forEach((colId) => {
        const td = row.querySelector(`td[data-col="${colId}"]`);
        if (!td) return;

        if (!isColVisible(colId)) {
            td.classList.add("col-hidden");
            td.textContent = "";
            return;
        }

        td.classList.remove("col-hidden");

        if (colId === firstLabelCol) {
            td.colSpan = visibleLabelCols.length;
            td.textContent = "Total da página";
            td.classList.add("comissao-tfoot-label");
        } else {
            td.hidden = true;
            td.textContent = "";
            td.classList.remove("comissao-tfoot-label");
        }
    });

    ["valor", "ipi", "percentual", "comissao"].forEach((colId) => {
        const td = row.querySelector(`td[data-col="${colId}"]`);
        if (!td) return;
        td.classList.toggle("col-hidden", !isColVisible(colId));
    });
}

function applyColumnVisibility() {
    const table = document.querySelector(".comissao-table");
    if (!table) return;

    COMISSAO_COLUMNS.forEach((col) => {
        const visible = isColVisible(col.id);
        table.querySelectorAll(`[data-col="${col.id}"]`).forEach((el) => {
            if (el.closest("#comissao-tfoot")) return;
            el.classList.toggle("col-hidden", !visible);
        });
    });

    updateTfootLayout();
    updateColPickerUI();
}

function updateColPickerUI() {
    const badge = document.getElementById("col-picker-badge");
    const list = document.getElementById("col-picker-list");
    if (!list) return;

    const hiddenCount = COMISSAO_COLUMNS.length - visibleCols.size;

    if (badge) {
        badge.hidden = hiddenCount <= 0;
        badge.textContent = String(hiddenCount);
    }

    list.querySelectorAll(".col-picker-option").forEach((option) => {
        const colId = option.dataset.col;
        const input = option.querySelector('input[type="checkbox"]');
        const visible = isColVisible(colId);

        if (input) {
            input.checked = visible;
            input.disabled = visible && visibleCols.size <= 1;
        }

        option.classList.toggle("is-hidden-col", !visible);
    });
}

function setVisibleCols(nextVisibleCols, { persist = true } = {}) {
    const normalized = COMISSAO_COLUMNS.map((col) => col.id).filter((id) => nextVisibleCols.includes(id));
    if (!normalized.length) return;

    visibleCols = new Set(normalized);
    if (persist) saveVisibleCols();
    applyColumnVisibility();
}

const COL_PICKER_GAP = 8;
const COL_PICKER_VIEWPORT_PAD = 16;
const COL_PICKER_WIDTH = 260;
let colPickerPanelHome = null;

function mountColPickerPanel() {
    const panel = document.getElementById("col-picker-panel");
    if (!panel) return;

    if (!colPickerPanelHome) {
        colPickerPanelHome = panel.parentElement;
    }

    if (panel.parentElement !== document.body) {
        document.body.appendChild(panel);
    }
}

function unmountColPickerPanel() {
    const panel = document.getElementById("col-picker-panel");
    if (!panel || !colPickerPanelHome) return;

    if (panel.parentElement === document.body) {
        colPickerPanelHome.appendChild(panel);
    }
}

function isColPickerTarget(target) {
    const picker = document.getElementById("col-picker");
    const panel = document.getElementById("col-picker-panel");
    return Boolean(picker?.contains(target) || panel?.contains(target));
}

function resetColPickerPanelPosition() {
    const panel = document.getElementById("col-picker-panel");
    const picker = document.getElementById("col-picker");
    const list = document.getElementById("col-picker-list");
    if (!panel) return;

    panel.classList.remove("is-floating");
    panel.style.left = "";
    panel.style.top = "";
    panel.style.width = "";
    panel.style.visibility = "";
    if (list) list.style.maxHeight = "";
    picker?.classList.remove("opens-up");
    unmountColPickerPanel();
}

function positionColPickerPanel() {
    const picker = document.getElementById("col-picker");
    const panel = document.getElementById("col-picker-panel");
    const toggle = document.getElementById("col-picker-toggle");
    const list = document.getElementById("col-picker-list");
    if (!picker?.classList.contains("is-open") || !panel || !toggle) return;

    const isMobile = window.matchMedia("(max-width: 768px)").matches;
    const rect = toggle.getBoundingClientRect();
    const maxWidth = window.innerWidth - COL_PICKER_VIEWPORT_PAD * 2;
    const panelWidth = isMobile ? maxWidth : Math.min(COL_PICKER_WIDTH, maxWidth);

    let left = isMobile ? COL_PICKER_VIEWPORT_PAD : rect.left;
    if (!isMobile && left + panelWidth > window.innerWidth - COL_PICKER_VIEWPORT_PAD) {
        left = rect.right - panelWidth;
    }
    left = Math.max(COL_PICKER_VIEWPORT_PAD, Math.min(left, window.innerWidth - COL_PICKER_VIEWPORT_PAD - panelWidth));

    panel.classList.add("is-floating");
    panel.style.width = `${panelWidth}px`;
    panel.style.left = `${left}px`;

    const footer = panel.querySelector(".col-picker-footer");
    const footerHeight = footer?.offsetHeight || 44;
    const panelPadding = 16;
    const topBelow = rect.bottom + COL_PICKER_GAP;
    const availableBelow = window.innerHeight - COL_PICKER_VIEWPORT_PAD - topBelow - footerHeight - panelPadding;
    const availableAbove = rect.top - COL_PICKER_GAP - COL_PICKER_VIEWPORT_PAD - footerHeight - panelPadding;
    const openUp = availableBelow < 160 && availableAbove > availableBelow;

    if (list) {
        list.style.maxHeight = `${Math.max(120, openUp ? availableAbove : availableBelow)}px`;
    }

    if (openUp) {
        const panelHeight = panel.offsetHeight;
        panel.style.top = `${Math.max(COL_PICKER_VIEWPORT_PAD, rect.top - COL_PICKER_GAP - panelHeight)}px`;
        picker.classList.add("opens-up");
    } else {
        panel.style.top = `${topBelow}px`;
        picker.classList.remove("opens-up");
    }
}

function toggleColPicker(open) {
    const picker = document.getElementById("col-picker");
    const panel = document.getElementById("col-picker-panel");
    const toggle = document.getElementById("col-picker-toggle");
    if (!picker || !panel || !toggle) return;

    const shouldOpen = typeof open === "boolean" ? open : !picker.classList.contains("is-open");

    if (!shouldOpen) {
        picker.classList.remove("is-open");
        panel.hidden = true;
        resetColPickerPanelPosition();
        toggle.setAttribute("aria-expanded", "false");
        return;
    }

    picker.classList.add("is-open");
    panel.hidden = false;
    mountColPickerPanel();
    positionColPickerPanel();
    toggle.setAttribute("aria-expanded", "true");
}

function buildColPickerList() {
    const list = document.getElementById("col-picker-list");
    if (!list) return;

    list.innerHTML = COMISSAO_COLUMNS.map(
        (col) => `
            <label class="col-picker-option" data-col="${col.id}">
                <input type="checkbox" value="${col.id}">
                <span>${col.label}</span>
            </label>
        `
    ).join("");

    list.querySelectorAll(".col-picker-option input").forEach((input) => {
        input.addEventListener("change", () => {
            const colId = input.value;
            const nextVisible = input.checked;

            if (!nextVisible && visibleCols.size <= 1) {
                input.checked = true;
                return;
            }

            if (nextVisible) visibleCols.add(colId);
            else visibleCols.delete(colId);

            saveVisibleCols();
            applyColumnVisibility();
        });
    });
}

function initColPicker() {
    loadVisibleCols();
    buildColPickerList();
    applyColumnVisibility();

    const picker = document.getElementById("col-picker");
    const toggle = document.getElementById("col-picker-toggle");
    const defaultBtn = document.getElementById("col-picker-default");
    const allBtn = document.getElementById("col-picker-all");

    toggle?.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        toggleColPicker();
    });

    defaultBtn?.addEventListener("click", (event) => {
        event.stopPropagation();
        setVisibleCols(DEFAULT_VISIBLE_COLS);
    });

    allBtn?.addEventListener("click", (event) => {
        event.stopPropagation();
        setVisibleCols(COMISSAO_COLUMNS.map((col) => col.id));
    });

    document.addEventListener("click", (event) => {
        if (!picker?.classList.contains("is-open")) return;
        if (isColPickerTarget(event.target)) return;
        toggleColPicker(false);
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape") toggleColPicker(false);
    });

    const repositionColPicker = () => {
        if (picker?.classList.contains("is-open")) {
            positionColPickerPanel();
        }
    };

    window.addEventListener("resize", repositionColPicker);
    window.addEventListener("scroll", repositionColPicker, true);
}

function buildComissaoRowCells(item, { includeScreenOnly = true, includePrintOnly = true } = {}) {
    const atrasoClass = item.atraso > 0 ? "col-atraso" : "col-atraso zero";
    const cells = [];

    cells.push(`<td data-col="data">${item.data || "—"}</td>`);

    if (includePrintOnly) {
        cells.push(`<td data-col="emissao" class="print-only-col">${item.emissao || "—"}</td>`);
        cells.push(`<td data-col="vencimento" class="print-only-col">${item.vencimento || "—"}</td>`);
    }

    cells.push(`<td data-col="cliente">${item.cliente || "—"}</td>`);
    cells.push(`<td data-col="duplicata">${item.duplicata || "—"}</td>`);

    if (includePrintOnly) {
        cells.push(`<td data-col="atraso" class="${atrasoClass} print-only-col">${formatAtraso(item.atraso)}</td>`);
    }

    cells.push(`<td data-col="valor" class="col-valor">R$ ${AntorList.formatMoney(item.valorVenda)}</td>`);

    if (includePrintOnly) {
        cells.push(`<td data-col="ipi" class="col-valor print-only-col">R$ ${AntorList.formatMoney(item.ipi)}</td>`);
        cells.push(`<td data-col="percentual" class="col-pct print-only-col">${formatPercentual(item.percentual)}</td>`);
    }

    cells.push(`<td data-col="comissao" class="col-valor">R$ ${AntorList.formatMoney(item.comissao)}</td>`);

    return cells.join("");
}

function groupItemsByRepresentante(items) {
    const groups = new Map();

    items.forEach((item) => {
        const nome = String(item.representante || "—").trim() || "—";
        if (!groups.has(nome)) {
            groups.set(nome, []);
        }
        groups.get(nome).push(item);
    });

    return Array.from(groups.entries()).map(([nome, groupItems]) => ({ nome, items: groupItems }));
}

function parsePrintDate(value) {
    const parts = String(value || "").split("/");
    if (parts.length !== 3) return 0;
    const day = Number(parts[0]);
    const month = Number(parts[1]);
    const year = Number(parts[2]);
    if (!day || !month || !year) return 0;
    return year * 10000 + month * 100 + day;
}

function sortItemsForPrint(items) {
    return [...items].sort((a, b) => {
        const clienteA = String(a.cliente || "—").trim() || "—";
        const clienteB = String(b.cliente || "—").trim() || "—";
        const byCliente = clienteA.localeCompare(clienteB, "pt-BR", { sensitivity: "base" });
        if (byCliente !== 0) return byCliente;
        return parsePrintDate(a.data) - parsePrintDate(b.data);
    });
}

function groupItemsByCliente(items) {
    const groups = [];

    sortItemsForPrint(items).forEach((item) => {
        const nome = String(item.cliente || "—").trim() || "—";
        const last = groups[groups.length - 1];
        if (!last || last.nome !== nome) {
            groups.push({ nome, items: [item] });
            return;
        }
        last.items.push(item);
    });

    return groups;
}

function buildPrintClienteSubtotalRow(cliente, totals) {
    return `
        <tr class="comissao-print-cliente-total">
            <td colspan="6" class="comissao-print-cliente-total-label">Subtotal — ${cliente}</td>
            <td class="col-valor">R$ ${AntorList.formatMoney(totals.venda)}</td>
            <td class="col-valor">R$ ${AntorList.formatMoney(totals.ipi)}</td>
            <td></td>
            <td class="col-valor">R$ ${AntorList.formatMoney(totals.comissao)}</td>
        </tr>
    `;
}

function buildPrintSectionRows(items) {
    return groupItemsByCliente(items)
        .map((clientGroup, groupIndex) => {
            const detailRows = clientGroup.items
                .map((item, itemIndex) => {
                    const rowClass =
                        itemIndex === 0 && groupIndex > 0 ? ' class="comissao-print-cliente-first"' : "";
                    return `<tr${rowClass}>${buildComissaoRowCells(item, { includePrintOnly: true })}</tr>`;
                })
                .join("");
            const subtotalRow = buildPrintClienteSubtotalRow(clientGroup.nome, getPageTotals(clientGroup.items));
            return detailRows + subtotalRow;
        })
        .join("");
}

function buildPrintSectionHtml(group) {
    const totals = getPageTotals(group.items);
    const rows = buildPrintSectionRows(group.items);

    return `
        <section class="comissao-print-section">
            <h3 class="comissao-print-rep-name">${group.nome}</h3>
            <table class="comissao-table comissao-table--print-section">
                ${COMISSAO_PRINT_TABLE_HEAD}
                <tbody>${rows}</tbody>
                <tfoot>
                    <tr>
                        <td colspan="6">Total</td>
                        <td class="col-valor">R$ ${AntorList.formatMoney(totals.venda)}</td>
                        <td class="col-valor">R$ ${AntorList.formatMoney(totals.ipi)}</td>
                        <td></td>
                        <td class="col-valor">R$ ${AntorList.formatMoney(totals.comissao)}</td>
                    </tr>
                </tfoot>
            </table>
        </section>
    `;
}

function renderPrintSections(data) {
    const container = document.getElementById("comissao-print-sections");
    if (!container) return;

    const groups = groupItemsByRepresentante(data.items);
    container.innerHTML = groups.map(buildPrintSectionHtml).join("");
}

function clearPrintSections() {
    const container = document.getElementById("comissao-print-sections");
    if (container) container.innerHTML = "";
}

function getPageTotals(items) {
    return items.reduce(
        (acc, item) => {
            acc.venda += Number(item.valorVenda) || 0;
            acc.ipi += Number(item.ipi) || 0;
            acc.comissao += Number(item.comissao) || 0;
            return acc;
        },
        { venda: 0, ipi: 0, comissao: 0 }
    );
}

function updateComissaoTableFooter(data) {
    const tfoot = document.getElementById("comissao-tfoot");
    const vendaEl = document.getElementById("comissao-tfoot-venda");
    const ipiEl = document.getElementById("comissao-tfoot-ipi");
    const comissaoEl = document.getElementById("comissao-tfoot-comissao");
    if (!tfoot || !vendaEl || !ipiEl || !comissaoEl) return;

    if (!data.items?.length) {
        tfoot.hidden = true;
        return;
    }

    const pageTotals = getPageTotals(data.items);
    tfoot.hidden = false;
    vendaEl.textContent = `R$ ${AntorList.formatMoney(pageTotals.venda)}`;
    ipiEl.textContent = `R$ ${AntorList.formatMoney(pageTotals.ipi)}`;
    comissaoEl.textContent = `R$ ${AntorList.formatMoney(pageTotals.comissao)}`;
}

function updatePrintHeader(data, periodo, scope = "page", range = null) {
    document.getElementById("print-periodo").textContent =
        `${AntorList.formatDateBr(periodo.periodoInicio)} a ${AntorList.formatDateBr(periodo.periodoFim)}`;

    const totalRecords = Number(data.totalRecords) || data.items.length;
    const page = Number(data.page) || 1;
    const totalPages = Number(lastComissaoData?.totalPages) || Number(data.totalPages) || 1;
    const rangeStart = Number(data.rangeStart) || 1;
    const rangeEnd = Number(data.rangeEnd) || data.items.length;
    const repCount = groupItemsByRepresentante(data.items).length;

    let registrosText;
    if (scope === "all") {
        registrosText = `${totalRecords} registro(s)`;
        if (repCount > 1) {
            registrosText += ` · ${repCount} representantes`;
        }
    } else if (scope === "range" && range) {
        registrosText = `${rangeStart}–${rangeEnd} de ${totalRecords} (pág. ${range.from}–${range.to}) · ${data.items.length} registro(s)`;
        if (repCount > 1) {
            registrosText += ` · ${repCount} representantes`;
        }
    } else {
        registrosText = `${data.items.length} registro(s) nesta página`;
        if (repCount > 1) {
            registrosText += ` · ${repCount} representantes`;
        }
        if (totalPages > 1) {
            registrosText = `${rangeStart}–${rangeEnd} de ${totalRecords} (pág. ${page}/${totalPages}) · ${registrosText}`;
        }
    }

    document.getElementById("print-registros").textContent = registrosText;
    document.getElementById("print-emissao").textContent = new Date().toLocaleString("pt-BR");
}

async function executeDownloadComissao(selection = { scope: "page" }) {
    if (comissaoLoading) {
        AntorToast.info("Aguarde o carregamento dos resultados.");
        return;
    }

    const scope = selection.scope || "page";
    const range = selection.range || null;

    if (scope === "range" && !range) {
        AntorToast.error("Intervalo de páginas inválido.");
        return;
    }

    closePrintScopeModal();
    setComissaoLoading(true);

    const downloadBtn = document.getElementById("btn-download");
    if (downloadBtn) {
        downloadBtn.disabled = true;
        downloadBtn.classList.add("is-loading");
    }

    try {
        const exportData = await fetchComissaoForPrint(scope, range);
        if (!exportData?.items?.length) {
            AntorToast.warning("Nenhum registro para exportar.");
            return;
        }

        const fileName = buildComissaoPrintFileName();
        downloadComissaoXlsx(fileName, exportData);
        AntorToast.success("Excel exportado com sucesso.");
    } catch (error) {
        AntorToast.error(error.message || "Não foi possível baixar o Excel.");
    } finally {
        setComissaoLoading(false);
        if (downloadBtn) {
            downloadBtn.disabled = false;
            downloadBtn.classList.remove("is-loading");
        }
    }
}

function confirmExportScope() {
    const selection = getPrintScopeFromUI();
    if (!selection) return;

    if (exportScopeMode === "excel") {
        executeDownloadComissao(selection);
        return;
    }

    executePrintComissao(selection);
}

function handlePrintComissao() {
    openExportScopeModal("print");
}

function handleDownloadComissao() {
    openExportScopeModal("excel");
}

function restoreComissaoAfterPrint() {
    clearPrintSections();

    if (!comissaoPrintSnapshot) return;

    document.getElementById("print-registros").textContent = comissaoPrintSnapshot.printRegistros;
    document.getElementById("comissao-total-venda").textContent = comissaoPrintSnapshot.totalVenda;
    document.getElementById("comissao-total").textContent = comissaoPrintSnapshot.totalComissao;
    document.getElementById("comissao-count").textContent = comissaoPrintSnapshot.count;
    comissaoPrintSnapshot = null;

    if (lastComissaoData) {
        updateComissaoTableFooter(lastComissaoData);
    }
}

function createRepPicker() {
    return AntorRepPicker.create({
        rootId: "rep-picker",
        inputId: "representante",
        toggleId: "rep-picker-toggle",
        panelId: "rep-picker-panel",
        searchId: "rep-picker-search",
        listId: "rep-picker-list",
        countId: "rep-picker-count",
        moreId: "rep-picker-more",
        pageSize: REP_PAGE_SIZE,
        todosLabel: REP_TODOS_LABEL,
        todosValue: REP_TODOS_LABEL,
        todosTitle: "Exibir comissões de todos os representantes",
        fetchPath: "/comissao/representantes",
        emptyMessage: "Nenhum representante encontrado.",
        loadErrorMessage: "Erro ao carregar representantes.",
        countWord: "representante",
        labelFn: repLabel,
        canInteract: () => Boolean(comissaoContext?.canSelectRepresentante),
    });
}

function applyRepresentanteField(context) {
    const input = document.getElementById("representante");
    const picker = document.getElementById("rep-picker");
    const toggle = document.getElementById("rep-picker-toggle");
    const panel = document.getElementById("rep-picker-panel");

    if (!input || !context) return;

    input.classList.remove("is-locked");
    picker?.classList.remove("is-locked");

    if (context.representanteLocked) {
        input.value = context.representanteNome || "";
        input.readOnly = true;
        input.classList.add("is-locked");
        input.placeholder = "Representante vinculado ao usuário";
        picker?.classList.add("is-locked");
        if (panel) panel.hidden = true;
        if (toggle) toggle.hidden = true;
        return;
    }

    input.readOnly = false;
    input.value = REP_TODOS_LABEL;
    input.placeholder = "Selecione o representante...";
    if (toggle) toggle.hidden = false;
    repPicker = createRepPicker();
}

async function initComissaoContext() {
    if (!AntorAPI.requireAuth()) return false;

    try {
        comissaoContext = await AntorAPI.apiFetch("/comissao/context");
        applyRepresentanteField(comissaoContext);
        return true;
    } catch (err) {
        console.error(err);
        if (err.message.includes("autenticado") || err.message.includes("Sessão")) {
            AntorAPI.clearSession();
            AntorAPI.requireAuth();
            return false;
        }
        AntorToast.error(err.message || "Erro ao carregar contexto de comissão.");
        return false;
    }
}

async function loadComissao(page = comissaoPage) {
    if (!AntorAPI.requireAuth()) return;

    const repInput = document.getElementById("representante");
    if (comissaoContext?.canSelectRepresentante && repInput && !repInput.value.trim()) {
        repInput.value = REP_TODOS_LABEL;
    }

    const periodo = getPeriodoFiltro();
    if (periodo.error) {
        comissaoPage = 1;
        renderComissao({ items: [], total: 0, count: 0, totalRecords: 0, totalPages: 0, page: 1 });
        AntorToast.warning(periodo.error);
        return;
    }

    comissaoPage = Math.max(Number(page) || 1, 1);

    const { params, periodo: periodoParams } = buildComissaoParams(comissaoPage, COMISSAO_PAGE_SIZE);
    if (periodoParams.error) {
        comissaoPage = 1;
        renderComissao({ items: [], total: 0, count: 0, totalRecords: 0, totalPages: 0, page: 1 });
        AntorToast.warning(periodoParams.error);
        return;
    }

    setComissaoLoading(true);

    try {
        const data = await AntorAPI.apiFetch(`/comissao?${params.toString()}`);
        comissaoPage = data.page || comissaoPage;
        renderComissao(data);
        applyComissaoSortHeader();
        if (params.get("debug") === "1" && data.meta) {
            console.info("[Comissão] filtros aplicados:", data.meta);
        }
    } catch (err) {
        console.error(err);
        renderComissao({ items: [], total: 0, count: 0, totalRecords: 0, totalPages: 0, page: 1 });
        if (err.message.includes("autenticado") || err.message.includes("Sessão")) {
            AntorAPI.clearSession();
            AntorAPI.requireAuth();
            return;
        }
        AntorToast.error(err.message || "Erro ao carregar comissão.");
    } finally {
        setComissaoLoading(false);
    }
}

document.getElementById("form-filtros")?.addEventListener("submit", (e) => {
    e.preventDefault();
    loadComissao(1);
});

AntorList.bindSortableHeaders(".comissao-table", (index, order) => {
    if (comissaoLoading) return;
    currentSort.field = SORT_KEYS[index] || "data";
    currentSort.order = order;
    loadComissao(1);
});

document.getElementById("comissao-prev")?.addEventListener("click", () => {
    if (comissaoLoading) return;
    if (comissaoPage > 1) {
        loadComissao(comissaoPage - 1);
    }
});

document.getElementById("comissao-next")?.addEventListener("click", () => {
    if (comissaoLoading) return;
    loadComissao(comissaoPage + 1);
});

document.getElementById("comissao-page-input")?.addEventListener("keydown", (event) => {
    if (event.key !== "Enter") return;
    event.preventDefault();
    goToComissaoPage(event.target.value);
});

document.getElementById("comissao-page-input")?.addEventListener("blur", (event) => {
    const totalPages = Number(lastComissaoData?.totalPages) || 1;
    const page = Number.parseInt(String(event.target.value), 10);
    if (!Number.isFinite(page) || page < 1) {
        event.target.value = String(comissaoPage);
        return;
    }
    if (page > totalPages) {
        event.target.value = String(comissaoPage);
    }
});

document.getElementById("btn-imprimir")?.addEventListener("click", () => {
    handlePrintComissao();
});

document.getElementById("comissao-print-modal-close")?.addEventListener("click", closePrintScopeModal);
document.getElementById("comissao-print-modal-cancel")?.addEventListener("click", closePrintScopeModal);
document.getElementById("comissao-print-modal-backdrop")?.addEventListener("click", closePrintScopeModal);
document.getElementById("comissao-print-modal-confirm")?.addEventListener("click", confirmExportScope);

document.getElementById("comissao-print-scope")?.addEventListener("change", (event) => {
    if (event.target.matches('input[name="print-scope"]')) {
        syncPrintScopeRangeFields();
    }
});

document.getElementById("print-scope-range-fields")?.addEventListener("mousedown", (event) => {
    event.stopPropagation();
});

document.getElementById("print-scope-range-fields")?.addEventListener("focusin", () => {
    const rangeOption = document.querySelector('input[name="print-scope"][value="range"]');
    if (rangeOption && !rangeOption.disabled) {
        rangeOption.checked = true;
    }
});

document.getElementById("comissao-print-scope")?.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && !event.target.matches(".comissao-print-range-input")) {
        event.preventDefault();
        confirmExportScope();
    }
});

document.addEventListener("keydown", (event) => {
    const modal = document.getElementById("comissao-print-modal");
    if (event.key === "Escape" && modal && !modal.hidden) {
        closePrintScopeModal();
    }
});

document.getElementById("btn-download")?.addEventListener("click", () => {
    handleDownloadComissao();
});

async function bootstrapComissao() {
    await AntorDatePicker.ready;
    AntorDatePicker.enhanceAll();
    bindPeriodoInputs();
    setDefaultDates();
    initColPicker();
    const ready = await initComissaoContext();
    if (ready) {
        loadComissao();
    }
}

bootstrapComissao();
