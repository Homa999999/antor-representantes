const VENDAS_WIDGET_SELECTORS = [
    "[data-widget='vendas-ano-mt']",
    "[data-widget='vendas-ano-rs']",
    "[data-widget='vendas-mes-mt']",
    "[data-widget='vendas-mes-rs']",
];

function maskStatValue(el) {
    const format = el.dataset.format || "";
    const suffix = el.dataset.suffix || "";

    if (format === "currency") return "R$ ••••••";
    if (suffix.trim() === "mt") return "•••••• mt";
    return "••••••";
}

function renderStatCard(el, { animate = false } = {}) {
    if (!el) return;

    if (AntorAPI.areVendasValuesHidden()) {
        window.cancelCounterAnimation?.(el);
        el.textContent = maskStatValue(el);
        el.classList.add("is-masked");
        return;
    }

    el.classList.remove("is-masked");

    const value = AntorAPI.parseStatValue(el.dataset.count);
    const prefix = el.dataset.prefix || "";
    const suffix = el.dataset.suffix || "";

    if (el.dataset.loaded !== "1") {
        window.renderStatFinalValue?.(el, value);
        return;
    }

    if (animate) {
        window.animateCounter?.(el, value, prefix, suffix);
        return;
    }

    window.renderStatFinalValue?.(el, value);
}

function refreshVendasWidgets({ animate = false } = {}) {
    VENDAS_WIDGET_SELECTORS.forEach((selector) => {
        const el = document.querySelector(selector);
        if (el) renderStatCard(el, { animate });
    });
}

function setStatCard(selector, value, { prefix = "", suffix = "", format = "" } = {}) {
    const el = document.querySelector(selector);
    if (!el) return;

    el.dataset.count = String(value ?? 0);
    el.dataset.prefix = prefix;
    el.dataset.suffix = suffix;
    if (format) {
        el.dataset.format = format;
    } else {
        delete el.dataset.format;
    }
    el.dataset.loaded = "1";
    renderStatCard(el, { animate: !AntorAPI.areVendasValuesHidden() });
}

function updateValuesToggleButton(btn) {
    if (!btn) return;

    const hidden = AntorAPI.areVendasValuesHidden();
    const icon = btn.querySelector("i");

    btn.setAttribute("aria-pressed", hidden ? "true" : "false");
    btn.setAttribute("aria-label", hidden ? "Exibir valores" : "Ocultar valores");
    btn.title = hidden ? "Exibir valores" : "Ocultar valores";

    if (icon) {
        icon.className = hidden ? "fa-regular fa-eye-slash" : "fa-regular fa-eye";
    }
}

function toggleVendasValuesVisibility() {
    AntorAPI.setVendasValuesHidden(!AntorAPI.areVendasValuesHidden());
    updateValuesToggleButton(document.querySelector("[data-values-toggle]"));
    refreshVendasWidgets({ animate: false });
}

function initValuesToggle() {
    const btn = document.querySelector("[data-values-toggle]");
    if (!btn) return;

    localStorage.removeItem("antor_vendas_values_hidden");

    updateValuesToggleButton(btn);

    if (btn.dataset.bound !== "1") {
        btn.addEventListener("click", toggleVendasValuesVisibility);
        btn.dataset.bound = "1";
    }

    refreshVendasWidgets({ animate: false });
}

const DONUT_CIRCUMFERENCE = 251;

