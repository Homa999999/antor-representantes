(function () {
    function itemLabel(item) {
        return String(item?.label || item?.na || item?.nome || "").trim();
    }

    function createRepPicker(config) {
        const root = document.getElementById(config.rootId);
        const input = document.getElementById(config.inputId);
        const toggle = document.getElementById(config.toggleId);
        const panel = document.getElementById(config.panelId);
        const searchInput = document.getElementById(config.searchId);
        const list = document.getElementById(config.listId);
        const countEl = document.getElementById(config.countId);
        const loadMoreBtn = document.getElementById(config.moreId);

        if (!root || !input || !panel || !list) return null;

        const pageSize = config.pageSize || 20;
        const todosLabel = config.todosLabel ?? null;
        const todosValue = config.todosValue ?? todosLabel ?? "";
        const todosTitle = config.todosTitle || "";
        const emptyMessage = config.emptyMessage || "Nenhum item encontrado.";
        const loadErrorMessage = config.loadErrorMessage || "Erro ao carregar lista.";
        const countWord = config.countWord || "item";

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
            if (typeof config.onOpenChange === "function") {
                config.onOpenChange(open);
            }
            toggle?.querySelector("i")?.classList.toggle("fa-chevron-down", !open);
            toggle?.querySelector("i")?.classList.toggle("fa-chevron-up", open);
        }

        function updateCount() {
            if (!countEl) return;
            const loaded = state.items.length;
            if (state.total === 0) {
                countEl.textContent = `Nenhum ${countWord} encontrado`;
                return;
            }
            countEl.textContent = `${loaded} de ${state.total} ${countWord}(s)`;
        }

        function appendTodosOption() {
            if (!todosLabel || state.query.trim()) return;

            const li = document.createElement("li");
            li.className = "rep-picker-option rep-picker-option-all";
            li.role = "option";
            li.dataset.label = todosValue;
            li.textContent = todosLabel;
            if (todosTitle) li.title = todosTitle;

            const current = input.value.trim();
            const selected =
                todosValue === ""
                    ? !current
                    : current.toLowerCase() === String(todosValue).trim().toLowerCase();

            if (selected) {
                li.classList.add("is-selected");
            }

            li.addEventListener("click", () => {
                input.value = todosValue;
                setOpen(false);
                list.querySelectorAll(".rep-picker-option.is-selected").forEach((el) => {
                    el.classList.remove("is-selected");
                });
                li.classList.add("is-selected");
                if (typeof config.onSelect === "function") {
                    config.onSelect(todosValue, null);
                }
            });

            list.appendChild(li);
        }

        function renderList(append = false) {
            if (!append) {
                list.innerHTML = "";
                appendTodosOption();
            }

            if (!state.items.length && !state.loading) {
                if (!state.query.trim()) return;
                const empty = document.createElement("li");
                empty.className = "rep-picker-empty";
                empty.textContent = emptyMessage;
                list.appendChild(empty);
                return;
            }

            const startIndex = append
                ? list.querySelectorAll(".rep-picker-option:not(.rep-picker-option-all)").length
                : 0;

            state.items.slice(startIndex).forEach((item) => {
                const label = typeof config.labelFn === "function" ? config.labelFn(item) : itemLabel(item);
                const li = document.createElement("li");
                li.className = "rep-picker-option";
                li.role = "option";
                li.dataset.label = label;
                li.textContent = label;
                if (item?.nome && item.nome !== label) {
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
                    if (typeof config.onSelect === "function") {
                        config.onSelect(label, item);
                    }
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
                    limit: String(pageSize),
                    offset: String(state.offset),
                });

                if (state.query.trim()) {
                    params.set("q", state.query.trim());
                }

                if (typeof config.extraParams === "function") {
                    const extra = config.extraParams();
                    if (extra && typeof extra === "object") {
                        Object.entries(extra).forEach(([key, value]) => {
                            if (value !== undefined && value !== null && String(value).trim() !== "") {
                                params.set(key, String(value).trim());
                            }
                        });
                    }
                }

                const url =
                    typeof config.buildUrl === "function"
                        ? config.buildUrl(params)
                        : `${config.fetchPath}?${params.toString()}`;

                const data = await AntorAPI.apiFetch(url);
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
                    list.innerHTML = `<li class="rep-picker-empty">${loadErrorMessage}</li>`;
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

        function canInteract() {
            return typeof config.canInteract === "function" ? config.canInteract() : true;
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
            if (!canInteract()) return;
            setOpen(true);
            if (!state.items.length) {
                fetchPage({ reset: true });
            }
        });

        input.addEventListener("input", () => {
            if (!canInteract()) return;
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
            setOpen,
            fetchPage,
            reset(options = {}) {
                state.query = "";
                state.offset = 0;
                state.total = 0;
                state.hasMore = false;
                state.items = [];
                if (searchInput) searchInput.value = "";
                if (options.clearInput !== false) {
                    input.value = options.inputValue ?? "";
                }
                setOpen(false);
                list.innerHTML = "";
                updateCount();
            },
        };
    }

    window.AntorRepPicker = {
        create: createRepPicker,
        itemLabel,
    };
})();
