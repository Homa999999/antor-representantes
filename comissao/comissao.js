let comissaoContext = null;
let repPicker = null;
let comissaoPage = 1;

const REP_PAGE_SIZE = 20;
const COMISSAO_PAGE_SIZE = 30;

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

    inicio.addEventListener("change", () => {
        clampPeriodoInput(inicio, `${new Date().getFullYear()}-01-01`);
        if (inicio.value > fim.value) {
            fim.value = inicio.value;
        }
        fim.min = inicio.value;
    });

    fim.addEventListener("change", () => {
        clampPeriodoInput(fim, max);
        if (fim.value < inicio.value) {
            inicio.value = fim.value;
        }
        inicio.max = fim.value;
    });
}

function setDefaultDates() {
    const inicio = document.getElementById("periodo-inicio");
    const fim = document.getElementById("periodo-fim");
    const anoInicio = `${new Date().getFullYear()}-01-01`;
    const hoje = AntorList.todayISO();

    if (inicio) inicio.value = clampPeriodoInput(inicio, anoInicio);
    if (fim) fim.value = clampPeriodoInput(fim, hoje);
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

function renderComissaoPagination(data) {
    const nav = document.getElementById("comissao-pagination");
    const info = document.getElementById("comissao-pagination-info");
    const current = document.getElementById("comissao-page-current");
    const prevBtn = document.getElementById("comissao-prev");
    const nextBtn = document.getElementById("comissao-next");

    if (!nav || !info || !current || !prevBtn || !nextBtn) return;

    const totalRecords = Number(data.totalRecords) || 0;
    const totalPages = Number(data.totalPages) || 0;
    const page = Number(data.page) || 1;

    if (!totalRecords || totalPages <= 1) {
        nav.hidden = true;
        return;
    }

    nav.hidden = false;
    info.textContent = `Mostrando ${data.rangeStart}-${data.rangeEnd} de ${totalRecords} registros`;
    current.textContent = `Página ${page} de ${totalPages}`;
    prevBtn.disabled = page <= 1;
    nextBtn.disabled = page >= totalPages;
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
            empty.querySelector("p").textContent = "Selecione um representante para pesquisar.";
            empty.querySelector("small").textContent = "Busque e escolha na lista de representantes.";
        } else {
            empty.querySelector("p").textContent = "Nenhum registro encontrado.";
            empty.querySelector("small").textContent = "Ajuste os filtros e tente novamente.";
        }
    } else {
        table.classList.add("has-rows");
        empty.classList.add("hidden");

        data.items.forEach((item) => {
            const tr = document.createElement("tr");
            tr.innerHTML = `
                <td>${item.representante || "—"}</td>
                <td>${item.periodo || "—"}</td>
                <td class="col-valor">R$ ${AntorList.formatMoney(item.comissao)}</td>
            `;
            tbody.appendChild(tr);
        });

        renderComissaoPagination(data);
    }

    const totalRecords = Number(data.totalRecords) || data.count || 0;
    document.getElementById("comissao-registros").textContent = `${totalRecords} registros`;
    document.getElementById("comissao-count").textContent = `${totalRecords} registro(s).`;
    document.getElementById("comissao-total").textContent = `R$ ${AntorList.formatMoney(data.total)}`;
}

