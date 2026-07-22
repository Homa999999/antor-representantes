const SORT_KEYS = ["emissao", "duplicata", "vencimento", "valor", "saldo", "pagamento", "pago", "atraso"];

const REP_PAGE_SIZE = 20;

const CLIENT_PAGE_SIZE = 20;

const REP_TODOS_LABEL = "Todos";

const CLIENT_TODOS_LABEL = "Todos os clientes";



let currentSort = { field: "vencimento", order: "asc" };

let financeiroContext = null;

let repPicker = null;

let clientPicker = null;



function getRepresentanteFiltroValue() {

    const input = document.getElementById("representante");

    if (financeiroContext?.representanteLocked) {

        return input?.value.trim() || financeiroContext.representanteNome || "";

    }

    if (financeiroContext?.canSelectRepresentante) {

        return input?.value.trim() || REP_TODOS_LABEL;

    }

    return input?.value.trim() || "";

}



function renderFinanceiro(data) {

    const tbody = document.getElementById("financeiro-tbody");

    const table = document.querySelector(".financeiro-table");

    const empty = document.getElementById("table-empty");

    if (!tbody || !table || !empty) return;



    tbody.innerHTML = "";



    if (data.error && !data.items?.length) {

        table.classList.remove("has-rows");

        empty.classList.remove("hidden");

        empty.querySelector("p").textContent = data.error;

        empty.querySelector("small").textContent = "Selecione um representante válido.";

    } else if (!data.items.length) {

        table.classList.remove("has-rows");

        empty.classList.remove("hidden");

        empty.querySelector("p").textContent = "Nenhum registro encontrado.";

        empty.querySelector("small").textContent = "Ajuste os filtros e tente novamente.";

    } else {

        table.classList.add("has-rows");

        empty.classList.add("hidden");



        data.items.forEach((item) => {

            const tr = document.createElement("tr");

            const atrasoClass = item.atraso > 0 ? " class=\"col-atraso\"" : "";

            tr.innerHTML = `

                <td>${AntorList.formatDateBr(item.emissao)}</td>

                <td>${item.duplicata || "—"}</td>

                <td>${AntorList.formatDateBr(item.vencimento)}</td>

                <td class="col-valor">${AntorList.formatMoney(item.valor)}</td>

                <td class="col-valor">${AntorList.formatMoney(item.saldo)}</td>

                <td>${AntorList.formatDateBr(item.pagamento)}</td>

                <td class="col-valor">${AntorList.formatMoney(item.pago)}</td>

                <td${atrasoClass}>${item.atraso > 0 ? `${item.atraso}d` : "—"}</td>

            `;

            tbody.appendChild(tr);

        });

    }



    document.getElementById("financeiro-registros").textContent = `${data.count || 0} registros`;

    document.getElementById("financeiro-count").textContent = `${data.count || 0} registro(s).`;

    document.getElementById("total-valor").textContent = `R$ ${AntorList.formatMoney(data.total?.valor || 0)}`;

    document.getElementById("total-saldo").textContent = `R$ ${AntorList.formatMoney(data.total?.saldo || 0)}`;

    document.getElementById("total-pago").textContent = `R$ ${AntorList.formatMoney(data.total?.pago || 0)}`;

}



function createFinanceiroRepPicker() {

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

        todosTitle: "Exibir financeiro de todos os representantes",

        fetchPath: "/financeiro/representantes",

        emptyMessage: "Nenhum representante encontrado.",

        loadErrorMessage: "Erro ao carregar representantes.",

        countWord: "representante",

        canInteract: () => Boolean(financeiroContext?.canSelectRepresentante),

        onOpenChange: (open) => {

            if (open) clientPicker?.setOpen(false);

        },

        onSelect: () => {

            clientPicker?.reset({ inputValue: "", clearInput: true });

            clientPicker?.fetchPage({ reset: true });

        },

    });

}



function createFinanceiroClientPicker() {

    return AntorRepPicker.create({

        rootId: "client-picker",

        inputId: "cliente",

        toggleId: "client-picker-toggle",

        panelId: "client-picker-panel",

        searchId: "client-picker-search",

        listId: "client-picker-list",

        countId: "client-picker-count",

        moreId: "client-picker-more",

        pageSize: CLIENT_PAGE_SIZE,

        todosLabel: CLIENT_TODOS_LABEL,

        todosValue: "",

        todosTitle: "Exibir todos os clientes do representante selecionado",

        fetchPath: "/financeiro/clientes",

        emptyMessage: "Nenhum cliente encontrado.",

        loadErrorMessage: "Erro ao carregar clientes.",

        countWord: "cliente",

        extraParams: () => ({

            representante: getRepresentanteFiltroValue(),

        }),

        onOpenChange: (open) => {

            if (open) repPicker?.setOpen(false);

        },

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

    repPicker = createFinanceiroRepPicker();

}



async function initFinanceiroContext() {

    if (!AntorAPI.requireAuth()) return false;



    try {

        financeiroContext = await AntorAPI.apiFetch("/financeiro/context");

        applyRepresentanteField(financeiroContext);

        clientPicker = createFinanceiroClientPicker();

        return true;

    } catch (err) {

        console.error(err);

        if (err.message.includes("autenticado") || err.message.includes("Sessão")) {

            AntorAPI.clearSession();

            AntorAPI.requireAuth();

            return;

        }

        AntorToast.error(err.message || "Erro ao carregar contexto do financeiro.");

        return false;

    }

}



async function loadFinanceiro() {

    if (!AntorAPI.requireAuth()) return;



    const repInput = document.getElementById("representante");

    if (financeiroContext?.canSelectRepresentante && repInput && !repInput.value.trim()) {

        repInput.value = REP_TODOS_LABEL;

    }



    const form = document.getElementById("form-filtros");

    const params = AntorList.formToQuery(form);

    params.set("sort", currentSort.field);

    params.set("order", currentSort.order);



    try {

        const data = await AntorAPI.apiFetch(`/financeiro?${params.toString()}`);

        renderFinanceiro(data);

    } catch (err) {

        console.error(err);

        if (err.message.includes("autenticado") || err.message.includes("Sessão")) {

            AntorAPI.clearSession();

            AntorAPI.requireAuth();

            return;

        }

        AntorToast.error(err.message || "Erro ao carregar financeiro.");

    }

}



document.getElementById("form-filtros")?.addEventListener("submit", (e) => {

    e.preventDefault();

    loadFinanceiro();

});



AntorList.bindSortableHeaders(".financeiro-table", (index, order) => {

    currentSort.field = SORT_KEYS[index] || "vencimento";

    currentSort.order = order;

    loadFinanceiro();

});



async function bootstrapFinanceiro() {
    await Promise.all([AntorDatePicker.ready, AntorSelect.ready]);
    AntorDatePicker.enhanceAll();
    AntorSelect.enhanceAll();

    const ready = await initFinanceiroContext();

    if (ready) {

        loadFinanceiro();

    }

}



bootstrapFinanceiro();

