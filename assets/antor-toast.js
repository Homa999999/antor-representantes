(function () {
    const queue = [];
    let toastApi = null;
    let initFailed = false;

    function fallback(message) {
        if (typeof message !== "string" || !message.trim()) return;
        if (typeof alert === "function") alert(message);
    }

    function dispatch(type, message, options) {
        if (!message) return;

        if (!toastApi || initFailed) {
            fallback(message);
            return;
        }

        try {
            if (type === "message") {
                toastApi(message, options);
            } else if (typeof toastApi[type] === "function") {
                toastApi[type](message, options);
            } else {
                toastApi(message, options);
            }
        } catch (error) {
            console.error("[AntorToast]", error);
            fallback(message);
        }
    }

    function enqueue(type, message, options) {
        if (toastApi && !initFailed) {
            dispatch(type, message, options);
            return;
        }
        queue.push([type, message, options]);
    }

    function flushQueue() {
        while (queue.length) {
            const [type, message, options] = queue.shift();
            dispatch(type, message, options);
        }
    }

    window.AntorToast = {
        ready: null,
        success(message, options) {
            enqueue("success", message, options);
        },
        error(message, options) {
            enqueue("error", message, options);
        },
        warning(message, options) {
            enqueue("warning", message, options);
        },
        info(message, options) {
            enqueue("info", message, options);
        },
        message(message, options) {
            enqueue("message", message, options);
        },
    };

    window.AntorToast.ready = (async () => {
        const React = (await import("https://esm.sh/react@18.3.1")).default;
        const { createRoot } = await import("https://esm.sh/react-dom@18.3.1/client");
        const { Toaster, toast } = await import("https://esm.sh/sonner@2.0.7");

        const host = document.createElement("div");
        host.id = "antor-sonner-host";
        document.body.appendChild(host);

        createRoot(host).render(
            React.createElement(Toaster, {
                position: "top-right",
                richColors: true,
                closeButton: true,
                duration: 4000,
                expand: false,
                gap: 10,
                visibleToasts: 5,
            })
        );

        toastApi = toast;
        flushQueue();
        return toast;
    })().catch((error) => {
        initFailed = true;
        console.error("[AntorToast] Sonner indisponível:", error);
        flushQueue();
        return null;
    });
})();