function createRepPicker() {
    const root = document.getElementById("rep-picker");
    const input = document.getElementById("representante");
    const toggle = document.getElementById("rep-picker-toggle");
    const panel = document.getElementById("rep-picker-panel");
    const searchInput = document.getElementById("rep-picker-search");
    const list = document.getElementById("rep-picker-list");
    const countEl = document.getElementById("rep-picker-count");
    const loadMoreBtn = document.getElementById("rep-picker-more");

    if (!root || !input || !panel || !list) return null;

    const state = {
        open: false,
        query: "",
        offset: 0,
        total: 0,
        hasMore: false,
        loading: false,
        items: [],
        debounceTimer: null,
    };

    function setOpen(open) {
        state.open = open;
        panel.hidden = !open;
        input.setAttribute("aria-expanded", open ? "true" : "false");
        root.classList.toggle("is-open", open);
        toggle?.querySelector("i")?.classList.toggle("fa-chevron-down", !open);
        toggle?.querySelector("i")?.classList.toggle("fa-chevron-up", open);
    }

    function updateCount() {
        if (!countEl) return;
        const loaded = state.items.length;
        if (state.total === 0) {
            countEl.textContent = "Nenhum representante encontrado";
            return;
        }
        countEl.textContent = `${loaded} de ${state.total} representante(s)`;
    }

    function renderList(append = false) {
        if (!append) {
            list.innerHTML = "";
        }

        if (!state.items.length && !state.loading) {
            const empty = document.createElement("li");
            empty.className = "rep-picker-empty";
            empty.textContent = "Nenhum representante encontrado.";
            list.appendChild(empty);
            return;
        }

        const startIndex = append ? list.querySelectorAll(".rep-picker-option").length : 0;
        state.items.slice(startIndex).forEach((item) => {
            const label = repLabel(item);
            const li = document.createElement("li");
            li.className = "rep-picker-option";
            li.role = "option";
            li.dataset.label = label;
            li.textContent = label;
            if (item.nome && item.nome !== label) {
                li.title = item.nome;
            }

            if (input.value.trim() === label) {
                li.classList.add("is-selected");
            }

            li.addEventListener("click", () => {
                input.value = label;
                setOpen(false);
                list.querySelectorAll(".rep-picker-option.is-selected").forEach((el) => {
                    el.classList.remove("is-selected");
                });
                li.classList.add("is-selected");
            });

            list.appendChild(li);
        });

        if (loadMoreBtn) {
            loadMoreBtn.hidden = !state.hasMore;
            loadMoreBtn.disabled = state.loading;
            loadMoreBtn.textContent = state.loading ? "Carregando..." : "Carregar mais";
        }

        updateCount();
    }

    async function fetchPage({ reset = false } = {}) {
        if (state.loading) return;

        if (reset) {
            state.offset = 0;
            state.items = [];
            list.innerHTML = `<li class="rep-picker-loading">Carregando...</li>`;
        } else if (loadMoreBtn) {
            loadMoreBtn.disabled = true;
            loadMoreBtn.textContent = "Carregando...";
        }

        state.loading = true;

        try {
            const params = new URLSearchParams({
                limit: String(REP_PAGE_SIZE),
                offset: String(state.offset),
            });
            if (state.query.trim()) {
                params.set("q", state.query.trim());
            }

            const data = await AntorAPI.apiFetch(`/comissao/representantes?${params.toString()}`);
            const newItems = data.items || [];

            if (reset) {
                state.items = newItems;
            } else {
                state.items = state.items.concat(newItems);
            }

            state.total = data.total || 0;
            state.hasMore = Boolean(data.hasMore);
            state.offset = data.nextOffset ?? state.items.length;
        } catch (err) {
            console.error(err);
            if (reset) {
                list.innerHTML = `<li class="rep-picker-empty">Erro ao carregar representantes.</li>`;
            }
            state.loading = false;
            if (loadMoreBtn) {
                loadMoreBtn.disabled = false;
                loadMoreBtn.textContent = "Carregar mais";
            }
            return;
        }

        state.loading = false;
        renderList(!reset);
    }

    function scheduleSearch() {
        clearTimeout(state.debounceTimer);
        state.debounceTimer = setTimeout(() => {
            fetchPage({ reset: true });
        }, 300);
    }

    toggle?.addEventListener("click", (event) => {
        event.preventDefault();
        event.stopPropagation();
        const willOpen = !state.open;
        setOpen(willOpen);
        if (willOpen) {
            searchInput?.focus();
            if (!state.items.length) {
                fetchPage({ reset: true });
            }
        }
    });

    input.addEventListener("focus", () => {
        if (!comissaoContext?.canSelectRepresentante) return;
        setOpen(true);
        if (!state.items.length) {
            fetchPage({ reset: true });
        }
    });

    input.addEventListener("input", () => {
        if (!comissaoContext?.canSelectRepresentante) return;
        state.query = input.value;
        setOpen(true);
        scheduleSearch();
    });

    searchInput?.addEventListener("input", () => {
        state.query = searchInput.value;
        scheduleSearch();
    });

    searchInput?.addEventListener("keydown", (event) => {
        if (event.key === "Escape") {
            setOpen(false);
            input.focus();
        }
    });

    loadMoreBtn?.addEventListener("click", () => {
        if (!state.hasMore || state.loading) return;
        fetchPage({ reset: false });
    });

    list.addEventListener("scroll", () => {
        if (!state.hasMore || state.loading) return;
        const nearBottom = list.scrollTop + list.clientHeight >= list.scrollHeight - 24;
        if (nearBottom) {
            fetchPage({ reset: false });
        }
    });

    document.addEventListener("click", (event) => {
        if (!root.contains(event.target)) {
            setOpen(false);
        }
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && state.open) {
            setOpen(false);
        }
    });

    return {
        reset() {
            state.query = "";
            state.offset = 0;
            state.total = 0;
            state.hasMore = false;
            state.items = [];
            if (searchInput) searchInput.value = "";
            setOpen(false);
            list.innerHTML = "";
            updateCount();
        },
    };
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
    input.value = "";
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
        }
        return false;
    }
}

async function loadComissao(page = comissaoPage) {
    if (!AntorAPI.requireAuth()) return;

    if (comissaoContext?.canSelectRepresentante && !document.getElementById("representante")?.value.trim()) {
        comissaoPage = 1;
        renderComissao({ items: [], total: 0, count: 0, totalRecords: 0, totalPages: 0, page: 1 });
        return;
    }

    const periodo = getPeriodoFiltro();
    if (periodo.error) {
        comissaoPage = 1;
        renderComissao({ items: [], total: 0, count: 0, totalRecords: 0, totalPages: 0, page: 1 });
        alert(periodo.error);
        return;
    }

    comissaoPage = Math.max(Number(page) || 1, 1);

    const form = document.getElementById("form-filtros");
    const params = AntorList.formToQuery(form);
    params.set("periodo_inicio", periodo.periodoInicio);
    params.set("periodo_fim", periodo.periodoFim);
    params.set("page", String(comissaoPage));
    params.set("limit", String(COMISSAO_PAGE_SIZE));

    try {
        const data = await AntorAPI.apiFetch(`/comissao?${params.toString()}`);
        comissaoPage = data.page || comissaoPage;
        renderComissao(data);
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
        alert(err.message || "Erro ao carregar comissão.");
    }
}

document.getElementById("form-filtros")?.addEventListener("submit", (e) => {
    e.preventDefault();
    loadComissao(1);
});

document.getElementById("comissao-prev")?.addEventListener("click", () => {
    if (comissaoPage > 1) {
        loadComissao(comissaoPage - 1);
    }
});

document.getElementById("comissao-next")?.addEventListener("click", () => {
    loadComissao(comissaoPage + 1);
});

document.getElementById("btn-imprimir")?.addEventListener("click", () => {
    window.print();
});

async function bootstrapComissao() {
    bindPeriodoInputs();
    setDefaultDates();
    const ready = await initComissaoContext();
    if (ready) {
        loadComissao();
    }
}

bootstrapComissao();