function updateDonut(meta) {
    const percent = Number(meta?.percent || 0);
    const concluidos = Number(meta?.concluidos || 0);
    const abertos = Number(meta?.abertos || 0);
    const total = Number(meta?.total || 0);

    const badge = document.querySelector("[data-widget='meta-badge']");
    const center = document.querySelector("[data-widget='meta-percent']");
    const mes = document.querySelector("[data-widget='meta-mes']");
    const fill = document.querySelector(".donut-fill");
    const legendDone = document.querySelector("[data-widget='meta-concluidos']");
    const legendPending = document.querySelector("[data-widget='meta-abertos']");
    const progressLabel = document.querySelector("[data-widget='meta-progress-label']");
    const progressBar = document.querySelector("[data-widget='meta-progress-bar']");

    if (mes) mes.textContent = meta?.mesLabel || "Mês atual";
    if (badge) badge.textContent = `${percent}%`;
    if (center) center.textContent = `${percent}%`;
    if (legendDone) legendDone.textContent = `${concluidos} concluídos`;
    if (legendPending) legendPending.textContent = `${abertos} em aberto`;
    if (progressLabel) progressLabel.textContent = `${concluidos} de ${total}`;
    if (progressBar) progressBar.style.width = `${percent}%`;

    if (fill) {
        fill.style.strokeDasharray = String(DONUT_CIRCUMFERENCE);
        fill.style.strokeDashoffset = String(DONUT_CIRCUMFERENCE - (DONUT_CIRCUMFERENCE * percent) / 100);
        fill.style.animation = "none";
    }
}

function formatUltimaAtualizacao(info) {
    if (!info?.ano || !info?.mes) return null;

    const mesReferencia = new Date(info.ano, info.mes - 1, 1);
    if (Number.isNaN(mesReferencia.getTime())) return null;

    const mesLabel = new Intl.DateTimeFormat("pt-BR", {
        month: "long",
        year: "numeric",
    })
        .format(mesReferencia)
        .replace(/^\w/, (c) => c.toUpperCase());

    if (info.dataHora) {
        const dataHora = new Date(info.dataHora);
        if (Number.isNaN(dataHora.getTime())) {
            return `Última atualização referente a ${mesLabel}`;
        }

        const dataLabel = new Intl.DateTimeFormat("pt-BR", {
            day: "2-digit",
            month: "long",
            year: "numeric",
        })
            .format(dataHora)
            .replace(/^\w/, (c) => c.toUpperCase());

        const hora = new Intl.DateTimeFormat("pt-BR", {
            hour: "2-digit",
            minute: "2-digit",
        }).format(dataHora);

        return `Última atualização em ${dataLabel} às ${hora}`;
    }

    return `Última atualização referente a ${mesLabel}`;
}

function updateUltimaAtualizacao(info) {
    const badge = document.querySelector("[data-widget='vendas-atualizado']");
    const textEl = document.querySelector("[data-widget='vendas-atualizado-text']");
    const formatted = formatUltimaAtualizacao(info);

    if (!badge || !textEl) return;

    if (!formatted) {
        badge.hidden = true;
        return;
    }

    textEl.textContent = formatted;
    badge.hidden = false;
}

function applyDashboard(data) {
    const vendas = data?.vendas || {};

    updateUltimaAtualizacao(vendas.ultimaAtualizacao);

    setStatCard("[data-widget='vendas-ano-mt']", vendas.vendasAnoMt, { suffix: " mt", format: "decimal" });
    setStatCard("[data-widget='vendas-ano-rs']", vendas.vendasAnoRs, { format: "currency" });
    setStatCard("[data-widget='vendas-mes-mt']", vendas.vendasMesMt, { suffix: " mt", format: "decimal" });
    setStatCard("[data-widget='vendas-mes-rs']", vendas.vendasMesRs, { format: "currency" });

    updateDonut(data?.meta || {});
    updateValuesToggleButton(document.querySelector("[data-values-toggle]"));
}

async function loadHomeDashboard() {
    if (!AntorAPI.requireAuth()) return;

    const mosaic = document.querySelector(".home-mosaic");
    if (mosaic) mosaic.classList.add("is-loading");

    try {
        const data = await AntorAPI.apiFetch("/dashboard/home");
        applyDashboard(data);
    } catch (err) {
        console.error(err);
        if (err.message.includes("autenticado") || err.message.includes("Sessão")) {
            AntorAPI.clearSession();
            AntorAPI.requireAuth();
        }
    } finally {
        mosaic?.classList.remove("is-loading");
    }
}

function bootstrapHome() {
    initValuesToggle();
    loadHomeDashboard();
}

if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bootstrapHome);
} else {
    bootstrapHome();
}
