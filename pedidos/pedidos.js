const SORT_KEYS = ["cliente", "comerc", "posse", "pedido", "emissao", "valor"];
let currentSort = { field: "emissao", order: "desc" };

function setDefaultDates() {
    const inicio = document.getElementById("periodo-inicio");
    const fim = document.getElementById("periodo-fim");
    if (inicio && !inicio.value) AntorDatePicker.setValue(inicio, AntorList.monthStartISO());
    if (fim && !fim.value) AntorDatePicker.setValue(fim, AntorList.todayISO());
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
            return;
        }
        AntorToast.error(err.message || "Erro ao carregar pedidos.");
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

async function bootstrapPedidos() {
    await Promise.all([AntorDatePicker.ready, AntorSelect.ready]);
    AntorDatePicker.enhanceAll();
    AntorSelect.enhanceAll();
    setDefaultDates();
    loadPedidos();
}

bootstrapPedidos();

/* ── Drawer novo pedido ── */

const drawerOverlay = document.getElementById("pedido-drawer-overlay");
const drawerForm = document.getElementById("form-novo-pedido");
const itensList = document.getElementById("pedido-itens-list");
let itemSeq = 0;

function createPedidoItem() {
    itemSeq += 1;
    const index = itemSeq;
    const el = document.createElement("article");
    el.className = "pedido-item";
    el.dataset.itemIndex = String(index);
    el.innerHTML = `
        <div class="pedido-item-head">
            <span class="pedido-item-num">Item ${index}</span>
            <button type="button" class="btn-item-remove" aria-label="Remover item ${index}">
                <i class="fa-solid fa-trash-can" aria-hidden="true"></i>
            </button>
        </div>
        <div class="pedido-item-grid">
            <div class="campo-drawer">
                <label>Produto</label>
                <div class="input-busca input-busca--pending">
                    <input type="text" name="produto" placeholder="Ref. ou nome do produto" autocomplete="off">
                    <button type="button" class="btn-busca" disabled title="Seleção em breve" tabindex="-1" aria-hidden="true">
                        <i class="fa-solid fa-magnifying-glass"></i>
                    </button>
                </div>
            </div>
            <div class="campo-drawer">
                <label>Cor</label>
                <div class="input-busca input-busca--pending">
                    <input type="text" name="cor" placeholder="Cor do produto" autocomplete="off">
                    <button type="button" class="btn-busca" disabled title="Seleção em breve" tabindex="-1" aria-hidden="true">
                        <i class="fa-solid fa-magnifying-glass"></i>
                    </button>
                </div>
            </div>
            <div class="campo-drawer">
                <label for="item-qtd-${index}">Quantidade</label>
                <input type="number" id="item-qtd-${index}" name="quantidade" min="0" step="1" inputmode="numeric" placeholder="0">
            </div>
            <div class="campo-drawer">
                <label for="item-metros-${index}">Metros</label>
                <input type="number" id="item-metros-${index}" name="metros" min="0" step="0.01" inputmode="decimal" placeholder="0,00">
            </div>
        </div>
    `;
    return el;
}

function renumberPedidoItems() {
    if (!itensList) return;
    const items = itensList.querySelectorAll(".pedido-item");
    items.forEach((item, i) => {
        const num = item.querySelector(".pedido-item-num");
        const removeBtn = item.querySelector(".btn-item-remove");
        if (num) num.textContent = `Item ${i + 1}`;
        if (removeBtn) {
            removeBtn.disabled = items.length <= 1;
            removeBtn.setAttribute("aria-label", `Remover item ${i + 1}`);
        }
    });
}

