function setDefaultDates() {
    const inicio = document.getElementById("periodo-inicio");
    const fim = document.getElementById("periodo-fim");
    if (inicio) inicio.value = `${new Date().getFullYear()}-01-01`;
    if (fim) fim.value = AntorList.todayISO();
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
    }

    document.getElementById("comissao-registros").textContent = `${data.count} registros`;
    document.getElementById("comissao-count").textContent = `${data.count} registro(s).`;
    document.getElementById("comissao-total").textContent = `R$ ${AntorList.formatMoney(data.total)}`;
}

async function loadComissao() {
    if (!AntorAPI.requireAuth()) return;

    const form = document.getElementById("form-filtros");
    const params = AntorList.formToQuery(form);

    try {
        const data = await AntorAPI.apiFetch(`/comissao?${params.toString()}`);
        renderComissao(data);
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
    loadComissao();
});

document.querySelectorAll(".btn-busca").forEach((btn) => {
    btn.addEventListener("click", () => {
        btn.closest(".input-busca")?.querySelector("input")?.focus();
    });
});

document.getElementById("btn-imprimir")?.addEventListener("click", () => {
    window.print();
});

setDefaultDates();
loadComissao();
