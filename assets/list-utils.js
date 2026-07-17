function formatMoney(value) {
    return Number(value || 0).toLocaleString("pt-BR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
    });
}

function formatDateBr(value) {
    if (!value) return "—";
    const [y, m, d] = String(value).slice(0, 10).split("-");
    if (!y || !m || !d) return "—";
    return `${d}/${m}/${y}`;
}

function monthStartISO(date = new Date()) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    return `${y}-${m}-01`;
}

function todayISO(date = new Date()) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
}

function monthEndISO(date = new Date()) {
    const end = new Date(date.getFullYear(), date.getMonth() + 1, 0);
    return todayISO(end);
}

function formToQuery(form) {
    const data = new FormData(form);
    const params = new URLSearchParams();
    for (const [key, value] of data.entries()) {
        if (String(value).trim()) params.set(key, String(value).trim());
    }
    return params;
}

function bindSortableHeaders(tableSelector, onSort) {
    const table = document.querySelector(tableSelector);
    if (!table) return;

    table.querySelectorAll("thead th.sortable").forEach((th, index) => {
        th.addEventListener("click", () => {
            table.querySelectorAll("thead th.sortable").forEach((h) => {
                if (h !== th) h.classList.remove("sorted-asc", "sorted-desc");
            });

            let order = "asc";
            if (th.classList.contains("sorted-asc")) {
                th.classList.remove("sorted-asc");
                th.classList.add("sorted-desc");
                order = "desc";
            } else if (th.classList.contains("sorted-desc")) {
                th.classList.remove("sorted-desc");
                order = "asc";
            } else {
                th.classList.add("sorted-asc");
                order = "asc";
            }

            onSort(index, order, th);
        });
    });
}

window.AntorList = {
    formatMoney,
    formatDateBr,
    monthStartISO,
    todayISO,
    monthEndISO,
    formToQuery,
    bindSortableHeaders,
};