function updateDrawerTotals() {
    if (!itensList) return;
    const items = itensList.querySelectorAll(".pedido-item");
    let metros = 0;
    let filled = 0;

    items.forEach((item) => {
        const produto = item.querySelector('[name="produto"]')?.value.trim();
        const qtd = Number(item.querySelector('[name="quantidade"]')?.value) || 0;
        const m = Number(item.querySelector('[name="metros"]')?.value) || 0;
        metros += m;
        if (produto || qtd > 0 || m > 0) filled += 1;
    });

    const countEl = document.getElementById("drawer-itens-count");
    const metrosEl = document.getElementById("drawer-metros-total");
    const valorEl = document.getElementById("drawer-valor-total");

    if (countEl) countEl.textContent = String(filled);
    if (metrosEl) metrosEl.textContent = AntorList.formatMoney(metros);
    if (valorEl) valorEl.textContent = AntorList.formatMoney(0);
}

function resetDrawerForm() {
    if (!drawerForm || !itensList) return;
    drawerForm.reset();

    const emissao = document.getElementById("novo-emissao");
    if (emissao) AntorDatePicker.setValue(emissao, AntorList.todayISO());

    itemSeq = 0;
    itensList.innerHTML = "";
    itensList.appendChild(createPedidoItem());
    renumberPedidoItems();
    updateDrawerTotals();
}

function openPedidoDrawer() {
    if (!drawerOverlay) return;
    resetDrawerForm();
    drawerOverlay.hidden = false;
    drawerOverlay.setAttribute("aria-hidden", "false");
    requestAnimationFrame(() => {
        drawerOverlay.classList.add("is-open");
    });
    document.body.classList.add("pedido-drawer-open");
    document.getElementById("novo-cliente")?.focus();
}

function closePedidoDrawer() {
    if (!drawerOverlay) return;
    drawerOverlay.classList.remove("is-open", "is-shake");
    drawerOverlay.setAttribute("aria-hidden", "true");
    document.body.classList.remove("pedido-drawer-open");
    window.setTimeout(() => {
        if (!drawerOverlay.classList.contains("is-open")) {
            drawerOverlay.hidden = true;
        }
    }, 320);
}

function shakeDrawer() {
    if (!drawerOverlay) return;
    drawerOverlay.classList.remove("is-shake");
    void drawerOverlay.offsetWidth;
    drawerOverlay.classList.add("is-shake");
}

document.querySelector(".btn-novo")?.addEventListener("click", openPedidoDrawer);
document.getElementById("pedido-drawer-close")?.addEventListener("click", closePedidoDrawer);
document.getElementById("pedido-drawer-cancel")?.addEventListener("click", closePedidoDrawer);
document.getElementById("pedido-drawer-backdrop")?.addEventListener("click", closePedidoDrawer);

document.getElementById("btn-add-item")?.addEventListener("click", () => {
    if (!itensList) return;
    itensList.appendChild(createPedidoItem());
    renumberPedidoItems();
    updateDrawerTotals();
    const last = itensList.lastElementChild;
    last?.querySelector('[name="produto"]')?.focus();
});

itensList?.addEventListener("click", (e) => {
    const btn = e.target.closest(".btn-item-remove");
    if (!btn || btn.disabled || !itensList) return;
    btn.closest(".pedido-item")?.remove();
    renumberPedidoItems();
    updateDrawerTotals();
});

itensList?.addEventListener("input", (e) => {
    if (e.target.matches('[name="quantidade"], [name="metros"], [name="produto"], [name="cor"]')) {
        updateDrawerTotals();
    }
});

drawerForm?.addEventListener("submit", (e) => {
    e.preventDefault();
    const cliente = document.getElementById("novo-cliente")?.value.trim();
    if (!cliente) {
        AntorToast.warning("Informe o cliente do pedido.");
        document.getElementById("novo-cliente")?.focus();
        shakeDrawer();
        return;
    }
    AntorToast.info("Salvamento disponível em breve. Por enquanto, use o formulário para montar o pedido.");
});

document.addEventListener("keydown", (e) => {
    if (e.key !== "Escape" || drawerOverlay?.hidden || !drawerOverlay?.classList.contains("is-open")) return;
    closePedidoDrawer();
});
