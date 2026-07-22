(function () {
    const instances = new Map();

    function waitForDeps() {
        if (window.React && window.ReactDOM && window.antd) {
            return Promise.resolve();
        }
        return new Promise((resolve) => {
            window.setTimeout(() => waitForDeps().then(resolve), 30);
        });
    }

    function resolveSelect(select) {
        if (typeof select === "string") return document.getElementById(select);
        return select || null;
    }

    function readOptions(select) {
        return Array.from(select.options).map((option) => ({
            value: option.value,
            label: option.textContent.trim(),
            disabled: option.disabled,
        }));
    }

    function resolvePopupContainer(select, options) {
        if (typeof options.getPopupContainer === "function") {
            return options.getPopupContainer;
        }
        const selector = select.dataset.popupContainer;
        if (selector) {
            return () => document.querySelector(selector) || document.body;
        }
        return () => document.body;
    }

    function normalizeValue(value, allowEmpty) {
        if (value == null) return allowEmpty ? undefined : "";
        if (allowEmpty && value === "") return undefined;
        return value;
    }

    function AntorSelectField({ record }) {
        const { useState, useEffect, createElement: h } = React;
        const allowEmpty = record.options.allowEmpty;
        const [value, setValue] = useState(() =>
            normalizeValue(record.select.value, allowEmpty)
        );

        useEffect(() => {
            record.api = {
                setValue(next) {
                    const normalized = normalizeValue(next, allowEmpty);
                    setValue(normalized);
                    record.select.value =
                        normalized === undefined || normalized === null ? "" : String(normalized);
                },
            };
        }, [record, allowEmpty]);

        const { Select, ConfigProvider } = antd;
        const locale = antd.locale?.pt_BR;

        function onChange(next) {
            const normalized = normalizeValue(next, allowEmpty);
            setValue(normalized);
            record.select.value =
                normalized === undefined || normalized === null ? "" : String(normalized);
            record.select.dispatchEvent(new Event("input", { bubbles: true }));
            record.select.dispatchEvent(new Event("change", { bubbles: true }));
        }

        return h(
            ConfigProvider,
            {
                locale,
                theme: {
                    token: {
                        colorPrimary: "#e6b800",
                        borderRadius: 10,
                        controlHeight: 40,
                        fontFamily: "'Plus Jakarta Sans', sans-serif",
                    },
                },
            },
            h(Select, {
                value: value,
                onChange,
                options: record.options.items,
                placeholder: record.options.placeholder,
                allowClear: record.options.allowClear,
                disabled: record.select.disabled,
                getPopupContainer: record.options.getPopupContainer,
                optionFilterProp: "label",
                showSearch: record.options.showSearch,
                style: { width: "100%" },
            })
        );
    }

    function enhance(select, options = {}) {
        select = resolveSelect(select);
        if (!select || select.tagName !== "SELECT" || select.dataset.antorSelectEnhanced === "true") {
            return instances.get(select?.id)?.api || null;
        }

        if (select.dataset.antorNative === "true") {
            return null;
        }

        const items = readOptions(select);
        const hasEmptyOption = items.some((item) => item.value === "");
        const placeholder =
            options.placeholder ||
            select.dataset.selectPlaceholder ||
            (hasEmptyOption ? items.find((item) => item.value === "")?.label : "") ||
            "Selecione";

        const selectOptions = hasEmptyOption
            ? items.filter((item) => item.value !== "")
            : items;

        const record = {
            select,
            options: {
                ...options,
                items: selectOptions,
                placeholder,
                allowEmpty: hasEmptyOption,
                allowClear: options.allowClear ?? hasEmptyOption,
                showSearch: options.showSearch ?? selectOptions.length > 6,
                getPopupContainer: resolvePopupContainer(select, options),
            },
            root: null,
            api: null,
        };

        const wrap = document.createElement("div");
        wrap.className = "antor-select-wrap";
        const mount = document.createElement("div");
        mount.className = "antor-select-mount";

        select.hidden = true;
        select.dataset.antorSelectEnhanced = "true";
        select.parentNode.insertBefore(wrap, select);
        wrap.appendChild(mount);
        wrap.appendChild(select);

        record.root = ReactDOM.createRoot(mount);
        record.root.render(React.createElement(AntorSelectField, { record }));
        instances.set(select.id, record);

        return record.api;
    }

    function enhanceAll(selector = "select:not([data-antor-native])") {
        document.querySelectorAll(selector).forEach((select) => enhance(select));
    }

    function setValue(select, value) {
        select = resolveSelect(select);
        if (!select) return;
        select.value = value == null ? "" : String(value);
        instances.get(select.id)?.api?.setValue(value);
    }

    window.AntorSelect = {
        ready: waitForDeps(),
        enhance,
        enhanceAll,
        setValue,
    };
})();
