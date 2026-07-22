(function () {
    const instances = new Map();

    function waitForDeps() {
        if (window.React && window.ReactDOM && window.antd && window.dayjs) {
            return Promise.resolve();
        }
        return new Promise((resolve) => {
            window.setTimeout(() => waitForDeps().then(resolve), 30);
        });
    }

    function parseISO(value) {
        if (!value) return null;
        const str = String(value).slice(0, 10);
        if (!/^\d{4}-\d{2}-\d{2}$/.test(str)) return null;
        const parsed = dayjs(str);
        return parsed.isValid() ? parsed : null;
    }

    function toISO(date) {
        return date && date.isValid() ? date.format("YYYY-MM-DD") : "";
    }

    function resolveInput(input) {
        if (typeof input === "string") return document.getElementById(input);
        return input || null;
    }

    function getConstraints(input, options) {
        const minStr = input.getAttribute("min") || options.min || "";
        const maxStr = input.getAttribute("max") || options.max || "";
        return {
            min: parseISO(minStr),
            max: parseISO(maxStr),
        };
    }

    function resolvePopupContainer(input, options) {
        if (typeof options.getPopupContainer === "function") {
            return options.getPopupContainer;
        }
        const selector = input.dataset.popupContainer;
        if (selector) {
            return () => document.querySelector(selector) || document.body;
        }
        return () => document.body;
    }

    function AntorDateField({ record }) {
        const { useState, useEffect, createElement: h } = React;
        const [value, setValue] = useState(() => parseISO(record.input.value));
        const [constraints, setConstraintsState] = useState(() =>
            getConstraints(record.input, record.options)
        );

        useEffect(() => {
            record.api = {
                setValue(iso) {
                    const next = parseISO(iso);
                    setValue(next);
                    record.input.value = iso || "";
                },
                setConstraints(next) {
                    if (next.min !== undefined) {
                        if (next.min) record.input.setAttribute("min", next.min);
                        else record.input.removeAttribute("min");
                    }
                    if (next.max !== undefined) {
                        if (next.max) record.input.setAttribute("max", next.max);
                        else record.input.removeAttribute("max");
                    }
                    setConstraintsState(getConstraints(record.input, record.options));
                },
            };
        }, [record]);

        const { DatePicker, ConfigProvider } = antd;
        const locale = antd.locale?.pt_BR;

        function onChange(date) {
            const iso = toISO(date);
            setValue(date && date.isValid() ? date : null);
            record.input.value = iso;
            record.input.dispatchEvent(new Event("input", { bubbles: true }));
            record.input.dispatchEvent(new Event("change", { bubbles: true }));
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
            h(DatePicker, {
                value: value && value.isValid() ? value : null,
                onChange,
                format: "DD/MM/YYYY",
                placeholder: record.options.placeholder || "Selecione a data",
                allowClear: record.options.allowClear ?? !record.input.required,
                disabledDate(current) {
                    if (!current) return false;
                    if (constraints.min && current.isBefore(constraints.min, "day")) return true;
                    if (constraints.max && current.isAfter(constraints.max, "day")) return true;
                    return false;
                },
                getPopupContainer: record.options.getPopupContainer,
                style: { width: "100%" },
                inputReadOnly: true,
            })
        );
    }

    function enhance(input, options = {}) {
        input = resolveInput(input);
        if (!input || input.dataset.antorDateEnhanced === "true") {
            return instances.get(input?.id)?.api || null;
        }

        const placeholder =
            options.placeholder ||
            input.dataset.datePlaceholder ||
            input.getAttribute("placeholder") ||
            "Selecione a data";

        const record = {
            input,
            options: {
                ...options,
                placeholder,
                getPopupContainer: resolvePopupContainer(input, options),
            },
            root: null,
            api: null,
        };

        const wrap = document.createElement("div");
        wrap.className = "antor-date-wrap";
        const mount = document.createElement("div");
        mount.className = "antor-date-mount";

        input.type = "hidden";
        input.dataset.antorDateEnhanced = "true";
        input.parentNode.insertBefore(wrap, input);
        wrap.appendChild(mount);
        wrap.appendChild(input);

        record.root = ReactDOM.createRoot(mount);
        record.root.render(React.createElement(AntorDateField, { record }));
        instances.set(input.id, record);

        return record.api;
    }

    function enhanceAll(selector = 'input[type="date"]') {
        document.querySelectorAll(selector).forEach((input) => enhance(input));
    }

    function setValue(input, iso) {
        input = resolveInput(input);
        if (!input) return;
        input.value = iso || "";
        instances.get(input.id)?.api?.setValue(iso || "");
    }

    function setConstraints(input, constraints) {
        input = resolveInput(input);
        if (!input) return;
        instances.get(input.id)?.api?.setConstraints(constraints || {});
    }

    if (window.dayjs) {
        dayjs.locale("pt-br");
    }

    window.AntorDatePicker = {
        ready: waitForDeps().then(() => {
            if (window.dayjs) dayjs.locale("pt-br");
        }),
        enhance,
        enhanceAll,
        setValue,
        setConstraints,
    };
})();
