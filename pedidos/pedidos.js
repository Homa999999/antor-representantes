const SORT_KEYS = ["cliente", "comerc", "posse", "pedido", "emissao", "valor"];
let currentSort = { field: "emissao", order: "desc" };

function setDefaultDates() {
    const inicio = document.getElementById("periodo-inicio");
    const fim = document.getElementById("periodo-fim");
    if (inicio && !inicio.value) inicio.value = AntorList.monthStartISO();
    if (fim && !fim.value) fim.value = AntorList.todayISO();
}

function renderPedidos(data) {
    const tbody = document.getElementById("pedidos-tbody");
    const table = document.querySelector(".pedidos-table");
    const empty = document.getElementById("table-empty");
    if (!tbody || !table || !empty) return;

    tbody.innerHTML = "";

    if (!data.items.length) {
        table.classList.remove("has-rows");
        empty.classList.remove("hidden");
    } else {
        table.classList.add("has-rows");
        empty.classList.add("hidden");

        data.items.forEach((item) => {
            const tr = document.createElement("tr");
            tr.innerHTML = `
                <td>${item.cliente || "—"}</td>
                <td>${item.comerciante || "—"}</td>
                <td>${item.posse || "—"}</td>
                <td>${item.pedido || "—"}</td>
                <td>${AntorList.formatDateBr(item.emissao)}</td>
                <td class="col-valor">${AntorList.formatMoney(item.valor)}</td>
                <td class="col-acoes">
                    <button type="button" class="btn-acao btn-acao-print" title="Imprimir" aria-label="Imprimir">
                        <i class="fa-solid fa-print"></i>
                    </button>
                    <button type="button" class="btn-acao btn-acao-edit" title="Editar" aria-label="Editar">
                        <i class="fa-solid fa-pen"></i>
                    </button>
                </td>
            `;
            tbody.appendChild(tr);
        });
    }

    document.getElementById("pedidos-registros").textContent = `${data.count} registros`;
    document.getElementById("pedidos-count").textContent = `${data.count} pedido(s).`;
    document.getElementById("pedidos-total").textContent = AntorList.formatMoney(data.total);
}

async function loadPedidos() {
    if (!AntorAPI.requireAuth()) return;

    const form = document.getElementById("form-filtros");
    const params = AntorList.formToQuery(form);
    params.set("sort", currentSort.field);
    params.set("order", currentSort.order);

    try {
        const data = await AntorAPI.apiFetch(`/pedidos?${params.toString()}`);
        renderPedidos(data);
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
    loadPedidos();
});

document.querySelectorAll(".btn-busca").forEach((btn) => {
    btn.addEventListener("click", () => {
        btn.closest(".input-busca")?.querySelector("input")?.focus();
    });
});

AntorList.bindSortableHeaders(".pedidos-table", (index, order) => {
    currentSort.field = SORT_KEYS[index] || "emissao";
    currentSort.order = order;
    loadPedidos();
});

setDefaultDates();
loadPedidos();
