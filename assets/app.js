const moneyFormatter = new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
});

const decimalFormatter = new Intl.NumberFormat("pt-BR", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
});

function formatMoneyBRL(value) {
    return moneyFormatter.format(Number(value) || 0);
}

function formatNumberBR(value) {
    return decimalFormatter.format(Number(value) || 0);
}

function renderStatFinalValue(el, targetValue = null) {
    if (!el) return;

    cancelCounterAnimation(el);

    const raw = targetValue != null ? targetValue : el.dataset.count;
    const value = typeof AntorAPI !== "undefined" ? AntorAPI.parseStatValue(raw) : Number(raw || 0);
    const safeValue = Number.isFinite(value) ? value : 0;
    const format = el.dataset.format || "";
    const prefix = el.dataset.prefix || "";
    const suffix = el.dataset.suffix || "";

    if (format === "currency") {
        el.textContent = formatMoneyBRL(safeValue);
        return;
    }

    if (format === "decimal") {
        el.textContent = prefix + formatNumberBR(safeValue) + suffix;
        return;
    }

    el.textContent = prefix + Math.round(safeValue) + suffix;
}

function animateCounter(el, target, prefix = "", suffix = "", duration = 1400) {
    if (el._counterFrame) {
        cancelAnimationFrame(el._counterFrame);
        el._counterFrame = null;
    }

    const safeTarget = Number(target);
    if (!Number.isFinite(safeTarget)) {
        renderStatFinalValue(el, 0);
        return;
    }

    const format = el.dataset.format || "";
    const start = performance.now();

    function renderValue(current) {
        if (format === "currency") {
            el.textContent = formatMoneyBRL(current);
            return;
        }

        if (format === "decimal") {
            el.textContent = prefix + formatNumberBR(current) + suffix;
            return;
        }

        el.textContent = prefix + Math.round(current) + suffix;
    }

    function tick(now) {
        const progress = Math.min((now - start) / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        const current = safeTarget * eased;

        renderValue(current);

        if (progress < 1) {
            el._counterFrame = requestAnimationFrame(tick);
        } else {
            el._counterFrame = null;
        }
    }

    el._counterFrame = requestAnimationFrame(tick);
}

function cancelCounterAnimation(el) {
    if (!el?._counterFrame) return;
    cancelAnimationFrame(el._counterFrame);
    el._counterFrame = null;
}

window.animateCounter = animateCounter;
window.cancelCounterAnimation = cancelCounterAnimation;
window.renderStatFinalValue = renderStatFinalValue;
window.formatMoneyBRL = formatMoneyBRL;
window.formatNumberBR = formatNumberBR;

if (document.querySelector(".sidebar") && typeof AntorAPI !== "undefined") {
    AntorAPI.requireAuth(AntorAPI.loginPath());
}

if (!document.querySelector(".home-mosaic")) {
    document.querySelectorAll("[data-count]").forEach((el) => {
        const target = parseFloat(el.dataset.count);
        const prefix = el.dataset.prefix || "";
        const suffix = el.dataset.suffix || "";
        animateCounter(el, target, prefix, suffix);
    });
}

function initTopbar() {
    const main = document.querySelector(".main");
    if (!main || !document.querySelector(".sidebar")) return null;

    let topbar = main.querySelector(".app-topbar");
    if (!topbar) {
        topbar = document.createElement("header");
        topbar.className = "app-topbar";
        topbar.innerHTML = `
            <div class="app-topbar-start"></div>
            <div class="app-topbar-actions">
                <div class="app-topbar-actions-inner">
                    <button
                        type="button"
                        class="topbar-icon-btn topbar-icon-btn--muted"
                        data-topbar-notifications
                        aria-label="Notificações (em breve)"
                        title="Notificações em breve"
                    >
                        <i class="fa-regular fa-bell"></i>
                    </button>
                </div>
            </div>
        `;
        main.insertBefore(topbar, main.firstChild);

        topbar.querySelector("[data-topbar-notifications]")?.addEventListener("click", (event) => {
            event.preventDefault();
        });
    }

    ensureTopbarActionsInner(topbar);

    topbar.querySelector("[data-topbar-title]")?.remove();

    return topbar;
}

function ensureTopbarActionsInner(topbar) {
    const actions = topbar?.querySelector(".app-topbar-actions");
    if (!actions) return null;

    let inner = actions.querySelector(".app-topbar-actions-inner");
    if (inner) return inner;

    inner = document.createElement("div");
    inner.className = "app-topbar-actions-inner";
    while (actions.firstChild) {
        inner.appendChild(actions.firstChild);
    }
    actions.appendChild(inner);
    return inner;
}

function initSidebar() {
    const sidebar = document.querySelector(".sidebar");
    const main = document.querySelector(".main");
    if (!sidebar || !main || document.getElementById("sidebar-toggle")) return;

    initTopbar();

    const overlay = document.createElement("div");
    overlay.className = "sidebar-overlay";
    overlay.id = "sidebar-overlay";

    const toggle = document.createElement("button");
    toggle.type = "button";
    toggle.className = "sidebar-toggle";
    toggle.id = "sidebar-toggle";
    toggle.setAttribute("aria-label", "Recolher menu");
    toggle.setAttribute("aria-expanded", "true");
    toggle.innerHTML = '<i class="fa-solid fa-chevron-left"></i>';

    const topbarStart = main.querySelector(".app-topbar-start");
    const appLayout = sidebar.closest(".app-layout") || document.body;

    if (topbarStart) {
        topbarStart.insertBefore(toggle, topbarStart.firstChild);
    } else {
        appLayout.appendChild(toggle);
    }

    appLayout.appendChild(overlay);

    function isMobile() {
        return window.matchMedia("(max-width: 768px)").matches;
    }

    function updateToggleIcon() {
        const icon = toggle.querySelector("i");

        if (isMobile()) {
            if (document.body.classList.contains("sidebar-open")) {
                icon.className = "fa-solid fa-xmark";
                toggle.setAttribute("aria-label", "Fechar menu");
                toggle.setAttribute("aria-expanded", "true");
            } else {
                icon.className = "fa-solid fa-bars";
                toggle.setAttribute("aria-label", "Abrir menu");
                toggle.setAttribute("aria-expanded", "false");
            }
            return;
        }

        if (document.body.classList.contains("sidebar-collapsed")) {
            icon.className = "fa-solid fa-chevron-right";
            toggle.setAttribute("aria-label", "Expandir menu");
            toggle.setAttribute("aria-expanded", "false");
        } else {
            icon.className = "fa-solid fa-chevron-left";
            toggle.setAttribute("aria-label", "Recolher menu");
            toggle.setAttribute("aria-expanded", "true");
        }
    }

    function openMobileSidebar() {
        document.body.classList.add("sidebar-open");
        updateToggleIcon();
    }

    function closeMobileSidebar() {
        document.body.classList.remove("sidebar-open");
        updateToggleIcon();
    }

    function collapseDesktopSidebar() {
        document.body.classList.add("sidebar-collapsed");
        localStorage.setItem("antor-sidebar-collapsed", "1");
        updateToggleIcon();
    }

    function expandDesktopSidebar() {
        document.body.classList.remove("sidebar-collapsed");
        localStorage.setItem("antor-sidebar-collapsed", "0");
        updateToggleIcon();
    }

    toggle.addEventListener("click", () => {
        if (isMobile()) {
            if (document.body.classList.contains("sidebar-open")) {
                closeMobileSidebar();
            } else {
                openMobileSidebar();
            }
            return;
        }

        if (document.body.classList.contains("sidebar-collapsed")) {
            expandDesktopSidebar();
        } else {
            collapseDesktopSidebar();
        }
    });

    overlay.addEventListener("click", closeMobileSidebar);

    document.addEventListener("keydown", (e) => {
        if (e.key === "Escape" && isMobile()) closeMobileSidebar();
    });

    window.addEventListener("resize", () => {
        if (isMobile()) {
            document.body.classList.remove("sidebar-collapsed");
            closeMobileSidebar();
        } else {
            closeMobileSidebar();
            if (localStorage.getItem("antor-sidebar-collapsed") === "1") {
                document.body.classList.add("sidebar-collapsed");
            }
        }
        updateToggleIcon();
    });

    sidebar.querySelectorAll(".sidebar-nav a, .sidebar-footer a").forEach((link) => {
        link.addEventListener("click", () => {
            if (isMobile()) closeMobileSidebar();
        });
    });

    if (!isMobile() && localStorage.getItem("antor-sidebar-collapsed") === "1") {
        document.body.classList.add("sidebar-collapsed");
    }

    updateToggleIcon();
}

initSidebar();

function getUserInitials(name) {
    const parts = String(name || "")
        .trim()
        .split(/\s+/)
        .filter(Boolean);

    if (parts.length === 0) return "?";
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function getAvatarStorageKey(userId) {
    return `antor_avatar_${userId}`;
}

function loadStoredAvatar(userId) {
    if (!userId) return null;
    return localStorage.getItem(getAvatarStorageKey(userId));
}

function saveStoredAvatar(userId, dataUrl) {
    if (!userId) return;
    localStorage.setItem(getAvatarStorageKey(userId), dataUrl);
}

function clearStoredAvatar(userId) {
    if (!userId) return;
    localStorage.removeItem(getAvatarStorageKey(userId));
}

const CROPPER_CDN = "1.6.2";
let cropperAssetsPromise = null;
let activeAvatarCropper = null;
let avatarEditorModal = null;

function loadCropperAssets() {
    if (window.Cropper) return Promise.resolve();
    if (cropperAssetsPromise) return cropperAssetsPromise;

    cropperAssetsPromise = new Promise((resolve, reject) => {
        if (!document.querySelector("[data-antor-cropper-css]")) {
            const link = document.createElement("link");
            link.rel = "stylesheet";
            link.href = `https://cdnjs.cloudflare.com/ajax/libs/cropperjs/${CROPPER_CDN}/cropper.min.css`;
            link.dataset.antorCropperCss = "";
            document.head.appendChild(link);
        }

        if (window.Cropper) {
            resolve();
            return;
        }

        const script = document.createElement("script");
        script.src = `https://cdnjs.cloudflare.com/ajax/libs/cropperjs/${CROPPER_CDN}/cropper.min.js`;
        script.onload = () => resolve();
        script.onerror = () => reject(new Error("Não foi possível carregar o editor de imagem."));
        document.head.appendChild(script);
    });

    return cropperAssetsPromise;
}

function isAvatarEditorOpen() {
    return Boolean(avatarEditorModal && !avatarEditorModal.hidden);
}

function destroyAvatarCropper() {
    if (activeAvatarCropper) {
        activeAvatarCropper.destroy();
        activeAvatarCropper = null;
    }
}

function ensureAvatarEditorModal() {
    if (avatarEditorModal) return avatarEditorModal;

    avatarEditorModal = document.createElement("div");
    avatarEditorModal.className = "avatar-editor-modal";
    avatarEditorModal.hidden = true;
    avatarEditorModal.innerHTML = `
        <div class="avatar-editor-backdrop" data-avatar-editor-close></div>
        <div class="avatar-editor-dialog" role="dialog" aria-modal="true" aria-labelledby="avatar-editor-title">
            <header class="avatar-editor-head">
                <div>
                    <h2 id="avatar-editor-title">Ajustar foto</h2>
                    <p>Recorte, gire e ajuste antes de salvar.</p>
                </div>
                <button type="button" class="avatar-editor-close" data-avatar-editor-close aria-label="Fechar">
                    <i class="fa-solid fa-xmark"></i>
                </button>
            </header>

            <div class="avatar-editor-stage">
                <img data-avatar-editor-image alt="Pré-visualização da foto">
            </div>

            <div class="avatar-editor-toolbar" aria-label="Ferramentas de edição">
                <button type="button" data-avatar-editor-action="rotate-left" title="Girar para a esquerda">
                    <i class="fa-solid fa-rotate-left"></i>
                    <span>Girar</span>
                </button>
                <button type="button" data-avatar-editor-action="rotate-right" title="Girar para a direita">
                    <i class="fa-solid fa-rotate-right"></i>
                    <span>Girar</span>
                </button>
                <button type="button" data-avatar-editor-action="flip-x" title="Espelhar horizontalmente">
                    <i class="fa-solid fa-arrows-left-right"></i>
                    <span>Espelhar</span>
                </button>
                <button type="button" data-avatar-editor-action="zoom-out" title="Diminuir zoom">
                    <i class="fa-solid fa-magnifying-glass-minus"></i>
                    <span>Zoom -</span>
                </button>
                <button type="button" data-avatar-editor-action="zoom-in" title="Aumentar zoom">
                    <i class="fa-solid fa-magnifying-glass-plus"></i>
                    <span>Zoom +</span>
                </button>
                <button type="button" data-avatar-editor-action="reset" title="Restaurar imagem">
                    <i class="fa-solid fa-arrow-rotate-left"></i>
                    <span>Resetar</span>
                </button>
            </div>

            <footer class="avatar-editor-foot">
                <button type="button" class="avatar-editor-btn avatar-editor-btn--ghost" data-avatar-editor-close>Cancelar</button>
                <button type="button" class="avatar-editor-btn avatar-editor-btn--primary" data-avatar-editor-confirm>Usar foto</button>
            </footer>
        </div>
    `;

    document.body.appendChild(avatarEditorModal);

    avatarEditorModal.querySelectorAll("[data-avatar-editor-close]").forEach((btn) => {
        btn.addEventListener("click", closeAvatarEditor);
    });

    avatarEditorModal.querySelector("[data-avatar-editor-confirm]")?.addEventListener("click", confirmAvatarEditor);

    avatarEditorModal.querySelectorAll("[data-avatar-editor-action]").forEach((btn) => {
        btn.addEventListener("click", () => {
            const action = btn.dataset.avatarEditorAction;
            if (!activeAvatarCropper) return;

            if (action === "rotate-left") activeAvatarCropper.rotate(-90);
            if (action === "rotate-right") activeAvatarCropper.rotate(90);
            if (action === "flip-x") {
                const { scaleX } = activeAvatarCropper.getImageData();
                activeAvatarCropper.scaleX(scaleX > 0 ? -1 : 1);
            }
            if (action === "zoom-in") activeAvatarCropper.zoom(0.12);
            if (action === "zoom-out") activeAvatarCropper.zoom(-0.12);
            if (action === "reset") activeAvatarCropper.reset();
        });
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && isAvatarEditorOpen()) {
            event.stopPropagation();
            closeAvatarEditor();
        }
    });

    return avatarEditorModal;
}

function closeAvatarEditor() {
    if (!avatarEditorModal) return;

    destroyAvatarCropper();
    avatarEditorModal.hidden = true;
    avatarEditorModal._onConfirm = null;
    document.body.classList.remove("avatar-editor-open");

    const img = avatarEditorModal.querySelector("[data-avatar-editor-image]");
    img?.removeAttribute("src");
}

function confirmAvatarEditor() {
    if (!activeAvatarCropper || typeof avatarEditorModal?._onConfirm !== "function") {
        closeAvatarEditor();
        return;
    }

    const canvas = activeAvatarCropper.getCroppedCanvas({
        width: 320,
        height: 320,
        imageSmoothingEnabled: true,
        imageSmoothingQuality: "high",
    });

    if (!canvas) return;

    const dataUrl = canvas.toDataURL("image/jpeg", 0.9);
    avatarEditorModal._onConfirm(dataUrl);
    closeAvatarEditor();
}

function openAvatarEditor(dataUrl, onConfirm) {
    return loadCropperAssets().then(() => {
        const modal = ensureAvatarEditorModal();
        const img = modal.querySelector("[data-avatar-editor-image]");

        modal._onConfirm = onConfirm;
        destroyAvatarCropper();

        img.onload = () => {
            destroyAvatarCropper();
            activeAvatarCropper = new window.Cropper(img, {
                aspectRatio: 1,
                viewMode: 1,
                dragMode: "move",
                autoCropArea: 1,
                responsive: true,
                guides: true,
                center: true,
                background: false,
                movable: true,
                zoomable: true,
                zoomOnWheel: true,
                rotatable: true,
                scalable: true,
                cropBoxMovable: true,
                cropBoxResizable: true,
                toggleDragModeOnDblclick: false,
            });
        };

        img.src = dataUrl;
        modal.hidden = false;
        document.body.classList.add("avatar-editor-open");
    });
}

function buildUserProfileElement() {
    const profile = document.createElement("div");
    profile.className = "user-profile";
    profile.dataset.userProfile = "";
    profile.innerHTML = `
        <button type="button" class="user-profile-trigger" data-user-menu-btn aria-label="Menu do usuário" aria-haspopup="menu" aria-expanded="false">
            <span class="user-profile-avatar" data-user-avatar-visual>
                <span class="user-profile-initials" data-user-avatar-initials>--</span>
                <img class="user-profile-photo" data-user-avatar-img alt="">
            </span>
            <span class="user-profile-info">
                <strong data-user-name>Usuário</strong>
                <i class="fa-solid fa-chevron-down user-profile-chevron" aria-hidden="true"></i>
            </span>
        </button>
        <div class="user-profile-menu" data-user-avatar-menu hidden role="menu">
            <button type="button" data-user-avatar-change role="menuitem">
                <i class="fa-solid fa-camera"></i>
                <span data-user-avatar-change-label>Trocar foto</span>
            </button>
            <button type="button" data-user-avatar-remove role="menuitem">
                <i class="fa-solid fa-trash"></i>
                Remover foto
            </button>
            <div class="user-profile-menu-divider" role="separator"></div>
            <button type="button" data-user-logout role="menuitem">
                <i class="fa-solid fa-right-from-bracket"></i>
                Sair
            </button>
        </div>
        <input type="file" accept="image/*" hidden data-user-avatar-input>
    `;
    return profile;
}

function logoutUser(event) {
    event?.preventDefault();
    if (typeof AntorAPI !== "undefined") AntorAPI.clearSession();
    document.body.style.opacity = "0";
    document.body.style.transition = "opacity 0.3s ease";
    setTimeout(() => {
        const loginPath = typeof AntorAPI !== "undefined" ? AntorAPI.loginPath() : "../login/";
        window.location.href = loginPath;
    }, 280);
}

function initUserProfile() {
    if (typeof AntorAPI === "undefined") return;

    const user = AntorAPI.getUser();
    if (!user) return;

    initTopbar();

    const topbarActions = document.querySelector(".app-topbar-actions-inner") || document.querySelector(".app-topbar-actions");
    if (!topbarActions) return;

    document.querySelector(".sidebar-footer [data-user-profile]")?.remove();

    let profile = topbarActions.querySelector("[data-user-profile]");
    if (
        !profile ||
        !profile.querySelector("[data-user-avatar-menu]") ||
        profile.querySelector("[data-user-email]") ||
        !profile.querySelector(".user-profile-chevron") ||
        !profile.querySelector("[data-user-logout]") ||
        !profile.querySelector("[data-user-menu-btn]")
    ) {
        profile?.remove();
        profile = buildUserProfileElement();
        topbarActions.appendChild(profile);
    }

    const nameEl = profile.querySelector("[data-user-name]");
    const initialsEl = profile.querySelector("[data-user-avatar-initials]");
    const imgEl = profile.querySelector("[data-user-avatar-img]");
    const avatarVisual = profile.querySelector("[data-user-avatar-visual]");
    const menuBtn = profile.querySelector("[data-user-menu-btn]");
    const fileInput = profile.querySelector("[data-user-avatar-input]");
    const avatarMenu = profile.querySelector("[data-user-avatar-menu]");
    const changeBtn = profile.querySelector("[data-user-avatar-change]");
    const changeLabel = profile.querySelector("[data-user-avatar-change-label]");
    const removeBtn = profile.querySelector("[data-user-avatar-remove]");
    const logoutBtn = profile.querySelector("[data-user-logout]");

    const displayName = String(user.nome || user.usuario || "Usuário").trim();

    if (nameEl) nameEl.textContent = displayName;
    if (initialsEl) initialsEl.textContent = getUserInitials(displayName);

    function updateAvatarMenuState(hasPhoto) {
        if (changeLabel) {
            changeLabel.textContent = hasPhoto ? "Trocar foto" : "Adicionar foto";
        }
        if (removeBtn) {
            removeBtn.hidden = !hasPhoto;
        }
    }

    function closeAvatarMenu() {
        if (!avatarMenu || !menuBtn) return;
        avatarMenu.hidden = true;
        menuBtn.setAttribute("aria-expanded", "false");
        profile.classList.remove("is-open");
    }

    function openAvatarMenu() {
        if (!avatarMenu || !menuBtn) return;
        avatarMenu.hidden = false;
        menuBtn.setAttribute("aria-expanded", "true");
        profile.classList.add("is-open");
    }

    function toggleAvatarMenu() {
        if (!avatarMenu) return;
        if (avatarMenu.hidden) openAvatarMenu();
        else closeAvatarMenu();
    }

    function applyAvatar(dataUrl) {
        if (!imgEl || !initialsEl || !avatarVisual) return;

        const valid = Boolean(dataUrl && String(dataUrl).startsWith("data:image/"));

        imgEl.onload = () => {
            avatarVisual.classList.add("has-photo");
            updateAvatarMenuState(true);
        };
        imgEl.onerror = () => {
            imgEl.removeAttribute("src");
            avatarVisual.classList.remove("has-photo");
            clearStoredAvatar(user.id);
            updateAvatarMenuState(false);
        };

        if (valid) {
            imgEl.src = dataUrl;
            if (imgEl.complete && imgEl.naturalWidth > 0) {
                avatarVisual.classList.add("has-photo");
                updateAvatarMenuState(true);
            }
        } else {
            imgEl.removeAttribute("src");
            avatarVisual.classList.remove("has-photo");
            updateAvatarMenuState(false);
            if (dataUrl) clearStoredAvatar(user.id);
        }
    }

    function removeAvatar() {
        clearStoredAvatar(user.id);
        applyAvatar(null);
        closeAvatarMenu();
    }

    applyAvatar(loadStoredAvatar(user.id));

    menuBtn?.addEventListener("click", (event) => {
        event.stopPropagation();
        toggleAvatarMenu();
    });

    changeBtn?.addEventListener("click", (event) => {
        event.stopPropagation();
        closeAvatarMenu();
        fileInput?.click();
    });

    removeBtn?.addEventListener("click", (event) => {
        event.stopPropagation();
        removeAvatar();
    });

    logoutBtn?.addEventListener("click", (event) => {
        event.stopPropagation();
        closeAvatarMenu();
        logoutUser(event);
    });

    document.addEventListener("click", (event) => {
        if (!profile.contains(event.target)) closeAvatarMenu();
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape") {
            if (isAvatarEditorOpen()) return;
            closeAvatarMenu();
        }
    });

    fileInput?.addEventListener("change", () => {
        const file = fileInput.files?.[0];
        if (!file) return;

        if (!file.type.startsWith("image/")) {
            fileInput.value = "";
            return;
        }

        const reader = new FileReader();
        reader.onload = () => {
            const dataUrl = String(reader.result || "");
            if (!dataUrl.startsWith("data:image/")) return;

            openAvatarEditor(dataUrl, (editedDataUrl) => {
                saveStoredAvatar(user.id, editedDataUrl);
                applyAvatar(editedDataUrl);
                closeAvatarMenu();
            }).catch((err) => {
                console.error(err);
                saveStoredAvatar(user.id, dataUrl);
                applyAvatar(dataUrl);
                closeAvatarMenu();
            }).finally(() => {
                fileInput.value = "";
            });
        };
        reader.readAsDataURL(file);
    });
}

initUserProfile();

document.getElementById("btn-sair")?.addEventListener("click", logoutUser);

document.querySelectorAll(".sidebar-nav a:not(.active)").forEach((link) => {
    link.addEventListener("click", (e) => {
        if (link.getAttribute("href") === "#") return;
        e.preventDefault();
        document.querySelector(".main")?.classList.add("page-exit");
        setTimeout(() => {
            window.location.href = link.getAttribute("href");
        }, 200);
    });
});

const style = document.createElement("style");
style.textContent = `
    .main.page-exit {
        opacity: 0;
        transform: translateY(8px);
        transition: opacity 0.2s ease, transform 0.2s ease;
    }
`;
document.head.appendChild(style);
