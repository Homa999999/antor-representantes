const SORT_KEYS = ["emissao", "duplicata", "vencimento", "valor", "saldo", "pagamento", "pago", "atraso"];
let currentSort = { field: "vencimento", order: "asc" };

function renderFinanceiro(data) {
    const tbody = document.getElementById("financeiro-tbody");
    const table = document.querySelector(".financeiro-table");
    const empty = document.getElementById("table-empty");
    if (!tbody || !table || !empty) return;

    tbody.innerHTML = "";

    if (data.requiresCliente) {
        table.classList.remove("has-rows");
        empty.classList.remove("hidden");
        empty.querySelector("p").textContent = "Informe um cliente para pesquisar.";
        empty.querySelector("small").textContent = "Representantes logados podem pesquisar sem cliente.";
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

    document.getElementById("financeiro-registros").textContent = `${data.count} registros`;
    document.getElementById("financeiro-count").textContent = `${data.count} registro(s).`;
    document.getElementById("total-valor").textContent = `R$ ${AntorList.formatMoney(data.total?.valor || 0)}`;
    document.getElementById("total-saldo").textContent = `R$ ${AntorList.formatMoney(data.total?.saldo || 0)}`;
    document.getElementById("total-pago").textContent = `R$ ${AntorList.formatMoney(data.total?.pago || 0)}`;
}

async function loadFinanceiro() {
    if (!AntorAPI.requireAuth()) return;

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
        }
    }
}

document.getElementById("form-filtros")?.addEventListener("submit", (e) => {
    e.preventDefault();
    loadFinanceiro();
});

document.querySelectorAll(".btn-busca").forEach((btn) => {
    btn.addEventListener("click", () => {
        btn.closest(".input-busca")?.querySelector("input")?.focus();
    });
});

AntorList.bindSortableHeaders(".financeiro-table", (index, order) => {
    currentSort.field = SORT_KEYS[index] || "vencimento";
    currentSort.order = order;
    loadFinanceiro();
});

loadFinanceiro();
